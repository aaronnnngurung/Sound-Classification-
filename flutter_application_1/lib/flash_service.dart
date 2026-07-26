import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FlashService {
  static final FlashService instance = FlashService._();
  FlashService._();

  static const _channel = MethodChannel('com.soundclass/haptic');

  Future<void> blinkForSound(String soundClass) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('cameraFlashAlert') ?? false;
      if (!enabled) return;

      await _channel.invokeMethod('flashBlink', {
        'soundClass': soundClass,
      });
    } catch (e) {
      debugPrint('Flash blink failed: $e');
    }
  }
}
