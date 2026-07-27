import 'package:flutter/services.dart';
import 'smartwatch/watch_sync_service.dart'; // Make sure this path is correct

class AlertNotificationService {
  static final AlertNotificationService instance = AlertNotificationService._();
  AlertNotificationService._();

  static const _channel = MethodChannel('com.soundclass/haptic');

  // Show a bold alert notification
  // This pops up over whatever app is running
  Future<void> showAlertNotification({
    required String soundClass,
    required String soundLabel,
    required double confidence,
  }) async {
    final String confidencePercent = (confidence * 100).toStringAsFixed(0);

    // 1. TRIGGER NATIVE PHONE ALERT (Heads-Up Popup & Phone Haptics)
    try {
      await _channel.invokeMethod('showAlertNotification', {
        'soundClass': soundClass,
        'soundLabel': soundLabel,
        'confidence': confidencePercent,
      });
    } catch (e) {
      print('Native Phone Alert Notification failed: $e');
    }

    // 2. TRIGGER WEAR OS WATCH ALERT & SYNC DATA
    try {
      // 🚨 FIX: We must construct the EmergencyAlert object first!
      final alert = EmergencyAlert(
        soundClass: soundClass,
        confidence: confidence,
        timestamp: DateTime.now(),
      );
      
      // Then pass that single object to the sync service
      await WatchSyncService.instance.sendEmergencyAlert(alert);
    } catch (e) {
      print('Watch Sync failed: $e');
    }
  }
}