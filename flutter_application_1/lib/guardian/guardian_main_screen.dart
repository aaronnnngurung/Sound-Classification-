import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'guardian_messaging_service.dart';

class GuardianMainScreen extends StatefulWidget {
  const GuardianMainScreen({super.key});

  @override
  State<GuardianMainScreen> createState() => _GuardianMainScreenState();
}

class _GuardianMainScreenState extends State<GuardianMainScreen> {
  int _selectedIndex = 0;

  // Design Tokens (Material 3 Palette)
  static const Color _primaryColor = Color(0xFF5B7CFA);
  static const Color _backgroundColor = Color(0xFFF8FAFC);
  static const Color _surfaceColor = Colors.white;
  static const Color _borderColor = Color(0xFFE2E8F0);
  static const Color _textSecondary = Color(0xFF64748B);

  final List<Widget> _pages = const [
    _GuardianDashboardPlaceholder(),
    _GuardianHistoryPlaceholder(),
    _GuardianProfilePlaceholder(),
  ];

  @override
  void initState() {
    super.initState();
    GuardianMessagingService.instance.initializeForCurrentUser();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: _surfaceColor,
          border: Border(top: BorderSide(color: _borderColor, width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          elevation: 0,
          backgroundColor: _surfaceColor,
          indicatorColor: _primaryColor.withOpacity(0.12),
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined, color: _textSecondary),
              selectedIcon: Icon(Icons.dashboard_rounded, color: _primaryColor),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined, color: _textSecondary),
              selectedIcon: Icon(Icons.history_rounded, color: _primaryColor),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded, color: _textSecondary),
              selectedIcon: Icon(Icons.person_rounded, color: _primaryColor),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DASHBOARD TAB
// ─────────────────────────────────────────────────────────────────────────────

class _GuardianDashboardPlaceholder extends StatelessWidget {
  const _GuardianDashboardPlaceholder();

  static const Color _primaryColor = Color(0xFF5B7CFA);
  static const Color _primaryColorDeep = Color(0xFF4A63E0);
  static const Color _surfaceColor = Colors.white;
  static const Color _borderColor = Color(0xFFE2E8F0);
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _activeGreen = Color(0xFF10B981);

  @override
  Widget build(BuildContext context) {
    final guardianUid = FirebaseAuth.instance.currentUser!.uid;
    final topInset = MediaQuery.of(context).padding.top;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('guardian_links')
          .where('guardianUid', isEqualTo: guardianUid)
          .limit(1)
          .snapshots(),
      builder: (context, linkSnapshot) {
        if (linkSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _primaryColor),
          );
        }

