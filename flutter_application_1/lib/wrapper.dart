import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard/main_screen.dart';
import 'auth/login.dart';
import 'auth/complete_profile_page.dart';
import 'guardian/guardian_main_screen.dart';

class Wrapper extends StatelessWidget {
  const Wrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5B7CFA)),
              ),
            ),
          );
        }

        if (snapshot.hasData) {
          final user = snapshot.data!;

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final userData =
                  userSnapshot.data?.data() as Map<String, dynamic>?;

              // 1. Incomplete Profile check (Google users who haven't selected a role)
              if (!userSnapshot.data!.exists || userData == null || userData['role'] == null) {
                return CompleteProfilePage(
                  uid: user.uid,
                  email: user.email ?? '',
                  defaultName: user.displayName ?? '',
                );
              }

              // 2. Guardian Role check
              if (userData['role'] == 'guardian') {
                return const GuardianMainScreen();
              }

              // 3. Deaf User default home
              return const MainScreen();
            },
          );
        }

        return const LoginPage();
      },
    );
  }
}