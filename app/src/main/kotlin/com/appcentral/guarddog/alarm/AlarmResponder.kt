package com.appcentral.guarddog.alarm

import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import com.appcentral.guarddog.core.Guard
import com.appcentral.guarddog.core.GuardCatalog
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/**
 * The alarm response: the selected sound looping at full volume + torch pulsing +
 * continuous haptics, simultaneously, until [stop] (ANDROID_HANDOFF §1.2).
 *
 * Audio goes out on the ALARM stream, which plays through silent/vibrate ringer
 * modes; the stream is raised to max while alarming and restored afterwards, and
 * re-asserted every second so a thief can't turn it down with the volume keys.
 * Torch and haptics are driven directly — no notification-LED dependency (§4.3).
 */
class AlarmResponder(
    private val context: Context,
    private val scope: CoroutineScope,
) {
    private val audio = context.getSystemService(AudioManager::class.java)
    private val cameras = context.getSystemService(CameraManager::class.java)
    private val torchCameraId: String? by lazy { findTorchCamera() }
    private val vibrator: Vibrator by lazy {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(VibratorManager::class.java).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Vibrator::class.java)
        }
    }

    private val alarmAttributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_ALARM)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build()

    private var player: MediaPlayer? = null
    private var chirpPlayer: MediaPlayer? = null
    private var torchJob: Job? = null
    private var volumeJob: Job? = null
    private var savedAlarmVolume: Int? = null
    private var focusRequest: AudioFocusRequest? = null

    val isSounding: Boolean get() = player != null

    fun start(guard: Guard) {
        if (player != null) return
        raiseAlarmVolume()
        requestFocus()
        player = createPlayer(guard.sound)?.apply {
            isLooping = true
            setVolume(1f, 1f)
            start()
        }
        startTorch()
        startHaptics()
    }

    fun stop() {
        player?.run {
            runCatching { stop() }
            release()
        }
        player = null
        torchJob?.cancel()
        torchJob = null
        setTorch(false)
        vibrator.cancel()
        volumeJob?.cancel()
        volumeJob = null
        restoreAlarmVolume()
        focusRequest?.let { audio.abandonAudioFocusRequest(it) }
        focusRequest = null
    }

    /** The car-remote "chirp-chirp": same sound on every engage and every disarm. */
    fun chirp() {
        chirpPlayer?.release()
        chirpPlayer = createPlayer(GuardCatalog.CHIRP_SOUND)?.apply {
            setOnCompletionListener {
                it.release()
                if (chirpPlayer === it) chirpPlayer = null
            }
            start()
        }
    }

    // region Audio

    private fun createPlayer(soundName: String): MediaPlayer? {
        val resId = soundResources[soundName]
        if (resId == null) {
            Log.w(TAG, "Missing sound resource $soundName")
            return null
        }
        return try {
            context.resources.openRawResourceFd(resId).use { afd ->
                MediaPlayer().apply {
                    setAudioAttributes(alarmAttributes)
                    setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                    prepare()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Could not prepare $soundName", e)
            null
        }
    }

    private fun raiseAlarmVolume() {
        val max = audio.getStreamMaxVolume(AudioManager.STREAM_ALARM)
        if (savedAlarmVolume == null) savedAlarmVolume = audio.getStreamVolume(AudioManager.STREAM_ALARM)
        setAlarmVolume(max)
        volumeJob = scope.launch {
            while (isActive) {
                delay(1_000)
                if (audio.getStreamVolume(AudioManager.STREAM_ALARM) < max) setAlarmVolume(max)
            }
        }
    }

    private fun restoreAlarmVolume() {
        savedAlarmVolume?.let { setAlarmVolume(it) }
        savedAlarmVolume = null
    }

    private fun setAlarmVolume(volume: Int) {
        try {
            audio.setStreamVolume(AudioManager.STREAM_ALARM, volume, 0)
        } catch (e: SecurityException) {
            // Some DND configurations refuse volume changes; the alarm still plays.
            Log.w(TAG, "Alarm volume change refused", e)
        }
    }

    private fun requestFocus() {
        // Focus loss is deliberately ignored: nothing but DISARM may silence the alarm.
        val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
            .setAudioAttributes(alarmAttributes)
            .setOnAudioFocusChangeListener { }
            .build()
        audio.requestAudioFocus(request)
        focusRequest = request
    }

    // endregion

    // region Torch

    private fun startTorch() {
        if (torchCameraId == null) return
        torchJob = scope.launch {
            while (isActive) {
                setTorch(true)
                delay(TORCH_ON_MS)
                setTorch(false)
                delay(TORCH_OFF_MS)
            }
        }
    }

    private fun setTorch(on: Boolean) {
        val id = torchCameraId ?: return
        try {
            cameras.setTorchMode(id, on)
        } catch (e: Exception) {
            // Camera in use by another app, or torch unavailable while locked on this OEM.
            Log.w(TAG, "Torch write failed", e)
        }
    }

    private fun findTorchCamera(): String? = try {
        cameras.cameraIdList.firstOrNull { id ->
            val c = cameras.getCameraCharacteristics(id)
            c.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true &&
                c.get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_BACK
        }
    } catch (e: Exception) {
        null
    }

    // endregion

    // region Haptics

    private fun startHaptics() {
        if (!vibrator.hasVibrator()) return
        // ~0.6 s buzz every 1.2 s, repeating until cancel().
        val effect = VibrationEffect.createWaveform(longArrayOf(0, 600, 600), 0)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            vibrator.vibrate(effect, VibrationAttributes.createForUsage(VibrationAttributes.USAGE_ALARM))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(effect, alarmAttributes)
        }
    }

    // endregion

    private companion object {
        const val TAG = "AlarmResponder"
        const val TORCH_ON_MS = 150L
        const val TORCH_OFF_MS = 100L
    }
}
