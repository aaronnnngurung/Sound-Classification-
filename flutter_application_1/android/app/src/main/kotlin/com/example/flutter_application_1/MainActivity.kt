package com.example.flutter_application_1

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.content.Context
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.soundclass/haptic"

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {

                "vibrate" -> {
                    val patternList =
                        call.argument<List<Int>>(
                            "pattern")
                    if (patternList != null) {
                        vibrate(patternList
                            .map { it.toLong() }
                            .toLongArray())
                        result.success(null)
                    } else {
                        result.error(
                            "INVALID_ARGS",
                            "Pattern null", null)
                    }
                }

                "openSettings" -> {
                    val intent = Intent(
                        Settings
                        .ACTION_APPLICATION_DETAILS_SETTINGS
                    )
                    intent.data = Uri.parse(
                        "package:$packageName")
                    startActivity(intent)
                    result.success(null)
                }

                // Returns device brand so Flutter
                // can show brand-specific instructions
                "getDeviceBrand" -> {
                    val brand = Build.MANUFACTURER
                        .lowercase()
                    result.success(brand)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun vibrate(pattern: LongArray) {
        if (Build.VERSION.SDK_INT >=
            Build.VERSION_CODES.S) {
            val vm = getSystemService(
                Context.VIBRATOR_MANAGER_SERVICE
            ) as VibratorManager
            vm.defaultVibrator.vibrate(
                VibrationEffect.createWaveform(
                    pattern, -1))
        } else {
            @Suppress("DEPRECATION")
            val v = getSystemService(
                Context.VIBRATOR_SERVICE
            ) as Vibrator
            if (Build.VERSION.SDK_INT >=
                Build.VERSION_CODES.O) {
                v.vibrate(
                    VibrationEffect.createWaveform(
                        pattern, -1))
            } else {
                @Suppress("DEPRECATION")
                v.vibrate(pattern, -1)
            }
        }
    }
}