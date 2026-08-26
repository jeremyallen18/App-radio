package com.example.brl_task4

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity en vez de FlutterActivity: lo exige local_auth
// para poder mostrar el prompt nativo de biometría/PIN en Android.
class MainActivity: FlutterFragmentActivity() {
}
