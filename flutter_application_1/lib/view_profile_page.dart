import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewProfilePage extends StatefulWidget {
  final Function(int)? onTabSwitchRequested;

  const ViewProfilePage({super.key, this.onTabSwitchRequested});

  @override
  State<ViewProfilePage> createState() => _ViewProfilePageState();
}

class _ViewProfilePageState extends State<ViewProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isDarkMode = false;

  static const Color maroonColor = Color(0xFF701E38);

  // Core business logic to push dynamic profile edits live into Firestore
  Future<void> _showEditProfileDialog(
    String currentUsername,
    String currentPhone,
  ) async {
    final TextEditingController nameController = TextEditingController(
      text: currentUsername,
    );
    final TextEditingController phoneController = TextEditingController(
      text: currentPhone,
    );
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final User? user = _auth.currentUser;

    if (user == null) return;

    return showDialog(
      context: context,
      barrierDismissible: false, // Force deliberate safe interaction saves
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Edit Profile Details',
            style: TextStyle(fontWeight: FontWeight.bold, color: maroonColor),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Full Display Name Form Input Row field
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      prefixIcon: const Icon(
                        Icons.person_outline,
                        color: maroonColor,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Username cannot be blank'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Active Contact Telephone Number Input Field Row
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: const Icon(
                        Icons.phone_outlined,
                        color: maroonColor,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Phone number cannot be blank'
                        : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: maroonColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    // Update the mapped document layout block straight into Firestore
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.email)
                        .update({
                          'username': nameController.text.trim(),
                          'phoneNumber': phoneController.text.trim(),
                        });

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Profile updated successfully!'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to update data: $e')),
                      );
                    }
                  }
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error signing out: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: maroonColor,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.email)
            .snapshots(),
        builder: (context, snapshot) {
          String displayUsername = 'User';
          String displayPhone = 'Not set';

          if (snapshot.hasData && snapshot.data!.exists) {
            Map<String, dynamic> userData =
                snapshot.data!.data() as Map<String, dynamic>;
            displayUsername = userData['username'] ?? 'User';
            displayPhone = userData['phoneNumber'] ?? 'Not set';
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: maroonColor,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  padding: const EdgeInsets.only(bottom: 32.0, top: 10.0),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.grey,
                        child: Icon(Icons.person, size: 60),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        displayUsername,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'PHONE: $displayPhone',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'MAIL: ${user?.email ?? "No email set"}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile.adaptive(
                          secondary: const Icon(
                            Icons.dark_mode_outlined,
                            color: maroonColor,
                          ),
                          title: const Text(
                            'Dark mode',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          value: _isDarkMode,
                          activeColor: maroonColor,
                          onChanged: (val) {
                            setState(() {
                              _isDarkMode = val;
                            });
                          },
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),

                        // ✅ ENABLED: This row now dynamically reads and passes current data into our update modal forms!
                        ListTile(
                          leading: const Icon(
                            Icons.person_outline_rounded,
                            color: maroonColor,
                          ),
                          title: const Text(
                            'Profile details',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: Colors.grey,
                          ),
                          onTap: () => _showEditProfileDialog(
                            displayUsername,
                            displayPhone,
                          ),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),

                        ListTile(
                          leading: const Icon(
                            Icons.settings_outlined,
                            color: maroonColor,
                          ),
                          title: const Text(
                            'Settings',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: Colors.grey,
                          ),
                          onTap: () {
                            if (widget.onTabSwitchRequested != null) {
                              widget.onTabSwitchRequested!(2);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Settings panel accessible via bottom bar tab.',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),

                        ListTile(
                          leading: const Icon(
                            Icons.logout_rounded,
                            color: maroonColor,
                          ),
                          title: const Text(
                            'Log out',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: maroonColor,
                            ),
                          ),
                          onTap: _signOut,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
