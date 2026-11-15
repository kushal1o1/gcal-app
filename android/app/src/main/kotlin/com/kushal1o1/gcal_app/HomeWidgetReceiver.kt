package com.kushal1o1.gcal_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

/**
 * gcal home-screen widget.
 *
 * Classic RemoteViews provider (no Glance/Compose renderer): renders whatever
 * the app last pushed via HomeWidget.saveWidgetData, so the widget never
 * depends on the Glance runtime / preview tooling that crashed on newer AGP.
 *
 * Expects a single "events_json" pref holding up to 3 rows of
 * {"title": ..., "time": ...} in the form "Nov 8 · 9:00 AM".
 */
class HomeWidgetReceiver : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (appWidgetId in appWidgetIds) {
            appWidgetManager.updateAppWidget(appWidgetId, buildViews(context, widgetData))
        }
    }

    private fun buildViews(context: Context, data: SharedPreferences): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.home_widget)
        val rows = listOf(
            Triple(R.id.widget_row0_container, R.id.widget_row0_title, R.id.widget_row0_time),
            Triple(R.id.widget_row1_container, R.id.widget_row1_title, R.id.widget_row1_time),
            Triple(R.id.widget_row2_container, R.id.widget_row2_title, R.id.widget_row2_time),
        )
        val raw = data.getString("events_json", null)
        if (raw.isNullOrBlank()) {
            views.setTextViewText(rows[0].second, context.getString(R.string.widget_no_upcoming))
            views.setViewVisibility(rows[0].third, View.GONE)
            for (i in 1 until rows.size) hide(views, rows[i])
            return views
        }

        var array: JSONArray
        var count: Int
        try {
            array = JSONArray(raw)
            count = array.length().coerceIn(0, rows.size)
        } catch (_: Exception) {
            array = JSONArray()
            count = 0
        }
        for (i in 0 until rows.size) {
            val (container, title, time) = rows[i]
            if (i < count) {
                val obj = array.getJSONObject(i)
                views.setTextViewText(title, obj.optString("title"))
                val timeText = obj.optString("time", "")
                if (timeText.isBlank()) {
                    views.setViewVisibility(time, View.GONE)
                } else {
                    views.setTextViewText(time, timeText)
                    views.setViewVisibility(time, View.VISIBLE)
                }
                views.setViewVisibility(container, View.VISIBLE)
            } else {
                hide(views, rows[i])
            }
        }
        return views
    }

    private fun hide(views: RemoteViews, row: Triple<Int, Int, Int>) {
        views.setViewVisibility(row.first, View.GONE)
        views.setViewVisibility(row.second, View.GONE)
        views.setViewVisibility(row.third, View.GONE)
    }
}