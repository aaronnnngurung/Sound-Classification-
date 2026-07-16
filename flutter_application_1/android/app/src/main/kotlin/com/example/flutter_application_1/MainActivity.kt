package com.example.flutter_application_1

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.android.FlutterFragmentActivity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import androidx.core.app.NotificationCompat

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
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

                "showAlertNotification" -> {

                    val soundClass =
                        call.argument<String>("soundClass") ?: ""

                    val soundLabel =
                        call.argument<String>("soundLabel") ?: ""

                    val confidence =
                        call.argument<String>("confidence") ?: ""

                    showAlertNotification(
                        soundClass,
                        soundLabel,
                        confidence
                    )

                    result.success(null)
                }
                "showPersistentNotification" -> {
    val title =
        call.argument<String>("title")
        ?: "SoundClass Active"
    val text =
        call.argument<String>("text")
        ?: "Monitoring..."
    showPersistentNotification(title, text)
    result.success(null)
}

"cancelPersistentNotification" -> {
    val nm = getSystemService(
        Context.NOTIFICATION_SERVICE
    ) as NotificationManager
    nm.cancel(888)
    result.success(null)
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
    private fun showPersistentNotification(
    title: String,
    text: String
) {
    val nm = getSystemService(
        Context.NOTIFICATION_SERVICE
    ) as NotificationManager

    // Create channel
    if (Build.VERSION.SDK_INT >=
        Build.VERSION_CODES.O) {
        val channel = NotificationChannel(
            "soundclass_persistent",
            "SoundClass Monitoring",
            NotificationManager.IMPORTANCE_LOW
        )
        nm.createNotificationChannel(channel)
    }

    val intent = packageManager
        .getLaunchIntentForPackage(packageName)
    val pi = PendingIntent.getActivity(
        this, 0, intent,
        PendingIntent.FLAG_UPDATE_CURRENT or
        PendingIntent.FLAG_IMMUTABLE
    )

    val notif = NotificationCompat
        .Builder(this, "soundclass_persistent")
        .setSmallIcon(
            android.R.drawable.ic_btn_speak_now)
        .setContentTitle(title)
        .setContentText(text)
        .setOngoing(true)
        // Ongoing = cannot be swiped away
        .setPriority(
            NotificationCompat.PRIORITY_LOW)
        .setContentIntent(pi)
        .build()

    nm.notify(888, notif)
}

    private fun showAlertNotification(
        soundClass: String,
        soundLabel: String,
        confidence: String
    ) {

        val notificationManager =
            getSystemService(
                Context.NOTIFICATION_SERVICE
            ) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {

            val channel = NotificationChannel(
                "soundclass_alert_channel",
                "Sound Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {

                description = "Emergency sound alerts"

                enableVibration(false)
            }

            notificationManager.createNotificationChannel(channel)
        }

        val intent =
            packageManager.getLaunchIntentForPackage(packageName)

        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or
                    PendingIntent.FLAG_IMMUTABLE
        )

        val emoji = when (soundClass) {

            "siren" -> "🚨"

            "crying_baby" -> "👶"

            "car_horn" -> "🚗"

            "glass_breaking" -> "💥"

            "door_wood_knock" -> "🚪"

            "clock_alarm" -> "⏰"

            "train" -> "🚂"

            "fireworks" -> "🎆"

            else -> "🔊"
        }

        val notification = NotificationCompat.Builder(
            this,
            "soundclass_alert_channel"
        )
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("$emoji $soundLabel Detected!")
            .setContentText("$confidence% confidence")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setFullScreenIntent(
                pendingIntent,
                true
            )
            .build()

        notificationManager.notify(999, notification)
    }
}
