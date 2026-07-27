import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'watch_sync_service.dart'; // Contains EmergencyAlert model
import 'dart:typed_data';

class WatchNotificationService {
  static final WatchNotificationService instance = WatchNotificationService._();
  WatchNotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Initialize notifications for the Wear OS Watch
  Future<void> init() async {
    if (_initialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    //  FIX: Pass 'settings:' as a named parameter
    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Optional: Handle notification taps on the watch face
      },
    );

    _initialized = true;
  }

  /// Displays high-priority notification on the Wear OS watch face
  Future<void> showEmergencyNotification(EmergencyAlert alert) async {
    if (!_initialized) {
      await init();
    }

    final String name = alert.soundClass.replaceAll('_', ' ').toUpperCase();
    final String confidencePercent = (alert.confidence * 100).toStringAsFixed(0);

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'watch_emergency_channel',
      'Watch Emergency Alerts',
      channelDescription: 'High priority vibration and popup alerts on smartwatch',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'EMERGENCY',
      enableVibration: true,
      // Custom vibration pattern for watch wrist motor: [pause, vibe, pause, vibe...]
      vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 1000]),
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
        interruptionLevel: InterruptionLevel.critical,
      ),
    );

    // 🚨 FIX: Pass all arguments as named parameters
    await _notificationsPlugin.show(
      id: alert.timestamp.millisecondsSinceEpoch ~/ 1000, // Unique ID per alert
      title: '🚨 $name DETECTED',
      body: 'Confidence: $confidencePercent%',
      notificationDetails: platformDetails,
      payload: alert.soundClass,
    );
  }
}