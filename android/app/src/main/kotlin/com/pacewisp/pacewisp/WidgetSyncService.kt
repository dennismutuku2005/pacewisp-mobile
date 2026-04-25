package com.pacewisp.pacewisp

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.os.Handler
import android.os.Looper
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.util.Log
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.Timer
import java.util.TimerTask

class WidgetSyncService : Service() {
    private var timer: Timer? = null

    override fun onBind(intent: Intent?): IBinder? = null

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
        }, 0, 20000) // 20 seconds
    }

    private fun fetchAndRefreshWidget() {
        try {
            // Read Flutter Shared Preferences
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val subdomain = prefs.getString("flutter.subdomain", "") ?: ""
            val domain = prefs.getString("flutter.domain", "pacewisp.co.ke") ?: "pacewisp.co.ke"
            val token = prefs.getString("flutter.token", "") ?: ""

            if (subdomain.isEmpty() || token.isEmpty()) return

            val host = if (subdomain.contains(".")) subdomain else "$subdomain.$domain"
            val url = URL("https://$host/dashboard/v1/dashboard.php?slug=widgets")
            
            with(url.openConnection() as HttpURLConnection) {
                requestMethod = "GET"
                setRequestProperty("Authorization", "Bearer $token")
                
                if (responseCode == HttpURLConnection.HTTP_OK) {
                    val response = inputStream.bufferedReader().use { it.readText() }
                    val json = JSONObject(response)
                    val data = json.optJSONObject("data") ?: json
                    
                    val income = data.optJSONObject("todays_earnings")?.optString("value", "0") ?: "0"
                    val entries = data.optJSONObject("active_users")?.optString("value", "0") ?: "0"

                    // Save to HomeWidgetPreferences for the provider to pick up
                    val widgetPrefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                    widgetPrefs.edit().apply {
                        putString("income", income)
                        putString("entries", entries)
                        apply()
                    }

                    // Force Widget Update
                    val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
                    val ids = appWidgetManager.getAppWidgetIds(ComponentName(applicationContext, AppWidgetProvider::class.java))
                    val provider = AppWidgetProvider()
                    provider.onUpdate(applicationContext, appWidgetManager, ids, widgetPrefs)
                }
            }
        } catch (e: Exception) {
            Log.e("WidgetSyncService", "Sync Error: ${e.message}")
        }
    }

    override fun onDestroy() {
        timer?.cancel()
        super.onDestroy()
    }
}
