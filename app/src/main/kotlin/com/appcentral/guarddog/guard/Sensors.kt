package com.appcentral.guarddog.guard

import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.SystemClock
import kotlin.math.sqrt

/**
 * User-acceleration magnitude in g (gravity removed), delivered at ~10 Hz to match
 * the trigger rule's sampling assumption (2 consecutive samples ≈ 100–200 ms of
 * movement). Uses the fused linear-acceleration sensor when present, otherwise a
 * low-pass gravity estimate subtracted from the raw accelerometer.
 */
class MotionSource(
    private val sensors: SensorManager,
    private val onSample: (magnitudeG: Double) -> Unit,
) : SensorEventListener {

    private val linear: Sensor? = sensors.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION)
    private val raw: Sensor? = sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
    private val gravity = FloatArray(3)
    private var gravityPrimed = false
    private var lastDeliveredMs = 0L

    val isAvailable: Boolean get() = linear != null || raw != null

    fun start(): Boolean {
        val sensor = linear ?: raw ?: return false
        gravityPrimed = false
        lastDeliveredMs = 0L
        return sensors.registerListener(this, sensor, SAMPLING_PERIOD_US)
    }

    fun stop() = sensors.unregisterListener(this)

    override fun onSensorChanged(event: SensorEvent) {
        val (x, y, z) = if (event.sensor.type == Sensor.TYPE_LINEAR_ACCELERATION) {
            Triple(event.values[0], event.values[1], event.values[2])
        } else {
            removeGravity(event.values)
        }
        // Many sensors deliver faster than requested; keep a 10 Hz cadence.
        val now = SystemClock.elapsedRealtime()
        if (now - lastDeliveredMs < MIN_INTERVAL_MS) return
        lastDeliveredMs = now
        onSample(sqrt((x * x + y * y + z * z).toDouble()) / SensorManager.GRAVITY_EARTH)
    }

    private fun removeGravity(v: FloatArray): Triple<Float, Float, Float> {
        if (!gravityPrimed) {
            v.copyInto(gravity, endIndex = 3)
            gravityPrimed = true
        }
        for (i in 0..2) gravity[i] = ALPHA * gravity[i] + (1 - ALPHA) * v[i]
        return Triple(v[0] - gravity[0], v[1] - gravity[1], v[2] - gravity[2])
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    private companion object {
        const val SAMPLING_PERIOD_US = 100_000
        const val MIN_INTERVAL_MS = 95L
        const val ALPHA = 0.8f
    }
}

/**
 * Proximity "covered" edges. Prefers the wake-up variant so readings keep arriving
 * with the screen off (handoff probe 4.1 — verify across OEMs).
 */
class ProximitySource(
    private val sensors: SensorManager,
    private val onCovered: (covered: Boolean) -> Unit,
) : SensorEventListener {

    private val sensor: Sensor? =
        sensors.getDefaultSensor(Sensor.TYPE_PROXIMITY, true) ?: sensors.getDefaultSensor(Sensor.TYPE_PROXIMITY)

    val isAvailable: Boolean get() = sensor != null

    fun start(): Boolean = sensor?.let {
        sensors.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
    } ?: false

    fun stop() = sensors.unregisterListener(this)

    override fun onSensorChanged(event: SensorEvent) {
        val max = event.sensor.maximumRange
        // Most proximity sensors are binary (0 or max); treat anything short of max
        // (capped at 5 cm for analog ones) as covered.
        onCovered(event.values[0] < minOf(max, NEAR_CM))
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    private companion object {
        const val NEAR_CM = 5f
    }
}
