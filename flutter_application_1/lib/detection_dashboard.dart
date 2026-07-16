import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'foreground_service_manager.dart';
import 'permission_service.dart';
import 'audio_ml_service.dart';
import 'database_helper.dart';
import 'background_permission_helper.dart';
import 'haptic_service.dart';
import 'alert_notification_service.dart';

class DetectionDashboard extends StatefulWidget {
  const DetectionDashboard({Key? key}) : super(key: key);

  @override
  State<DetectionDashboard> createState() => _DetectionDashboardState();
}

class _DetectionDashboardState extends State<DetectionDashboard>
    with SingleTickerProviderStateMixin {
  bool _isListening = false;
  String? _lastDetectedSound;
  double? _lastConfidence;
  DateTime? _lastDetectedTime;

  //we add this to make sure that the loop is not infinite
  bool _isAlertWindowOpen = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

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

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Listen for data from foreground service
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);

    // Also set callback for fallback mode
    ForegroundServiceManager.instance.onSoundDetected =
        (soundClass, confidence) {
          if (mounted && !_isAlertWindowOpen) {
            _onSoundDetected(soundClass, confidence);
          }
        };

    _syncServiceState();
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    _pulseController.dispose();
    // Do NOT stop detection here
    // Detection must continue in background
    super.dispose();
  }

  void _onReceiveTaskData(Object data) {
    if (data is Map<String, dynamic>) {
      final soundClass = data['soundClass'] as String?;
      final confidence = data['confidence'] as double?;
      if (soundClass != null &&
          confidence != null &&
          !_isAlertWindowOpen &&
          mounted) {
        _onSoundDetected(soundClass, confidence);
      }
    }
  }

  Future<void> _syncServiceState() async {
    final running = await ForegroundServiceManager.instance.isRunning;
    if (mounted) {
      setState(() => _isListening = running);
      if (running) {
        _pulseController.repeat(reverse: true);
      }
    }
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stopDetection();
    } else {
      await _checkPermissionsThenStart();
    }
  }

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

  Future<void> _checkPermissionsThenStart() async {
    Future<void> _showMicPermissionDialog() async {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Microphone Permission'),
          content: const Text(
            'This app needs microphone access to detect sounds. Please grant the permission in app settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }

    // Step 1 — Check microphone permission
    final micStatus = await Permission.microphone.status;
    print('Microphone status: $micStatus');

    // Step 2 — If not granted, request it NOW
    // while we are still in the UI thread
    // with an active Activity
    if (!micStatus.isGranted) {
      print('Requesting microphone permission...');
      final result = await Permission.microphone.request();
      print('Microphone request result: $result');

      if (!result.isGranted) {
        // User denied — show explanation
        if (mounted) {
          await _showMicPermissionDialog();
        }
        return;
      }
    }

    // Step 3 — Also check notification permission
    // on Android 13+
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    // Step 4 — Permission is now granted
    // Safe to start the foreground service
    await _startDetection();
  }

  Future<void> _startDetection() async {
    setState(() => _isListening = true);
    _pulseController.repeat(reverse: true);

    print('Dashboard: starting foreground service');

    final started = await ForegroundServiceManager.instance.startService();

    print('Dashboard: service started = $started');
    print('Using fallback: ${ForegroundServiceManager.instance.usingFallback}');

    if (!started) {
      setState(() => _isListening = false);

      _pulseController.stop();
      _pulseController.reset();

      if (mounted) {
        await BackgroundPermissionHelper.showDialog(context);
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.mic_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('Detection started — continues in background'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _onSoundDetected(String soundClass, double confidence) {
    setState(() {
      _lastDetectedSound = soundClass;
      _lastConfidence = confidence;
      _lastDetectedTime = DateTime.now();
    });

    final config = _soundConfig[soundClass];
    if (config == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      DatabaseHelper.instance.insertDetection(
        soundClass: soundClass,
        displayLabel: config['label'] as String,
        confidence: confidence,
        userId: uid,
      );
    }

    ForegroundServiceManager.instance.updateNotification(
      config['label'] as String,
      confidence,
    );

    Future.delayed(const Duration(seconds: 5), () {
      if (_isListening) {
        ForegroundServiceManager.instance.resetNotification();
      }
    });
    // PB-03 — Haptic vibration
    // Uses native Android vibrator
    // Works in foreground AND background
    HapticService.instance.vibrateForSound(soundClass);

    // PB-04 — Visual alert (foreground)
    // Full screen overlay when app is open
    if (!_isAlertWindowOpen) {
      _showAlertOverlay(soundClass, confidence);
    }
    AlertNotificationService.instance.showAlertNotification(
      soundClass: soundClass,
      soundLabel: config['label'] as String,
      confidence: confidence,
    );
  }

  void _triggerHapticForSound(String soundClass) {
    switch (soundClass) {
      case 'siren':
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
        HapticFeedback.mediumImpact();
        Future.delayed(
          const Duration(milliseconds: 300),
          HapticFeedback.mediumImpact,
        );
        break;

      case 'car_horn':
        HapticFeedback.heavyImpact();
        break;

      case 'glass_breaking':
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
        HapticFeedback.lightImpact();
        break;
    }
  }

  void _showAlertOverlay(String soundClass, double confidence) {
    final config = _soundConfig[soundClass];
    if (config == null) return;
    //we do this to lock the screen from recieving new alrts imediately.
    setState(() {
      _isAlertWindowOpen = true;
    });

    showDialog(
      context: context,
      barrierDismissible:
          false, //this prevents closing by tapping outside the box
      builder: (ctx) => AlertOverlay(
        soundLabel: config['label'] as String,
        description: config['description'] as String,
        icon: config['icon'] as IconData,
        color: config['color'] as Color,
        confidence: confidence,
        onDismiss: () {
          Navigator.pop(ctx); //remove the current overlay

          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _isAlertWindowOpen = false; //unlock the screen after 2 seconds
              });
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Sound Detector'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildListeningCard(),

            if (_isListening && ForegroundServiceManager.instance.usingFallback)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 16, bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange[300]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: Colors.orange[700],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Running in compatibility mode. '
                        'For full background support, '
                        'enable Autostart in Settings.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            _buildLastDetectionCard(),

            const SizedBox(height: 24),

            _buildControlButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildListeningCard() {
    return Card(
      elevation: 8,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isListening
                ? [Colors.green[400]!, Colors.green[600]!]
                : [Colors.grey[400]!, Colors.grey[600]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.3),
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_off,
                  size: 50,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isListening ? 'Listening...' : 'Not Listening',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isListening
                  ? 'Detecting emergency sounds'
                  : 'Tap the button to start',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLastDetectionCard() {
    if (_lastDetectedSound == null) {
      return Card(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'No detections yet',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
        ),
      );
    }

    final config = _soundConfig[_lastDetectedSound];
    if (config == null) return const SizedBox();

    return Card(
      elevation: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: config['color'] as Color, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  config['icon'] as IconData,
                  color: config['color'] as Color,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Last Detection',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      Text(
                        config['label'] as String,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${(_lastConfidence! * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: config['color'] as Color,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _formatTime(_lastDetectedTime!),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _lastConfidence,
                minHeight: 6,
                backgroundColor: (config['color'] as Color).withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  config['color'] as Color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _toggleListening,
        icon: Icon(
          _isListening ? Icons.stop_circle_rounded : Icons.mic_rounded,
        ),
        label: Text(
          _isListening ? 'Stop Detection' : 'Start Detection',
          style: const TextStyle(fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _isListening ? Colors.red : Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}

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
                Text(
                  widget.soundLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    widget.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 10),
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
