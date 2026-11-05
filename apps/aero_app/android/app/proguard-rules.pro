# ---- Flutter ----
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ---- media_kit / libmpv ----
# The native bridge is looked up reflectively from Dart FFI.
-keep class com.alexmercerind.media_kit.** { *; }
-keep class com.alexmercerind.** { *; }
-dontwarn com.alexmercerind.**

# ---- flutter_js / QuickJS ----
-keep class io.abner.flutter_js.** { *; }
-dontwarn io.abner.flutter_js.**

# ---- Drift / sqlite3 ----
-keep class app.cachet.** { *; }
-dontwarn java.sql.**
-dontwarn javax.naming.**

# ---- Kotlin coroutines / okhttp (dio uses Dart HTTP, but plugins may pull these) ----
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# Keep line numbers for readable crash reports.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
