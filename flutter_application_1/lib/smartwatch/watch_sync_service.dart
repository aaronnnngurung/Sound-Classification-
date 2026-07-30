import 'dart:async';
import 'package:flutter_wear_os_connectivity/flutter_wear_os_connectivity.dart';
import 'package:vibration/vibration.dart';
import 'watch_notification_service.dart';
import 'package:flutter_application_1/utils/emergency.dart';
/// A single emergency event — used on BOTH sides: the phone constructs
/// one to send, the watch reconstructs one from the incoming DataItem.
class EmergencyAlert {
  final String soundClass;
  final double confidence;
  final DateTime timestamp;

  const EmergencyAlert({
    required this.soundClass,
    required this.confidence,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'class': soundClass,
    'confidence': confidence,
    'timestamp': timestamp.millisecondsSinceEpoch,
  };

  factory EmergencyAlert.fromJson(Map<String, dynamic> json) {
    return EmergencyAlert(
      soundClass: json['class'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (json['timestamp'] as num).toInt(),
      ),
    );
  }
}

/// Shared by BOTH the phone app and the watch app (same Flutter project,
/// two entry points — lib/main.dart and lib/main_watch.dart). Only the
/// methods relevant to each side get called from that side:
///   - Phone calls initializePhoneSide() once, then sendEmergencyAlert()
///     per detection.
///   - Watch calls initializeWatchListener() once at startup.
class WatchSyncService {
  static final WatchSyncService instance = WatchSyncService._();
  WatchSyncService._();

  static const String _dataPath = '/emergency-alert';
  // Advertised by the phone so the watch can tell "a phone is nearby"
  // apart from "the SoundClass phone app is actually running and
  // reachable" — a real Bluetooth connection alone doesn't mean the
  // companion app is installed/active on the other end.
  static const String _phoneCapability = 'soundclass_phone_app';

  final FlutterWearOsConnectivity _connectivity = FlutterWearOsConnectivity();

  final _alertController = StreamController<EmergencyAlert>.broadcast();
  Stream<EmergencyAlert> get alertStream => _alertController.stream;

  final _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  bool _configured = false;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _connectivity.configureWearableAPI();
    _configured = true;
  }

  // ── PHONE SIDE ──────────────────────────────────────────────────

  /// Call once, early in the phone app's lifecycle (e.g. alongside
  /// ForegroundServiceManager.initialize() in main.dart), so the watch
  /// can detect the phone app as a live capability.
  Future<void> initializePhoneSide() async {
    await _ensureConfigured();
    try {
      await _connectivity.registerNewCapability(_phoneCapability);
    } catch (e) {
      print('WatchSyncService: registerNewCapability failed: $e');
    }
  }

  /// Call this from the phone for every detection that already passed
  /// AudioMLService.isDetectionValid — see foreground_service_manager.dart
  /// SoundDetectionTaskHandler._handleDetection for where to add the call.
  Future<void> sendEmergencyAlert(EmergencyAlert alert) async {
    await _ensureConfigured();
    try {
      // isUrgent: true — emergency alerts should not wait for the
      // system's opportunistic sync window. syncData still succeeds
      // even if the watch is briefly unreachable; it'll deliver once
      // the watch reconnects, rather than being dropped like a
      // best-effort message would be.
      final dataItem = await _connectivity.syncData(
        path: _dataPath,
        data: alert.toJson(),
        isUrgent: true,
      );
      print(
        'WatchSyncService: sent ${alert.soundClass} '
        '(${dataItem != null ? "synced" : "queued — watch not reachable yet"})',
      );
    } catch (e) {
      print('WatchSyncService: sendEmergencyAlert failed: $e');
    }
  }

  // ── WATCH SIDE ──────────────────────────────────────────────────

  /// Call once from main_watch.dart at startup.
  Future<void> initializeWatchListener() async {
    await _ensureConfigured();

    _connectivity
        .dataChanged(pathURI: Uri(scheme: 'wear', host: '*', path: _dataPath))
        .listen((dataEvents) {
          for (final event in dataEvents) {
            if (event.type != DataEventType.changed) continue;
            try {
              final alert = EmergencyAlert.fromJson(event.dataItem.mapData);
              _alertController.add(alert);
              _vibrateHeavily();
              WatchNotificationService.instance.showEmergencyNotification(
                alert,
              );
            } catch (e) {
              print('WatchSyncService: failed to parse incoming alert: $e');
            }
          }
        });

    // Reactive "connected to phone" status, driven by the phone
    // advertising _phoneCapability in initializePhoneSide(). This
    // reflects "the SoundClass phone app is live", not just "a phone is
    // paired" — a paired-but-app-not-running phone won't show connected.
    _connectivity.capabilityChanged(capabilityName: _phoneCapability).listen((
      info,
    ) {
      _connectionController.add(info.associatedDevices.isNotEmpty);
    });

    final initialCapability = await _connectivity.findCapabilityByName(
      _phoneCapability,
    );
    _connectionController.add(
      initialCapability?.associatedDevices.isNotEmpty ?? false,
    );
  }

  // Heavy wrist vibration on top of the notification channel's own
  // vibration pattern (see watch_notification_service.dart) — belt and
  // suspenders for something safety-critical. If that feels redundant
  // once you test on real hardware, it's safe to drop one or the other.
  Future<void> _vibrateHeavily() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator ?? false) {
        Vibration.vibrate(pattern: [0, 400, 150, 400, 150, 800]);
      }
    } catch (e) {
      print('WatchSyncService: vibration failed: $e');
    }
  }

  void dispose() {
    _alertController.close();
    _connectionController.close();
  }
}