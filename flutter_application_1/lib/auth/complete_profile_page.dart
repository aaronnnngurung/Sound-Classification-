import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/dashboard/main_screen.dart';
import 'package:flutter_application_1/guardian/guardian_main_screen.dart';

class CompleteProfilePage extends StatefulWidget {
  final String uid;
  final String email;
  final String defaultName;

  const CompleteProfilePage({
    Key? key,
    required this.uid,
    required this.email,
    required this.defaultName,
  }) : super(key: key);

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _guardianCodeController = TextEditingController();

  String _selectedRole = 'deaf'; // Default selection
  bool _isLoading = false;

  static const Color _primaryColor = Color(0xFF5B7CFA);
  static const Color _surfaceColor = Colors.white;
  static const Color _backgroundColor = Color(0xFFF8FAFC);
  static const Color _borderColor = Color(0xFFE2E8F0);
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.defaultName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _guardianCodeController.dispose();
    super.dispose();
  }

  // Generate unique Guardian Code for Deaf users
  String _generateGuardianCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List.generate(8, (index) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final String username = _nameController.text.trim();
      final String phone = _phoneController.text.trim();

      // Validate Guardian Link Code if registering as a Guardian
      String? deafUserUid;

      if (_selectedRole == 'guardian') {
        final codeSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where(
              'guardianCode',
              isEqualTo: _guardianCodeController.text.trim().toUpperCase(),
            )
            .limit(1)
            .get();

        if (codeSnapshot.docs.isEmpty) {
          throw Exception('Invalid Guardian Link Code');
        }

        deafUserUid = codeSnapshot.docs.first.id;

        final existingLink = await FirebaseFirestore.instance
            .collection('guardian_links')
            .doc(deafUserUid)
            .get();

        if (existingLink.exists) {
          throw Exception(
            'This Deaf User already has a connected Guardian.',
          );
        }
      }

      final String? guardianCode =
          _selectedRole == 'deaf' ? _generateGuardianCode() : null;

      Map<String, dynamic> userData = {
        'uid': widget.uid,
        'email': widget.email,
        'username': username,
        'phoneNumber': phone.isEmpty ? 'Not set' : phone,
        'role': _selectedRole,
        'createdAt': FieldValue.serverTimestamp(),
        if (guardianCode != null) 'guardianCode': guardianCode,
      };

      // Save user record to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .set(userData, SetOptions(merge: true));

      // Create guardian link document if registering as a Guardian
      if (_selectedRole == 'guardian' && deafUserUid != null) {
        await FirebaseFirestore.instance
            .collection('guardian_links')
            .doc(deafUserUid)
            .set({
          'deafUserUid': deafUserUid,
          'guardianUid': widget.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        // Pop up the Guardian Link Code for Deaf users, just like the signup page
        if (_selectedRole == 'deaf' && guardianCode != null) {
          await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) {
              return AlertDialog(
                title: const Text('Profile Completed'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your Guardian Link Code'),
                    const SizedBox(height: 12),
                    SelectableText(
                      guardianCode,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Share this code with your Guardian to connect accounts.',
                    ),
                  ],
                ),
                actions: [
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: guardianCode),
                      );

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Guardian Code copied')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Copy Code'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Continue'),
                  ),
                ],
              );
            },
          );
        }

        if (!mounted) return;

        // Redirect straight to the navigation bar homepage for the selected role
        if (_selectedRole == 'guardian') {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const GuardianMainScreen()),
            (route) => false,
          );
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const MainScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Complete Your Profile', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'One last step! 🚀',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _textPrimary),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Please select your account type and confirm your details to continue.',
                  style: TextStyle(fontSize: 14, color: _textSecondary),
                ),
                const SizedBox(height: 28),

                // Name Field
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name / Username',
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    filled: true,
                    fillColor: _surfaceColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please enter your name' : null,
                ),
                const SizedBox(height: 16),

                // Phone Field (Deaf / Hard of Hearing User)
                if (_selectedRole == 'deaf') ...[
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number (Optional)',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      filled: true,
                      fillColor: _surfaceColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Guardian Link Code Field (Guardian)
                if (_selectedRole == 'guardian') ...[
                  TextFormField(
                    controller: _guardianCodeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Enter Guardian Link Code',
                      prefixIcon: const Icon(Icons.vpn_key_outlined),
                      filled: true,
                      fillColor: _surfaceColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Please enter the Guardian Link Code' : null,
                  ),
                  const SizedBox(height: 16),
                ],

                const SizedBox(height: 12),

                // Role Selection Cards
                const Text(
                  'SELECT YOUR ROLE',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _textSecondary, letterSpacing: 1.1),
                ),
                const SizedBox(height: 12),

                _buildRoleOption(
                  roleValue: 'deaf',
                  title: 'Deaf / Hard of Hearing User',
                  subtitle: 'Use real-time sound classification & connect with a guardian for safety.',
                  icon: Icons.hearing_rounded,
                ),
                const SizedBox(height: 12),

                _buildRoleOption(
                  roleValue: 'guardian',
                  title: 'Guardian',
                  subtitle: 'Monitor emergency notifications & alerts from a connected user.',
                  icon: Icons.shield_outlined,
                ),

                const SizedBox(height: 36),

                // Submit Button
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Complete Setup', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleOption({
    required String roleValue,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedRole == roleValue;

    return InkWell(
      onTap: () => setState(() => _selectedRole = roleValue),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _primaryColor : _borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? _primaryColor.withOpacity(0.12) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isSelected ? _primaryColor : _textSecondary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? _primaryColor : _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: _textSecondary, height: 1.3)),
                ],
              ),
            ),
            Radio<String>(
              value: roleValue,
              groupValue: _selectedRole,
              activeColor: _primaryColor,
              onChanged: (val) {
                if (val != null) setState(() => _selectedRole = val);
              },
            ),
          ],
        ),
      ),
    );
  }
}