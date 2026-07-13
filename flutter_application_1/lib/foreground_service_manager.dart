import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'dart:developer';

class ForegroundServiceManager {
  // Singleton
  static final ForegroundServiceManager instance = ForegroundServiceManager._();
  ForegroundServiceManager._();

  // Initialize the foreground task settings
  // Call this once in main() before runApp
  static void initialize() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'soundclass_detection',
        channelName: 'Sound Detection Service',
        channelDescription:
            'SoundClass is actively monitoring '
            'sounds in your environment.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        // LOW priority means notification is visible
        // but does not make sound or pop up intrusively
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // How often the background task runs
        // 5000ms = checks every 5 seconds
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        // Do not restart on reboot automatically
        allowWakeLock: true,
        // Keep CPU awake during detection
        allowWifiLock: false,
      ),
    );
  }

  //  Start the foreground service
  Future<ServiceRequestResult> startService() async {
    if (await FlutterForegroundTask.isRunningService) {
      return await FlutterForegroundTask.restartService();
    }

    return await FlutterForegroundTask.startService(
      serviceId: 101,
      notificationTitle: 'SoundClass is Active',
      notificationText: 'Monitoring your environment for sounds...',
      notificationIcon: null,
      notificationButtons: [
        const NotificationButton(id: 'stop_detection', text: 'Stop Detection'),
      ],
      callback: startCallback,
    );
  }

  //  Stop the foreground service
  Future<ServiceRequestResult> stopService() async {
    return await FlutterForegroundTask.stopService();
  }

  //  Update notification text
  // Called when a sound is detected to update
  // the notification with the latest sound
  Future<void> updateNotification(String soundLabel, double confidence) async {
    await FlutterForegroundTask.updateService(
      notificationTitle: 'Sound Detected: $soundLabel',
      notificationText:
          '${(confidence * 100).toStringAsFixed(0)}% confidence '
          '— tap to open SoundClass',
    );
  }

  //  Reset notification to default text
  Future<void> resetNotification() async {
    await FlutterForegroundTask.updateService(
      notificationTitle: 'SoundClass is Active',
      notificationText: 'Monitoring your environment for sounds...',
    );
  }

  // Check if service is running
  Future<bool> get isRunning async {
    return await FlutterForegroundTask.isRunningService;
  }
}

//  Background task handler
// This runs in the background when the app is minimized
// Aaron will add TFLite inference calls inside onRepeatEvent
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(SoundDetectionTaskHandler());
}

class SoundDetectionTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Called when the foreground service starts
    // Aaron initializes TFLite interpreter here
    log('Background sound detection started');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Called every 5000ms (set in ForegroundTaskOptions)
    // Aaron adds audio capture + inference here
    // When a sound is detected he calls:
    // FlutterForegroundTask.sendDataToMain({'soundClass': 'siren', 'confidence': 0.94})
    log('Background check running: $timestamp');
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    // Called when the foreground service stops
    // Aaron cleans up TFLite interpreter here
    log('Background sound detection stopped');
  }

  @override
  void onNotificationButtonPressed(String id) {
    // Called when user taps the Stop Detection
    // button in the notification
    if (id == 'stop_detection') {
      FlutterForegroundTask.stopService();
    }
  }

  @override
  void onNotificationPressed() {
    // Called when user taps the notification itself
    // Opens the app
    FlutterForegroundTask.launchApp('/dashboard');
  }
}
