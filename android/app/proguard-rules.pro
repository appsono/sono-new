-keepattributes Signature, InnerClasses

-keep class androidx.media.** { *; }
-keep class android.support.v4.media.** { *; }

-dontwarn android.support.v4.media.**

# media kit
-keep class com.alexmercerind.** { *; }
-dontwarn com.alexmercerind.**

# audio_service
-keep class com.ryanheise.audioservice.** { *; }
-dontwarn com.ryanheise.audioservice.**
