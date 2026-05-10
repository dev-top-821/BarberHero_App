# ── flutter_stripe ─────────────────────────────────────────────
# The Stripe SDK references Push Provisioning (Google Wallet)
# classes that live in a separate, optional artifact we don't
# ship. R8 fails the release build on these missing references
# unless we tell it not to warn. We never call this code path.
-dontwarn com.stripe.android.pushProvisioning.**
-keep class com.stripe.android.pushProvisioning.** { *; }

# The React Native wrapper classes that reference the above:
-dontwarn com.reactnativestripesdk.pushprovisioning.**
-keep class com.reactnativestripesdk.pushprovisioning.** { *; }

# ── Firebase (extra safety — default rules usually cover it,
#    but some reflection calls get stripped under R8 full mode) ─
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
