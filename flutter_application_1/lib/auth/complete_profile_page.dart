import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
      
      Map<String, dynamic> userData = {
        'uid': widget.uid,
        'email': widget.email,
        'username': username,
        'phoneNumber': phone.isEmpty ? 'Not set' : phone,
        'role': _selectedRole,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Add Guardian Code only if registering as a Deaf User
      if (_selectedRole == 'deaf') {
        userData['guardianCode'] = _generateGuardianCode();
      }

      // Save user record to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .set(userData, SetOptions(merge: true));

      if (mounted) {
        // Redirect to the correct homepage according to selected role
        if (_selectedRole == 'guardian') {
          Navigator.of(context).pushNamedAndRemoveUntil('/guardianHome', (route) => false);
        } else {
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
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

                // Phone Field
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
                const SizedBox(height: 28),

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