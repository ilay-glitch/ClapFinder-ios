package com.appcentral.guarddog.core

/**
 * Don't Touch motion sensitivity (ANDROID_HANDOFF §1.2).
 *
 * [thresholdG] is the user-acceleration magnitude (gravity removed, in g) that a
 * sample must exceed. Tuned against iPhone sensors — re-validate on Android hardware.
 */
enum class Sensitivity(val key: String, val thresholdG: Double) {
    LOW("low", 0.15),       // deliberate pickup
    MEDIUM("medium", 0.08), // default
    HIGH("high", 0.04);     // nudge — known to fire on table vibration

    companion object {
        val DEFAULT = MEDIUM

        fun fromKey(key: String?): Sensitivity = entries.firstOrNull { it.key == key } ?: DEFAULT
    }
}
