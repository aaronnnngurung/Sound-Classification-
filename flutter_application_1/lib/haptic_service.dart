import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HapticService {
  static final HapticService instance = HapticService._();
  HapticService._();

  static const _channel = MethodChannel('com.soundclass/haptic');

  // Main method called for every detection
  // Works both foreground and background
  Future<void> vibrateForSound(String soundClass) async {
    // First try native Android vibration
    // This works in background and foreground
    final bool nativeWorked = await _nativeVibrate(soundClass);

    // Fallback to Flutter haptics if native fails
    // Only works in foreground but better than nothing
    if (!nativeWorked) {
      _flutterHaptic(soundClass);
    }
  }

  //  Native Android vibration
  // Calls MainActivity.kt vibrate() method
  // Works when app is in background or screen locked
  Future<bool> _nativeVibrate(String soundClass) async {
    try {
      final pattern = _getPattern(soundClass);
      await _channel.invokeMethod('vibrate', {'pattern': pattern});
      return true;
    } catch (e) {
      debugPrint('Native vibrate failed: $e');
      return false;
    }
  }

  // Flutter fallback haptics
  // Only works when app is in foreground
  void _flutterHaptic(String soundClass) {
    switch (soundClass) {
      case 'siren':
        HapticFeedback.heavyImpact();
        Future.delayed(
          const Duration(milliseconds: 200),
          HapticFeedback.heavyImpact,
        );
        Future.delayed(
          const Duration(milliseconds: 400),
          HapticFeedback.heavyImpact,
        );
        break;
      case 'crying_baby':
        HapticFeedback.mediumImpact();
        Future.delayed(
          const Duration(milliseconds: 300),
          HapticFeedback.mediumImpact,
        );
        break;
      case 'car_horn':
        HapticFeedback.heavyImpact();
        break;
      case 'glass_breaking':
        HapticFeedback.lightImpact();
        Future.delayed(
          const Duration(milliseconds: 100),
          HapticFeedback.lightImpact,
        );
        Future.delayed(
          const Duration(milliseconds: 200),
          HapticFeedback.lightImpact,
        );
        break;
      default:
        HapticFeedback.mediumImpact();
    }
  }

  //  Vibration patterns per sound class
  // Pattern format: [wait, buzz, wait, buzz, ...]
  // All values in milliseconds
  List<int> _getPattern(String soundClass) {
    switch (soundClass) {
      case 'siren':
        // 3 long heavy pulses — urgent emergency feel
        // wait 0ms → buzz 500ms → wait 200ms
        // → buzz 500ms → wait 200ms → buzz 500ms
        return [0, 500, 200, 500, 200, 500];

      case 'crying_baby':
        // 2 soft medium pulses — gentle alert
        // wait 0ms → buzz 250ms → wait 300ms
        // → buzz 250ms
        return [0, 250, 300, 250];

      case 'car_horn':
        // 1 sharp strong pulse — like a horn blast
        // wait 0ms → buzz 400ms
        return [0, 400];

      case 'glass_breaking':
        // 4 very short rapid pulses — sharp/staccato
        // mimics the sound of shattering glass
        return [0, 80, 60, 80, 60, 80, 60, 80];

      case 'door_wood_knock':
        // 2 pulses with knock rhythm
        // wait 0ms → buzz 150ms → wait 150ms
        // → buzz 150ms
        return [0, 150, 150, 150];

      default:
        // Generic single pulse for anything else
        return [0, 300];
    }
  }
}
