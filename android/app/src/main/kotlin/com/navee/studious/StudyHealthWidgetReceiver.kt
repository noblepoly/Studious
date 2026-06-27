package com.navee.studious

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class StudyHealthWidgetReceiver : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            // Connect to our XML layout
            val views = RemoteViews(context.packageName, R.layout.study_health_widget).apply {
                
                // Grab the integer we saved from Flutter! (Defaults to 0 if empty)
                val health = widgetData.getInt("health_progress", 0)

                // Fill the green progress bar!
                setProgressBar(R.id.health_progress_bar, 100, health, false)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}