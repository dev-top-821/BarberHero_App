# ── Firebase (default rules usually cover it, but some
#    reflection calls get stripped under R8 full mode) ─
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
