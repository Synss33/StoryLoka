package com.storyloka.storyloka

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (bukan FlutterActivity) disyaratkan paket
// local_auth agar BiometricPrompt berjalan (login biometrik F-03).
class MainActivity : FlutterFragmentActivity()
