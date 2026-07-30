import 'dart:async';
import 'package:flutter/material.dart';
import '../smartwatch/watch_sync_service.dart';
import '../smartwatch/smartwatch_history.dart';
import '../smartwatch/watch_round_safe_area.dart';
import '../utils/emergency.dart';

class SmartwatchScreen extends StatefulWidget {
  const SmartwatchScreen({Key? key}) : super(key: key);

  @override
  State<SmartwatchScreen> createState() => _SmartwatchScreenState();
}

class _SmartwatchScreenState extends State<SmartwatchScreen>
    with SingleTickerProviderStateMixin {
  bool _isConnected = false;
  bool _isEmergencyMode = false;
  EmergencyAlert? _activeAlert;
  final List<EmergencyAlert> _history = [];

  late final AnimationController _pulseController;
  StreamSubscription<EmergencyAlert>? _alertSub;
  StreamSubscription<bool>? _connectionSub;
  StreamSubscription<bool>? _emergencyModeSub;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _alertSub = WatchSyncService.instance.alertStream.listen(_onAlertReceived);
    _connectionSub = WatchSyncService.instance.connectionStream.listen((
      connected,
    ) {
      if (mounted) setState(() => _isConnected = connected);
    });
    _emergencyModeSub = WatchSyncService.instance.emergencyModeStream.listen((
      enabled,
    ) {
      if (mounted) setState(() => _isEmergencyMode = enabled);
    });
  }

  @override
  void dispose() {
    _alertSub?.cancel();
    _connectionSub?.cancel();
    _emergencyModeSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _toggleEmergencyMode() async {
    final newState = !_isEmergencyMode;
    setState(() => _isEmergencyMode = newState);
    await EmergencyModeService.setEnabled(newState);
    await WatchSyncService.instance.sendEmergencyModeToggle(newState);
  }

  void _onAlertReceived(EmergencyAlert alert) {
    if (!mounted) return;
    setState(() {
      _activeAlert = alert;
      _history.insert(0, alert);
    });

    // Emergency state auto-clears after a while — by then the user has
    // felt the vibration and seen the system notification either way,
    // so the watch face returns to normal monitoring on its own.
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && _activeAlert == alert) {
        setState(() => _activeAlert = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final alert = _activeAlert;
    // NOTE: removed the plain SafeArea wrapper that was here — it only
    // handles rectangular system insets, not round-bezel clipping.
    // WatchRoundSafeArea (used inside each state builder below) is the
    // one actually doing that job now.
    return Scaffold(
      backgroundColor: Colors.black,
      body: alert != null
          ? _buildEmergencyState(alert)
          : _buildMonitoringState(),
    );
  }

  Widget _buildMonitoringState() {
    // NOTE: the spec listed both "Monitoring..." and "Connected to
    // Phone" as example status text without saying which state each
    // belongs to. Assumed here: connected -> "Monitoring..." (primary
    // line) + "Connected to phone" (secondary line); not connected ->
    // "Not Connected" + "Waiting for phone...". Swap below if you meant
    // it the other way.
    return WatchRoundSafeArea(
      child: SingleChildScrollView(
        // Scroll fallback rather than a fixed layout — on smaller round
        // profiles this content could still be taller than the safe
        // inscribed area even after insetting; scrolling beats silently
        // clipping/overflowing.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: Tween(
                begin: 0.9,
                end: 1.0,
              ).animate(_pulseController),
              child: Icon(
                _isConnected ? Icons.watch_rounded : Icons.watch_off_rounded,
                color: _isConnected ? Colors.greenAccent : Colors.grey,
                size: 36,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isConnected ? 'Monitoring...' : 'Not Connected',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 3),
            Text(
              _isConnected ? 'Connected to phone' : 'Waiting for phone...',
              style: TextStyle(color: Colors.grey[500], fontSize: 10),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _toggleEmergencyMode,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _isEmergencyMode
                      ? Colors.red.withOpacity(0.25)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isEmergencyMode
                        ? Colors.redAccent
                        : Colors.white24,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isEmergencyMode
                          ? Icons.emergency_rounded
                          : Icons.emergency_outlined,
                      color: _isEmergencyMode
                          ? Colors.redAccent
                          : Colors.white54,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isEmergencyMode ? 'Emergency ON' : 'Emergency OFF',
                      style: TextStyle(
                        color: _isEmergencyMode
                            ? Colors.redAccent
                            : Colors.white54,
                        fontSize: 10,
                        fontWeight: _isEmergencyMode
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            IconButton(
              icon: const Icon(
                Icons.history_rounded,
                color: Colors.white70,
                size: 22,
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        SmartwatchHistoryScreen(initialHistory: _history),
                  ),
                );
              },
            ),
            const Text(
              'History',
              style: TextStyle(color: Colors.white54, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyState(EmergencyAlert alert) {
    // The full-bleed red background is deliberate — an unmissable,
    // edge-to-edge alert fill. Only the TEXT/ICON content goes inside
    // WatchRoundSafeArea; the background itself isn't inset.
    return Container(
      color: Colors.red[900],
      child: Center(
        child: WatchRoundSafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: Tween(
                    begin: 0.95,
                    end: 1.15,
                  ).animate(_pulseController),
                  child: const Icon(
                    Icons.warning_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _friendlyName(alert.soundClass).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 5),
                Text(
                  '${(alert.confidence * 100).toStringAsFixed(0)}% confidence',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _friendlyName(String soundClass) {
    switch (soundClass) {
      case 'siren':
        return 'Siren';
      case 'crying_baby':
        return 'Crying Baby';
      case 'door_wood_knock':
        return 'Knocking';
      case 'glass_breaking':
        return 'Glass Breaking';
      case 'fireworks':
        return 'Fireworks';
      case 'car_horn':
        return 'Car Horn';
      default:
        return soundClass;
    }
  }
}