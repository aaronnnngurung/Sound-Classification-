// foreground_service_manager.dart
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'audio_ml_service.dart';
import 'haptic_service.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(SoundDetectionTaskHandler());
}

class ForegroundServiceManager {
  static final ForegroundServiceManager instance = ForegroundServiceManager._();
  ForegroundServiceManager._();

  // Track if we are using fallback mode
  bool _usingFallback = false;
  bool get usingFallback => _usingFallback;

  static void initialize() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'soundclass_v4',
        channelName: 'SoundClass Detection',
        channelDescription: 'Emergency sound detection',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(10000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  // Callback set by dashboard to receive results
  Function(String soundClass, double confidence)? onSoundDetected;

  Future<bool> startService() async {
    print('=== START SERVICE ===');
    _usingFallback = false;

    await FlutterForegroundTask.requestNotificationPermission();

    // Try foreground service first
    final serviceStarted = await _tryStartForegroundService();

    if (serviceStarted) {
      print('Foreground service started OK');
      return true;
    }

    // Foreground service failed
    // Fall back to main isolate with wake lock
    print(
      'Foreground service failed — '
      'using fallback mode',
    );
    return await _startFallbackMode();
  }

  Future<bool> _tryStartForegroundService() async {
    if (await FlutterForegroundTask.isRunningService) {
      return true;
    }

    for (int i = 1; i <= 2; i++) {
      print('Service attempt $i...');
      try {
        await FlutterForegroundTask.startService(
          serviceId: 256,
          notificationTitle: 'SoundClass Active',
          notificationText: 'Monitoring your environment...',
          notificationButtons: [
            const NotificationButton(id: 'stop_btn', text: 'Stop'),
          ],
          callback: startCallback,
        );
      } catch (e) {
        print('Service attempt $i error: $e');
      }

      await Future.delayed(const Duration(milliseconds: 800));

      if (await FlutterForegroundTask.isRunningService) {
        return true;
      }
    }
    return false;
  }

  // Fallback: run in main isolate with wake lock
  // This keeps detection running even on Xiaomi
  // as long as the app is not fully killed
  Future<bool> _startFallbackMode() async {
    print('Starting fallback mode...');
    _usingFallback = true;

    try {
      // Keep CPU awake
      await WakelockPlus.enable();
      print('Wake lock enabled');

      // Show notification via platform channel
      await _showFallbackNotification();

      // Start audio in main isolate
      await AudioMLService.instance.startListening(
        onResult: (label, confidence) {
        print(
          'Fallback detected: $label '
          '(${(confidence * 100).toStringAsFixed(1)}%)',
        );

        bool detected =
            (label == 'car_horn' || label == 'fireworks')
                ? confidence >= 0.95
                : confidence >= 0.80;

        if (!detected) return;

        HapticService.instance.vibrateForSound(label);
        onSoundDetected?.call(label, confidence);
        _updateFallbackNotification(label, confidence);
},
      );

      print('Fallback mode started OK');
      return true;
    } catch (e) {
      print('Fallback mode error: $e');
      _usingFallback = false;
      return false;
    }
  }

  Future<void> stopService() async {
    print('=== STOP SERVICE ===');

    if (_usingFallback) {
      // Stop fallback mode
      await AudioMLService.instance.stopListening();
      await WakelockPlus.disable();
      await _cancelFallbackNotification();
      _usingFallback = false;
    } else {
      // Stop foreground service
      await FlutterForegroundTask.stopService();
    }
  }

  Future<void> updateNotification(String label, double confidence) async {
    if (_usingFallback) {
      await _updateFallbackNotification(label, confidence);
    } else {
      await FlutterForegroundTask.updateService(
        notificationTitle: '🔊 $label Detected!',
        notificationText:
            '${(confidence * 100).toStringAsFixed(0)}% confidence',
      );
      Future.delayed(const Duration(seconds: 5), () {
        FlutterForegroundTask.updateService(
          notificationTitle: 'SoundClass Active',
          notificationText: 'Monitoring your environment...',
        );
      });
    }
  }

  Future<void> resetNotification() async {
    if (!_usingFallback) {
      await FlutterForegroundTask.updateService(
        notificationTitle: 'SoundClass Active',
        notificationText: 'Monitoring your environment...',
      );
    }
  }

  Future<bool> get isRunning async {
    if (_usingFallback) {
      return AudioMLService.instance.isListening;
    }
    return FlutterForegroundTask.isRunningService;
  }

  // ── Fallback notification via platform channel ──
  static const _channel = MethodChannel('com.soundclass/haptic');

  Future<void> _showFallbackNotification() async {
    try {
      await _channel.invokeMethod('showPersistentNotification', {
        'title': 'SoundClass Active',
        'text': 'Monitoring your environment...',
      });
    } catch (e) {
      print('Fallback notification error: $e');
    }
  }

  Future<void> _updateFallbackNotification(
    String label,
    double confidence,
  ) async {
    try {
      await _channel.invokeMethod('showPersistentNotification', {
        'title': '🔊 $label Detected!',
        'text': '${(confidence * 100).toStringAsFixed(0)}% confidence',
      });
    } catch (e) {
      print('Update notification error: $e');
    }
  }

  Future<void> _cancelFallbackNotification() async {
    try {
      await _channel.invokeMethod('cancelPersistentNotification');
    } catch (e) {
      print('Cancel notification error: $e');
    }
  }
}

// Foreground service task handler
// Used when foreground service actually starts
class SoundDetectionTaskHandler extends TaskHandler {
  bool _started = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('TaskHandler: onStart');
    if (_started) return;
    _started = true;

    try {
      await AudioMLService.instance.startListening(
        onResult: (label, confidence) {
          if (confidence >= 0.92) {
            HapticService.instance.vibrateForSound(label);
            FlutterForegroundTask.sendDataToMain({
              'soundClass': label,
              'confidence': confidence,
            });
            FlutterForegroundTask.updateService(
              notificationTitle: '🔊 $label Detected!',
              notificationText:
                  '${(confidence * 100).toStringAsFixed(0)}% confidence',
            );
            Future.delayed(
              const Duration(seconds: 5),
              () => FlutterForegroundTask.updateService(
                notificationTitle: 'SoundClass Active',
                notificationText: 'Monitoring your environment...',
              ),
            );
          }
        },
      );
      print('TaskHandler: audio started OK');
    } catch (e) {
      print('TaskHandler error: $e');
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    print(
      'TaskHandler: heartbeat — '
      'listening: ${AudioMLService.instance.isListening}',
    );

    if (!AudioMLService.instance.isListening) {
      print('TaskHandler: restarting audio...');
     AudioMLService.instance.startListening(
      onResult: (label, confidence) {
        bool detected =
            (label == 'car_horn' || label == 'fireworks')
                ? confidence >= 0.95
                : confidence >= 0.80;

        if (!detected) return;

        HapticService.instance.vibrateForSound(label);

        FlutterForegroundTask.sendDataToMain({
          'soundClass': label,
          'confidence': confidence,
        });
      },
    );
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    print('TaskHandler: onDestroy');
    _started = false;
    await AudioMLService.instance.stopListening();
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop_btn') {
      FlutterForegroundTask.stopService();
    }
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/dashboard');
  }
}
