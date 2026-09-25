# Flutter Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Flutter Reactive BLE
-keep class com.signify.hue.flutterreactiveble.** { *; }
-dontwarn com.signify.hue.flutterreactiveble.**

# Sentry
-keepattributes LineNumberTable,SourceFile
-keepclassmembers class * {
    @com.google.errorprone.annotations.Keep <methods>;
}
-dontwarn io.sentry.**
