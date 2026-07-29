import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class ProfileScreen extends StatelessWidget {
  final VoidCallback? onOpenSettings;

  const ProfileScreen({Key? key, this.onOpenSettings}) : super(key: key);

  // 2026 Material 3 Shared Palette (matching DetectionDashboard & SettingsScreen)
  static const Color _primaryColor = Color(0xFF5B7CFA);
  static const Color _primaryColorDeep = Color(0xFF4A63E0);
  static const Color _backgroundColor = Color(0xFFF8FAFC);
  static const Color _surfaceColor = Colors.white;
  static const Color _borderColor = Color(0xFFE2E8F0);
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _activeGreen = Color(0xFF10B981);
  static const Color _activeGreenDeep = Color(0xFF059669);
  static const Color _dangerRed = Color(0xFFEF4444);
  static const Color _purpleAccent = Color(0xFF9333EA);
  static const Color _tealAccent = Color(0xFF0D9488);

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _primaryColor),
            );
          }

          // Error state
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _dangerRed.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: _dangerRed,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Failed to load profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.maybePop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            );
          }

          // No data state
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text(
                'No profile data found.',
                style: TextStyle(color: _textSecondary, fontSize: 15),
              ),
            );
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

          return Column(
            children: [
              // ── Top Bar & Hero Header ──────────────────────────────
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 32),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_primaryColorDeep, _primaryColor],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          'My Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Avatar Circle with Monogram
                    Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _surfaceColor,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withOpacity(0.18),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          username.isNotEmpty ? username[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: _primaryColorDeep,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      username,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xD9FFFFFF),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Role Badge Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.35),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        role.toString().toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Scrollable Details Section ─────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  child: Column(
                    children: [
                      // Contact Info Card
                      _buildInfoCard(
                        title: 'CONTACT INFORMATION',
                        items: [
                          _InfoItem(
                            icon: Icons.email_rounded,
                            iconColor: _primaryColor,
                            label: 'Email Address',
                            value: email,
                          ),
                          _InfoItem(
                            icon: Icons.phone_rounded,
                            iconColor: _activeGreen,
                            label: 'Phone Number',
                            value: phone,
                          ),
                          _InfoItem(
                            icon: Icons.emergency_rounded,
                            iconColor: _dangerRed,
                            label: 'Emergency Contact',
                            value: emergency,
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),
                      if (role == 'deaf') ...[
                      _GuardianConnectionCard(
                        deafUserUid: user!.uid,
                        guardianCode: data['guardianCode'] ?? 'Not available',
                      ),
                      const SizedBox(height: 18),
                      ],

                      // Account Details Card
                      _buildInfoCard(
                        title: 'ACCOUNT DETAILS',
                        items: [
                          _InfoItem(
                            icon: Icons.badge_rounded,
                            iconColor: _purpleAccent,
                            label: 'Role',
                            value: role.toString().toUpperCase(),
                          ),
                          _InfoItem(
                            icon: Icons.calendar_today_rounded,
                            iconColor: _tealAccent,
                            label: 'Member Since',
                            value: createdAt,
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Quick Actions Card
                      _buildInfoCard(
                        title: 'QUICK ACTIONS',
                        items: [],
                        customContent: Column(
                          children: [
                            _buildQuickAction(
                              context: context,
                              icon: Icons.settings_rounded,
                              iconColor: _primaryColor,
                              label: 'Settings',
                              onTap: () =>
                                  onOpenSettings?.call(),
                            ),
                            const Divider(height: 24, color: _borderColor),
                            _buildQuickAction(
                              context: context,
                              icon: Icons.lock_reset_rounded,
                              iconColor: _purpleAccent,
                              label: 'Change Password',
                              onTap: () async {
                                if (user?.email != null) {
                                  await FirebaseAuth.instance
                                      .sendPasswordResetEmail(
                                    email: user!.email!,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Row(
                                          children: [
                                            Icon(
                                              Icons.check_circle_rounded,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                            SizedBox(width: 10),
                                            Text('Reset link sent to your email'),
                                          ],
                                        ),
                                        backgroundColor: _activeGreenDeep,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                            const Divider(height: 24, color: _borderColor),
                            _buildQuickAction(
                              context: context,
                              icon: Icons.logout_rounded,
                              iconColor: _dangerRed,
                              label: 'Sign Out',
                              onTap: () => _confirmSignOut(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              title,
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Content rendering
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
                          color: item.iconColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(item.icon, color: item.iconColor, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.label,
                              style: const TextStyle(
                                color: _textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.value,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _textPrimary,
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
                      child: Divider(height: 1, color: _borderColor),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: _textSecondary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Sign Out',
          style: TextStyle(fontWeight: FontWeight.w700, color: _textPrimary),
        ),
        content: const Text(
          'Are you sure you want to sign out of your account?',
          style: TextStyle(color: _textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: _textSecondary),
            ),
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
              backgroundColor: _dangerRed,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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


class _GuardianConnectionCard extends StatelessWidget {
  final String deafUserUid;
  final String guardianCode;

  const _GuardianConnectionCard({
    required this.deafUserUid,
    required this.guardianCode,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('guardian_links')
          .doc(deafUserUid)
          .snapshots(),
      builder: (context, linkSnapshot) {
        final isConnected = linkSnapshot.data?.exists == true;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'GUARDIAN CONNECTION',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Guardian Code',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      guardianCode,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: guardianCode),
                      );

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Guardian Code copied'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_outlined),
                  ),
                ],
              ),
              const Divider(height: 28),
              if (!isConnected)
                const Row(
                  children: [
                    Icon(Icons.circle, color: Colors.grey, size: 12),
                    SizedBox(width: 8),
                    Text(
                      'No Guardian Connected',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                )
              else
                _ConnectedGuardianDetails(
                  guardianUid:
                      linkSnapshot.data!.data()!['guardianUid'] as String,
                  linkReference: linkSnapshot.data!.reference,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ConnectedGuardianDetails extends StatelessWidget {
  final String guardianUid;
  final DocumentReference<Map<String, dynamic>> linkReference;

  const _ConnectedGuardianDetails({
    required this.guardianUid,
    required this.linkReference,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(guardianUid)
          .get(),
      builder: (context, snapshot) {
        final guardian = snapshot.data?.data();
        final name = guardian?['username'] ?? 'Guardian';
        final phone = guardian?['phoneNumber'] ?? 'Not available';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.circle, color: Color(0xFF10B981), size: 12),
                SizedBox(width: 8),
                Text(
                  'Connected',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Guardian: $name',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Phone: $phone',
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () async {
                await linkReference.delete();

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Guardian disconnected successfully.'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.link_off),
              label: const Text('Disconnect Guardian'),
            ),
          ],
        );
      },
    );
  }
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