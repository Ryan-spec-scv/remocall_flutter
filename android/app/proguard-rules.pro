# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep accessibility service
-keep class com.remocall.remocall_flutter.SnapPayAccessibilityService { *; }
-keep class * extends android.accessibilityservice.AccessibilityService { *; }

# Keep notification service
-keep class com.remocall.remocall_flutter.NotificationService { *; }
-keep class * extends android.service.notification.NotificationListenerService { *; }

# Keep MainActivity
-keep class com.remocall.remocall_flutter.MainActivity { *; }

# Keep all native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep accessibility service metadata
-keep class android.accessibilityservice.** { *; }
-keepattributes *Annotation*

# Prevent obfuscation of service classes
-keepnames class * extends android.app.Service
-keepnames class * extends android.accessibilityservice.AccessibilityService

# Google Play Core missing classes
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Keep Google Play Core classes if they exist
-keep class com.google.android.play.core.** { *; }