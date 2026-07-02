import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Added this import for Firestore settings
import 'package:flutter_application_1/homepage.dart';
import 'package:flutter_application_1/login.dart';
import 'package:flutter_application_1/wrapper.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_application_1/detection_dashboard.dart';
import 'package:flutter_application_1/settings_screen.dart';
import 'package:flutter_application_1/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  await GoogleSignIn.instance.initialize(
    serverClientId:
        '472136775764-ablk8iqlfjd1hp2qd6jn45o9bfuqp8sr.apps.googleusercontent.com',
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sound Classification App',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      debugShowCheckedModeBanner: false,

      home: const Wrapper(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomePage(),

        '/dashboard': (context) => const DetectionDashboard(),
        '/history': (context) => const Scaffold(
          // placeholder
          body: Center(child: Text('History coming soon')),
        ),
        '/settings': (context) => const SettingsScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}
