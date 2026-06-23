import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 1. Added this import for Firestore settings
import 'package:flutter_application_1/wrapper.dart';
import 'firebase_options.dart'; // 1. Added this import for Firebase after the setup

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase once right at launch
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VisiAlert',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      debugShowCheckedModeBanner: false,

      // we can send the user straight to the Wrapper immediately!
      home: const Wrapper(),
    );
  }
}
