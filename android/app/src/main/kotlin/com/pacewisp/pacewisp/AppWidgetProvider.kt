package com.pacewisp.pacewisp

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class AppWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                val isBlurred = widgetData.getBoolean("is_blurred", true)
                // Default formatting
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

                val pendingIntent = es.antonborri.home_widget.HomeWidgetLaunchIntent.getActivity(context,
                                MainActivity::class.java, Uri.parse("homeWidget://toggle_blur"))
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
