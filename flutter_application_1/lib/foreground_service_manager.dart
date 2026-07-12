import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'audio_ml_service.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(SoundDetectionTaskHandler());
}

class ForegroundServiceManager {
  static final ForegroundServiceManager instance = ForegroundServiceManager._();
  ForegroundServiceManager._();

  static void initialize() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'soundclass_channel',
        channelName: 'Sound Detection',
        channelDescription: 'SoundClass emergency sound alerts',
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

  Future<bool> startService() async {
    print('=== START SERVICE ===');

    // Request notification permission
    // Required on Android 13+
    await FlutterForegroundTask.requestNotificationPermission();

    // If already running just restart it
    if (await FlutterForegroundTask.isRunningService) {
      print('Already running — restarting');
      await FlutterForegroundTask.restartService();
      return true;
    }

    // Try up to 3 times
    // Works on all brands including
    // Samsung, Xiaomi, Oppo, Vivo, Realme, OnePlus
    for (int attempt = 1; attempt <= 3; attempt++) {
      print('Attempt $attempt...');
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
        print('Attempt $attempt error: $e');
      }

      // Wait then check if it started
      await Future.delayed(const Duration(milliseconds: 800));

      final running = await FlutterForegroundTask.isRunningService;
      print('Running after attempt $attempt: $running');

      if (running) return true;

      // Wait longer before next attempt
      if (attempt < 3) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    return false;
  }

  Future<void> stopService() async {
    print('=== STOP SERVICE ===');
    await AudioMLService.instance.stopListening();
    await FlutterForegroundTask.stopService();
  }

  Future<void> updateNotification(String label, double confidence) async {
    await FlutterForegroundTask.updateService(
      notificationTitle: '🔊 $label Detected!',
      notificationText:
          '${(confidence * 100).toStringAsFixed(0)}'
          '% confidence',
    );
  }

  Future<void> resetNotification() async {
    await FlutterForegroundTask.updateService(
      notificationTitle: 'SoundClass Active',
      notificationText: 'Monitoring your environment...',
    );
  }

  Future<bool> get isRunning async => FlutterForegroundTask.isRunningService;
}

class SoundDetectionTaskHandler extends TaskHandler {
  bool _started = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('TaskHandler: onStart');
    if (_started) return;
    _started = true;

    try {
      await AudioMLService.instance.startListening(
        onResult: (String label, double confidence) {
          if (confidence >= 0.85) {
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
      print('TaskHandler: AudioML started OK');
    } catch (e) {
      print('TaskHandler: error: $e');
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    print('TaskHandler: heartbeat');
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
