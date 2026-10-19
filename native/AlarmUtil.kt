package com.zico.clario

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import org.json.JSONObject

object AlarmUtil {
    private const val PREF = "clario_alarms"
    private const val FLAGS = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

    private fun load(ctx: Context): JSONObject = try {
        JSONObject(ctx.getSharedPreferences(PREF, Context.MODE_PRIVATE).getString("list", "{}") ?: "{}")
    } catch (e: Exception) {
        JSONObject()
    }

    private fun save(ctx: Context, o: JSONObject) {
        ctx.getSharedPreferences(PREF, Context.MODE_PRIVATE).edit().putString("list", o.toString()).apply()
    }

    private fun pending(ctx: Context, id: Int, title: String): PendingIntent {
        val i = Intent(ctx, AlarmReceiver::class.java)
            .setAction("com.zico.clario.ALARM")
            .putExtra("id", id)
            .putExtra("title", title)
        return PendingIntent.getBroadcast(ctx, id, i, FLAGS)
    }

    private fun arm(ctx: Context, id: Int, at: Long, title: String) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val show = PendingIntent.getActivity(ctx, 0, Intent(ctx, MainActivity::class.java), FLAGS)
        am.setAlarmClock(AlarmManager.AlarmClockInfo(at, show), pending(ctx, id, title))
    }

    fun schedule(ctx: Context, id: Int, at: Long, title: String) {
        arm(ctx, id, at, title)
        val o = load(ctx)
        o.put(id.toString(), JSONObject().put("at", at).put("title", title))
        save(ctx, o)
    }

    fun cancel(ctx: Context, id: Int) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(pending(ctx, id, ""))
        forget(ctx, id)
        (ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(id)
    }

    fun count(ctx: Context): Int = load(ctx).length()

    fun forget(ctx: Context, id: Int) {
        val o = load(ctx)
        o.remove(id.toString())
        save(ctx, o)
    }

    fun rescheduleAll(ctx: Context) {
        val o = load(ctx)
        val now = System.currentTimeMillis()
        val keys = o.keys().asSequence().toList()
        for (k in keys) {
            val e = o.getJSONObject(k)
            val at = e.getLong("at")
            if (at > now) {
                arm(ctx, k.toInt(), at, e.optString("title", ""))
            } else {
                o.remove(k)
            }
        }
        save(ctx, o)
    }
}
