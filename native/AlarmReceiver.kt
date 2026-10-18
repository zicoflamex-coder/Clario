package com.zico.clario

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.RingtoneManager
import android.os.Build

class AlarmReceiver : BroadcastReceiver() {

    @Suppress("DEPRECATION")
    override fun onReceive(ctx: Context, intent: Intent) {
        val id = intent.getIntExtra("id", 0)
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (intent.action == "com.zico.clario.STOP") {
            nm.cancel(id)
            return
        }

        AlarmUtil.forget(ctx, id)
        val title = intent.getStringExtra("title") ?: "آلارم"
        val sound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        val vib = longArrayOf(0, 700, 400, 700, 400, 700)
        val chId = "clario_alarm_v1"

        if (Build.VERSION.SDK_INT >= 26) {
            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            val ch = NotificationChannel(chId, "آلارم‌ها", NotificationManager.IMPORTANCE_HIGH)
            ch.setSound(sound, attrs)
            ch.enableVibration(true)
            ch.vibrationPattern = vib
            ch.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            nm.createNotificationChannel(ch)
        }

        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val openI = Intent(ctx, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val open = PendingIntent.getActivity(ctx, id, openI, flags)
        val stopI = Intent(ctx, AlarmReceiver::class.java)
            .setAction("com.zico.clario.STOP")
            .putExtra("id", id)
        val stop = PendingIntent.getBroadcast(ctx, id + 500000, stopI, flags)

        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(ctx, chId) else Notification.Builder(ctx)
        b.setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText("زمان آلارم رسید ⏰")
            .setContentIntent(open)
            .setFullScreenIntent(open, true)
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_ALARM)
            .addAction(0, "توقف", stop)
        if (Build.VERSION.SDK_INT >= 26) {
            b.setTimeoutAfter(90000)
        } else {
            b.setSound(sound, AudioManager.STREAM_ALARM)
            b.setVibrate(vib)
            b.setPriority(Notification.PRIORITY_MAX)
        }
        val n = b.build()
        n.flags = n.flags or Notification.FLAG_INSISTENT
        nm.notify(id, n)
    }
}
