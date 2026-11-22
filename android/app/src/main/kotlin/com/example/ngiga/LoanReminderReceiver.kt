package com.example.ngiga

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject

object LoanReminders {
    private const val PREFS = "loan_reminders"
    private const val CHANNEL = "stockroom_due"
    private const val THREE_HOURS = 3L * 60 * 60 * 1000

    fun sync(context: Context, loans: List<Map<String, Any?>>, silent: Boolean) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit().putBoolean("silent", silent).apply()
        val old = JSONArray(prefs.getString("loans", "[]"))
        for (i in 0 until old.length()) {
            val entry = old.getJSONObject(i)
            cancel(context, entry.optString("id"), "due")
            cancel(context, entry.optString("id"), "overdue")
            if (loans.none { it["id"] == entry.optString("id") }) {
                prefs.edit().remove("last_" + entry.optString("id"))
                    .remove("due_" + entry.optString("id")).apply()
            }
        }
        val saved = JSONArray()
        for (loan in loans) {
            val id = loan["id"] as? String ?: continue
            val name = loan["name"] as? String ?: "Borrowed item"
            val due = (loan["due"] as? Number)?.toLong() ?: continue
            val entry = JSONObject().put("id", id).put("name", name).put("due", due)
            saved.put(entry)
            val dueSent = prefs.getBoolean("due_$id", false)
            schedule(context, entry,
                if (due > System.currentTimeMillis() && !dueSent) "due" else "overdue")
        }
        prefs.edit().putString("loans", saved.toString()).apply()
    }

    fun schedule(context: Context, entry: JSONObject, kind: String) {
        val due = entry.optLong("due")
        val now = System.currentTimeMillis()
        val whenMillis = if (kind == "due") {
            maxOf(now + 60_000, due - 60 * 60 * 1000)
        } else {
            val lastSent = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getLong("last_" + entry.optString("id"), 0)
            maxOf(now + 60_000, due, lastSent + THREE_HOURS)
        }
        val intent = Intent(context, LoanReminderReceiver::class.java).apply {
            putExtra("id", entry.optString("id"))
            putExtra("kind", kind)
        }
        val pending = PendingIntent.getBroadcast(context, (entry.optString("id") + kind).hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenMillis, pending)
    }

    fun cancel(context: Context, id: String, kind: String) {
        val intent = Intent(context, LoanReminderReceiver::class.java)
        val pending = PendingIntent.getBroadcast(context, (id + kind).hashCode(), intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE) ?: return
        (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(pending)
        pending.cancel()
    }

    fun entry(context: Context, id: String): JSONObject? {
        val saved = JSONArray(context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString("loans", "[]"))
        for (i in 0 until saved.length()) {
            val entry = saved.getJSONObject(i)
            if (entry.optString("id") == id) return entry
        }
        return null
    }

    fun notify(context: Context, entry: JSONObject, kind: String) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(NotificationChannel(CHANNEL, "E-QUIP loan reminders",
            NotificationManager.IMPORTANCE_HIGH))
        if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(
                android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) return
        val name = entry.optString("name")
        val title = if (kind == "due") "Return $name soon" else "$name is overdue"
        val message = if (kind == "due") "Your item is due in about one hour."
            else "Please return this item. We'll remind you again in three hours."
        val open = PendingIntent.getActivity(context, 0,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title).setContentText(message)
            .setSilent(context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getBoolean("silent", false))
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setAutoCancel(true).setContentIntent(open).build()
        manager.notify((entry.optString("id") + kind).hashCode(), notification)
    }
}

class LoanReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra("id") ?: return
        val kind = intent.getStringExtra("kind") ?: return
        val entry = LoanReminders.entry(context, id) ?: return
        val due = entry.optLong("due")
        if (kind == "due" && System.currentTimeMillis() < due) {
            LoanReminders.notify(context, entry, "due")
            context.getSharedPreferences("loan_reminders", Context.MODE_PRIVATE)
                .edit().putBoolean("due_$id", true).apply()
            LoanReminders.schedule(context, entry, "overdue")
        } else {
            LoanReminders.notify(context, entry, "overdue")
            context.getSharedPreferences("loan_reminders", Context.MODE_PRIVATE)
                .edit().putLong("last_$id", System.currentTimeMillis()).apply()
            LoanReminders.schedule(context, entry, "overdue")
        }
    }
}

class LoanReminderBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        val saved = JSONArray(context.getSharedPreferences("loan_reminders", Context.MODE_PRIVATE)
            .getString("loans", "[]"))
        for (i in 0 until saved.length()) {
            val entry = saved.getJSONObject(i)
            LoanReminders.schedule(context, entry,
                if (entry.optLong("due") > System.currentTimeMillis()) "due" else "overdue")
        }
    }
}
