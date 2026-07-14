-dontwarn java.beans.**
-dontwarn org.mozilla.javascript.**

# Keep audio_service and just_audio_background classes
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.just_audio_background.** { *; }
-keep class com.ryanheise.just_audio.** { *; }
-keep class com.google.android.exoplayer2.** { *; }
-keep class androidx.media3.** { *; }
-keep class androidx.media.** { *; }
