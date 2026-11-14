# Proguard / R8 rules for Boored

# Missing rules reported by R8
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# ML Kit Text Recognition optional language packs (Chinese, Devanagari, Japanese, Korean)
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-dontwarn com.google.mlkit.vision.text.**
-dontwarn com.google_mlkit_text_recognition.**

# Keep ML Kit components
-keep class com.google.mlkit.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }
-keep class com.google_mlkit_selfie_segmentation.** { *; }

# OpenCV
-dontwarn org.opencv.**
-keep class org.opencv.** { *; }
-keepclassmembers class org.opencv.** { *; }

# Flutter & plugins
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Suppress all other harmless unresolved references during minification
-ignorewarnings
