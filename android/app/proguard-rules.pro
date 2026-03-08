-keep class com.lucasjosino.on_audio_query.** { *; }
-dontwarn com.lucasjosino.on_audio_query.**
-keepattributes Signature, InnerClasses

-keep class com.google.android.exoplayer2.** { *; }
-keep class androidx.media3.** { *; }

-keep class androidx.media.** { *; }
-keep class android.support.v4.media.** { *; }

-dontwarn com.google.android.exoplayer2.**
-dontwarn androidx.media3.**
-dontwarn android.support.v4.media.**