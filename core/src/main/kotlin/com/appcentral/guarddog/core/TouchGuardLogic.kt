package com.appcentral.guarddog.core

/**
 * Pure state machine for Don't Touch: disarmed → grace → monitoring → alarming
 * (ANDROID_HANDOFF §1.2).
 *
 * No clock inside — every call takes `nowMs` from the caller, so grace and trigger
 * rules are tested without sleeping.
 *
 * Trigger rule: [samplesToTrigger] consecutive samples above the sensitivity
 * threshold. One below-threshold sample resets the count (rejects single spikes).
 */
class TouchGuardLogic(
    val gracePeriodMs: Long = GRACE_PERIOD_MS,
    val samplesToTrigger: Int = 2,
) {
    enum class State { DISARMED, GRACE, MONITORING, ALARMING }

    /** What a call changed — the coordinator turns these into chirps, alarms, analytics. */
    enum class Event { MONITORING_STARTED, ALARM }

    var state: State = State.DISARMED
        private set
    var sensitivity: Sensitivity = Sensitivity.DEFAULT
        private set

    private var armedAtMs: Long? = null
    private var consecutiveAbove = 0

    val isActive: Boolean get() = state != State.DISARMED

    /** Arms into the grace period. No-op unless disarmed. */
    fun arm(sensitivity: Sensitivity, nowMs: Long) {
        if (state != State.DISARMED) return
        this.sensitivity = sensitivity
        armedAtMs = nowMs
        consecutiveAbove = 0
        state = State.GRACE
    }

    /**
     * Disarms from any state.
     * @return the state it was in, so callers can tell a completed session
     *   (MONITORING) from a grace-cancel or an alarm dismissal.
     */
    fun disarm(): State {
        val previous = state
        state = State.DISARMED
        armedAtMs = null
        consecutiveAbove = 0
        return previous
    }

    /**
     * Advances grace → monitoring once the grace period has elapsed. Called by a
     * ticker so the chirp fires on time even if the phone is perfectly still.
     */
    fun tick(nowMs: Long): Event? {
        val armedAt = armedAtMs ?: return null
        if (state == State.GRACE && nowMs - armedAt >= gracePeriodMs) {
            state = State.MONITORING
            consecutiveAbove = 0
            return Event.MONITORING_STARTED
        }
        return null
    }

    /** Feeds one user-acceleration magnitude sample (g). */
    fun onSample(magnitudeG: Double, nowMs: Long): Event? {
        val started = tick(nowMs)
        if (state != State.MONITORING) return started
        if (magnitudeG > sensitivity.thresholdG) {
            consecutiveAbove += 1
            if (consecutiveAbove >= samplesToTrigger) {
                state = State.ALARMING
                return Event.ALARM
            }
        } else {
            consecutiveAbove = 0
        }
        return started
    }

    /** Whole seconds left in the grace countdown (for the ring and the notification). */
    fun graceRemainingSeconds(nowMs: Long): Int {
        val armedAt = armedAtMs ?: return 0
        if (state != State.GRACE) return 0
        val remaining = gracePeriodMs - (nowMs - armedAt)
        return ((remaining + 999) / 1000).toInt().coerceIn(0, (gracePeriodMs / 1000).toInt())
    }

    fun secondsSinceArmed(nowMs: Long): Int = armedAtMs?.let { ((nowMs - it) / 1000).toInt() } ?: 0

    companion object {
        const val GRACE_PERIOD_MS = 5_000L
    }
}
