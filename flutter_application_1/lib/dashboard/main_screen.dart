// main_screen.dart
import 'package:flutter/material.dart';
import 'homepage.dart';
import 'detection_history_screen.dart';
import 'detection_dashboard.dart';
import '../profile/settings_screen.dart';
import '../profile/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

@override
Widget build(BuildContext context) {
  final screens = [
    const HomePage(),
    const DetectionHistoryScreen(),
    const DetectionDashboard(),
    const SettingsScreen(),
    ProfileScreen(
      onOpenSettings: () {
        setState(() {
          _currentIndex = 3;
        });
      },
    ),
  ];

  return Scaffold(
    // Each tab renders here
    body: IndexedStack(
      index: _currentIndex,
      children: screens,
    ),

    // Bottom navigation bar
    bottomNavigationBar: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.dashboard_rounded,
                label: 'Dashboard',
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.history_rounded,
                label: 'History',
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.mic_rounded,
                label: 'Detect',
              ),
              _buildNavItem(
                index: 3,
                icon: Icons.settings_rounded,
                label: 'Settings',
              ),
              _buildNavItem(
                index: 4,
                icon: Icons.person_rounded,
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final bool isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.blue[600]!.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.blue[600] : Colors.grey[400],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? Colors.blue[600] : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }
}