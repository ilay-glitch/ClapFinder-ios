package com.appcentral.guarddog.guard

import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import com.appcentral.guarddog.GuardDogApp
import com.appcentral.guarddog.R
import com.appcentral.guarddog.core.PocketGuardLogic
import com.appcentral.guarddog.core.TouchGuardLogic

/**
 * Foreground service that keeps an armed session alive with the screen off — the
 * Android replacement for iOS's silent-audio keep-alive (ANDROID_HANDOFF §4.4).
 *
 * It owns no guard logic: [GuardEngine] does the work; this holds the process in
 * the foreground, keeps the CPU awake for sensor delivery, and shows the ongoing
 * status notification with a disarm action (the Live Activity equivalent, §1.2).
 *
 * If the system destroys it while a guard is armed, the engine stands down loudly.
 */
class GuardService : Service() {

    private var wakeLock: PowerManager.WakeLock? = null
    private var stoppingNormally = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        stoppingNormally = false
        if (intent?.action == ACTION_DISARM) {
            engine().disarmActive()
            return START_NOT_STICKY
        }
        val engine = engine()
        if (!engine.isAnyActive) {
            // Restarted with nothing armed (e.g. a stale start): don't linger.
            stopSelf()
            return START_NOT_STICKY
        }
        ServiceCompat.startForeground(
            this,
            Notifications.ID_ONGOING,
            buildNotification(),
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            } else {
                0
            },
        )
        acquireWakeLock()
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        if (instance === this) instance = null
        NotificationManagerCompat.from(this).cancel(Notifications.ID_ONGOING)
        if (!stoppingNormally) engine().standDown("service_destroyed")
        super.onDestroy()
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        // Non-wake-up sensors stop delivering when the SoC sleeps; armed sessions are
        // user-bounded, so hold a partial lock for their duration.
        wakeLock = getSystemService(PowerManager::class.java)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "GuardDog:guard")
            .apply {
                setReferenceCounted(false)
                acquire(MAX_SESSION_MS)
            }
    }

    private fun updateNotification() {
        if (stoppingNormally || !Notifications.canPost(this)) return
        try {
            NotificationManagerCompat.from(this).notify(Notifications.ID_ONGOING, buildNotification())
        } catch (_: SecurityException) {
        }
    }

    private fun buildNotification(): Notification {
        val engine = engine()
        val touch = engine.touchUi.value
        val pocket = engine.pocketUi.value
        val status = when (engine.activeMode) {
            GuardEngine.Mode.TOUCH -> when (touch.state) {
                TouchGuardLogic.State.GRACE -> getString(R.string.notif_grace, touch.graceRemaining)
                TouchGuardLogic.State.ALARMING -> getString(R.string.touch_status_alarming)
                else -> getString(R.string.touch_status_monitoring)
            }
            GuardEngine.Mode.POCKET -> when (pocket.state) {
                PocketGuardLogic.State.AWAITING_POCKET -> getString(R.string.pocket_status_awaiting)
                PocketGuardLogic.State.ALARMING -> getString(R.string.pocket_status_alarming)
                else -> getString(R.string.pocket_status_monitoring)
            }
            null -> getString(R.string.touch_status_disarmed)
        }
        val disarm = PendingIntent.getService(
            this,
            1,
            Intent(this, GuardService::class.java).setAction(ACTION_DISARM),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val action = NotificationCompat.Action.Builder(0, getString(R.string.notif_disarm_action), disarm)
            // A locked phone must be unlocked before the guard can be disarmed from the shade.
            .setAuthenticationRequired(true)
            .build()
        return NotificationCompat.Builder(this, Notifications.CHANNEL_STATUS)
            .setSmallIcon(R.drawable.ic_stat_guard)
            .setContentTitle(getString(R.string.app_name))
            .setContentText(status)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .setContentIntent(Notifications.openAppIntent(this))
            .addAction(action)
            .build()
    }

    private fun engine() = (application as GuardDogApp).engine

    companion object {
        /** Safety net only: a session normally ends on disarm, long before this. */
        private const val MAX_SESSION_MS = 12 * 60 * 60 * 1000L
        private const val ACTION_DISARM = "com.appcentral.guarddog.action.DISARM"

        private var instance: GuardService? = null

        fun start(context: Context) {
            ContextCompat.startForegroundService(context, Intent(context, GuardService::class.java))
        }

        fun stop(context: Context) {
            instance?.stoppingNormally = true
            context.stopService(Intent(context, GuardService::class.java))
        }

        /** Re-renders the ongoing notification if the service is running. */
        fun refresh(context: Context) {
            instance?.updateNotification()
        }
    }
}
