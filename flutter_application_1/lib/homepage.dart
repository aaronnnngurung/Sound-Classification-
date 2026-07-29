// homepage.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'database_helper.dart';
import 'foreground_service_manager.dart';

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
    if (confidence >= 0.85) return Colors.green[600]!;
    if (confidence >= 0.70) return Colors.orange[600]!;
    return Colors.red[400]!;
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
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadData();
          await _refreshDetectionStatus();
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── App Bar ──────────────────────────────
            SliverAppBar(
              expandedHeight: 130,
              floating: false,
              pinned: true,
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.blue[700]!, Colors.blue[500]!],
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Hello, $_username 👋',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Stay aware. Stay safe.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_rounded),
                  onPressed: () {},
                ),
              ],
            ),

            SliverPadding(
              padding: const EdgeInsets.all(16),
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
                          color: Colors.blue[600]!,
                          subtitle: 'All time',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          title: 'High Confidence',
                          value: _highConfidenceCount.toString(),
                          icon: Icons.verified_rounded,
                          color: Colors.green[600]!,
                          subtitle:
                              '${_totalDetections > 0 ? ((_highConfidenceCount / _totalDetections) * 100).toStringAsFixed(0) : 0}% of total',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Recent Detections ───────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Detections',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          'See All',
                          style: TextStyle(
                            color: Colors.blue[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
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
  // Blue = idle / tap to start. Green + pulsing dot = actively listening.
  Widget _buildDetectionStatusCard() {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/dashboard');
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _isDetectionRunning
                ? [Colors.green[500]!, Colors.green[700]!]
                : [Colors.blue[500]!, Colors.blue[700]!],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (_isDetectionRunning ? Colors.green : Colors.blue)
                  .withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isDetectionRunning
                    ? Icons.mic_rounded
                    : Icons.mic_none_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _isDetectionRunning
                            ? 'Listening...'
                            : 'Start Sound Detection',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_isDetectionRunning) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isDetectionRunning
                        ? 'Monitoring your environment in real time'
                        : 'Detect sirens, alarms, horns and more',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withOpacity(0.8),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
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
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                // Confidence label
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _confidenceColor(confidence).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _confidenceLabel(confidence),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _confidenceColor(confidence),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatTimeAgo(timestamp),
            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.hearing_rounded, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            'No detections yet',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Start detection to see results here',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ],
      ),
    );
  }
}
