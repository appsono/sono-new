-keepattributes Signature, InnerClasses

-keep class com.google.android.exoplayer2.** { *; }
-keep class androidx.media3.** { *; }

-keep class androidx.media.** { *; }
-keep class android.support.v4.media.** { *; }

-dontwarn com.google.android.exoplayer2.**
-dontwarn androidx.media3.**
-dontwarn android.support.v4.media.**

# media kit
-keep class com.alexmercerind.** { *; }
-dontwarn com.alexmercerind.**

# audio_service
-keep class com.ryanheise.audioservice.** { *; }
-dontwarn com.ryanheise.audioservice.**
