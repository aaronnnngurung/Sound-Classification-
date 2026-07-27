// emergency.dart
//
// FR-11 — Emergency Mode: when enabled, restricts alerts to
// safety-critical sounds only, suppressing alerts for routine sounds.
//
// This has to work from TWO different isolates:
//   1. The main UI isolate — SettingsScreen reads/writes the toggle.
//   2. The background foreground-service isolate — SoundDetectionTaskHandler
//      (in foreground_service_manager.dart) needs to check this on every
//      single detection, before doing anything else (haptics, the ongoing
//      notification, sendDataToMain to the dashboard).
//
// A plain in-memory singleton bool would NOT be visible across that
// isolate boundary (we hit the same issue with mic permission checks in
// AudioMLService — each isolate has its own memory). SharedPreferences is
// backed by a file on native storage, so both isolates read the current
// value straight from disk instead of trusting stale in-memory state.
import 'package:shared_preferences/shared_preferences.dart';

class EmergencyModeService {
  EmergencyModeService._();

  static const String _prefsKey = 'emergencyModeEnabled';

  // The ONLY sound classes considered "safety-critical" while Emergency
  // Mode is on. Per the current product decision, that's siren only —
  // crying_baby, car_horn, glass_breaking, door_wood_knock, and fireworks
  // are all treated as "routine" and get fully suppressed (no haptic, no
  // notification, no overlay, no dashboard update) while Emergency Mode
  // is active, even though they're still valid emergency-class detections
  // outside of Emergency Mode. Add classes here if "safety-critical"
  // should be broader — e.g. `{'siren', 'glass_breaking'}`.
  static const Set<String> safetyCriticalClasses = {'siren'};

  /// Raw stored value, or null if Emergency Mode has never been set on
  /// this device (used by SettingsScreen to know whether to fall back to
  /// a Firestore-synced value on first load).
  static Future<bool?> getStoredValue() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey);
  }

  /// Whether Emergency Mode is currently enabled. Defaults to false
  /// (normal mode) if never set. Always re-reads from persistent
  /// storage rather than caching — the value needs to be current no
  /// matter which isolate is asking.
  static Future<bool> isEnabled() async {
    return (await getStoredValue()) ?? false;
  }

  /// Turn Emergency Mode on/off. Called from SettingsScreen when the
  /// user flips the toggle.
  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, enabled);
    print('EmergencyMode: set to $enabled');
  }

  /// Single choke point for "should this detection be allowed to alert
  /// right now?" — call this before doing ANYTHING else with a
  /// detection (haptics, notification updates, sendDataToMain to the
  /// dashboard). In normal mode everything is allowed to alert; in
  /// Emergency Mode only [safetyCriticalClasses] are.
  static Future<bool> shouldAlert(String soundClass) async {
    final emergencyModeOn = await isEnabled();
    if (!emergencyModeOn) return true;

    final allowed = safetyCriticalClasses.contains(soundClass);
    if (!allowed) {
      print(
        'EmergencyMode: suppressing "$soundClass" — not safety-critical '
        'while Emergency Mode is on.',
      );
    }
    return allowed;
  }
}