package com.appcentral.guarddog.guard

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.appcentral.guarddog.MainActivity
import com.appcentral.guarddog.R

/** Channels and the three notification kinds: ongoing status, alarm, stand-down. */
object Notifications {

    const val CHANNEL_STATUS = "guard_status"
    const val CHANNEL_ALARM = "guard_alarm"
    const val CHANNEL_STOPPED = "guard_stopped"

    const val ID_ONGOING = 1001
    private const val ID_ALARM = 1002
    private const val ID_STANDDOWN = 1003

    fun createChannels(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannels(
            listOf(
                NotificationChannel(
                    CHANNEL_STATUS,
                    context.getString(R.string.channel_status_name),
                    NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    description = context.getString(R.string.channel_status_desc)
                    setShowBadge(false)
                },
                NotificationChannel(
                    CHANNEL_ALARM,
                    context.getString(R.string.channel_alarm_name),
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = context.getString(R.string.channel_alarm_desc)
                    // The alarm itself is already blasting; the notification only buzzes.
                    setSound(null, null)
                    enableVibration(true)
                },
                NotificationChannel(
                    CHANNEL_STOPPED,
                    context.getString(R.string.channel_stopped_name),
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply { description = context.getString(R.string.channel_stopped_desc) },
            ),
        )
    }

    fun openAppIntent(context: Context): PendingIntent = PendingIntent.getActivity(
        context,
        0,
        Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    fun postAlarm(context: Context) = notify(
        context,
        ID_ALARM,
        NotificationCompat.Builder(context, CHANNEL_ALARM)
            .setSmallIcon(R.drawable.ic_stat_guard)
            .setContentTitle(context.getString(R.string.alarm_notification_title))
            .setContentText(context.getString(R.string.alarm_notification_body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setContentIntent(openAppIntent(context))
            .setOnlyAlertOnce(false)
            .setAutoCancel(true)
            .build(),
    )

    /** Removes the delivered alarm notification. Pending repeats are cancelled by the engine. */
    fun cancelAlarm(context: Context) = NotificationManagerCompat.from(context).cancel(ID_ALARM)

    /** Fail loud: the user must never believe they're guarded when they aren't. */
    fun postStandDown(context: Context) = notify(
        context,
        ID_STANDDOWN,
        NotificationCompat.Builder(context, CHANNEL_STOPPED)
            .setSmallIcon(R.drawable.ic_stat_guard)
            .setContentTitle(context.getString(R.string.standdown_notification_title))
            .setContentText(context.getString(R.string.standdown_notification_body))
            .setStyle(NotificationCompat.BigTextStyle().bigText(context.getString(R.string.standdown_notification_body)))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(openAppIntent(context))
            .setAutoCancel(true)
            .build(),
    )

    fun canPost(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED

    private fun notify(context: Context, id: Int, notification: android.app.Notification) {
        if (!canPost(context)) return
        try {
            NotificationManagerCompat.from(context).notify(id, notification)
        } catch (_: SecurityException) {
            // Permission revoked between the check and the post — nothing more to do.
        }
    }
}
