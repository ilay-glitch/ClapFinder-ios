package com.appcentral.guarddog.guard

import android.content.Context
import android.hardware.SensorManager
import android.os.PowerManager
import android.os.SystemClock
import android.util.Log
import com.appcentral.guarddog.alarm.AlarmResponder
import com.appcentral.guarddog.core.AnalyticsClient
import com.appcentral.guarddog.core.Events
import com.appcentral.guarddog.core.Guard
import com.appcentral.guarddog.core.PocketGuardLogic
import com.appcentral.guarddog.core.Sensitivity
import com.appcentral.guarddog.core.TouchGuardLogic
import com.appcentral.guarddog.data.Prefs
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/**
 * Process-wide owner of both guard modes. Main-thread confined.
 *
 * Wraps the pure state machines with the impure parts: sensors, the alarm, chirps,
 * notifications, analytics, and the foreground service that keeps the process
 * sensing with the screen off. Modes are mutually exclusive — arming one disarms
 * the other.
 */
class GuardEngine(
    private val context: Context,
    private val prefs: Prefs,
    private val analytics: AnalyticsClient,
    private val scope: CoroutineScope,
) {
    enum class Mode(val key: String) { TOUCH("touch"), POCKET("pocket") }

    data class TouchUi(
        val state: TouchGuardLogic.State = TouchGuardLogic.State.DISARMED,
        val graceRemaining: Int = 0,
        val armedGuard: Guard? = null,
    )

    data class PocketUi(
        val state: PocketGuardLogic.State = PocketGuardLogic.State.DISARMED,
        val armedGuard: Guard? = null,
    )

    sealed interface ArmResult {
        data object Armed : ArmResult
        data object NoSensor : ArmResult
    }

    private val touch = TouchGuardLogic()
    private val pocket = PocketGuardLogic()
    private val responder = AlarmResponder(context, scope)
    private val sensorManager = context.getSystemService(SensorManager::class.java)
    private val motion = MotionSource(sensorManager, ::onMotionSample)
    private val proximity = ProximitySource(sensorManager, ::onProximity)

    private val _touchUi = MutableStateFlow(TouchUi())
    val touchUi: StateFlow<TouchUi> = _touchUi.asStateFlow()

    private val _pocketUi = MutableStateFlow(PocketUi())
    val pocketUi: StateFlow<PocketUi> = _pocketUi.asStateFlow()

    private var armedGuard: Guard? = null
    /** Blanks the screen and disables touch while the sensor is covered — pocket fabric can't tap the UI. */
    private val pocketScreenLock: PowerManager.WakeLock? =
        context.getSystemService(PowerManager::class.java).let { pm ->
            if (pm.isWakeLockLevelSupported(PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK)) {
                pm.newWakeLock(PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK, "GuardDog:pocket")
                    .apply { setReferenceCounted(false) }
            } else {
                null
            }
        }
    private var ticker: Job? = null
    private var alarmNotifications: Job? = null

    /** Called when a session completes (user disarm from MONITORING, either mode). */
    var onSessionCompleted: (() -> Unit)? = null

    val activeMode: Mode?
        get() = when {
            touch.isActive -> Mode.TOUCH
            pocket.isActive -> Mode.POCKET
            else -> null
        }

    val isAnyActive: Boolean get() = activeMode != null

    // region Don't Touch

    fun armTouch(guard: Guard, sensitivity: Sensitivity): ArmResult {
        if (touch.isActive) return ArmResult.Armed
        if (!motion.isAvailable) return ArmResult.NoSensor
        if (pocket.isActive) disarmPocket()
        armedGuard = guard
        touch.arm(sensitivity, now())
        if (!motion.start()) {
            touch.disarm()
            armedGuard = null
            return ArmResult.NoSensor
        }
        sessionStarted(Mode.TOUCH)
        analytics.log(Events.touchArmed(sensitivity))
        startTicker()
        publishTouch()
        return ArmResult.Armed
    }

    /** @return the state disarmed from (MONITORING = a completed session). */
    fun disarmTouch(chirp: Boolean = true): TouchGuardLogic.State {
        if (!touch.isActive) return TouchGuardLogic.State.DISARMED
        val nowMs = now()
        val armedFor = touch.secondsSinceArmed(nowMs)
        val sensitivity = touch.sensitivity
        val previous = touch.disarm()
        motion.stop()
        stopAlarm()
        if (chirp) responder.chirp()
        analytics.log(Events.touchDisarmed(sensitivity, previous == TouchGuardLogic.State.ALARMING, armedFor))
        if (previous == TouchGuardLogic.State.MONITORING) onSessionCompleted?.invoke()
        sessionEnded()
        publishTouch()
        return previous
    }

    private fun onMotionSample(magnitudeG: Double) = handleTouchEvent(touch.onSample(magnitudeG, now()))

    private fun handleTouchEvent(event: TouchGuardLogic.Event?) {
        when (event) {
            TouchGuardLogic.Event.MONITORING_STARTED -> responder.chirp()
            TouchGuardLogic.Event.ALARM -> {
                analytics.log(Events.touchTriggered(touch.sensitivity, touch.secondsSinceArmed(now())))
                startAlarm(withNotifications = true)
            }
            null -> Unit
        }
        if (event != null) publishTouch()
    }

    // endregion

    // region Pocket Mode

    fun armPocket(guard: Guard): ArmResult {
        if (pocket.isActive) return ArmResult.Armed
        if (!proximity.isAvailable) return ArmResult.NoSensor
        if (touch.isActive) disarmTouch()
        armedGuard = guard
        pocket.arm(now())
        if (!proximity.start()) {
            pocket.disarm()
            armedGuard = null
            return ArmResult.NoSensor
        }
        pocketScreenLock?.acquire(MAX_POCKET_SCREEN_LOCK_MS)
        sessionStarted(Mode.POCKET)
        analytics.log(Events.pocketArmed())
        startTicker()
        publishPocket()
        return ArmResult.Armed
    }

    fun disarmPocket(chirp: Boolean = true): PocketGuardLogic.State {
        if (!pocket.isActive) return PocketGuardLogic.State.DISARMED
        val armedFor = pocket.secondsSinceArmed(now())
        val previous = pocket.disarm()
        proximity.stop()
        pocketScreenLock?.let { if (it.isHeld) it.release() }
        stopAlarm()
        if (chirp) responder.chirp()
        analytics.log(Events.pocketDisarmed(previous == PocketGuardLogic.State.ALARMING, armedFor))
        if (previous == PocketGuardLogic.State.MONITORING) onSessionCompleted?.invoke()
        sessionEnded()
        publishPocket()
        return previous
    }

    private fun onProximity(covered: Boolean) {
        pocket.setCovered(covered, now())
        handlePocketEvent(pocket.evaluate(now()))
    }

    private fun handlePocketEvent(event: PocketGuardLogic.Event?) {
        when (event) {
            PocketGuardLogic.Event.ENGAGED -> {
                responder.chirp() // audible through the fabric
                analytics.log(Events.pocketEngaged())
            }
            PocketGuardLogic.Event.ALARM -> {
                analytics.log(Events.pocketAlarm())
                startAlarm(withNotifications = false)
            }
            null -> Unit
        }
        if (event != null) publishPocket()
    }

    // endregion

    // region Shared

    /** Disarms whichever mode is active (notification action). */
    fun disarmActive() {
        when (activeMode) {
            Mode.TOUCH -> disarmTouch()
            Mode.POCKET -> disarmPocket()
            null -> Unit
        }
    }

    /**
     * The session died underneath us (service destroyed, sensor lost). Quiet states
     * stand down loudly; a sounding alarm is never silenced by chaos.
     */
    fun standDown(reason: String) {
        val mode = activeMode ?: return
        if (touch.state == TouchGuardLogic.State.ALARMING || pocket.state == PocketGuardLogic.State.ALARMING) {
            Log.w(TAG, "Stand-down ($reason) ignored while alarming")
            return
        }
        Log.w(TAG, "Stand-down: $reason")
        when (mode) {
            Mode.TOUCH -> disarmTouch(chirp = false)
            Mode.POCKET -> {
                analytics.log(Events.pocketStandDown(reason))
                disarmPocket(chirp = false)
            }
        }
        Notifications.postStandDown(context)
    }

    private fun startAlarm(withNotifications: Boolean) {
        armedGuard?.let(responder::start)
        if (withNotifications) {
            // Now, +5 s, +10 s. Disarm cancels the unfired ones and removes the delivered one.
            alarmNotifications = scope.launch {
                repeat(ALARM_NOTIFICATION_COUNT) { index ->
                    if (index > 0) delay(ALARM_NOTIFICATION_SPACING_MS)
                    Notifications.postAlarm(context)
                }
            }
        }
        GuardService.refresh(context)
    }

    private fun stopAlarm() {
        responder.stop()
        alarmNotifications?.cancel()
        alarmNotifications = null
        Notifications.cancelAlarm(context)
    }

    private fun sessionStarted(mode: Mode) {
        prefs.activeSession = mode.key
        GuardService.start(context)
    }

    private fun sessionEnded() {
        armedGuard = null
        ticker?.cancel()
        ticker = null
        prefs.activeSession = null
        GuardService.stop(context)
    }

    /** Drives grace expiry and debounce deadlines even when no sensor event arrives. */
    private fun startTicker() {
        ticker?.cancel()
        ticker = scope.launch {
            while (isActive) {
                delay(TICK_MS)
                val nowMs = now()
                if (touch.isActive) {
                    val before = _touchUi.value.graceRemaining
                    val event = touch.tick(nowMs)
                    handleTouchEvent(event)
                    if (event == null && touch.graceRemainingSeconds(nowMs) != before) {
                        publishTouch()
                        GuardService.refresh(context)
                    }
                }
                if (pocket.isActive) handlePocketEvent(pocket.evaluate(nowMs))
            }
        }
    }

    private fun publishTouch() {
        _touchUi.value = TouchUi(
            state = touch.state,
            graceRemaining = touch.graceRemainingSeconds(now()),
            armedGuard = if (touch.isActive) armedGuard else null,
        )
        GuardService.refresh(context)
    }

    private fun publishPocket() {
        _pocketUi.value = PocketUi(
            state = pocket.state,
            armedGuard = if (pocket.isActive) armedGuard else null,
        )
        GuardService.refresh(context)
    }

    private fun now() = SystemClock.elapsedRealtime()

    // endregion

    private companion object {
        const val TAG = "GuardEngine"
        const val TICK_MS = 100L
        const val ALARM_NOTIFICATION_COUNT = 3
        const val ALARM_NOTIFICATION_SPACING_MS = 5_000L
        const val MAX_POCKET_SCREEN_LOCK_MS = 12 * 60 * 60 * 1000L
    }
}
