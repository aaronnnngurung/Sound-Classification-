import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:flutter/services.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({Key? key}) : super(key: key);

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emergencyPhoneController = TextEditingController();
  final TextEditingController _guardianCodeController = TextEditingController();

  String _selectedRole = 'deaf'; // Default role selection

  bool _isLoading = false;
  bool _obscurePassword = true;

  // Animation Controllers
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // 2026 Material 3 Design Tokens
  static const Color _primaryColor = Color(0xFF5B7CFA);
  static const Color _surfaceColor = Colors.white;
  static const Color _backgroundColor = Color(0xFFF8FAFC);
  static const Color _inputBgColor = Color(0xFFF1F5F9);
  static const Color _borderColor = Color(0xFFE2E8F0);
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    // Entrance Animations
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _animController.forward();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _emergencyPhoneController.dispose();
    _guardianCodeController.dispose();
    _animController.dispose();
    
    super.dispose();
  }

  // Fast Native Internet Connectivity Check
  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  String _generateGuardianCode(){
    final random = Random.secure();
    final number = 100000 + random.nextInt(9000000);
    return 'DG$number';
  }

  Future<void> _handleSignUp() async {
    if (_usernameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        
        (_selectedRole == 'deaf' && 
        _emergencyPhoneController.text.trim().isEmpty) ||
        
        //this prevents the guardian account from being submitted without a code. 
  
         (_selectedRole == 'guardian' && 
         _guardianCodeController.text.trim().isEmpty)){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check Internet First
    bool isConnected = await _hasInternetConnection();
    if (!isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No internet connection. Please connect to the internet to proceed.'),
            backgroundColor: Color(0xFFDC2626),
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      //this code checks if the code belongs to an existing deaf user.   
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
          throw Exception('Invalid Guardian Code');
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

      // 1. Create Credentials
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      String uid = userCredential.user!.uid;

      final String? guardianCode = 
      _selectedRole == 'deaf' ? _generateGuardianCode(): null;

      // 2. Write to Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'username': _usernameController.text.trim(),
        'email': _emailController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'emergencyContact': _emergencyPhoneController.text.trim(),
        'createdAt': DateTime.now(),
        'role': _selectedRole,
        if (guardianCode !=null) 'guardianCode': guardianCode,
      });

      //creates one link document whose ID is the Deaf User's UID   
      if (_selectedRole == 'guardian' && deafUserUid != null) {
      await FirebaseFirestore.instance
          .collection('guardian_links')
          .doc(deafUserUid)
          .set({
        'deafUserUid': deafUserUid,
        'guardianUid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
}

if (mounted) {
  if (_selectedRole == 'deaf' && guardianCode != null) {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Registration Successful'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your Guardian Code'),
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

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Sign up failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Database submission error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Ambient Mesh Gradient & Soft Glowing Background Orbs
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFEEF2FF),
                  Color(0xFFF8FAFC),
                  Color(0xFFE0E7FF),
                ],
              ),
            ),
          ),
          Positioned(
            top: -40,
            left: -50,
            child: _GlowOrb(size: 250, color: _primaryColor, opacity: 0.14),
          ),
          Positioned(
            bottom: -60,
            right: -60,
            child: _GlowOrb(size: 320, color: const Color(0xFF818CF8), opacity: 0.16),
          ),

          // Content with Entrance Animation
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: constraints.maxHeight < 700 ? 12.0 : 24.0,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: SlideTransition(
                          position: _slideAnim,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Standout Hero Logo
                              const Center(child: _AppLogo(size: 76)),
                              const SizedBox(height: 22),

                              // Header Titles
                              const Text(
                                'Create Account',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: _textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Join SoundClass to get started',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: _textSecondary,
                                ),
                              ),
                              const SizedBox(height: 28),

                              // Form Container Card
                              Container(
                                decoration: BoxDecoration(
                                  color: _surfaceColor,
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(color: _borderColor, width: 1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF0F172A).withOpacity(0.04),
                                      blurRadius: 24,
                                      offset: const Offset(0, 12),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [

                                    const Text(
                                    'Register as',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  DropdownButtonFormField<String>(
                                    value: _selectedRole,
                                    isExpanded: true,
                                    borderRadius: BorderRadius.circular(20),
                                    dropdownColor: _surfaceColor,
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: _textSecondary,
                                    ),
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(
                                        Icons.person_outline_rounded,
                                        color: _textSecondary,
                                        size: 20,
                                      ),
                                      filled: true,
                                      fillColor: _inputBgColor,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 18,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(20),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(20),
                                        borderSide: const BorderSide(color: _borderColor, width: 1),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(20),
                                        borderSide: const BorderSide(color: _primaryColor, width: 1.5),
                                      ),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'deaf',
                                        child: Text('Deaf User'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'guardian',
                                        child: Text('Guardian'),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() => _selectedRole = value);
                                      }
                                    },
                                  ),

                                  const SizedBox(height: 16),

                                  const SizedBox(height: 16),
                                    // Username
                                    _buildInputField(
                                      controller: _usernameController,
                                      label: 'Username',
                                      icon: Icons.person_outline_rounded,
                                    ),
                                    const SizedBox(height: 16),

                                    // Email
                                    _buildInputField(
                                      controller: _emailController,
                                      label: 'Email address',
                                      icon: Icons.mail_outline_rounded,
                                      keyboardType: TextInputType.emailAddress,
                                    ),
                                    const SizedBox(height: 16),

                                    // Password
                                    _buildInputField(
                                      controller: _passwordController,
                                      label: 'Password',
                                      icon: Icons.lock_outline_rounded,
                                      obscureText: _obscurePassword,
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                          color: _textSecondary,
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _obscurePassword = !_obscurePassword;
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Phone Number
                                    _buildInputField(
                                      controller: _phoneController,
                                      label: 'Phone Number',
                                      icon: Icons.phone_outlined,
                                      keyboardType: TextInputType.phone,
                                    ),
                                    const SizedBox(height: 16),

                                    //Guardian Code 
                                    if (_selectedRole == 'guardian') ...[

                                      _buildInputField(
                                        controller: _guardianCodeController,
                                        label: 'Guardian Code',
                                        icon: Icons.vpn_key_outlined,
                                        keyboardType: TextInputType.text,
                                  
                                      ),

                                      const SizedBox(height: 16),

                                    ],

                                    // Emergency Contact Number

                                    if (_selectedRole == 'deaf') ...[
                                      _buildInputField(
                                        controller: _emergencyPhoneController,
                                        label: 'Emergency Contact Number',
                                        icon: Icons.emergency_outlined,
                                        keyboardType: TextInputType.phone,
                                      ),
                                      const SizedBox(height: 24),
                                    ] else ...[
                                      const SizedBox(height: 24),
                                    ],
                                    
                                    // Submit Button
                                    SizedBox(
                                      height: 52,
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : _handleSignUp,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _primaryColor,
                                          foregroundColor: Colors.white,
                                          disabledBackgroundColor: _primaryColor.withOpacity(0.6),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                        ).copyWith(
                                          overlayColor: MaterialStateProperty.all(
                                            Colors.white.withOpacity(0.08),
                                          ),
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                ),
                                              )
                                            : const Text(
                                                'Create Account',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Already have account
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Already have an account? ',
                                    style: TextStyle(
                                      color: _textSecondary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: const Text(
                                      'Sign In',
                                      style: TextStyle(
                                        color: _primaryColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: _textPrimary, fontSize: 15),
      cursorColor: _primaryColor,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textSecondary, fontSize: 14),
        prefixIcon: Icon(icon, color: _textSecondary, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: _inputBgColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: _borderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: _primaryColor, width: 1.5),
        ),
      ),
    );
  }
}

/// Soft glowing background orb used to add ambient depth without a heavy gradient.
/// Mirrors the widget used on the login page for visual consistency across the flow.
class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _GlowOrb({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withOpacity(opacity),
              color.withOpacity(0.0),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hero logo tile shared (visually) with the Login page.
/// Wrapped in a subtle gradient ring + layered shadow so it stands out
/// as the visual anchor of the screen without relying on bright color.
class _AppLogo extends StatelessWidget {
  final double size;

  const _AppLogo({this.size = 92});

  static const Color _primaryColor = Color(0xFF5B7CFA);

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'app_logo',
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF818CF8),
              _primaryColor,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withOpacity(0.28),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(16.0),
          child: Image.asset(
            'assets/logo.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}