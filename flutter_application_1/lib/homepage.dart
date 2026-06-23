import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/dashboard_page.dart';
import 'view_profile_page.dart';
import 'history_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _currentIndex = 0; // 1. Set default starting tab to Dashboard index (0)

  // Global theme color matched across pages
  static const Color maroonColor = Color(0xFF701E38);

  @override
  Widget build(BuildContext context) {
    final User? user = _auth.currentUser;

    // 2. Define our unified pages list here.
    // The current body of your homepage becomes the "Dashboard View" block below!
    final List<Widget> _pages = [
      // TAB 0: DASHBOARD VIEW (now uses local user)
      const DashboardPage(),

      // TAB 1: HISTORY PLACEHOLDER
      const HistoryPage(),

      // TAB 2: SETTINGS PLACEHOLDER
      const SettingsPage(),

      // TAB 3: VIEW PROFILE SCREEN
      const ViewProfilePage(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      // Automatically swap out screen widgets using the list index
      body: _pages[_currentIndex],

      // 3. Centralized Bottom Navigation Bar controlling your system landscape layout shell
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(
          0xFF1B4D8F,
        ), // Active tab item highlight color
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentIndex = index; // Move tabs smoothly when tapped
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_toggle_off_rounded),
            activeIcon: Icon(Icons.history_rounded),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // Extracted your original homepage body UI code to serve beautifully as the "Dashboard Tab View"
  Widget _buildDashboardView(User? user) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Home Dashboard'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        // FIXED ALIGNMENT: Watches document by email snapshot path to keep all updates synced live
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.email)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: maroonColor),
            );
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
                      color: Colors.blue[50],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.volume_up_rounded,
                        size: 60,
                        color: Color(0xFF1B4D8F),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome, $displayUsername!',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF343A40),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Profile Info Preview Dashboard Card
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'ACCOUNT PROFILE STATUS',
                              style: TextStyle(
                                color: Color(0xFF1B4D8F),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                fontSize: 12,
                              ),
                            ),
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 16,
                              color: Colors.green[400],
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        _buildProfileLine(
                          'Email:',
                          user?.email ?? 'No email set',
                        ),
                        const SizedBox(height: 12),
                        _buildProfileLine('Phone Number:', displayPhone),
                        const SizedBox(height: 12),
                        _buildProfileLine(
                          'Emergency Contact:',
                          displayEmergency,
                        ),
                      ],
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

  Widget _buildProfileLine(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2B2D42),
          ),
        ),
      ],
    );
  }
}
