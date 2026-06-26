package wtf.sono

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

// ==== player home screen widget ====
// render current title/artist
// + debug play-state label
class SonoPlayerWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.sono_player_widget)

            val title = widgetData.getString("player_title", null)
            val artist = widgetData.getString("player_artist", null)
            val playing = widgetData.getBoolean("player_playing", false)

            val hasSong = !title.isNullOrEmpty()

            views.setTextViewText(R.id.widget_title, if (hasSong) title else "Sono")
            views.setTextViewText(R.id.widget_artist, if (hasSong) (artist ?: "") else "")
            views.setTextViewText(
                R.id.widget_state,
                when {
                    !hasSong -> ""
                    playing -> "Playing"
                    else -> "Paused"
                }
            )

            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
