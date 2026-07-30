// homepage.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/database_helper.dart';
import '../services/foreground_service_manager.dart';

class HomePage extends StatefulWidget {
  // Called when the user taps the detection status card — lets
  // MainScreen switch to the Detection tab from here.
  final VoidCallback? onOpenDetection;

  const HomePage({Key? key, this.onOpenDetection}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final User? _user = FirebaseAuth.instance.currentUser;
  String _username = 'User';
  List<Map<String, dynamic>> _recentDetections = [];
  int _totalDetections = 0;
  int _highConfidenceCount = 0;
  bool _isLoading = true;

  // Live detection status shown in the big status card
  bool _isDetectionRunning = false;
  Timer? _statusTimer;

  // 2026 Material 3 Design Tokens — shared with Login / SignUp
  static const Color _primaryColor = Color(0xFF5B7CFA);
  static const Color _primaryColorDeep = Color(0xFF4A63E0);
  static const Color _backgroundColor = Color(0xFFF8FAFC);
  static const Color _surfaceColor = Colors.white;
  static const Color _borderColor = Color(0xFFE2E8F0);
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _successColor = Color(0xFF16A34A);

  final Map<String, Map<String, dynamic>> _soundConfig = {
    'siren': {
      'label': 'Siren',
      'icon': Icons.emergency_rounded,
      'color': Colors.red[600]!,
    },
    'crying_baby': {
      'label': 'Baby Cry',
      'icon': Icons.child_care_rounded,
      'color': Colors.orange[600]!,
    },
    'car_horn': {
      'label': 'Car Horn',
      'icon': Icons.directions_car_rounded,
      'color': Colors.amber[700]!,
    },
    'fire_alarm': {
      'label': 'Fire Alarm',
      'icon': Icons.local_fire_department_rounded,
      'color': Colors.deepOrange[600]!,
    },
    'glass_breaking': {
      'label': 'Glass Break',
      'icon': Icons.crisis_alert_rounded,
      'color': Colors.purple[600]!,
    },
    'door_wood_knock': {
      'label': 'Knocking',
      'icon': Icons.door_front_door_rounded,
      'color': Colors.brown[600]!,
    },
    'clock_alarm': {
      'label': 'Clock Alarm',
      'icon': Icons.alarm_rounded,
      'color': Colors.blue[700]!,
    },
    'train': {
      'label': 'Train',
      'icon': Icons.train_rounded,
      'color': Colors.teal[600]!,
    },
    'fireworks': {
      'label': 'Fireworks',
      'icon': Icons.celebration_rounded,
      'color': Colors.pink[600]!,
    },
  };

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshDetectionStatus();
    // Poll periodically so the card reflects reality even if detection
    // was started/stopped from the Detection tab while Home wasn't visible.
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _refreshDetectionStatus();
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshDetectionStatus() async {
    final running = await ForegroundServiceManager.instance.isRunning;
    if (mounted && running != _isDetectionRunning) {
      setState(() => _isDetectionRunning = running);
    }
  }

  Future<void> _loadData() async {
    if (_user == null) return;

    try {
      // Load username from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .get();
      if (doc.exists) {
        setState(() {
          _username = doc.data()?['username'] ?? 'User';
        });
      }

      // Load detection records from SQLite
      final records = await DatabaseHelper.instance.getAllDetections(
        _user!.uid,
      );

      // Calculate stats
      final highConf = records
          .where((r) => (r['confidence'] as double) >= 0.85)
          .length;

      setState(() {
        _totalDetections = records.length;
        _highConfidenceCount = highConf;
        // Show only 5 most recent
        _recentDetections = records.take(5).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // Confidence label helper
  String _confidenceLabel(double confidence) {
    if (confidence >= 0.85) return 'High Confidence';
    if (confidence >= 0.70) return 'Medium Confidence';
    return 'Low Confidence';
  }

  Color _confidenceColor(double confidence) {
    if (confidence >= 0.85) return _successColor;
    if (confidence >= 0.70) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  String _formatTimeAgo(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) {
        return '${diff.inMinutes} mins ago';
      }
      if (diff.inHours < 24) {
        return '${diff.inHours} hr ago';
      }
      return '${diff.inDays} days ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: RefreshIndicator(
        color: _primaryColor,
        onRefresh: () async {
          await _loadData();
          await _refreshDetectionStatus();
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // ── Header ───────────────────────────────
            // A plain SliverToBoxAdapter instead of a SliverAppBar avoids the
            // double top-inset (status bar padding + hardcoded padding) that
            // was causing the large gap under the greeting.
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(20, topInset + 16, 20, 22),
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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Hello, $_username 👋',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Stay aware. Stay safe.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _HeaderIconButton(
                      icon: Icons.notifications_rounded,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Detection Status Card ───────────
                  _buildDetectionStatusCard(),

                  const SizedBox(height: 20),

                  // ── Stats Cards ─────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          title: 'Total Detections',
                          value: _totalDetections.toString(),
                          icon: Icons.hearing_rounded,
                          color: _primaryColor,
                          subtitle: 'All time',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          title: 'High Confidence',
                          value: _highConfidenceCount.toString(),
                          icon: Icons.verified_rounded,
                          color: _successColor,
                          subtitle:
                              '${_totalDetections > 0 ? ((_highConfidenceCount / _totalDetections) * 100).toStringAsFixed(0) : 0}% of total',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Recent Detections ───────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Detections',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          foregroundColor: _primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'See All',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: _primaryColor,
                          strokeWidth: 2.5,
                        ),
                      ),
                    )
                  else if (_recentDetections.isEmpty)
                    _buildEmptyState()
                  else
                    ..._recentDetections
                        .map((r) => _buildRecentCard(r))
                        .toList(),

                  const SizedBox(height: 80),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Big, clearly visible status card — mirrors the "Start Sound
  // Detection" hero card style, but reflects REAL detection state
  // (polled from ForegroundServiceManager) instead of being static.
  // Indigo = idle / tap to start. Green + pulsing dot = actively listening.
  Widget _buildDetectionStatusCard() {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/dashboard');
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _isDetectionRunning
                ? [const Color(0xFF22C55E), _successColor]
                : [_primaryColor, _primaryColorDeep],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: (_isDetectionRunning ? _successColor : _primaryColor)
                  .withOpacity(0.28),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isDetectionRunning
                    ? Icons.mic_rounded
                    : Icons.mic_none_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _isDetectionRunning
                              ? 'Listening...'
                              : 'Start Sound Detection',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_isDetectionRunning) ...[
                        const SizedBox(width: 8),
                        const _PulsingDot(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isDetectionRunning
                        ? 'Monitoring your environment in real time'
                        : 'Detect sirens, alarms, horns and more',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.88),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withOpacity(0.85),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: _textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentCard(Map<String, dynamic> record) {
    final soundClass = record['sound_class'] as String;
    final confidence = record['confidence'] as double;
    final timestamp = record['timestamp'] as String;
    final config = _soundConfig[soundClass];
    final color = (config?['color'] as Color?) ?? Colors.grey[600]!;
    final label = config?['label'] as String? ?? soundClass;
    final icon = config?['icon'] as IconData? ?? Icons.volume_up_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor, width: 1),
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                // Confidence label
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _confidenceColor(confidence).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _confidenceLabel(confidence),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _confidenceColor(confidence),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatTimeAgo(timestamp),
            style: const TextStyle(fontSize: 11, color: _textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor, width: 1),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.hearing_rounded, size: 30, color: _primaryColor.withOpacity(0.6)),
          ),
          const SizedBox(height: 14),
          const Text(
            'No detections yet',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Start detection to see results here',
            style: TextStyle(color: _textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Circular translucent icon button used in the header (notifications, etc.)
class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.16),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

/// Small pulsing dot indicating live/active detection state.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);

  late final Animation<double> _opacity = Tween<double>(begin: 0.4, end: 1.0)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}