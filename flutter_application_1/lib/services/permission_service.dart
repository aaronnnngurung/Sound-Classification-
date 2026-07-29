import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  // Singleton
  static final PermissionService instance = PermissionService._();
  PermissionService._();

  //  Check if microphone permission is granted
  Future<bool> isMicrophoneGranted() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  //  Check if notification permission is granted
  Future<bool> isNotificationGranted() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  //  Request microphone permission
  Future<PermissionStatus> requestMicrophone() async {
    return await Permission.microphone.request();
  }

  //  Request notification permission
  Future<PermissionStatus> requestNotification() async {
    return await Permission.notification.request();
  }

  //  Request both at once
  Future<Map<Permission, PermissionStatus>> requestAll() async {
    return await [Permission.microphone, Permission.notification].request();
  }

  //  Check if permanently denied
  // Permanently denied means user tapped "Never ask again"
  // In this case we must send them to phone Settings manually
  Future<bool> isMicrophonePermanentlyDenied() async {
    final status = await Permission.microphone.status;
    return status.isPermanentlyDenied;
  }

  Future<bool> isNotificationPermanentlyDenied() async {
    final status = await Permission.notification.status;
    return status.isPermanentlyDenied;
  }

  // Open app settings
  // Used when permission is permanently denied
  Future<void> openSettings() async {
    await openAppSettings();
  }

  //  Check all required permissions at once
  Future<PermissionCheckResult> checkAll() async {
    final mic = await Permission.microphone.status;
    final notif = await Permission.notification.status;

    return PermissionCheckResult(
      microphoneGranted: mic.isGranted,
      notificationGranted: notif.isGranted,
      microphonePermanentlyDenied: mic.isPermanentlyDenied,
      notificationPermanentlyDenied: notif.isPermanentlyDenied,
    );
  }
}

// Simple data class to hold permission check results
class PermissionCheckResult {
  final bool microphoneGranted;
  final bool notificationGranted;
  final bool microphonePermanentlyDenied;
  final bool notificationPermanentlyDenied;

  const PermissionCheckResult({
    required this.microphoneGranted,
    required this.notificationGranted,
    required this.microphonePermanentlyDenied,
    required this.notificationPermanentlyDenied,
  });

  // True only if both are granted
  bool get allGranted => microphoneGranted && notificationGranted;
}
