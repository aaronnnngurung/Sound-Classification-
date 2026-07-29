import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'emergency.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;

  // PB-011 — Power save mode toggle
  bool _powerSaveMode = false;

  // Camera flash alert toggle
  bool _cameraFlashAlert = false;

  // PB-012 — Mic conflict notification toggle
  bool _micConflictAlert = true;

  // FR-11 — Emergency Mode: restricts alerts to safety-critical sounds
  // only (see EmergencyModeService.safetyCriticalClasses — siren, by
  // current product decision), suppressing alerts for routine sounds.
  // Source of truth lives in EmergencyModeService (SharedPreferences),
  // NOT just this local field — the background foreground-service
  // isolate reads it directly from there on every detection, since an
  // in-memory bool here wouldn't be visible to that isolate at all.
  bool _emergencyMode = false;

  // Sensitivity slider (maps to confidence threshold)
  double _sensitivity = 0.85;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Load saved settings from Firestore
  Future<void> _loadSettings() async {
    if (_user == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedFlash = prefs.getBool('cameraFlashAlert');
      if (savedFlash != null && mounted) {
        setState(() => _cameraFlashAlert = savedFlash);
      }

      // Emergency Mode's local (per-device) value is authoritative,
      // same pattern as cameraFlashAlert above — only fall back to
      // whatever's in Firestore if this device has never set it.
      final savedEmergencyMode = await EmergencyModeService.getStoredValue();
      if (savedEmergencyMode != null && mounted) {
        setState(() => _emergencyMode = savedEmergencyMode);
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .collection('settings')
          .doc('preferences')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _powerSaveMode = data['powerSaveMode'] ?? false;
          _micConflictAlert = data['micConflictAlert'] ?? true;
          _sensitivity = (data['sensitivity'] ?? 0.85).toDouble();
          if (savedFlash == null) {
            _cameraFlashAlert = data['cameraFlashAlert'] ?? false;
          }
          if (savedEmergencyMode == null) {
            _emergencyMode = data['emergencyMode'] ?? false;
          }
        });

        // This device had never set Emergency Mode locally, so we just
        // pulled it from Firestore instead — write it back into
        // SharedPreferences so the background isolate (which only ever
        // reads local storage, never Firestore) actually sees it.
        if (savedEmergencyMode == null) {
          await EmergencyModeService.setEnabled(_emergencyMode);
        }
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  // Save settings to Firestore
  Future<void> _saveSettings() async {
    if (_user == null) return;
    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .collection('settings')
          .doc('preferences')
          .set({
            'powerSaveMode': _powerSaveMode,
            'micConflictAlert': _micConflictAlert,
            'cameraFlashAlert': _cameraFlashAlert,
            'emergencyMode': _emergencyMode,
            'sensitivity': _sensitivity,
            'updatedAt': DateTime.now().toIso8601String(),
          }, SetOptions(merge: true));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('cameraFlashAlert', _cameraFlashAlert);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // FR-11 — flips Emergency Mode immediately (not gated behind the
  // "Save Settings" button) because it needs to take effect right away
  // for the background detection isolate, which reads
  // EmergencyModeService's SharedPreferences-backed value directly.
  // Firestore sync for this field still happens on the normal Save flow.
  Future<void> _onEmergencyModeChanged(bool val) async {
    setState(() => _emergencyMode = val);
    await EmergencyModeService.setEnabled(val);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            val
                ? 'Emergency Mode on — only sirens will alert you now'
                : 'Emergency Mode off — all emergency sounds will alert you',
          ),
          backgroundColor: val ? Colors.red[600] : Colors.grey[700],
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Edit profile details
  Future<void> _updateProfile() async {
    final usernameController = TextEditingController();
    final phoneController = TextEditingController();
    final emergencyController = TextEditingController();

    // Pre-fill with current values
    if (_user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        usernameController.text = data['username'] ?? '';
        phoneController.text = data['phoneNumber'] ?? '';
        emergencyController.text = data['emergencyContact'] ?? '';
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField(
                controller: usernameController,
                label: 'Username',
                icon: Icons.person_rounded,
              ),
              const SizedBox(height: 12),
              _buildDialogField(
                controller: phoneController,
                label: 'Phone Number',
                icon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _buildDialogField(
                controller: emergencyController,
                label: 'Emergency Contact',
                icon: Icons.emergency_rounded,
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(_user!.uid)
                    .update({
                      'username': usernameController.text.trim(),
                      'phoneNumber': phoneController.text.trim(),
                      'emergencyContact': emergencyController.text.trim(),
                    });
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Update failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Emergency Mode — placed first/prominently since it's a
            // safety-critical system setting, and visually flagged (red
            // accent) when active so it's obvious at a glance.
            _buildSectionHeader('EMERGENCY MODE'),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _emergencyMode ? Colors.red[50] : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _emergencyMode ? Colors.red[300]! : Colors.transparent,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _buildToggleTile(
                icon: Icons.emergency_share_rounded,
                iconColor: Colors.red[600]!,
                title: 'Emergency Mode',
                subtitle:
                    'Only alert for safety-critical sounds (siren). '
                    'Routine sounds like knocking, fireworks, glass '
                    'breaking, a crying baby, or a car horn stay '
                    'silent — no vibration, flash, or notification — '
                    'while this is on.',
                value: _emergencyMode,
                onChanged: _onEmergencyModeChanged,
              ),
            ),

            const SizedBox(height: 20),

            // Detection Settings
            _buildSectionHeader('DETECTION SETTINGS'),
            const SizedBox(height: 10),
            _buildSettingsCard([
              // Sensitivity slider
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            color: Colors.blue[600],
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Detection Sensitivity',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${(_sensitivity * 100).toInt()}%',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Minimum confidence required to trigger an alert',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  Slider(
                    value: _sensitivity,
                    min: 0.60,
                    max: 0.99,
                    divisions: 39,
                    activeColor: Colors.blue[600],
                    onChanged: (val) => setState(() => _sensitivity = val),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '60% (More alerts)',
                        style: TextStyle(color: Colors.grey[400], fontSize: 10),
                      ),
                      Text(
                        '99% (Fewer alerts)',
                        style: TextStyle(color: Colors.grey[400], fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),

              const Divider(height: 24),

              // Camera flash alerts
              _buildToggleTile(
                icon: Icons.flash_on,
                iconColor: Colors.purple[600]!,
                title: 'Camera Flash Alerts',
                subtitle: 'Blink camera flashlight on urgent sound triggers.',
                value: _cameraFlashAlert,
                onChanged: (val) => setState(() => _cameraFlashAlert = val),
              ),

              const Divider(height: 24),

              // Power save mode (PB-011)
              _buildToggleTile(
                icon: Icons.battery_saver_rounded,
                iconColor: Colors.green[600]!,
                title: 'Power Save Mode',
                subtitle: 'Reduces detection frequency to preserve battery',
                value: _powerSaveMode,
                onChanged: (val) => setState(() => _powerSaveMode = val),
              ),

              const Divider(height: 24),

              // Mic conflict notification (PB-012)
              _buildToggleTile(
                icon: Icons.mic_off_rounded,
                iconColor: Colors.orange[600]!,
                title: 'Microphone Conflict Alerts',
                subtitle: 'Notify when another app is using the microphone',
                value: _micConflictAlert,
                onChanged: (val) => setState(() => _micConflictAlert = val),
              ),
            ]),

            const SizedBox(height: 20),

            //  Account Settings
            _buildSectionHeader('ACCOUNT'),
            const SizedBox(height: 10),
            _buildSettingsCard([
              _buildActionTile(
                icon: Icons.person_rounded,
                iconColor: Colors.blue[600]!,
                title: 'Edit Profile',
                subtitle: _user?.email ?? '',
                onTap: _updateProfile,
              ),
              const Divider(height: 24),
              _buildActionTile(
                icon: Icons.lock_reset_rounded,
                iconColor: Colors.purple[600]!,
                title: 'Change Password',
                subtitle: 'Send a password reset link to your email',
                onTap: () async {
                  if (_user?.email != null) {
                    await FirebaseAuth.instance.sendPasswordResetEmail(
                      email: _user!.email!,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Reset link sent to your email'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                },
              ),
            ]),

            const SizedBox(height: 20),

            // About
            _buildSectionHeader('ABOUT'),
            const SizedBox(height: 10),
            _buildSettingsCard([
              _buildActionTile(
                icon: Icons.info_rounded,
                iconColor: Colors.teal[600]!,
                title: 'App Version',
                subtitle: 'v1.0.0 — Group 41 Capstone Project',
                onTap: () {},
              ),
              const Divider(height: 24),
              _buildActionTile(
                icon: Icons.privacy_tip_rounded,
                iconColor: Colors.indigo[600]!,
                title: 'Privacy Policy',
                subtitle: 'All audio processed on-device. Nothing uploaded.',
                onTap: () {},
              ),
            ]),

            const SizedBox(height: 28),

            // Save Button
            ElevatedButton(
              onPressed: _isSaving ? null : _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Save Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.grey[500],
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.blue[600],
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
        ],
      ),
    );
  }
}
