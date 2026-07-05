import 'package:flutter/material.dart';
import 'permission_service.dart';
import 'wrapper.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({Key? key}) : super(key: key);

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  final PermissionService _permService = PermissionService.instance;

  bool _micGranted = false;
  bool _notifGranted = false;
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    _checkCurrentStatus();
  }

  // Check what is already granted when screen opens
  Future<void> _checkCurrentStatus() async {
    final result = await _permService.checkAll();
    setState(() {
      _micGranted = result.microphoneGranted;
      _notifGranted = result.notificationGranted;
    });
  }

  // Request all permissions at once
  Future<void> _requestPermissions() async {
    setState(() => _isRequesting = true);

    final result = await _permService.checkAll();

    // If permanently denied, send to phone settings
    if (result.microphonePermanentlyDenied ||
        result.notificationPermanentlyDenied) {
      await _showPermanentlyDeniedDialog();
      setState(() => _isRequesting = false);
      return;
    }

    // Request whatever is not yet granted
    await _permService.requestAll();

    // Check again after requesting
    final updated = await _permService.checkAll();
    setState(() {
      _micGranted = updated.microphoneGranted;
      _notifGranted = updated.notificationGranted;
      _isRequesting = false;
    });

    // If both granted, move to the app
    if (updated.allGranted) {
      _proceedToApp();
    }
  }

  // Navigate to main app after permissions granted
  void _proceedToApp() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const Wrapper()));
  }

  // Show dialog when permission is permanently denied
  Future<void> _showPermanentlyDeniedDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.settings_rounded, color: Colors.orange[600]),
            const SizedBox(width: 10),
            const Text(
              'Open Settings',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'You previously denied a required permission.\n\n'
          'Please open your phone Settings and manually '
          'enable:\n\n'
          '• Microphone\n'
          '• Notifications\n\n'
          'under "Permissions" for SoundClass.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Not Now', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _permService.openSettings();
              // Re-check after user comes back from settings
              await _checkCurrentStatus();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool allGranted = _micGranted && _notifGranted;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue[700]!, Colors.blue[400]!],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                const SizedBox(height: 40),

                //  Icon
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    size: 56,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 32),

                //  Title
                const Text(
                  'App Permissions',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'SoundClass needs the following permissions '
                  'to detect sounds and alert you.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.85),
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 40),

                // Permission cards
                _buildPermissionCard(
                  icon: Icons.mic_rounded,
                  title: 'Microphone',
                  description:
                      'Required to listen for and classify '
                      'emergency sounds in real time. '
                      'Audio is processed on-device only — '
                      'nothing is recorded or uploaded.',
                  isGranted: _micGranted,
                  isRequired: true,
                ),

                const SizedBox(height: 14),

                _buildPermissionCard(
                  icon: Icons.notifications_rounded,
                  title: 'Notifications',
                  description:
                      'Required to show visual alerts on '
                      'your screen when an emergency sound '
                      'is detected, even when the app is '
                      'running in the background.',
                  isGranted: _notifGranted,
                  isRequired: true,
                ),

                const SizedBox(height: 40),

                //  Main button
                if (!allGranted)
                  ElevatedButton(
                    onPressed: _isRequesting ? null : _requestPermissions,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue[700],
                      disabledBackgroundColor: Colors.white54,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _isRequesting
                        ? SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.blue[700],
                            ),
                          )
                        : const Text(
                            'Grant Permissions',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),

                // Show continue button when all granted
                if (allGranted) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green[600],
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.white),
                        SizedBox(width: 10),
                        Text(
                          'All permissions granted',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: _proceedToApp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue[700],
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Continue to App',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Skip option (reduced functionality)
                TextButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: const Text(
                          'Limited Functionality',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        content: const Text(
                          'Without microphone permission, '
                          'sound detection will not work.\n\n'
                          'Without notification permission, '
                          'you will not receive alerts.\n\n'
                          'You can grant permissions later '
                          'from Settings.',
                          style: TextStyle(height: 1.5),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Go Back'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _proceedToApp();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[600],
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Skip Anyway'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Text(
                    'Skip for now',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 13,
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    required bool isRequired,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted ? Colors.green[400]! : Colors.white.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon circle
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isGranted
                  ? Colors.green[600]
                  : Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isGranted ? Icons.check_rounded : icon,
              color: Colors.white,
              size: 24,
            ),
          ),

          const SizedBox(width: 16),

          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isRequired) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red[400],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Required',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isGranted ? Colors.green[600] : Colors.orange[700],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isGranted ? '✓ Granted' : '✗ Not granted',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
