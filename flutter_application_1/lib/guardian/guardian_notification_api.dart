import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class GuardianNotificationApi {
  GuardianNotificationApi._();

  static final instance = GuardianNotificationApi._();

  // Android Emulator → your computer's localhost.
  // For a real phone later, replace this with your computer's LAN IP.
  static const String _baseUrl = 'http://10.0.2.2:3000';

  Future<void> notifyEmergency({
    required String soundClass,
    required double confidence,
  }) async {
    if (soundClass != 'siren' && soundClass != 'glass_breaking') {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final idToken = await user.getIdToken();

      await http.post(
        Uri.parse('$_baseUrl/api/notify'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'userId': user.uid,
          'sound': soundClass,
          'confidence': confidence,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
    } catch (error) {
      // A notification failure must never break local sound detection.
      print('Guardian notification request failed: $error');
    }
  }
}