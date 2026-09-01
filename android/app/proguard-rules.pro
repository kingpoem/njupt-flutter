# Keep Flutter/Rust JNI entrypoints when R8 minifies.
-keep class io.flutter.** { *; }
-keep class com.kingpoem.njupt_flutter.** { *; }
-dontwarn io.flutter.embedding.**
