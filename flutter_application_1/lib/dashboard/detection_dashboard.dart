import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Services
import 'package:flutter_application_1/services/foreground_service_manager.dart';
import 'package:flutter_application_1/services/permission_service.dart';
import 'package:flutter_application_1/services/haptic_service.dart';
import 'package:flutter_application_1/services/alert_notification_service.dart';
import 'package:flutter_application_1/services/flash_service.dart';

// Utils
import 'package:flutter_application_1/utils/database_helper.dart';
import 'package:flutter_application_1/utils/background_permission_helper.dart';

// Guardian
import 'package:flutter_application_1/guardian/guardian_notification_api.dart';
import 'package:flutter_application_1/smartwatch/watch_sync_service.dart';

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

  bool _isAlertWindowOpen = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;

  // 2026 Material 3 Shared Color Palette
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

  final Map<String, Map<String, dynamic>> _soundConfig = {
    'siren': {
      'label': 'Siren',
      'icon': Icons.emergency_rounded,
      'color': Color(0xFFDC2626),
      'description': 'Emergency vehicle detected nearby',
    },
    'crying_baby': {
      'label': 'Crying Baby',
      'icon': Icons.child_care_rounded,
      'color': Color(0xFFEA580C),
      'description': 'Baby crying detected',
    },
    'car_horn': {
      'label': 'Car Horn',
      'icon': Icons.directions_car_rounded,
      'color': Color(0xFFD97706),
      'description': 'Vehicle horn detected',
    },
    'fire_alarm': {
      'label': 'Fire Alarm',
      'icon': Icons.local_fire_department_rounded,
      'color': Color(0xFFE11D48),
      'description': 'Fire or smoke alarm triggered',
    },
    'glass_breaking': {
      'label': 'Glass Breaking',
      'icon': Icons.crisis_alert_rounded,
      'color': Color(0xFF9333EA),
      'description': 'Glass breaking detected',
    },
    'door_wood_knock': {
      'label': 'Knocking',
      'icon': Icons.door_front_door_rounded,
      'color': Color(0xFF78350F),
      'description': 'Knocking sound detected',
    },
    'clock_alarm': {
      'label': 'Clock Alarm',
      'icon': Icons.alarm_rounded,
      'color': Color(0xFF1D4ED8),
      'description': 'Loud clock alarm sounding',
    },
    'train': {
      'label': 'Train',
      'icon': Icons.train_rounded,
      'color': Color(0xFF0D9488),
      'description': 'Train or railway signal nearby',
    },
    'fireworks': {
      'label': 'Fireworks',
      'icon': Icons.celebration_rounded,
      'color': Color(0xFFDB2777),
      'description': 'Fireworks or loud explosions detected',
    },
  };

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.2, end: 0.65).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);

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
    super.dispose();
  }

  void _onReceiveTaskData(Object data) {
    if (data is! Map) return;

    final soundClass = data['soundClass']?.toString();
    final rawConfidence = data['confidence'];
    final confidence = rawConfidence is num ? rawConfidence.toDouble() : null;

    if (soundClass != null &&
        confidence != null &&
        !_isAlertWindowOpen &&
        mounted) {
      _onSoundDetected(soundClass, confidence);
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
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.mic_off_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('Sound detection stopped'),
            ],
          ),
          backgroundColor: _textSecondary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _checkPermissionsThenStart() async {
    Future<void> showMicPermissionDialog() async {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: _surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Microphone Permission', style: TextStyle(fontWeight: FontWeight.w700, color: _textPrimary)),
          content: const Text(
            'This app needs microphone access to detect emergency sounds in real-time. Please grant permission in app settings.',
            style: TextStyle(color: _textSecondary, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }

    final micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      final result = await Permission.microphone.request();
      if (!result.isGranted) {
        if (mounted) await showMicPermissionDialog();
        return;
      }
    }

    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    await _startDetection();
  }

  Future<void> _startDetection() async {
    setState(() => _isListening = true);
    _pulseController.repeat(reverse: true);

    final started = await ForegroundServiceManager.instance.startService();

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
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.mic_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('Detection active — running in background'),
            ],
          ),
          backgroundColor: _activeGreenDeep,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
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

    WatchSyncService.instance.sendEmergencyAlert(
    EmergencyAlert(
      soundClass: soundClass,
      confidence: confidence,
      timestamp: DateTime.now(),
    ),
  );

    HapticService.instance.vibrateForSound(soundClass);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      DatabaseHelper.instance.insertDetection(
        soundClass: soundClass,
        displayLabel: config['label'] as String,
        confidence: confidence,
        userId: uid,
      );

      GuardianNotificationApi.instance.notifyEmergency(
        soundClass: soundClass,
        confidence: confidence,
      );

        FirebaseFirestore.instance.collection('detections').add({
        'userId': uid,
        'soundClass': soundClass,
        'sound': config['label'] as String,
        'confidence': confidence,
        'timestamp': FieldValue.serverTimestamp(),
      });

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

    final isAppOpen =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

    if (isAppOpen) {
      if (!_isAlertWindowOpen) {
        _showAlertOverlay(soundClass, confidence);
      }
    } else {
      AlertNotificationService.instance.showAlertNotification(
        soundClass: soundClass,
        soundLabel: config['label'] as String,
        confidence: confidence,
      );
    }
  }

  void _showAlertOverlay(String soundClass, double confidence) {
    final config = _soundConfig[soundClass];
    if (config == null) return;
    setState(() => _isAlertWindowOpen = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertOverlay(
        soundLabel: config['label'] as String,
        description: config['description'] as String,
        icon: config['icon'] as IconData,
        color: config['color'] as Color,
        confidence: confidence,
        onDismiss: () => Navigator.pop(ctx),
      ),
    ).then((_) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _isAlertWindowOpen = false);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Column(
        children: [
          // ── Header Bar ──────────────────────────────────────────────
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
            child: Row(
              children: [
                if (Navigator.canPop(context))
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Sound Monitor 🎙️',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Live AI acoustic monitoring & alert system',
                        style: TextStyle(
                          color: Color(0xD9FFFFFF),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Scrollable Content ──────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                children: [
                  _buildListeningHero(),

                  if (_isListening && ForegroundServiceManager.instance.usingFallback)
                    _buildCompatibilityWarning(),

                  const SizedBox(height: 24),
                  _buildLastDetectionCard(),

                  const SizedBox(height: 28),
                  _buildControlButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero Microphone Card (Redesigned) ──────────────────────────────
  Widget _buildListeningHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isListening
              ? _activeGreen.withOpacity(0.3)
              : _borderColor,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _isListening
                ? _activeGreen.withOpacity(0.12)
                : const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Dynamic Microphone Graphic
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Pulsing Glow Aura
                  if (_isListening) ...[
                    Container(
                      width: 150 * _pulseAnimation.value,
                      height: 150 * _pulseAnimation.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _activeGreen.withOpacity(0.12 * _glowAnimation.value),
                      ),
                    ),
                    Container(
                      width: 125 * _pulseAnimation.value,
                      height: 125 * _pulseAnimation.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _activeGreen.withOpacity(0.22 * _glowAnimation.value),
                      ),
                    ),
                  ],

                  // Center Microphone Button Shell
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _isListening
                          ? const LinearGradient(
                              colors: [_activeGreen, _activeGreenDeep],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : const LinearGradient(
                              colors: [Color(0xFF94A3B8), Color(0xFF64748B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      boxShadow: [
                        BoxShadow(
                          color: (_isListening ? _activeGreen : const Color(0xFF64748B))
                              .withOpacity(0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isListening ? Icons.mic_rounded : Icons.mic_off_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Status Badge Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _isListening
                  ? _activeGreen.withOpacity(0.1)
                  : _inputBgColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening ? _activeGreen : _textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _isListening ? 'MONITORING ACTIVE' : 'MONITORING PAUSED',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: _isListening ? _activeGreenDeep : _textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Text(
            _isListening ? 'Listening for acoustic events...' : 'Tap below to activate detector',
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  static const Color _inputBgColor = Color(0xFFF1F5F9);

  Widget _buildCompatibilityWarning() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Row(
        children: const [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Color(0xFFD97706),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Running in compatibility mode. Enable Autostart in system settings for background persistence.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastDetectionCard() {
    if (_lastDetectedSound == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _borderColor),
        ),
        child: Column(
          children: const [
            Icon(Icons.graphic_eq_rounded, color: _textSecondary, size: 28),
            SizedBox(height: 8),
            Text(
              'No Recent Detections',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Identified sound events will trigger alerts here',
              style: TextStyle(color: _textSecondary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    final config = _soundConfig[_lastDetectedSound];
    if (config == null) return const SizedBox();

    final Color soundColor = config['color'] as Color;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: soundColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: soundColor.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: soundColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  config['icon'] as IconData,
                  color: soundColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LATEST DETECTION',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      config['label'] as String,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: soundColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${(_lastConfidence! * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: soundColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(_lastDetectedTime!),
                    style: const TextStyle(color: _textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _lastConfidence,
              minHeight: 6,
              backgroundColor: _inputBgColor,
              valueColor: AlwaysStoppedAnimation<Color>(soundColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _toggleListening,
        icon: Icon(
          _isListening ? Icons.stop_rounded : Icons.play_arrow_rounded,
          size: 24,
        ),
        label: Text(
          _isListening ? 'Stop Detection' : 'Start Detection',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _isListening ? _dangerRed : _primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
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
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

// ── Redesigned Full-Screen Alert Overlay ─────────────────────────────
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

    _scaleAnimation = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

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
          color: widget.color.withOpacity(0.96),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0x33FFFFFF),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(widget.icon, size: 64, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'CRITICAL SOUND DETECTED',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 2.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.soundLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    widget.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xE6FFFFFF),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${(widget.confidence * 100).toStringAsFixed(1)}% confidence score',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 50),
                GestureDetector(
                  onTap: widget.onDismiss,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Text(
                      'Dismiss Alert',
                      style: TextStyle(
                        color: widget.color,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}