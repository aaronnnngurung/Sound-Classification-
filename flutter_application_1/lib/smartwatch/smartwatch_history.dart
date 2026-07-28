import 'dart:async';
import 'package:flutter/material.dart';
import '../smartwatch/watch_sync_service.dart';

class SmartwatchHistoryScreen extends StatefulWidget {
  final List<EmergencyAlert> initialHistory;

  const SmartwatchHistoryScreen({Key? key, required this.initialHistory})
    : super(key: key);

  @override
  State<SmartwatchHistoryScreen> createState() =>
      _SmartwatchHistoryScreenState();
}

class _SmartwatchHistoryScreenState extends State<SmartwatchHistoryScreen> {
  late List<EmergencyAlert> _history;
  StreamSubscription<EmergencyAlert>? _alertSub;

  @override
  void initState() {
    super.initState();
    _history = List.of(widget.initialHistory);

    // Subscribes independently so a new alert arriving WHILE this
    // screen is open shows up immediately, instead of only appearing
    // after backing out and reopening History.
    _alertSub = WatchSyncService.instance.alertStream.listen((alert) {
      if (mounted) setState(() => _history.insert(0, alert));
    });
  }

  @override
  void dispose() {
    _alertSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fraction of screen width, not a flat pixel value — so this holds
    // up across round profiles instead of just whatever emulator this
    // was tuned against.
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    final horizontalInset = shortestSide * 0.14;

    return Scaffold(
      backgroundColor: Colors.black,
      // NOTE: no `appBar:` here on purpose. A standard AppBar
      // auto-places its back button in the literal top-left corner —
      // exactly where a round bezel clips content or makes it
      // untappable. _buildHeader below puts back-button + title as one
      // centered row instead.
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: _history.isEmpty
                  ? const Center(
                      child: Text(
                        'No alerts yet',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalInset,
                        vertical: 4,
                      ),
                      itemCount: _history.length,
                      itemBuilder: (context, index) {
                        final alert = _history[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                _iconFor(alert.soundClass),
                                color: Colors.redAccent,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _friendlyName(alert.soundClass),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      _formatTime(alert.timestamp),
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${(alert.confidence * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: const Padding(
              // Extra invisible tap padding — the icon itself is small
              // on purpose (round-safe), but the tap target shouldn't be.
              padding: EdgeInsets.all(8),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white70,
                size: 14,
              ),
            ),
          ),
          const Text(
            'History',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          // Balances the back button's width so the title stays
          // visually centered on the row instead of drifting right.
          const SizedBox(width: 30),
        ],
      ),
    );
  }

  IconData _iconFor(String soundClass) {
    switch (soundClass) {
      case 'siren':
        return Icons.emergency_rounded;
      case 'crying_baby':
        return Icons.child_care_rounded;
      case 'door_wood_knock':
        return Icons.door_front_door_rounded;
      case 'glass_breaking':
        return Icons.crisis_alert_rounded;
      case 'fireworks':
        return Icons.celebration_rounded;
      case 'car_horn':
        return Icons.directions_car_rounded;
      default:
        return Icons.warning_rounded;
    }
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

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }
}