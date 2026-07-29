import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class GuardianMessagingService {
  GuardianMessagingService._();

  static final instance = GuardianMessagingService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> initializeForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final userData = userDoc.data();
    if (userData?['role'] != 'guardian') return;

    final permission = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final allowed =
        permission.authorizationStatus == AuthorizationStatus.authorized ||
            permission.authorizationStatus == AuthorizationStatus.provisional;

    if (!allowed) return;

    final token = await _messaging.getToken();

    if (token != null) {
      await _saveToken(user.uid, token);
    }

    _messaging.onTokenRefresh.listen((newToken) {
      _saveToken(user.uid, newToken);
    });
  }

  Future<void> _saveToken(String uid, String token) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}