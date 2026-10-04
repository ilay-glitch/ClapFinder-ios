package com.appcentral.guarddog.alarm

import com.appcentral.guarddog.R

/**
 * Sound name (as named in core's GuardCatalog) → raw resource. Explicit references keep
 * release resource shrinking from stripping sounds that are only named by string.
 */
internal val soundResources: Map<String, Int> = mapOf(
    "air_horn" to R.raw.air_horn,
    "alarm_clock" to R.raw.alarm_clock,
    "arm_chirp" to R.raw.arm_chirp,
    "beep" to R.raw.beep,
    "bell" to R.raw.bell,
    "cat_meow" to R.raw.cat_meow,
    "cow_moo" to R.raw.cow_moo,
    "dog_bark" to R.raw.dog_bark,
    "doorbell" to R.raw.doorbell,
    "duck_quack" to R.raw.duck_quack,
    "foghorn" to R.raw.foghorn,
    "frog_ribbit" to R.raw.frog_ribbit,
    "pig_oink" to R.raw.pig_oink,
    "rooster_crow" to R.raw.rooster_crow,
    "sheep_baa" to R.raw.sheep_baa,
    "siren" to R.raw.siren,
    "whistle" to R.raw.whistle,
)
