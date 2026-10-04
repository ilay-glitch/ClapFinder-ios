package com.appcentral.guarddog.core

/** `ad_skip_reason` analytics enum (EVENTS.md). */
enum class AdSkipReason(val key: String) {
    NONE("none"),
    FIRST_LAUNCH("first_launch"),
    FREQUENCY_CAP("frequency_cap"),
    SESSION_CAP("session_cap"),
    LOAD_FAILED("load_failed"),
    TIMEOUT("timeout"),
}
