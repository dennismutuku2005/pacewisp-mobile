package com.pacewisp.pacewisp

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.Timer
import java.util.TimerTask

class WidgetSyncService : Service() {

    companion object {
        private const val TAG = "WidgetSyncService"
        private const val CHANNEL_ID = "widget_sync_channel"
        private const val NOTIFICATION_ID = 1001
        private const val SYNC_INTERVAL_MS = 20_000L
    }

    private var timer: Timer? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startSyncTimer()
        return START_STICKY
    }

    private fun startSyncTimer() {
        timer?.cancel()
        timer = Timer()
        timer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                fetchAndRefreshWidget()
            }
        }, 0L, SYNC_INTERVAL_MS)
    }

    private fun fetchAndRefreshWidget() {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val subdomain = prefs.getString("flutter.subdomain", "") ?: ""
            val domain = prefs.getString("flutter.domain", "pacewisp.co.ke") ?: "pacewisp.co.ke"
            val token = prefs.getString("flutter.token", "") ?: ""

            if (subdomain.isEmpty() || token.isEmpty()) {
                Log.w(TAG, "No credentials — skipping sync")
                return
            }

            val host = if (subdomain.contains(".")) subdomain else "$subdomain.$domain"
            val ts = System.currentTimeMillis()
            val urlString = "https://$host/dashboard/v1/dashboard.php?action=widgets&_t=$ts"
            Log.d(TAG, "Fetching: $urlString")

            val url = URL(urlString)
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "GET"
            conn.connectTimeout = 10000
            conn.readTimeout = 10000
            conn.setRequestProperty("Authorization", "Bearer $token")
            conn.setRequestProperty("Cache-Control", "no-cache, no-store")

            val code = conn.responseCode
            Log.d(TAG, "HTTP: $code")

            if (code == HttpURLConnection.HTTP_OK) {
                val response = conn.inputStream.bufferedReader().use { it.readText() }
                val json = JSONObject(response)
                val dataObj = json.optJSONObject("data")
                val widgets = dataObj?.optJSONObject("widgets") ?: dataObj ?: json

                val income = widgets.optJSONObject("todays_earnings")?.optString("value", "0") ?: "0"
                val entries = widgets.optJSONObject("active_users")?.optString("value", "0") ?: "0"
                val accountName = prefs.getString("flutter.account_name", "PaceWISP Admin") ?: "PaceWISP Admin"
                val isBlurred = prefs.getBoolean("flutter.is_widget_blurred", true)

                Log.d(TAG, "Income: $income | Entries: $entries")

                val widgetPrefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                val editor = widgetPrefs.edit()
                editor.putString("account_name", accountName)
                editor.putString("income", "KSH $income")
                editor.putString("entries", "$entries Entries")
                editor.putBoolean("is_blurred", isBlurred)
                editor.commit()

                val mgr = AppWidgetManager.getInstance(applicationContext)
                val ids = mgr.getAppWidgetIds(
                    ComponentName(applicationContext, AppWidgetProvider::class.java)
                )
                if (ids.isNotEmpty()) {
                    val updateIntent = Intent(applicationContext, AppWidgetProvider::class.java)
                    updateIntent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    updateIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                    sendBroadcast(updateIntent)
                    Log.d(TAG, "Broadcast sent for ${ids.size} widget(s)")
                }
            }
            conn.disconnect()
        } catch (e: Exception) {
            Log.e(TAG, "Sync error: ${e.message}", e)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Widget Live Sync",
                NotificationManager.IMPORTANCE_MIN
            )
            channel.description = "Keeps your Home Screen widget data live"
            channel.setShowBadge(false)
            // Fix: safe call on nullable getSystemService result
            val notifManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            notifManager?.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("PaceWISP Widget")
            .setContentText("Syncing dashboard data…")
            .setSmallIcon(android.R.drawable.ic_popup_sync)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(true)
            .setSilent(true)
            .build()
    }

    override fun onDestroy() {
        timer?.cancel()
        super.onDestroy()
    }
}
