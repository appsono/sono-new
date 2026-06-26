package wtf.sono

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File
import kotlin.math.max

// ==== player home screen widget ====
// full-bleed album cover, with fallback when no cover
class SonoPlayerWidgetProvider : HomeWidgetProvider() {
    // cap longest side for RemoteViews binder limit
    // (thumbs are already small)
    private val maxCoverPx = 512

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val coverPath = widgetData.getString("player_cover", null)
        val bitmap =
            coverPath
                ?.takeIf { it.isNotEmpty() }
                ?.let { decodeBounded(it, maxCoverPx) }

        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.sono_player_widget)

            if (bitmap != null) {
                views.setImageViewBitmap(R.id.widget_cover, bitmap)
                views.setViewVisibility(R.id.widget_cover, View.VISIBLE)
                views.setViewVisibility(R.id.widget_fallback, View.GONE)
            } else {
                views.setViewVisibility(R.id.widget_cover, View.GONE)
                views.setViewVisibility(R.id.widget_fallback, View.VISIBLE)
            }

            appWidgetManager.updateAppWidget(id, views)
        }
    }

    // decode with inSampleSize to prevent large bitmap binder overflow
    private fun decodeBounded(
        path: String,
        maxPx: Int,
    ): Bitmap? {
        val file = File(path)
        if (!file.exists()) return null
        return try {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(path, bounds)
            var longest = max(bounds.outWidth, bounds.outHeight)
            var sample = 1
            while (longest / sample > maxPx) sample *= 2
            BitmapFactory.decodeFile(path, BitmapFactory.Options().apply { inSampleSize = sample })
        } catch (e: Exception) {
            null
        }
    }
}
