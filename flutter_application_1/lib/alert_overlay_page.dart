import 'package:flutter/material.dart';

class AlertOverlayPage extends StatefulWidget {
  final String soundClass;
  final bool isEmergency;

  const AlertOverlayPage({
    super.key,
    required this.soundClass,
    required this.isEmergency,
  });

  @override
  State<AlertOverlayPage> createState() => _AlertOverlayPageState();
}

class _AlertOverlayPageState extends State<AlertOverlayPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;

  // Custom colors matching your project identity
  static const Color emergencyColor = Color(
    0xFFD90429,
  ); // High visibility flashing red
  static const Color standardColor = Color(
    0xFF1B4D8F,
  ); // High visibility tracking blue

  @override
  void initState() {
    super.initState();
    // Initialize a repeating animation to strobe/flash the background color for emergency attention
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color baseThemeColor = widget.isEmergency ? emergencyColor : standardColor;

    return Scaffold(
      backgroundColor: Colors.black, // Stark background contrast
      body: AnimatedBuilder(
        animation: _blinkController,
        builder: (context, child) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            // Smoothly animate between bright theme alert color and darker safe shade
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  baseThemeColor.withValues(
                    alpha: 0.4 + (_blinkController.value * 0.5),
                  ),
                  Colors.black,
                ],
                radius: 1.2,
              ),
              border: Border.all(
                color: widget.isEmergency
                    ? emergencyColor.withValues(alpha: _blinkController.value)
                    : standardColor.withValues(alpha: _blinkController.value),
                width: 12,
              ),
            ),
            child: child,
          );
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 40.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top alert status banner indication
                Column(
                  children: [
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: baseThemeColor.withValues(alpha: 0.2),
                      ),
                      child: Icon(
                        widget.isEmergency
                            ? Icons.warning_amber_rounded
                            : Icons.hearing_rounded,
                        size: 90,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      widget.isEmergency ? 'CRITICAL ALERT' : 'SOUND DETECTED',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                        color: widget.isEmergency
                            ? const Color(0xFFFFCCD5)
                            : const Color(0xFFE8F0FE),
                      ),
                    ),
                  ],
                ),

                // Core Classified Target Name Output Section
                Column(
                  children: [
                    Text(
                      widget.soundClass.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.5,
                        shadows: const [
                          Shadow(
                            blurRadius: 10.0,
                            color: Colors.black,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.isEmergency
                          ? 'High-priority environmental security threat risk verified nearby. Check your physical surroundings immediately!'
                          : 'An environmental sound wave match has been captured by the local mic array classifier.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[300],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),

                // Dismiss action alignment button layout
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(60),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 5,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'DISMISS ALERT',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
