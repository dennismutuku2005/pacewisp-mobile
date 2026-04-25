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
        private const val SYNC_INTERVAL_MS = 20_000L // 20 seconds
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
        return START_STICKY // Android will restart this service if killed
    }

    private fun startSyncTimer() {
        timer?.cancel()
        timer = Timer()
        timer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                fetchAndRefreshWidget()
            }
        }, 0, SYNC_INTERVAL_MS)
    }

    private fun fetchAndRefreshWidget() {
        try {
            // Read Flutter SharedPreferences (flutter. prefix is how the plugin stores keys)
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val subdomain = prefs.getString("flutter.subdomain", "") ?: ""
            val domain = prefs.getString("flutter.domain", "pacewisp.co.ke") ?: "pacewisp.co.ke"
            val token = prefs.getString("flutter.token", "") ?: ""

            if (subdomain.isEmpty() || token.isEmpty()) {
                Log.w(TAG, "No credentials found — skipping sync")
                return
            }

            val host = if (subdomain.contains(".")) subdomain else "$subdomain.$domain"
            // FIX: Use correct query param ?action=widgets (not ?slug=widgets)
            val url = URL("https://$host/dashboard/v1/dashboard.php?action=widgets&_t=${System.currentTimeMillis()}")

            Log.d(TAG, "Fetching widget data from: $url")

            with(url.openConnection() as HttpURLConnection) {
                requestMethod = "GET"
                connectTimeout = 10000
                readTimeout = 10000
                setRequestProperty("Authorization", "Bearer $token")
                setRequestProperty("Cache-Control", "no-cache, no-store")

                val code = responseCode
                Log.d(TAG, "HTTP Response: $code")

                if (code == HTTP_OK) {
                    val response = inputStream.bufferedReader().use { it.readText() }
                    val json = JSONObject(response)

                    // Navigate: data -> widgets
                    val dataObj = json.optJSONObject("data")
                    val widgets = dataObj?.optJSONObject("widgets") ?: dataObj ?: json

                    val income = widgets.optJSONObject("todays_earnings")?.optString("value", "0") ?: "0"
                    val entries = widgets.optJSONObject("active_users")?.optString("value", "0") ?: "0"

                    Log.d(TAG, "Parsed — Income: $income, Entries: $entries")

                    // Read account name from flutter prefs
                    val accountName = prefs.getString("flutter.account_name", "PaceWISP Admin") ?: "PaceWISP Admin"
                    val isBlurred = prefs.getBoolean("flutter.is_widget_blurred", true)

                    // Save to HomeWidgetPreferences so the provider reads correctly
                    val widgetPrefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                    widgetPrefs.edit().apply {
                        putString("account_name", accountName)
                        putString("income", if (income != "0") "KSH $income" else "KSH 0")
                        putString("entries", "$entries Entries")
                        putBoolean("is_blurred", isBlurred)
                        commit() // commit (not apply) to ensure it's written before the update
                    }

                    // FIX: Send a broadcast to force widget refresh — do NOT instantiate AppWidgetProvider directly
                    val mgr = AppWidgetManager.getInstance(applicationContext)
                    val ids = mgr.getAppWidgetIds(ComponentName(applicationContext, AppWidgetProvider::class.java))
                    if (ids.isNotEmpty()) {
                        val updateIntent = Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE).apply {
                            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                            setClass(applicationContext, AppWidgetProvider::class.java)
                        }
                        sendBroadcast(updateIntent)
                        Log.d(TAG, "Widget update broadcast sent for ${ids.size} widget(s)")
                    }
                } else {
                    Log.e(TAG, "API returned non-200: $code")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Sync Error: ${e.message}", e)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Widget Live Sync",
                NotificationManager.IMPORTANCE_MIN // silent, no sound
            ).apply {
                description = "Keeps your Home Screen widget data live"
                setShowBadge(false)
            }
            val mgr = getSystemService(NotificationManager::class.java)
            mgr.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("PaceWISP Widget")
            .setContentText("Syncing dashboard data…")
            .setSmallIcon(android.R.drawable.stat_notify_sync)
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
