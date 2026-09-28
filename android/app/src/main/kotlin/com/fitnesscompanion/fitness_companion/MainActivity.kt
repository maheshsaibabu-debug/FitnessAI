package com.fitnesscompanion.fitness_companion

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (not plain FlutterActivity): the `health` plugin
// registers an Activity Result launcher for the Health Connect permission
// flow, which requires the host Activity to be an androidx ComponentActivity.
// Plain FlutterActivity extends android.app.Activity directly and isn't one —
// health's onAttachedToActivity throws a ClassCastException against it,
// silently failing plugin registration and breaking every health call.
class MainActivity : FlutterFragmentActivity()
