import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isSigningOut = false;

  Future<void> _signOut() async {
    setState(() {
      _isSigningOut = true;
    });

    try {
      await _auth.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
      }
    }
  }

  void _showSignOutConfirmation() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog( // Renamed to dialogContext to avoid context confusion
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext); // Closes dialog using its own localized channel context
              _signOut(); // Executes signout cleanly on main thread
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Dashboard'),
        centerTitle: true,
        elevation: 0,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        // Connects dynamically to the exact profile written during your registration sequence
        future: FirebaseFirestore.instance.collection('users').doc(user?.uid).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          Map<String, dynamic> userData = {};
          if (snapshot.hasData && snapshot.data!.exists) {
            userData = snapshot.data!.data() as Map<String, dynamic>;
          }

          String displayUsername = userData['username'] ?? 'User';
          String displayPhone = userData['phoneNumber'] ?? 'Not set';
          String displayEmergency = userData['emergencyContact'] ?? 'Not set';

          return SingleChildScrollView(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue[100],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.volume_up_rounded,
                        size: 60,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome, $displayUsername!',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Center(
                          child: Text(
                            'ACCOUNT PROFILE',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Divider(height: 24),
                        _buildProfileLine('Email:', user?.email ?? 'No email'),
                        const SizedBox(height: 12),
                        _buildProfileLine('Phone Number:', displayPhone),
                        const SizedBox(height: 12),
                        _buildProfileLine('Emergency Contact:', displayEmergency),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ElevatedButton(
                      onPressed: _isSigningOut ? null : _showSignOutConfirmation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        disabledBackgroundColor: Colors.grey,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSigningOut
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.logout, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'Sign Out',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Declared clean return type configuration cleanly
  Widget _buildProfileLine(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
      ],
    );
  }
}