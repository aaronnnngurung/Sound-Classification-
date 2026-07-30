import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'forgot_password_page.dart';
import 'signup_page.dart';
import 'complete_profile_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  // Animation Controllers
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // Material 3 Design Tokens
  static const Color _primaryColor = Color(0xFF5B7CFA);
  static const Color _primaryColorDeep = Color(0xFF4A63E0);
  static const Color _surfaceColor = Colors.white;
  static const Color _backgroundColor = Color(0xFFF8FAFC);
  static const Color _inputBgColor = Color(0xFFF1F5F9);
  static const Color _borderColor = Color(0xFFE2E8F0);
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    // Setup Entrance Animations
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
    _emailController.dispose();
    _passwordController.dispose();
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

  // Email/Password Login Function
  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Check Internet First
    bool isConnected = await _hasInternetConnection();
    if (!isConnected) {
      if (mounted) {
        setState(() {
          _errorMessage = "No internet connection. Please connect to the internet and try again.";
          _isLoading = false;
        });
      }
      return;
    }

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? user = userCredential.user;

      if (user != null && mounted) {
        // Fetch user document from Firestore
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        final data = userDoc.data() as Map<String, dynamic>?;

        // If user document is missing or role isn't assigned yet
        if (!userDoc.exists || data == null || data['role'] == null) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => CompleteProfilePage(
                uid: user.uid,
                email: user.email ?? '',
                defaultName: user.displayName ?? '',
              ),
            ),
            (route) => false,
          );
        } else {
          // Route user based on role stored in Firestore
          String role = data['role'];
          if (role == 'guardian') {
            Navigator.of(context).pushNamedAndRemoveUntil('/guardianHome', (route) => false);
          } else {
            Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "An unexpected error occurred: $e";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Google Sign-In Function
  Future<void> signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Check Internet First
    bool isConnected = await _hasInternetConnection();
    if (!isConnected) {
      if (mounted) {
        setState(() {
          _errorMessage = "No internet connection. Please connect to the internet and try again.";
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final googleSignIn = GoogleSignIn.instance;
      final GoogleSignInAccount? googleUser = await googleSignIn.authenticate();

      if (googleUser == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final authClient = googleSignIn.authorizationClient;
      final authorization = await authClient.authorizeScopes(['email', 'profile']);
      final String? accessToken = authorization.accessToken;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: accessToken,
      );

      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null && mounted) {
        // Fetch user document from Firestore
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        final data = userDoc.data() as Map<String, dynamic>?;

        // If user is NEW or HAS NO ROLE, redirect to CompleteProfilePage
        if (!userDoc.exists || data == null || data['role'] == null) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => CompleteProfilePage(
                uid: user.uid,
                email: user.email ?? '',
                defaultName: user.displayName ?? '',
              ),
            ),
            (route) => false,
          );
        } else {
          // User exists and already has a role set -> Redirect based on role
          String role = data['role'];
          if (role == 'guardian') {
            Navigator.of(context).pushNamedAndRemoveUntil('/guardianHome', (route) => false);
          } else {
            Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
          }
        }
      }
    } catch (e) {
      print("Google Sign-In Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Sign-In failed: $e'),
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
            top: -60,
            right: -60,
            child: _GlowOrb(size: 260, color: _primaryColor, opacity: 0.16),
          ),
          Positioned(
            bottom: 40,
            left: -80,
            child: _GlowOrb(size: 300, color: const Color(0xFF818CF8), opacity: 0.14),
          ),

          // Main Screen Content with Fade & Slide Animation
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: constraints.maxHeight < 700 ? 20.0 : 40.0,
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
                              // Hero Logo
                              const Center(child: _AppLogo()),
                              const SizedBox(height: 28),

                              // Header Titles
                              const Text(
                                'SoundClass',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: _textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Classify sounds with ease',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: _textSecondary,
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Login Card Container
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
                                padding: const EdgeInsets.all(28.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const Text(
                                      'Welcome back',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                        color: _textPrimary,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Sign in to access your account',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        color: _textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 24),

                                    // Error Banner
                                    AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 250),
                                      transitionBuilder: (child, animation) => SizeTransition(
                                        sizeFactor: animation,
                                        axisAlignment: -1,
                                        child: FadeTransition(opacity: animation, child: child),
                                      ),
                                      child: _errorMessage != null
                                          ? Padding(
                                              key: const ValueKey('error'),
                                              padding: const EdgeInsets.only(bottom: 20.0),
                                              child: _ErrorBanner(message: _errorMessage!),
                                            )
                                          : const SizedBox.shrink(key: ValueKey('no-error')),
                                    ),

                                    // Email Field
                                    _buildInputField(
                                      controller: _emailController,
                                      label: 'Email address',
                                      icon: Icons.mail_outline_rounded,
                                      keyboardType: TextInputType.emailAddress,
                                    ),
                                    const SizedBox(height: 16),

                                    // Password Field
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
                                    const SizedBox(height: 8),

                                    // Forgot Password Link
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
                                          );
                                        },
                                        style: TextButton.styleFrom(
                                          foregroundColor: _primaryColor,
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: const Text(
                                          'Forgot password?',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),

                                    // Sign In Primary Button
                                    SizedBox(
                                      height: 52,
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : _login,
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
                                                'Sign In',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),

                                    // Divider
                                    Row(
                                      children: const [
                                        Expanded(child: Divider(color: _borderColor, thickness: 1)),
                                        Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 12),
                                          child: Text(
                                            'or continue with',
                                            style: TextStyle(
                                              color: _textSecondary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                        Expanded(child: Divider(color: _borderColor, thickness: 1)),
                                      ],
                                    ),
                                    const SizedBox(height: 20),

                                    // Google Sign In Button
                                    SizedBox(
                                      height: 52,
                                      child: OutlinedButton(
                                        onPressed: _isLoading ? null : signInWithGoogle,
                                        style: OutlinedButton.styleFrom(
                                          backgroundColor: _surfaceColor,
                                          foregroundColor: _textPrimary,
                                          side: const BorderSide(color: _borderColor, width: 1),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Image.asset(
                                              'assets/image.png',
                                              width: 20,
                                              height: 20,
                                            ),
                                            const SizedBox(width: 12),
                                            const Text(
                                              'Sign in with Google',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: _textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 28),

                              // Route to SignUp Page
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    "Don't have an account? ",
                                    style: TextStyle(
                                      color: _textSecondary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const SignUpPage()),
                                      );
                                    },
                                    child: const Text(
                                      'Sign Up',
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

/// Glowing background orb helper widget
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

/// App Logo Widget
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
          padding: const EdgeInsets.all(18.0),
          child: Image.asset(
            'assets/logo.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

/// Error banner widget
class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            color: Color(0xFFDC2626),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}