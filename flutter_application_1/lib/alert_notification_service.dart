// This fires a separate bold notification
// when a sound is detected
// It appears as a heads-up popup even when
// the phone screen is off or in another app

import 'package:flutter/services.dart';

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
    try {
      await _channel.invokeMethod('showAlertNotification', {
        'soundClass': soundClass,
        'soundLabel': soundLabel,
        'confidence': (confidence * 100).toStringAsFixed(0),
      });
    } catch (e) {
      print('Alert notification failed: $e');
    }
  }
}
