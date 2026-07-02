// profile_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error state
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 60,
                    color: Colors.red[300],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to load profile',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          // No data state
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('No profile data found.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final username = data['username'] ?? 'Unknown User';
          final email = user?.email ?? 'No email';
          final phone = data['phoneNumber'] ?? 'Not set';
          final emergency = data['emergencyContact'] ?? 'Not set';
          final role = data['role'] ?? 'user';
          final createdAt = data['createdAt'] != null
              ? _formatDate(data['createdAt'])
              : 'Unknown';

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // Header banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 32, bottom: 40),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.blue[600]!, Colors.blue[400]!],
                    ),
                  ),
                  child: Column(
                    children: [
                      // Avatar circle with initials
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            username.isNotEmpty
                                ? username[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[600],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        username,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Role badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                        child: Text(
                          role.toString().toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                //  Profile details card
                Transform.translate(
                  offset: const Offset(0, -20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        _buildInfoCard(
                          title: 'CONTACT INFORMATION',
                          items: [
                            _InfoItem(
                              icon: Icons.email_rounded,
                              iconColor: Colors.blue[600]!,
                              label: 'Email Address',
                              value: email,
                            ),
                            _InfoItem(
                              icon: Icons.phone_rounded,
                              iconColor: Colors.green[600]!,
                              label: 'Phone Number',
                              value: phone,
                            ),
                            _InfoItem(
                              icon: Icons.emergency_rounded,
                              iconColor: Colors.red[600]!,
                              label: 'Emergency Contact',
                              value: emergency,
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        _buildInfoCard(
                          title: 'ACCOUNT DETAILS',
                          items: [
                            _InfoItem(
                              icon: Icons.badge_rounded,
                              iconColor: Colors.purple[600]!,
                              label: 'Role',
                              value: role.toString().toUpperCase(),
                            ),
                            _InfoItem(
                              icon: Icons.calendar_today_rounded,
                              iconColor: Colors.teal[600]!,
                              label: 'Member Since',
                              value: createdAt,
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Quick actions
                        _buildInfoCard(
                          title: 'QUICK ACTIONS',
                          items: [],
                          customContent: Column(
                            children: [
                              _buildQuickAction(
                                context: context,
                                icon: Icons.edit_rounded,
                                iconColor: Colors.blue[600]!,
                                label: 'Settings',
                                onTap: () =>
                                    Navigator.pushNamed(context, '/settings'),
                              ),
                              const Divider(height: 20),
                              _buildQuickAction(
                                context: context,
                                icon: Icons.lock_reset_rounded,
                                iconColor: Colors.purple[600]!,
                                label: 'Change Password',
                                onTap: () async {
                                  if (user?.email != null) {
                                    await FirebaseAuth.instance
                                        .sendPasswordResetEmail(
                                          email: user!.email!,
                                        );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Reset link sent to your email',
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                              const Divider(height: 20),
                              _buildQuickAction(
                                context: context,
                                icon: Icons.logout_rounded,
                                iconColor: Colors.red[600]!,
                                label: 'Sign Out',
                                onTap: () => _confirmSignOut(context),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required List<_InfoItem> items,
    Widget? customContent,
  }) {
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
          // Section title
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 16),

          // Info rows
          if (customContent != null) customContent,
          if (items.isNotEmpty)
            ...items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              return Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: item.iconColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(item.icon, color: item.iconColor, size: 18),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.label,
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.value,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (i < items.length - 1)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1),
                    ),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Sign Out',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to sign out of your account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic value) {
    try {
      if (value is String) {
        final dt = DateTime.parse(value);
        return '${dt.day} ${_monthName(dt.month)} ${dt.year}';
      }
      // Firestore Timestamp
      final ts = value as dynamic;
      final dt = ts.toDate() as DateTime;
      return '${dt.day} ${_monthName(dt.month)} ${dt.year}';
    } catch (_) {
      return 'Unknown';
    }
  }

  String _monthName(int m) => [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][m];
}

class _InfoItem {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });
}
