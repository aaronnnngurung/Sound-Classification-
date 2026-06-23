import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _contactController = TextEditingController();

  // Local preferences states
  bool _hapticVibration = true;
  bool _visualFlashAlerts = true;
  double _sensitivityThreshold = 0.70; // 70% confidence tolerance default

  static const Color maroonColor = Color(0xFF701E38);
  static const Color navyColor = Color(0xFF1B4D8F);

  @override
  void dispose() {
    _contactController.dispose();
    super.dispose();
  }

  // Updates the critical emergency contact phone number in Firestore
  void _updateEmergencyContact(String currentContact) {
    _contactController.text = currentContact == 'Not set' ? '' : currentContact;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Emergency Contact',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter a phone number to notify in case of high-priority environmental safety alarms:',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contactController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'e.g., +1234567890',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(
                  Icons.phone_outlined,
                  color: maroonColor,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: maroonColor),
            onPressed: () async {
              final User? user = _auth.currentUser;
              String newContact = _contactController.text.trim();
              if (newContact.isEmpty) newContact = 'Not set';

              Navigator.pop(dialogContext);

              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user?.email)
                    .update({'emergencyContact': newContact});

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Emergency contact saved.'),
                      backgroundColor: navyColor,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update contact: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'App Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.email)
            .snapshots(),
        builder: (context, snapshot) {
          String emergencyContact = 'Not set';
          if (snapshot.hasData && snapshot.data!.exists) {
            Map<String, dynamic> userData =
                snapshot.data!.data() as Map<String, dynamic>;
            emergencyContact = userData['emergencyContact'] ?? 'Not set';
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // --- SECTION 1: HAPTICS & FEEDBACK ---
              _buildSectionHeader('Feedback Settings'),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      title: const Text(
                        'Haptic Vibration Alerts',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: const Text(
                        'Vibrate the device pattern synchronously upon detection',
                      ),
                      activeColor: maroonColor,
                      value: _hapticVibration,
                      onChanged: (val) =>
                          setState(() => _hapticVibration = val),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile.adaptive(
                      title: const Text(
                        'Visual Camera Flash Alerts',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: const Text(
                        'Strobe flashlight when highly critical sirens trigger',
                      ),
                      activeColor: maroonColor,
                      value: _visualFlashAlerts,
                      onChanged: (val) =>
                          setState(() => _visualFlashAlerts = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // --- SECTION 2: MACHINE LEARNING ACCURACY CRITERIA ---
              _buildSectionHeader('Classification Parameters'),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.grey[200]!),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12.0,
                    horizontal: 16.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Detection Confidence Tolerance',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${(_sensitivityThreshold * 100).toInt()}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: navyColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Minimum probability threshold required to emit feedback notifications.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                      Slider.adaptive(
                        activeColor: navyColor,
                        inactiveColor: Colors.blue[50],
                        min: 0.50,
                        max: 0.95,
                        divisions: 9,
                        value: _sensitivityThreshold,
                        onChanged: (val) =>
                            setState(() => _sensitivityThreshold = val),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // --- SECTION 3: SAFETY ASSISTIVE MEASURES ---
              _buildSectionHeader('Assistive & Safety'),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.grey[200]!),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFDF2F4),
                    ),
                    child: const Icon(
                      Icons.gpp_maybe_rounded,
                      color: maroonColor,
                    ),
                  ),
                  title: const Text(
                    'Configure Emergency Contact',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    emergencyContact,
                    style: TextStyle(
                      color: emergencyContact == 'Not set'
                          ? Colors.grey
                          : maroonColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Colors.grey,
                  ),
                  onTap: () => _updateEmergencyContact(emergencyContact),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 6.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
