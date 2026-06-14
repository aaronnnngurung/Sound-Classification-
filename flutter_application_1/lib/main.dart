import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 1. Added this import for Firestore settings
import 'package:flutter_application_1/wrapper.dart'; 

// 2. Added 'async' here so 'await' works perfectly
void main() async { 
  WidgetsFlutterBinding.ensureInitialized();
  
  // 3. Initialize Firebase once right at launch
  await Firebase.initializeApp();

  // 4. Corrected the lowercase 's' in Firestore
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
  
  runApp(const MyApp()); 
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sound Classification App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      // 5. Cleaned this up: Since Firebase initializes in main(), 
      // we can send the user straight to the Wrapper immediately!
      home: const Wrapper(), 
    );
  }
}