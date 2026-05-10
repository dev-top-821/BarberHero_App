package com.barberhero.barberhero_customer

// flutter_stripe requires MainActivity to extend FlutterFragmentActivity so
// the Stripe PaymentSheet fragment can attach to the host Activity.
// Extending FlutterActivity will crash the PaymentSheet with:
//   "Your Main Activity class [...] is not a subclass FlutterFragmentActivity"
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
