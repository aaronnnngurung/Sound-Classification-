import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'detection_dashboard.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'SoundClass',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
        // Profile icon top right
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_rounded),
            tooltip: 'My Profile',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          String username = 'User';
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            username = data['username'] ?? 'User';
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // Greeting wala part
                Text(
                  'Hello, $username 👋',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'What would you like to do today?',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),

                const SizedBox(height: 28),

                //  Primary action — Start Detection
                _buildPrimaryCard(
                  context: context,
                  icon: Icons.mic_rounded,
                  title: 'Start Sound Detection',
                  subtitle:
                      'Detect sirens, alarms, horns and more in real time',
                  color: Colors.blue[600]!,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DetectionDashboard(),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                //  Secondary grid
                Row(
                  children: [
                    Expanded(
                      child: _buildGridCard(
                        context: context,
                        icon: Icons.history_rounded,
                        label: 'Detection\nHistory',
                        color: Colors.teal[600]!,
                        onTap: () => Navigator.pushNamed(context, '/history'),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildGridCard(
                        context: context,
                        icon: Icons.settings_rounded,
                        label: 'Settings',
                        color: Colors.purple[600]!,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: _buildGridCard(
                        context: context,
                        icon: Icons.account_circle_rounded,
                        label: 'My\nProfile',
                        color: Colors.indigo[600]!,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProfileScreen(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildGridCard(
                        context: context,
                        icon: Icons.info_rounded,
                        label: 'About\nApp',
                        color: Colors.orange[700]!,
                        onTap: () => _showAboutDialog(context),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // ── Sound classes quick reference
                _buildSoundClassesCard(),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  // Large primary action card
  Widget _buildPrimaryCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withOpacity(0.75)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withOpacity(0.7),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  // Smaller square grid card
  Widget _buildGridCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Sound classes quick reference card
  Widget _buildSoundClassesCard() {
    final sounds = [
      {
        'icon': Icons.emergency_rounded,
        'label': 'Siren',
        'color': Colors.red[600]!,
      },
      {
        'icon': Icons.directions_car_rounded,
        'label': 'Car Horn',
        'color': Colors.amber[700]!,
      },
      {
        'icon': Icons.child_care_rounded,
        'label': 'Baby Cry',
        'color': Colors.orange[600]!,
      },
      {
        'icon': Icons.local_fire_department_rounded,
        'label': 'Fire Alarm',
        'color': Colors.deepOrange[600]!,
      },
      {
        'icon': Icons.crisis_alert_rounded,
        'label': 'Glass Break',
        'color': Colors.purple[600]!,
      },
      {
        'icon': Icons.door_front_door_rounded,
        'label': 'Knocking',
        'color': Colors.brown[600]!,
      },
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DETECTABLE SOUNDS',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.2,
            ),
            itemCount: sounds.length,
            itemBuilder: (ctx, i) {
              final s = sounds[i];
              return Container(
                decoration: BoxDecoration(
                  color: (s['color'] as Color).withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (s['color'] as Color).withOpacity(0.2),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      s['icon'] as IconData,
                      color: s['color'] as Color,
                      size: 24,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s['label'] as String,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: (s['color'] as Color).withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_rounded, color: Colors.orange[700]),
            const SizedBox(width: 10),
            const Text(
              'About SoundClass',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'SoundClass is a mobile-based assistive alert system '
          'designed for Deaf and Hard of Hearing (DHH) users.\n\n'
          'It uses a CNN machine learning model to detect '
          'emergency sounds in real time and converts them into '
          'haptic vibrations and visual alerts — entirely offline, '
          'with no audio ever leaving your device.\n\n'
          'Developed by Group 41 — IIMS College\n'
          'Version 1.0.0',
          style: TextStyle(height: 1.55, fontSize: 13),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
