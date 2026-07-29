import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/login.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_application_1/homepage.dart';
import 'package:flutter_application_1/signup_page.dart'; // Added SignUpPage import
import 'package:flutter_application_1/forgot_password_page.dart';
import 'package:flutter_application_1/wrapper.dart';
import 'package:flutter_application_1/permission_screen.dart';
import 'package:flutter_application_1/detection_dashboard.dart';
import 'package:flutter_application_1/profile_screen.dart';
import 'package:flutter_application_1/settings_screen.dart';
import 'package:flutter_application_1/detection_history_screen.dart';
import 'permission_service.dart';
import 'package:flutter_application_1/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/foreground_service_manager.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_application_1/smartwatch/watch_sync_service.dart';
import 'package:flutter_application_1/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();

  await Firebase.initializeApp();

  // Initialize foreground service settings
  ForegroundServiceManager.initialize();

  // Advertise this app as a watch-connectable capability
  WatchSyncService.instance.initializePhoneSide();

  await GoogleSignIn.instance.initialize(
    serverClientId:
        '472136775764-ablk8iqlfjd1hp2qd6jn45o9bfuqp8sr.apps.googleusercontent.com',
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  // Check permissions
  final permResult = await PermissionService.instance.checkAll();

  // Check if onboarding already completed
  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool('onboarding_complete') ?? false;

  // Decide which screen to show first
  Widget homeScreen;
  if (!permResult.allGranted) {
    // Show permissions first
    homeScreen = const PermissionScreen();
  } else if (!onboardingDone) {
    // Show onboarding after permissions
    homeScreen = const OnboardingScreen();
  } else {
    // Both done — go straight to app
    homeScreen = const Wrapper();
  }

  runApp(MyApp(homeScreen: homeScreen));
}

class MyApp extends StatelessWidget {
  final Widget homeScreen;
  const MyApp({Key? key, required this.homeScreen}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SoundClass',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5B7CFA)),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: homeScreen,
      routes: {
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(), // Registered /signup route
        '/home': (context) => const HomePage(),
        '/forgot_password': (context) => const ForgotPasswordPage(),
        '/dashboard': (context) => const DetectionDashboard(),
        '/profile': (context) => const ProfileScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/history': (context) => const DetectionHistoryScreen(),
        '/permissions': (context) => const PermissionScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/main': (context) => const MainScreen(),
      },
    );
  }
}