        if (!linkSnapshot.hasData || linkSnapshot.data!.docs.isEmpty) {
          return Column(
            children: [
              _buildHeaderBanner(
                topInset: topInset,
                title: 'Guardian Dashboard 🛡️',
                subtitle: 'Real-time safety monitoring',
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: _primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.link_off_rounded,
                            size: 36,
                            color: _primaryColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No Deaf User Connected',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Link to a user using their Guardian Code from the Profile tab to begin safety monitoring.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: _textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        final deafUserUid =
            linkSnapshot.data!.docs.first.data()['deafUserUid'] as String;

        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(deafUserUid)
              .get(),
          builder: (context, deafUserSnapshot) {
            if (deafUserSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: _primaryColor),
              );
            }

            final deafUser = deafUserSnapshot.data?.data();
            final name = deafUser?['username'] ?? 'Connected User';

            return Column(
              children: [
                _buildHeaderBanner(
                  topInset: topInset,
                  title: 'Guardian Dashboard 🛡️',
                  subtitle: 'Monitoring active safety channel',
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Connected User Status Card
                        _buildCard(
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: _primaryColor.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: _primaryColorDeep,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Monitoring $name',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: _textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: _activeGreen,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Text(
                                          'Status: Connected & Active',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _activeGreen,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Section Title
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Text(
                            'LATEST ALERT CHANNEL',
                            style: TextStyle(
                              color: _textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Emergency Card Component
                        _LatestEmergencyCard(deafUserUid: deafUserUid),

                        const SizedBox(height: 20),

                        // Quick Safety Information Tile
                        _buildCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.shield_outlined,
                                      color: _primaryColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Guardian Channel Active',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Push notifications are enabled. Emergency alerts (Sirens & Glass Breaking) detected by $name's device will automatically trigger instant alerts here.",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _textSecondary,
                                  height: 1.4,
                                ),
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
        );
      },
    );
  }

  static Widget _buildHeaderBanner({
    required double topInset,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xD9FFFFFF),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildCard({required Widget child}) {
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
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LATEST EMERGENCY CARD
// ─────────────────────────────────────────────────────────────────────────────

class _LatestEmergencyCard extends StatelessWidget {
  final String deafUserUid;

  const _LatestEmergencyCard({required this.deafUserUid});

  static const Color _primaryColor = Color(0xFF5B7CFA);
  static const Color _surfaceColor = Colors.white;
  static const Color _borderColor = Color(0xFFE2E8F0);
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _dangerRed = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('detections')
          .where('userId', isEqualTo: deafUserUid)
          .where(
            'soundClass',
            whereIn: ['siren', 'glass_breaking'],
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _borderColor),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: _primaryColor),
            ),
          );
        }

        final detections = [...?snapshot.data?.docs];

        if (detections.isEmpty) {
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
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: _primaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Latest Emergency',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'No emergency sound detected yet.',
                        style: TextStyle(fontSize: 12, color: _textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        detections.sort((a, b) {
          final aTime =
              (a.data()['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          final bTime =
              (b.data()['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          return bTime.compareTo(aTime);
        });

        final latest = detections.first.data();
        final timestamp = latest['timestamp'] as Timestamp?;
        final confidence = ((latest['confidence'] ?? 0) * 100).toStringAsFixed(0);
        final soundName = latest['sound'] ?? 'Emergency Sound';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _dangerRed.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: _dangerRed.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _dangerRed.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: _dangerRed,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Latest Emergency',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _dangerRed,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _dangerRed,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$confidence% Conf',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      soundName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timestamp == null
                          ? 'Just now'
                          : _formatTimestamp(timestamp.toDate().toLocal()),
                      style: const TextStyle(fontSize: 12, color: _textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _formatTimestamp(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} • ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HISTORY TAB
// ─────────────────────────────────────────────────────────────────────────────

class _GuardianHistoryPlaceholder extends StatelessWidget {
  const _GuardianHistoryPlaceholder();

  static const Color _primaryColor = Color(0xFF5B7CFA);
  static const Color _primaryColorDeep = Color(0xFF4A63E0);
  static const Color _surfaceColor = Colors.white;
  static const Color _borderColor = Color(0xFFE2E8F0);
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _dangerRed = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    final guardianUid = FirebaseAuth.instance.currentUser!.uid;
    final topInset = MediaQuery.of(context).padding.top;

    return Column(
      children: [
        // Header Banner
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 20),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Emergency History 📋',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Timeline of all safety & hazard alerts',
                style: TextStyle(
                  color: Color(0xD9FFFFFF),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),

        // Stream Content Body
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('guardian_links')
                .where('guardianUid', isEqualTo: guardianUid)
                .limit(1)
                .snapshots(),
            builder: (context, linkSnapshot) {
              if (linkSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: _primaryColor),
                );
              }

              if (!linkSnapshot.hasData || linkSnapshot.data!.docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.link_off_rounded, size: 48, color: _textSecondary),
                        SizedBox(height: 12),
                        Text(
                          'No Deaf User Connected',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final deafUserUid =
                  linkSnapshot.data!.docs.first.data()['deafUserUid'] as String;

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('detections')
                    .where('userId', isEqualTo: deafUserUid)
                    .where(
                      'soundClass',
                      whereIn: ['siren', 'glass_breaking'],
                    )
                    .snapshots(),
                builder: (context, detectionSnapshot) {
                  if (detectionSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: _primaryColor),
                    );
                  }

                  final detections = detectionSnapshot.data?.docs ?? [];

                  if (detections.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 52,
                            color: _textSecondary,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No emergency detections logged',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _textPrimary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'All emergency events will appear here in real-time.',
                            style: TextStyle(fontSize: 12, color: _textSecondary),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    itemCount: detections.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final data = detections[index].data();
                      final timestamp = data['timestamp'] as Timestamp?;
                      final soundName = data['sound'] ?? 'Emergency Sound';
                      final confidence =
                          ((data['confidence'] ?? 0) * 100).toStringAsFixed(0);

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _surfaceColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: _dangerRed.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.warning_amber_rounded,
                                color: _dangerRed,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    soundName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: _textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    timestamp == null
                                        ? 'Just now'
                                        : timestamp.toDate().toLocal().toString(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _primaryColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$confidence%',
                                style: const TextStyle(
                                  color: _primaryColorDeep,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE TAB & LINK MANAGEMENT
// ─────────────────────────────────────────────────────────────────────────────

class _GuardianProfilePlaceholder extends StatelessWidget {
  const _GuardianProfilePlaceholder();

  static const Color _primaryColor = Color(0xFF5B7CFA);
  static const Color _primaryColorDeep = Color(0xFF4A63E0);
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

    if (user == null) {
      return const Center(child: Text('No user logged in'));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _primaryColor),
          );
        }

        if (userSnapshot.hasError ||
            !userSnapshot.hasData ||
            !userSnapshot.data!.exists) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.error_outline_rounded,
                    size: 48, color: _dangerRed),
                SizedBox(height: 12),
                Text(
                  'Failed to load profile details.',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
              ],
            ),
          );
        }

        final userData = userSnapshot.data!.data() ?? {};
        final username = userData['username'] ?? 'Guardian User';
        final email = user.email ?? 'No email';
        final phone = userData['phoneNumber'] ?? 'Not set';
        final role = userData['role'] ?? 'guardian';
        final createdAt = userData['createdAt'] != null
            ? _formatDate(userData['createdAt'])
            : 'Unknown';

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('guardian_links')
              .where('guardianUid', isEqualTo: user.uid)
              .limit(1)
              .snapshots(),
          builder: (context, linkSnapshot) {
            final isConnected =
                linkSnapshot.hasData && linkSnapshot.data!.docs.isNotEmpty;
            final linkDoc = isConnected ? linkSnapshot.data!.docs.first : null;

            return Column(
              children: [
                // Header Hero Banner
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 28),
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
                            'Guardian Profile',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Avatar Monogram
                      Container(
                        width: 84,
                        height: 84,
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
                            username.isNotEmpty
                                ? username[0].toUpperCase()
                                : 'G',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: _primaryColorDeep,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
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

                      // Role Badge
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

                // Body Section
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Contact Info Card (Editable)
                        _buildInfoCard(
                          title: 'CONTACT INFORMATION',
                          actionWidget: IconButton(
                            icon: const Icon(Icons.edit_rounded,
                                color: _primaryColor, size: 20),
                            onPressed: () => _showEditProfileDialog(
                              context,
                              user.uid,
                              username,
                              phone,
                            ),
                            tooltip: 'Edit Profile Details',
                          ),
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
                          ],
                        ),

                        const SizedBox(height: 18),

                        // Connection Status & Management Card
                        _buildConnectionCard(
                          context: context,
                          isConnected: isConnected,
                          guardianUid: user.uid,
                          linkDoc: linkDoc,
                        ),

                        const SizedBox(height: 18),

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
                                icon: Icons.edit_rounded,
                                iconColor: _primaryColor,
                                label: 'Edit Profile Details',
                                onTap: () => _showEditProfileDialog(
                                  context,
                                  user.uid,
                                  username,
                                  phone,
                                ),
                              ),
                              const Divider(height: 24, color: _borderColor),
                              _buildQuickAction(
                                icon: Icons.lock_reset_rounded,
                                iconColor: _purpleAccent,
                                label: 'Change Password',
                                onTap: () async {
                                  if (user.email != null) {
                                    await FirebaseAuth.instance
                                        .sendPasswordResetEmail(
                                      email: user.email!,
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
                                              Text(
                                                  'Password reset link sent to your email'),
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
        );
      },
    );
  }

  // Edit Profile Modal Routine (Without Emergency Contact)
  static void _showEditProfileDialog(
    BuildContext context,
    String guardianUid,
    String currentUsername,
    String currentPhone,
  ) {
    final usernameController = TextEditingController(text: currentUsername);
    final phoneController =
        TextEditingController(text: currentPhone == 'Not set' ? '' : currentPhone);

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Edit Profile',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username / Full Name',
                    hintText: 'Enter your name',
                    prefixIcon:
                        const Icon(Icons.person_rounded, color: _primaryColor),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    hintText: 'Enter phone number',
                    prefixIcon:
                        const Icon(Icons.phone_rounded, color: _activeGreen),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child:
                  const Text('Cancel', style: TextStyle(color: _textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final newUsername = usernameController.text.trim();
                final newPhone = phoneController.text.trim();

                if (newUsername.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Username cannot be empty')),
                  );
                  return;
                }

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(guardianUid)
                    .update({
                  'username': newUsername,
                  'phoneNumber': newPhone.isEmpty ? 'Not set' : newPhone,
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Profile updated successfully'),
                      backgroundColor: _activeGreenDeep,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Save Changes'),
            ),
          ],
        );
      },
    );
  }

  static Widget _buildConnectionCard({
    required BuildContext context,
    required bool isConnected,
    required String guardianUid,
    required QueryDocumentSnapshot<Map<String, dynamic>>? linkDoc,
  }) {
    if (!isConnected) {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'GUARDIAN CONNECTION',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _textSecondary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'DISCONNECTED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'No active pairing found. Connect to a Deaf user to receive their emergency alerts.',
              style: TextStyle(fontSize: 13, color: _textSecondary),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _showConnectDialog(context, guardianUid),
                icon: const Icon(Icons.link_rounded),
                label: const Text('Connect to Deaf User'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final deafUserUid = linkDoc!.data()['deafUserUid'] as String;

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(deafUserUid)
          .get(),
      builder: (context, deafSnapshot) {
        final deafData = deafSnapshot.data?.data();
        final deafName = deafData?['username'] ?? 'Connected User';
        final deafCode = deafData?['guardianCode'] ?? 'Not available';

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'GUARDIAN CONNECTION',
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _activeGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'CONNECTED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _activeGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24, color: _borderColor),
              _buildDetailRow(
                icon: Icons.person_rounded,
                label: 'Connected User',
                value: deafName,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildDetailRow(
                      icon: Icons.qr_code_rounded,
                      label: 'Guardian Code',
                      value: deafCode,
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: deafCode));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Guardian Code copied'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_rounded, color: _primaryColor),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await linkDoc.reference.delete();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              const Text('Guardian disconnected successfully.'),
                          backgroundColor: _activeGreenDeep,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.link_off_rounded),
                  label: const Text('Disconnect Guardian Link'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFEF2F2),
                    foregroundColor: _dangerRed,
                    elevation: 0,
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _primaryColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: _textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _buildInfoCard({
    required String title,
    required List<_InfoItem> items,
    Widget? actionWidget,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              if (actionWidget != null) actionWidget,
            ],
          ),
          SizedBox(height: actionWidget != null ? 4 : 14),
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

  static Widget _buildQuickAction({
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

  static void _confirmSignOut(BuildContext context) {
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
            child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/login', (route) => false);
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

  static String _formatDate(dynamic value) {
    try {
      if (value is String) {
        final dt = DateTime.parse(value);
        return '${dt.day} ${_monthName(dt.month)} ${dt.year}';
      }
      final ts = value as dynamic;
      final dt = ts.toDate() as DateTime;
      return '${dt.day} ${_monthName(dt.month)} ${dt.year}';
    } catch (_) {
      return 'Unknown';
    }
  }

  static String _monthName(int m) => [
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

// ─────────────────────────────────────────────────────────────────────────────
// DIALOG ROUTINES
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _showConnectDialog(
  BuildContext context,
  String guardianUid,
) async {
  final codeController = TextEditingController();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Connect to Deaf User',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the 8-character Guardian Code provided on the user’s device.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
              decoration: InputDecoration(
                labelText: 'Guardian Code',
                hintText: 'e.g. DG482913',
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = codeController.text.trim().toUpperCase();

              final userQuery = await FirebaseFirestore.instance
                  .collection('users')
                  .where('guardianCode', isEqualTo: code)
                  .limit(1)
                  .get();

              if (userQuery.docs.isEmpty) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Invalid Guardian Code'),
                      backgroundColor: const Color(0xFFEF4444),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
                return;
              }

              final deafUserUid = userQuery.docs.first.id;

              final existingLink = await FirebaseFirestore.instance
                  .collection('guardian_links')
                  .doc(deafUserUid)
                  .get();

              if (existingLink.exists) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'This Deaf User already has a connected Guardian.',
                      ),
                      backgroundColor: const Color(0xFFEF4444),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
                return;
              }

              await FirebaseFirestore.instance
                  .collection('guardian_links')
                  .doc(deafUserUid)
                  .set({
                'deafUserUid': deafUserUid,
                'guardianUid': guardianUid,
                'createdAt': FieldValue.serverTimestamp(),
              });

              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Connected successfully.'),
                    backgroundColor: const Color(0xFF059669),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B7CFA),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Connect'),
          ),
        ],
      );
    },
  );

  codeController.dispose();
}