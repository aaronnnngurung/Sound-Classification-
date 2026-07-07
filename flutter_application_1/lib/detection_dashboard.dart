// detection_dashboard.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'foreground_service_manager.dart';
import 'permission_service.dart';
import 'database_helper.dart';

class DetectionDashboard extends StatefulWidget {
  const DetectionDashboard({Key? key}) : super(key: key);

  @override
  State<DetectionDashboard> createState() => _DetectionDashboardState();
}

class _DetectionDashboardState extends State<DetectionDashboard>
    with SingleTickerProviderStateMixin {
  // State variables
  bool _isListening = false;
  String? _lastDetectedSound;
  double? _lastConfidence;
  DateTime? _lastDetectedTime;

  // Pulse animation for listening indicator
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  //  Sound configuration
  // Maps each sound class to display properties
  final Map<String, Map<String, dynamic>> _soundConfig = {
    'siren': {
      'label': 'Siren',
      'icon': Icons.emergency_rounded,
      'color': Colors.red[600],
      'description': 'Emergency vehicle detected nearby',
    },
    'crying_baby': {
      'label': 'Baby Crying',
      'icon': Icons.child_care_rounded,
      'color': Colors.orange[600],
      'description': 'Infant crying detected',
    },
    'car_horn': {
      'label': 'Car Horn',
      'icon': Icons.directions_car_rounded,
      'color': Colors.amber[700],
      'description': 'Vehicle horn detected',
    },
    'fire_alarm': {
      'label': 'Fire Alarm',
      'icon': Icons.local_fire_department_rounded,
      'color': Colors.deepOrange[600],
      'description': 'Fire alarm sound detected',
    },
    'glass_breaking': {
      'label': 'Glass Breaking',
      'icon': Icons.crisis_alert_rounded,
      'color': Colors.purple[600],
      'description': 'Glass breaking detected',
    },
    'door_wood_knock': {
      'label': 'Knocking',
      'icon': Icons.door_front_door_rounded,
      'color': Colors.brown[600],
      'description': 'Knocking sound detected',
    },
    'clock_alarm': {
      'label': 'Clock Alarm',
      'icon': Icons.alarm_rounded,
      'color': Colors.blue[700],
      'description': 'Alarm clock detected',
    },
    'train': {
      'label': 'Train',
      'icon': Icons.train_rounded,
      'color': Colors.teal[600],
      'description': 'Train sound detected',
    },
    'fireworks': {
      'label': 'Fireworks',
      'icon': Icons.celebration_rounded,
      'color': Colors.pink[600],
      'description': 'Fireworks detected',
    },
  };

  // Lifecycle
  @override
  void initState() {
    super.initState();

    // Setup pulse animation for listening indicator
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Check if service is already running when
    // screen opens (user may have navigated away)
    _syncServiceState();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // Sync UI state with actual service state
  // Handles case where user navigates away and back
  Future<void> _syncServiceState() async {
    final running = await ForegroundServiceManager.instance.isRunning;
    if (mounted) {
      setState(() => _isListening = running);
      if (running) {
        _pulseController.repeat(reverse: true);
      }
    }
  }

  //  Toggle listening on/off
  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stopDetection();
    } else {
      await _checkPermissionsThenStart();
    }
  }

  // Stop detection and foreground service
  Future<void> _stopDetection() async {
    setState(() => _isListening = false);
    _pulseController.stop();
    _pulseController.reset();

    await ForegroundServiceManager.instance.stopService();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.mic_off_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('Sound detection stopped'),
            ],
          ),
          backgroundColor: Colors.grey,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Check permissions before starting
  Future<void> _checkPermissionsThenStart() async {
    final result = await PermissionService.instance.checkAll();

    if (!result.microphoneGranted) {
      _showMicPermissionDialog();
      return;
    }

    await _startDetection();
  }

  // Start detection and foreground service
  Future<void> _startDetection() async {
    setState(() => _isListening = true);
    _pulseController.repeat(reverse: true);

    // Start the foreground service
    // Shows persistent notification
    // Keeps app alive in background (PB-07)
    await ForegroundServiceManager.instance.startService();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.mic_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('Sound detection started'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }

    // ── Aaron connects TFLite inference here ──────────
    // When his model detects a sound above 85%
    // confidence, he calls:
    // _onSoundDetected('siren', 0.94);
  }

  // ── Called by  TFLite when sound detected ────────────────
  // This is the central method that connects
  // ML output to UI, haptics, alerts, and storage
  void _onSoundDetected(String soundClass, double confidence) {
    // Update UI state
    setState(() {
      _lastDetectedSound = soundClass;
      _lastConfidence = confidence;
      _lastDetectedTime = DateTime.now();
    });

    // Get config for this sound class
    final config = _soundConfig[soundClass];
    if (config == null) return;

    // 1. Save to SQLite history (PB-09)
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      DatabaseHelper.instance.insertDetection(
        soundClass: soundClass,
        displayLabel: config['label'] as String,
        confidence: confidence,
        userId: uid,
      );
    }

    // 2. Update foreground notification
    ForegroundServiceManager.instance.updateNotification(
      config['label'] as String,
      confidence,
    );

    // Reset notification after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (_isListening) {
        ForegroundServiceManager.instance.resetNotification();
      }
    });

    // 3. Trigger haptic feedback (PB-03)
    _triggerHapticForSound(soundClass);

    // 4. Show full-screen visual alert (PB-04)
    _showAlertOverlay(soundClass, confidence);
  }

  //  Haptic patterns per sound class (PB-03)
  void _triggerHapticForSound(String soundClass) {
    switch (soundClass) {
      case 'siren':
      case 'fire_alarm':
        // Three strong pulses for critical emergencies
        HapticFeedback.heavyImpact();
        Future.delayed(
          const Duration(milliseconds: 200),
          HapticFeedback.heavyImpact,
        );
        Future.delayed(
          const Duration(milliseconds: 400),
          HapticFeedback.heavyImpact,
        );
        break;

      case 'crying_baby':
        // Two medium pulses for baby cry
        HapticFeedback.mediumImpact();
        Future.delayed(
          const Duration(milliseconds: 300),
          HapticFeedback.mediumImpact,
        );
        break;

      case 'car_horn':
        // One strong pulse for horn
        HapticFeedback.heavyImpact();
        break;

      case 'glass_breaking':
        // Three rapid light pulses
        HapticFeedback.lightImpact();
        Future.delayed(
          const Duration(milliseconds: 100),
          HapticFeedback.lightImpact,
        );
        Future.delayed(
          const Duration(milliseconds: 200),
          HapticFeedback.lightImpact,
        );
        break;

      default:
        // Single light pulse for other sounds
        HapticFeedback.lightImpact();
        break;
    }
  }

  //  Full-screen alert overlay (PB-04)
  void _showAlertOverlay(String soundClass, double confidence) {
    final config = _soundConfig[soundClass];
    if (config == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: (config['color'] as Color).withOpacity(0.92),
      builder: (ctx) => AlertOverlay(
        soundLabel: config['label'] as String,
        description: config['description'] as String,
        icon: config['icon'] as IconData,
        color: config['color'] as Color,
        confidence: confidence,
        onDismiss: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  //  Microphone permission dialog
  void _showMicPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.mic_off_rounded, color: Colors.red[600]),
            const SizedBox(width: 10),
            const Text(
              'Microphone Required',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Sound detection needs microphone access '
          'to monitor your environment.\n\n'
          'Please grant microphone permission '
          'to start detecting sounds.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final status = await PermissionService.instance
                  .requestMicrophone();
              if (status.isGranted && mounted) {
                await _startDetection();
              } else if (mounted) {
                await PermissionService.instance.openSettings();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
  }

  // Build
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Sound Detection',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // History shortcut
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Detection History',
            onPressed: () => Navigator.pushNamed(context, '/history'),
          ),
          // Settings shortcut
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Settings',
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Status banner when running
            if (_isListening) _buildRunningBanner(),
            if (_isListening) const SizedBox(height: 16),

            //  Listening indicator (PB-06)
            _buildListeningIndicator(),

            const SizedBox(height: 36),

            //  Start/Stop toggle (PB-08)
            _buildToggleButton(),

            const SizedBox(height: 28),

            //  Last detected card
            _buildLastDetectedCard(),

            const SizedBox(height: 28),

            //  Detectable sounds grid
            _buildSoundCategoriesGrid(),

            // ── Temporary test button
            // REMOVE after Aaron finishes TFLite
            const SizedBox(height: 20),
            _buildTestButton(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  //  Running banner
  Widget _buildRunningBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, size: 10, color: Colors.green[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Detection is running in the background. '
              'You will be alerted even if you switch apps.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  //  Pulsing mic indicator (PB-06)
  Widget _buildListeningIndicator() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _isListening ? _pulseAnimation.value : 1.0,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening ? Colors.blue[600] : Colors.grey[300],
                  boxShadow: _isListening
                      ? [
                          BoxShadow(
                            color: Colors.blue[600]!.withOpacity(0.4),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ]
                      : [],
                ),
                child: Icon(
                  _isListening ? Icons.mic_rounded : Icons.mic_off_rounded,
                  size: 64,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          _isListening ? 'Listening...' : 'Tap to Start',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _isListening ? Colors.blue[600] : Colors.grey[500],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _isListening
              ? 'Monitoring your environment'
              : 'Sound detection is paused',
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),
      ],
    );
  }

  //  Start/Stop button (PB-08) ────────────────────────────────────
  Widget _buildToggleButton() {
    return GestureDetector(
      onTap: _toggleListening,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: _isListening ? Colors.red[600] : Colors.blue[600],
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (_isListening ? Colors.red[600]! : Colors.blue[600]!)
                  .withOpacity(0.35),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isListening
                  ? Icons.stop_circle_rounded
                  : Icons.play_circle_rounded,
              color: Colors.white,
              size: 26,
            ),
            const SizedBox(width: 10),
            Text(
              _isListening ? 'Stop Detection' : 'Start Detection',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  //  Last detected sound card
  Widget _buildLastDetectedCard() {
    if (_lastDetectedSound == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Icon(Icons.hearing_rounded, size: 36, color: Colors.grey[300]),
            const SizedBox(height: 10),
            Text(
              'No sound detected yet',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Start detection to begin monitoring',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
      );
    }

    final config = _soundConfig[_lastDetectedSound!];
    final color = (config?['color'] as Color?) ?? Colors.blue[600]!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              config?['icon'] as IconData? ?? Icons.volume_up_rounded,
              color: color,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Last Detected',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  config?['label'] as String? ?? _lastDetectedSound!,
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${(_lastConfidence! * 100).toStringAsFixed(1)}% confidence',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          if (_lastDetectedTime != null)
            Text(
              _formatTime(_lastDetectedTime!),
              style: TextStyle(color: Colors.grey[400], fontSize: 11),
            ),
        ],
      ),
    );
  }

  //  Sound categories grid
  Widget _buildSoundCategoriesGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DETECTABLE SOUNDS',
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.1,
          ),
          itemCount: _soundConfig.length,
          itemBuilder: (context, index) {
            final key = _soundConfig.keys.elementAt(index);
            final config = _soundConfig[key]!;
            final color = config['color'] as Color;
            final isActive = _lastDetectedSound == key;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: isActive ? color.withOpacity(0.15) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive ? color : Colors.grey[200]!,
                  width: isActive ? 2 : 1,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    config['icon'] as IconData,
                    color: isActive ? color : Colors.grey[400],
                    size: 28,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    config['label'] as String,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isActive ? color : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  //  Test button
  // Simulates a detection — REMOVE after Aaron
  // connects TFLite
  Widget _buildTestButton() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange[200]!),
          ),
          child: Text(
            '⚠ Test mode — remove after TFLite integration',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.orange[800],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: _soundConfig.keys.map((key) {
            final config = _soundConfig[key]!;
            final color = config['color'] as Color;
            return GestureDetector(
              onTap: () => _onSoundDetected(key, 0.92),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.4)),
                ),
                child: Text(
                  config['label'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  //  Helpers
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    return '${time.hour}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }
}

// Full-screen alert overlay widget (PB-04)
class AlertOverlay extends StatefulWidget {
  final String soundLabel;
  final String description;
  final IconData icon;
  final Color color;
  final double confidence;
  final VoidCallback onDismiss;

  const AlertOverlay({
    Key? key,
    required this.soundLabel,
    required this.description,
    required this.icon,
    required this.color,
    required this.confidence,
    required this.onDismiss,
  }) : super(key: key);

  @override
  State<AlertOverlay> createState() => _AlertOverlayState();
}

class _AlertOverlayState extends State<AlertOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: widget.color.withOpacity(0.94),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated icon
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                    ),
                    child: Icon(widget.icon, size: 72, color: Colors.white),
                  ),
                ),

                const SizedBox(height: 32),

                // Sound detected label
                Text(
                  'SOUND DETECTED',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    letterSpacing: 2.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                // Sound name
                Text(
                  widget.soundLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                // Description
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    widget.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),

                const SizedBox(height: 10),

                // Confidence
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${(widget.confidence * 100).toStringAsFixed(1)}% confidence',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 60),

                // Dismiss button
                GestureDetector(
                  onTap: widget.onDismiss,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 52,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      'Dismiss',
                      style: TextStyle(
                        color: widget.color,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Swipe hint
                Text(
                  'Tap dismiss to close this alert',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
