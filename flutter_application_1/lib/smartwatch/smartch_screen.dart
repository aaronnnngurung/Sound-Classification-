import 'dart:async';
import 'package:flutter/material.dart';
import '../smartwatch/watch_sync_service.dart';
import '../smartwatch/smartwatch_history.dart';

class SmartwatchScreen extends StatefulWidget {
  const SmartwatchScreen({Key? key}) : super(key: key);

  @override
  State<SmartwatchScreen> createState() => _SmartwatchScreenState();
}

class _SmartwatchScreenState extends State<SmartwatchScreen>
    with SingleTickerProviderStateMixin {
  bool _isConnected = false;
  EmergencyAlert? _activeAlert;
  final List<EmergencyAlert> _history = [];

  late final AnimationController _pulseController;
  StreamSubscription<EmergencyAlert>? _alertSub;
  StreamSubscription<bool>? _connectionSub;

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
  }

  @override
  void dispose() {
    _alertSub?.cancel();
    _connectionSub?.cancel();
    _pulseController.dispose();
    super.dispose();
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: alert != null
            ? _buildEmergencyState(alert)
            : _buildMonitoringState(),
      ),
    );
  }

  Widget _buildMonitoringState() {
    // NOTE: the spec listed both "Monitoring..." and "Connected to
    // Phone" as example status text without saying which state each
    // belongs to. Assumed here: connected -> "Monitoring..." (primary
    // line) + "Connected to phone" (secondary line); not connected ->
    // "Not Connected" + "Waiting for phone...". Swap below if you meant
    // it the other way.
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
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
              size: 48,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _isConnected ? 'Monitoring...' : 'Not Connected',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            _isConnected ? 'Connected to phone' : 'Waiting for phone...',
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.white70),
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
            style: TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyState(EmergencyAlert alert) {
    return Container(
      color: Colors.red[900],
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
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
                  size: 56,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _friendlyName(alert.soundClass).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                '${(alert.confidence * 100).toStringAsFixed(0)}% confidence',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
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