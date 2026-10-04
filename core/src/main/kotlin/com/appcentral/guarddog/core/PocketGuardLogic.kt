package com.appcentral.guarddog.core

/**
 * Pure state machine for Pocket Mode: disarmed → awaitingPocket → monitoring →
 * alarming (ANDROID_HANDOFF §1.3).
 *
 * Debounces: cover must be sustained ≥ [coverDebounceMs] to engage (rejects
 * hand-shadow flicker while pocketing); uncover must be sustained ≥
 * [uncoverDebounceMs] to alarm (rejects loose-fabric flicker). A flicker back to
 * the previous sensor state clears the pending transition. Values were tuned on
 * iPhone — re-validate on Android hardware.
 */
class PocketGuardLogic(
    val coverDebounceMs: Long = 1_500L,
    val uncoverDebounceMs: Long = 500L,
) {
    enum class State { DISARMED, AWAITING_POCKET, MONITORING, ALARMING }

    enum class Event {
        /** Cover sustained — the guard engaged (chirp moment). */
        ENGAGED,
        /** Uncover sustained — the phone was pulled out. */
        ALARM,
    }

    var state: State = State.DISARMED
        private set

    private var armedAtMs: Long? = null
    private var coveredSinceMs: Long? = null
    private var uncoveredSinceMs: Long? = null

    val isActive: Boolean get() = state != State.DISARMED

    fun arm(nowMs: Long) {
        if (state != State.DISARMED) return
        armedAtMs = nowMs
        coveredSinceMs = null
        uncoveredSinceMs = null
        state = State.AWAITING_POCKET
    }

    /** @return the state it was in when disarmed. */
    fun disarm(): State {
        val previous = state
        state = State.DISARMED
        armedAtMs = null
        coveredSinceMs = null
        uncoveredSinceMs = null
        return previous
    }

    /**
     * Feeds a proximity reading. Repeated reports of the same value do NOT reset a
     * pending debounce.
     */
    fun setCovered(covered: Boolean, nowMs: Long) {
        when (state) {
            State.DISARMED, State.ALARMING -> Unit
            State.AWAITING_POCKET ->
                coveredSinceMs = if (covered) coveredSinceMs ?: nowMs else null
            State.MONITORING ->
                uncoveredSinceMs = if (covered) null else uncoveredSinceMs ?: nowMs
        }
    }

    /** Performs a transition whose debounce has elapsed. Call from a ticker. */
    fun evaluate(nowMs: Long): Event? = when (state) {
        State.DISARMED, State.ALARMING -> null
        State.AWAITING_POCKET -> {
            val since = coveredSinceMs
            if (since != null && nowMs - since >= coverDebounceMs) {
                coveredSinceMs = null
                state = State.MONITORING
                Event.ENGAGED
            } else {
                null
            }
        }
        State.MONITORING -> {
            val since = uncoveredSinceMs
            if (since != null && nowMs - since >= uncoverDebounceMs) {
                uncoveredSinceMs = null
                state = State.ALARMING
                Event.ALARM
            } else {
                null
            }
        }
    }

    fun secondsSinceArmed(nowMs: Long): Int = armedAtMs?.let { ((nowMs - it) / 1000).toInt() } ?: 0
}
