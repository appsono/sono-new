package wtf.sono

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.view.KeyEvent
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File
import kotlin.math.max

// ==== player home screen widget ====
// full-bleed album cover, with fallback when no cover
class SonoPlayerWidgetProvider : HomeWidgetProvider() {
    private val maxCoverPx = 512
    private val statePrefs = "sono_widget_state"
    private val keyLastPlaying = "last_playing"
    private val keyLastSong = "last_song"
    private val keyLastCoverChild = "last_cover_child"
    private val keyLastCoverPresent = "last_cover_present"

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

        val title = widgetData.getString("player_title", null)
        val playing = widgetData.getBoolean("player_playing", false)
        val hasSong = !title.isNullOrEmpty()

        val state = context.getSharedPreferences(statePrefs, Context.MODE_PRIVATE)
        val hadLast = state.contains(keyLastPlaying)
        val lastPlaying = state.getBoolean(keyLastPlaying, playing)

        // playing -> child 0, paused -> child 1
        val targetIndex = if (playing) 0 else 1
        val fromIndex = if (lastPlaying) 0 else 1
        val animate = hasSong && hadLast && (playing != lastPlaying)

        val song = widgetData.getString("player_song", null) ?: ""
        val hasCover = bitmap != null
        val hadLastSong = state.contains(keyLastSong)
        val lastSong = state.getString(keyLastSong, "")
        val lastCoverChild = state.getInt(keyLastCoverChild, 0)
        val lastCoverPresent = state.getBoolean(keyLastCoverPresent, false)

        val songChanged = hadLastSong && song != lastSong
        val coverSlide = songChanged && hasCover && lastCoverPresent
        val newCoverChild = if (hasCover && coverSlide) 1 - lastCoverChild else lastCoverChild

        // media buttons aimed at audio_service session
        val prevPi = mediaButton(context, KeyEvent.KEYCODE_MEDIA_PREVIOUS, 1)
        val playPausePi = mediaButton(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE, 2)
        val nextPi = mediaButton(context, KeyEvent.KEYCODE_MEDIA_NEXT, 3)

        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.sono_player_widget)

            if (bitmap != null) {
                views.setViewVisibility(R.id.widget_cover, View.VISIBLE)
                views.setViewVisibility(R.id.widget_fallback, View.GONE)

                val targetChildId = if (newCoverChild == 0) R.id.widget_cover_a else R.id.widget_cover_b
                views.setImageViewBitmap(targetChildId, bitmap)

                if (coverSlide) {
                    views.setDisplayedChild(R.id.widget_cover, lastCoverChild)
                    views.showNext(R.id.widget_cover)
                } else {
                    views.setDisplayedChild(R.id.widget_cover, newCoverChild)
                }
            } else {
                views.setViewVisibility(R.id.widget_cover, View.GONE)
                views.setViewVisibility(R.id.widget_fallback, View.VISIBLE)
            }

            if (hasSong) {
                views.setViewVisibility(R.id.widget_overlay, View.VISIBLE)
                if (animate) {
                    views.setDisplayedChild(R.id.widget_overlay, fromIndex)
                    views.showNext(R.id.widget_overlay)
                } else {
                    views.setDisplayedChild(R.id.widget_overlay, targetIndex)
                }
            } else {
                views.setViewVisibility(R.id.widget_overlay, View.GONE)
            }

            views.setOnClickPendingIntent(R.id.widget_zone_prev, prevPi)
            views.setOnClickPendingIntent(R.id.widget_zone_playpause, playPausePi)
            views.setOnClickPendingIntent(R.id.widget_zone_next, nextPi)

            appWidgetManager.updateAppWidget(id, views)
        }

        // remember what just showed
        state
            .edit()
            .putBoolean(keyLastPlaying, playing)
            .putString(keyLastSong, song)
            .putInt(keyLastCoverChild, newCoverChild)
            .putBoolean(keyLastCoverPresent, hasCover)
            .apply()
    }

    private fun mediaButton(
        context: Context,
        keyCode: Int,
        requestCode: Int,
    ): PendingIntent {
        val intent =
            Intent(Intent.ACTION_MEDIA_BUTTON).apply {
                component =
                    ComponentName(
                        context.packageName,
                        "com.ryanheise.audioservice.MediaButtonReceiver",
                    )
                putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
            }
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
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
