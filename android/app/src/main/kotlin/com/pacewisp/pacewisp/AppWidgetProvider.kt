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

class AppWidgetProvider : HomeWidgetProvider() {
    companion object {
        const val ACTION_TOGGLE_BLUR = "com.pacewisp.pacewisp.ACTION_TOGGLE_BLUR"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_TOGGLE_BLUR) {
            // Get the specific SharedPreferences used by home_widget
            val prefs = context.getSharedPreferences("HomeWidgetPrefs", Context.MODE_PRIVATE)
            val current = prefs.getBoolean("is_blurred", true)
            prefs.edit().putBoolean("is_blurred", !current).apply()

            // Notify update
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisAppWidget = ComponentName(context.packageName, AppWidgetProvider::class.java.name)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(thisAppWidget)
            onUpdate(context, appWidgetManager, appWidgetIds, prefs)
        }
        super.onReceive(context, intent)
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                val isBlurred = widgetData.getBoolean("is_blurred", true)
                val income = widgetData.getString("income", "0") ?: "0"
                val entries = widgetData.getString("entries", "0") ?: "0"
                val accountName = widgetData.getString("account_name", "PaceWisp System Data") ?: "PaceWisp System Data"

                setTextViewText(R.id.tv_title, accountName)
                
                if (isBlurred) {
                    setTextViewText(R.id.tv_income, "Income: ***")
                    setTextViewText(R.id.tv_entries, "Entries: ***")
                } else {
                    setTextViewText(R.id.tv_income, "Income: $income")
                    setTextViewText(R.id.tv_entries, "Entries: $entries")
                }

                // Create a Broadcast Intent instead of Activity Intent
                val intent = Intent(context, AppWidgetProvider::class.java).apply {
                    action = ACTION_TOGGLE_BLUR
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    context, 0, intent, 
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
