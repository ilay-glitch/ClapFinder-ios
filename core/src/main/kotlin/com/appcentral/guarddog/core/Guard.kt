package com.appcentral.guarddog.core

/**
 * One alarm voice in the guard grid. [sound] names the `res/raw` resource.
 * The selection is global: it is the alarm sound for BOTH modes, and the alarm
 * overlay shows its [emoji].
 */
data class Guard(
    val id: String,
    val name: String,
    val emoji: String,
    val sound: String,
)

/** The 16 guards, in grid order (ANDROID_HANDOFF §1.4, §2.2). */
object GuardCatalog {

    val all: List<Guard> = listOf(
        Guard("dog", "Dog", "🐕", "dog_bark"),
        Guard("cat", "Cat", "🐈", "cat_meow"),
        Guard("cow", "Cow", "🐮", "cow_moo"),
        Guard("frog", "Frog", "🐸", "frog_ribbit"),
        Guard("duck", "Duck", "🦆", "duck_quack"),
        Guard("pig", "Pig", "🐖", "pig_oink"),
        Guard("rooster", "Rooster", "🐔", "rooster_crow"),
        Guard("sheep", "Sheep", "🐑", "sheep_baa"),
        Guard("siren", "Siren", "🚨", "siren"),
        Guard("alarm_clock", "Alarm Clock", "⏰", "alarm_clock"),
        Guard("air_horn", "Air Horn", "📢", "air_horn"),
        Guard("bell", "Bell", "🔔", "bell"),
        Guard("whistle", "Whistle", "🎵", "whistle"),
        Guard("beep", "Beeper", "🔊", "beep"),
        Guard("doorbell", "Doorbell", "🚪", "doorbell"),
        Guard("foghorn", "Foghorn", "🚢", "foghorn"),
    )

    val default: Guard = all.first()

    /** The car-remote "chirp-chirp" played on every engage and every disarm. */
    const val CHIRP_SOUND = "arm_chirp"

    fun byId(id: String?): Guard = all.firstOrNull { it.id == id } ?: default
}
