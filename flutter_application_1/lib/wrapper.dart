import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'homepage.dart';
import 'login.dart';
 
class Wrapper extends StatelessWidget {
  const Wrapper({Key? key}) : super(key: key);
 
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // While checking authentication state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
 
        // If user is logged in, show homepage
        if (snapshot.hasData) {
          return HomePage();
        }
 
        // If user is not logged in, show login page
        return LoginPage();
      },
    );
  }
}
 