// detection_dashboard.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'permission_service.dart';
import 'audio_ml_service.dart';

class DetectionDashboard extends StatefulWidget {
  const DetectionDashboard({Key? key}) : super(key: key);

  @override
  State<DetectionDashboard> createState() => _DetectionDashboardState();
}

class _DetectionDashboardState extends State<DetectionDashboard>
    with SingleTickerProviderStateMixin {
  // Controls whether sound detection is running
  bool _isListening = false;

  // Last detected sound — null means nothing detected yet
  String? _lastDetectedSound;
  double? _lastConfidence;
  DateTime? _lastDetectedTime;

  // Pulse animation for the listening indicator
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Maps each sound class to its display properties (stores all the detectable sounds)
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
      'label': 'Alarm Clock',
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

  @override
  void initState() {
    super.initState();

    // Pulse animation for listening indicator
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Pause animation when not listening
    _pulseController.stop();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    // If already listening → stop
    if (_isListening) {
      setState(() => _isListening = false);
      _pulseController.stop();

      AudioMLService.instance.stopListening();
      return;
    }

    // Check microphone permission before starting
    final result = await PermissionService.instance.checkAll();

    if (!result.microphoneGranted) {
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
            'Sound detection needs microphone access.\n\n'
            'Please grant microphone permission to start detecting sounds.',
            style: TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);

                final status = await PermissionService.instance
                    .requestMicrophone();

                if (status.isGranted && mounted) {
                  setState(() {
                    _isListening = true;
                  });

                  _pulseController.repeat(reverse: true);

                  // Aaron will connect TFLite inference here.
                  String modelPath = "assets/models/emergency_audio_classifier.tflite";
                  
                } else if (mounted) {
                  await PermissionService.instance.openSettings();
                }
              },
              child: const Text("Grant Permission"),
            ),
          ],
        ),
      );

      return;
    }

    // Permission granted
    setState(() => _isListening = true);
    _pulseController.repeat(reverse: true);

    // =====================================================
    // TODO (Aaron):
    // Start the TFLite sound classification here.
    AudioMLService.instance.startListening(onResult: 
    (String detectedClass, double confidence) {
      // Only trigger if confidence is above 85%
      if (confidence >= 0.85) {
        _onSoundDetected(detectedClass, confidence);
      }
    });
    // When a sound is detected it should call:
    //
    // _onSoundDetected(className, confidence);
    //
    // Example:
    // _onSoundDetected("siren", 0.94);
    // =====================================================
  }

  // Called by the inference engine when a sound is classified above 85%
  // Aaron will hook this up from the TFLite wrapper
  void _onSoundDetected(String soundClass, double confidence) {
    setState(() {
      _lastDetectedSound = soundClass;
      _lastConfidence = confidence;
      _lastDetectedTime = DateTime.now();
    });

    // Trigger haptic feedback (PB-03)
    _triggerHapticForSound(soundClass);

    // Show full-screen alert overlay (PB-04)
    _showAlertOverlay(soundClass, confidence);
  }

  // Different vibration patterns for different sounds (PB-03)
  void _triggerHapticForSound(String soundClass) {
    switch (soundClass) {
      case 'siren':
      case 'fire_alarm':
        // Long strong vibration for critical emergencies
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 200), () {
          HapticFeedback.heavyImpact();
        });
        Future.delayed(const Duration(milliseconds: 400), () {
          HapticFeedback.heavyImpact();
        });
        break;
      case 'crying_baby':
        // Double medium pulse for baby cry
        HapticFeedback.mediumImpact();
        Future.delayed(const Duration(milliseconds: 300), () {
          HapticFeedback.mediumImpact();
        });
        break;
      case 'car_horn':
        // Single strong pulse for horn
        HapticFeedback.heavyImpact();
        break;
      default:
        // Single light pulse for other sounds
        HapticFeedback.lightImpact();
        break;
    }
  }

  // Full-screen alert overlay (PB-04)
  void _showAlertOverlay(String soundClass, double confidence) {
    final config = _soundConfig[soundClass];
    if (config == null) return;

    showDialog(
      context: context,
      barrierColor:
          (config['color'] as Color?)?.withOpacity(0.85) ??
          Colors.red.withOpacity(0.85),
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
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Detection History',
            onPressed: () {
              Navigator.pushNamed(context, '/history');
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 16),

              // Listening indicator
              _buildListeningIndicator(),

              const SizedBox(height: 40),

              // Start / Stop toggle
              _buildToggleButton(),

              const SizedBox(height: 40),

              // Last detected sound card
              _buildLastDetectedCard(),

              const SizedBox(height: 32),

              // Sound categories grid
              _buildSoundCategoriesGrid(),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // Pulsing microphone indicator
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

  // Large start/stop button
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
                  .withOpacity(0.3),
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

  // Card showing last detected sound
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
            Icon(Icons.hearing_rounded, size: 36, color: Colors.grey[400]),
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

  // Grid of all detectable sound categories
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

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}

// ── Full-screen alert overlay (PB-04) ────────────────────────────────────────
class AlertOverlay extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: color.withOpacity(0.92),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pulsing icon
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.2),
                ),
                child: Icon(icon, size: 72, color: Colors.white),
              ),
              const SizedBox(height: 32),
              const Text(
                'SOUND DETECTED',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                soundLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                '${(confidence * 100).toStringAsFixed(1)}% confidence',
                style: const TextStyle(color: Colors.white60, fontSize: 14),
              ),
              const SizedBox(height: 60),
              GestureDetector(
                onTap: onDismiss,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text(
                    'Dismiss',
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
