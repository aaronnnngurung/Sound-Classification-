import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'alert_overlay_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // App States
  bool _isListening = false;
  bool _emergencyModeOnly = false;

  // Animation controller for the microphone pulse effect
  late AnimationController _pulseController;

  static const Color maroonColor = Color(0xFF701E38);
  static const Color navyColor = Color(0xFF1B4D8F);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleListening() {
    setState(() {
      _isListening = !_isListening;
      if (_isListening) {
        _pulseController.repeat(); // Start wave animation loop

        // TEST TRIGGER SIMULATION: Immediately launch the alert modal view
        // when they enable audio tracking to see your design implementation live!
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AlertOverlayPage(
              soundClass: "Fire Alarm",
              isEmergency: true,
            ),
          ),
        );
      } else {
        _pulseController.stop(); // Pause wave animation
        _pulseController.reset();
      }
    });

    // Temporary placeholder feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isListening ? 'Sound detection activated' : 'Sound detection paused',
        ),
        duration: const Duration(seconds: 1),
        backgroundColor: _isListening ? navyColor : Colors.grey[700],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Sound Classifier',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.email)
            .snapshots(),
        builder: (context, snapshot) {
          String displayUsername = 'User';
          if (snapshot.hasData && snapshot.data!.exists) {
            Map<String, dynamic> userData =
                snapshot.data!.data() as Map<String, dynamic>;
            displayUsername = userData['username'] ?? 'User';
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16),

                // Welcome banner alignment
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, $displayUsername!',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF343A40),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isListening
                            ? 'Monitoring your environment live...'
                            : 'System is currently resting',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 60),

                // Animated Listening Target Toggle Component
                Center(
                  child: GestureDetector(
                    onTap: _toggleListening,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer Pulsating Rings (Only render when system is actively tracking audio)
                        if (_isListening)
                          ...List.generate(2, (index) {
                            return AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                return Container(
                                  width:
                                      140 +
                                      (index * 40) +
                                      (_pulseController.value * 50),
                                  height:
                                      140 +
                                      (index * 40) +
                                      (_pulseController.value * 50),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        (_emergencyModeOnly
                                                ? maroonColor
                                                : navyColor)
                                            .withValues(
                                              alpha:
                                                  (1.0 -
                                                      _pulseController.value) *
                                                  0.2,
                                            ),
                                  ),
                                );
                              },
                            );
                          }),

                        // Primary Target Ring Switch
                        Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isListening
                                ? (_emergencyModeOnly ? maroonColor : navyColor)
                                : Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                            border: Border.all(
                              color: _isListening
                                  ? Colors.transparent
                                  : Colors.grey[200]!,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            _isListening
                                ? Icons.graphic_eq_rounded
                                : Icons.mic_none_rounded,
                            size: 64,
                            color: _isListening
                                ? Colors.white
                                : Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Live status text indicators
                Text(
                  _isListening ? 'LISTENING ACTIVE' : 'SYSTEM IDLE',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: _isListening
                        ? (_emergencyModeOnly ? maroonColor : navyColor)
                        : Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isListening
                      ? 'Tap to pause sound alerts'
                      : 'Tap button to start detecting sounds',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),

                const SizedBox(height: 60),

                // Emergency Mode Custom Toggle Card
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[200]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _emergencyModeOnly
                              ? const Color(0xFFFDF2F4)
                              : Colors.orange[50],
                        ),
                        child: Icon(
                          _emergencyModeOnly
                              ? Icons.gpp_maybe_rounded
                              : Icons.notifications_active_outlined,
                          color: _emergencyModeOnly
                              ? maroonColor
                              : Colors.orange[700],
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Emergency Filter Only',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2B2D42),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _emergencyModeOnly
                                  ? 'Alerts restricted to Sirens & Alarms'
                                  : 'Detecting all environmental sound classes',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        activeTrackColor: maroonColor,
                        value: _emergencyModeOnly,
                        onChanged: (val) {
                          setState(() {
                            _emergencyModeOnly = val;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
