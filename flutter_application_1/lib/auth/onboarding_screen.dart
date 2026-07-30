// onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../wrapper.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // Controls which page the user is on
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Consent checkbox state on last page
  bool _hasAgreed = false;
  bool _isSaving = false;

  // Total number of pages
  final int _totalPages = 4;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Move to next page
  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  // Move to previous page
  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  // Save consent and proceed to app
  Future<void> _acceptAndContinue() async {
    if (!_hasAgreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please read and check the box to agree before continuing',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Save that user has completed onboarding
      // This means it will never show again
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete', true);
      await prefs.setString('consent_date', DateTime.now().toIso8601String());

      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const Wrapper()));
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          //  Page content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              // Disable swipe — use buttons only
              onPageChanged: (page) => setState(() => _currentPage = page),
              children: [
                _buildPage1(),
                _buildPage2(),
                _buildPage3(),
                _buildPage4(),
              ],
            ),
          ),

          //  Bottom navigation bar
          _buildBottomBar(),
        ],
      ),
    );
  }

  // Page 1: Welcome
  Widget _buildPage1() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue[700]!, Colors.blue[400]!],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.hearing_rounded,
                  size: 62,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'Welcome to\nSoundClass',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'A mobile-based assistive alert system '
                'designed for Deaf and Hard of Hearing '
                '(DHH) individuals.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withOpacity(0.88),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Group 41 — IIMS College',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  //  Page 2: What the app does
  Widget _buildPage2() {
    return Container(
      color: Colors.grey[50],
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Icon(Icons.info_rounded, size: 56, color: Colors.blue[600]),
              const SizedBox(height: 20),
              const Text(
                'How SoundClass Works',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 28),
              _buildFeatureRow(
                icon: Icons.mic_rounded,
                color: Colors.blue[600]!,
                title: 'Real-Time Sound Detection',
                description:
                    'The app listens to your environment '
                    'continuously using your phone microphone '
                    'and classifies sounds using an AI model '
                    'running entirely on your device.',
              ),
              _buildFeatureRow(
                icon: Icons.vibration_rounded,
                color: Colors.purple[600]!,
                title: 'Haptic and Visual Alerts',
                description:
                    'When an emergency sound is detected above '
                    '85% confidence, you receive a vibration '
                    'pattern and a full-screen visual alert '
                    'specific to that sound type.',
              ),
              _buildFeatureRow(
                icon: Icons.wifi_off_rounded,
                color: Colors.green[600]!,
                title: 'Works Fully Offline',
                description:
                    'Sound classification happens on your '
                    'device with no internet connection needed. '
                    'Your audio never leaves your phone.',
              ),
              _buildFeatureRow(
                icon: Icons.history_rounded,
                color: Colors.teal[600]!,
                title: 'Detection History',
                description:
                    'Every detected sound is logged locally '
                    'on your device so you can review what '
                    'sounds were detected while you were busy.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  //  Page 3: Sound categories
  Widget _buildPage3() {
    final sounds = [
      {
        'icon': Icons.emergency_rounded,
        'label': 'Siren',
        'color': Colors.red[600]!,
      },
      {
        'icon': Icons.directions_car_rounded,
        'label': 'Car Horn',
        'color': Colors.amber[700]!,
      },
      {
        'icon': Icons.child_care_rounded,
        'label': 'Baby Crying',
        'color': Colors.orange[600]!,
      },
      {
        'icon': Icons.local_fire_department_rounded,
        'label': 'Fire Alarm',
        'color': Colors.deepOrange[600]!,
      },
      {
        'icon': Icons.crisis_alert_rounded,
        'label': 'Glass Breaking',
        'color': Colors.purple[600]!,
      },
      {
        'icon': Icons.door_front_door_rounded,
        'label': 'Knocking',
        'color': Colors.brown[600]!,
      },
    ];

    return Container(
      color: Colors.grey[50],
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Icon(
                Icons.spatial_audio_rounded,
                size: 56,
                color: Colors.blue[600],
              ),
              const SizedBox(height: 20),
              const Text(
                'Detectable Sounds',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'SoundClass can detect and alert you to '
                'these 9 sound categories',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: sounds.length,
                  itemBuilder: (ctx, i) {
                    final s = sounds[i];
                    final color = s['color'] as Color;
                    return Container(
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(s['icon'] as IconData, color: color, size: 30),
                          const SizedBox(height: 8),
                          Text(
                            s['label'] as String,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: color,
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
      ),
    );
  }

  //  Page 4: Privacy consent
  Widget _buildPage4() {
    return Container(
      color: Colors.grey[50],
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Icon(
                  Icons.privacy_tip_rounded,
                  size: 56,
                  color: Colors.indigo[600],
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Audio Monitoring Consent',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Please read carefully before proceeding',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ),
              const SizedBox(height: 24),

              // Consent points
              _buildConsentPoint(
                number: '1',
                title: 'No Audio Storage',
                content:
                    'Raw audio is processed in device '
                    'memory and discarded immediately after '
                    'classification (less than 200ms retention). '
                    'No audio is ever saved to your phone or '
                    'uploaded anywhere.',
              ),
              _buildConsentPoint(
                number: '2',
                title: 'Fully Offline Processing',
                content:
                    'Sound analysis takes place entirely '
                    'on your device. No internet connection '
                    'is required for sound detection to work.',
              ),
              _buildConsentPoint(
                number: '3',
                title: 'Minimal Metadata Only',
                content:
                    'Only minimal metadata is stored locally: '
                    'sound type detected, confidence score, '
                    'and timestamp. This is saved to your '
                    'device for your personal history log.',
              ),
              _buildConsentPoint(
                number: '4',
                title: 'Microphone Indicator',
                content:
                    'A visible listening indicator is shown '
                    'on the dashboard whenever the microphone '
                    'is active. You can stop detection at '
                    'any time using the Stop button.',
              ),
              _buildConsentPoint(
                number: '5',
                title: 'Full User Control',
                content:
                    'You can stop monitoring at any time, '
                    'clear your detection history, and '
                    'revoke microphone permission from '
                    'your phone Settings at any time.',
              ),

              const SizedBox(height: 24),

              // Consent checkbox
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _hasAgreed ? Colors.green[50] : Colors.orange[50],
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _hasAgreed
                        ? Colors.green[300]!
                        : Colors.orange[300]!,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _hasAgreed,
                      onChanged: (val) =>
                          setState(() => _hasAgreed = val ?? false),
                      activeColor: Colors.green[600],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'I have read and understood '
                          'the above information. I agree '
                          'that this app processes sound '
                          'locally on my device and I '
                          'consent to use it responsibly.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[800],
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Accept button
              ElevatedButton(
                onPressed: _isSaving ? null : _acceptAndContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hasAgreed
                      ? Colors.blue[600]
                      : Colors.grey[400],
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: _hasAgreed ? 2 : 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _hasAgreed
                            ? 'I Agree — Continue to App'
                            : 'Please check the box above',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),

              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  // Bottom navigation bar
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          if (_currentPage > 0)
            TextButton(
              onPressed: _prevPage,
              child: Row(
                children: [
                  Icon(
                    Icons.arrow_back_ios_rounded,
                    size: 14,
                    color: Colors.grey[600],
                  ),
                  Text('Back', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            )
          else
            const SizedBox(width: 70),

          // Page dots
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _totalPages,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? Colors.blue[600]
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),

          // Next button (hidden on last page)
          if (_currentPage < _totalPages - 1)
            TextButton(
              onPressed: _nextPage,
              child: Row(
                children: [
                  Text(
                    'Next',
                    style: TextStyle(
                      color: Colors.blue[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Colors.blue[600],
                  ),
                ],
              ),
            )
          else
            const SizedBox(width: 70),
        ],
      ),
    );
  }

  //  Helper widgets
  Widget _buildFeatureRow({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
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
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentPoint({
    required String number,
    required String title,
    required String content,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.indigo[600],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    height: 1.5,
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
