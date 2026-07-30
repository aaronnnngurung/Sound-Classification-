import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/utils/emergency.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;

  // 2026 Material 3 Shared Palette (matching DetectionDashboard)
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
  static const Color _inputBgColor = Color(0xFFF1F5F9);

  // PB-011 — Power save mode toggle
  bool _powerSaveMode = false;

  // Camera flash alert toggle
  bool _cameraFlashAlert = false;

  // PB-012 — Mic conflict notification toggle
  bool _micConflictAlert = true;

  // FR-11 — Emergency Mode
  bool _emergencyMode = false;

  // Sensitivity slider (maps to confidence threshold)
  double _sensitivity = 0.85;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Load saved settings from Firestore & Local Storage
  Future<void> _loadSettings() async {
    if (_user == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedFlash = prefs.getBool('cameraFlashAlert');
      if (savedFlash != null && mounted) {
        setState(() => _cameraFlashAlert = savedFlash);
      }

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
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text('Settings saved successfully'),
              ],
            ),
            backgroundColor: _activeGreenDeep,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: _dangerRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Immediate toggle for Emergency Mode (gated isolate synchronization)
  Future<void> _onEmergencyModeChanged(bool val) async {
    setState(() => _emergencyMode = val);
    await EmergencyModeService.setEnabled(val);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            val
                ? 'Emergency Mode ON — sirens only'
                : 'Emergency Mode OFF — all emergency sounds active',
          ),
          backgroundColor: val ? _dangerRed : _textSecondary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Edit profile dialog logic
  Future<void> _updateProfile() async {
    final usernameController = TextEditingController();
    final phoneController = TextEditingController();
    final emergencyController = TextEditingController();

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
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.w700, color: _textPrimary),
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
            child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
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
                    SnackBar(
                      content: const Text('Profile updated successfully'),
                      backgroundColor: _activeGreenDeep,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Update failed: $e'),
                      backgroundColor: _dangerRed,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
      style: const TextStyle(fontSize: 14, color: _textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textSecondary, fontSize: 13),
        prefixIcon: Icon(icon, color: _primaryColor, size: 20),
        filled: true,
        fillColor: _inputBgColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
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
                        'Settings ⚙️',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Customize alert thresholds & preferences',
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

          // ── Main Content Area ───────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Emergency Mode Hero Tile
                  _buildSectionHeader('EMERGENCY MODE'),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _emergencyMode ? const Color(0xFFFEF2F2) : _surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _emergencyMode
                            ? _dangerRed.withOpacity(0.4)
                            : _borderColor,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _emergencyMode
                              ? _dangerRed.withOpacity(0.08)
                              : const Color(0xFF0F172A).withOpacity(0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _buildToggleTile(
                      icon: Icons.emergency_share_rounded,
                      iconColor: _dangerRed,
                      title: 'Emergency Mode',
                      subtitle:
                          'Only alert for safety-critical sounds (siren). Routine sounds stay silent while enabled.',
                      value: _emergencyMode,
                      onChanged: _onEmergencyModeChanged,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Detection Settings Card
                  _buildSectionHeader('DETECTION SETTINGS'),
                  const SizedBox(height: 10),
                  _buildSettingsCard([
                    // Sensitivity Slider Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: _primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.tune_rounded,
                                    color: _primaryColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Sensitivity Threshold',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: _textPrimary,
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
                                color: _primaryColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '${(_sensitivity * 100).toInt()}%',
                                style: const TextStyle(
                                  color: _primaryColorDeep,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Minimum AI confidence score needed to trigger audio alerts',
                          style: TextStyle(color: _textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: _primaryColor,
                            inactiveTrackColor: _inputBgColor,
                            thumbColor: _primaryColor,
                            overlayColor: _primaryColor.withOpacity(0.15),
                            trackHeight: 6,
                          ),
                          child: Slider(
                            value: _sensitivity,
                            min: 0.60,
                            max: 0.99,
                            divisions: 39,
                            onChanged: (val) => setState(() => _sensitivity = val),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              '60% (More alerts)',
                              style: TextStyle(color: _textSecondary, fontSize: 10),
                            ),
                            Text(
                              '99% (Fewer alerts)',
                              style: TextStyle(color: _textSecondary, fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const Divider(height: 28, color: _borderColor),

                    // Camera Flash Alert Toggle
                    _buildToggleTile(
                      icon: Icons.flash_on_rounded,
                      iconColor: const Color(0xFF9333EA),
                      title: 'Camera Flash Alerts',
                      subtitle: 'Blink physical LED flash when sound events trigger',
                      value: _cameraFlashAlert,
                      onChanged: (val) => setState(() => _cameraFlashAlert = val),
                    ),

                    const Divider(height: 28, color: _borderColor),

                    // Power Save Mode Toggle
                    _buildToggleTile(
                      icon: Icons.battery_saver_rounded,
                      iconColor: _activeGreen,
                      title: 'Power Save Mode',
                      subtitle: 'Optimizes microphone sampling rate for battery life',
                      value: _powerSaveMode,
                      onChanged: (val) => setState(() => _powerSaveMode = val),
                    ),

                    const Divider(height: 28, color: _borderColor),

                    // Mic Conflict Alert Toggle
                    _buildToggleTile(
                      icon: Icons.mic_off_rounded,
                      iconColor: const Color(0xFFD97706),
                      title: 'Microphone Conflict Alerts',
                      subtitle: 'Notify if another app overrides the active microphone',
                      value: _micConflictAlert,
                      onChanged: (val) => setState(() => _micConflictAlert = val),
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // Account Settings Card
                  _buildSectionHeader('ACCOUNT'),
                  const SizedBox(height: 10),
                  _buildSettingsCard([
                    _buildActionTile(
                      icon: Icons.person_rounded,
                      iconColor: _primaryColor,
                      title: 'Edit Profile Details',
                      subtitle: _user?.email ?? 'Not signed in',
                      onTap: _updateProfile,
                    ),
                    const Divider(height: 28, color: _borderColor),
                    _buildActionTile(
                      icon: Icons.lock_reset_rounded,
                      iconColor: const Color(0xFF9333EA),
                      title: 'Change Password',
                      subtitle: 'Send reset instructions directly to your email',
                      onTap: () async {
                        if (_user?.email != null) {
                          await FirebaseAuth.instance.sendPasswordResetEmail(
                            email: _user!.email!,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Reset link sent to your email'),
                                backgroundColor: _activeGreenDeep,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // About Section Card
                  _buildSectionHeader('ABOUT APP'),
                  const SizedBox(height: 10),
                  _buildSettingsCard([
                    _buildActionTile(
                      icon: Icons.info_rounded,
                      iconColor: const Color(0xFF0D9488),
                      title: 'App Version',
                      subtitle: 'v1.0.0 — Group 41 Capstone Project',
                      onTap: () {},
                    ),
                    const Divider(height: 28, color: _borderColor),
                    _buildActionTile(
                      icon: Icons.privacy_tip_rounded,
                      iconColor: const Color(0xFF4F46E5),
                      title: 'Privacy Policy',
                      subtitle: 'Audio stays strictly local on device. No voice data uploaded.',
                      onTap: () {},
                    ),
                  ]),

                  const SizedBox(height: 32),

                  // Save Settings Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _inputBgColor,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
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
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: _textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 16,
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
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
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
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: _textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: _primaryColor,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
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
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: _textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _textSecondary, size: 22),
          ],
        ),
      ),
    );
  }
}