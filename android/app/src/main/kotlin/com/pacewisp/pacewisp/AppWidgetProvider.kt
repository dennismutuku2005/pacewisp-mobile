package com.pacewisp.pacewisp

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import com.pacewisp.pacewisp.R

class AppWidgetProvider : HomeWidgetProvider() {
    companion object {
        const val ACTION_TOGGLE_BLUR = "com.pacewisp.pacewisp.ACTION_TOGGLE_BLUR"
        const val PREFS_NAME = "HomeWidgetPreferences"
    }

    override fun onReceive(context: Context, intent: Intent) {
        try {
            if (intent.action == ACTION_TOGGLE_BLUR) {
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val current = prefs.getBoolean("is_blurred", true)
                prefs.edit().putBoolean("is_blurred", !current).apply()

                // Trigger live sync when unblurring
                if (current == true) { 
                    try {
                        val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(
                            context, Uri.parse("pacewisp://sync_data")
                        )
                        backgroundIntent.send()
                    } catch (e: Exception) {}
                }

                val appWidgetManager = AppWidgetManager.getInstance(context)
                val thisAppWidget = ComponentName(context, AppWidgetProvider::class.java)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(thisAppWidget)
                onUpdate(context, appWidgetManager, appWidgetIds, prefs)
            }
        } catch (e: Exception) {}
        super.onReceive(context, intent)
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_layout)
                
                val isBlurred = widgetData.getBoolean("is_blurred", true)
                val income = widgetData.getString("income", "0") ?: "0"
                val entries = widgetData.getString("entries", "0") ?: "0"
                val accountName = widgetData.getString("account_name", "PaceWisp Admin") ?: "PaceWisp Admin"

                views.setTextViewText(R.id.tv_title, accountName)
                
                if (isBlurred) {
                    views.setTextViewText(R.id.tv_income, "KSH ***")
                    views.setTextViewText(R.id.tv_entries, "*** Entries")
                } else {
                    views.setTextViewText(R.id.tv_income, if (income.contains("KSH")) income else "KSH $income")
                    views.setTextViewText(R.id.tv_entries, if (entries.contains("Entries")) entries else "$entries Entries")
                }

                val intent = Intent(context, AppWidgetProvider::class.java).apply {
                    action = ACTION_TOGGLE_BLUR
                    data = Uri.parse("pacewisp://widget/$widgetId")
                }
                
                val pendingIntent = PendingIntent.getBroadcast(
                    context, widgetId, intent, 
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
                
                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (e: Exception) {}
        }
    }
}
