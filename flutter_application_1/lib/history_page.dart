import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const Color maroonColor = Color(0xFF701E38);
  static const Color navyColor = Color(0xFF1B4D8F);

  void _showFalsePositiveDialog(
    BuildContext context,
    String alertId,
    String currentSoundClass,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.report_problem_rounded, color: maroonColor),
              SizedBox(width: 8),
              Text('Report False Positive'),
            ],
          ),
          content: Text(
            'Was this alert incorrectly identified as a "$currentSoundClass"? Submitting feedback helps improve accuracy.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: maroonColor),
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await FirebaseFirestore.instance
                      .collection('alerts')
                      .doc(alertId)
                      .update({
                        'isFalsePositive': true,
                        'reportedAt': FieldValue.serverTimestamp(),
                      });

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Feedback logged successfully.'),
                        backgroundColor: navyColor,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to submit report: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'Report',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Alert History Log',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('alerts')
            .where('userEmail', isEqualTo: user?.email)
            .snapshots(), // Removed orderBy temporarily to prevent backend mismatches with missing fields
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text('Error loading history: ${snapshot.error}'),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: maroonColor),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_toggle_off_rounded,
                    size: 70,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No sound history recorded yet.',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          // Sort documents safely in memory to prevent missing field errors
          final alerts = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final doc = alerts[index];
              final String alertId = doc.id;

              // 1. SAFEST EXTRACATION METHOD: Convert to a regular Dart map object
              // to fully prevent the SDK 'Bad state' field missing crash.
              final Map<String, dynamic>? alertData =
                  doc.data() as Map<String, dynamic>?;

              if (alertData == null) return const SizedBox.shrink();

              // 2. Safe Fallbacks using Map operations
              String soundClass = alertData.containsKey('soundClass')
                  ? (alertData['soundClass'] ?? 'Unknown Sound')
                  : 'Unknown Sound';
              bool isEmergency = alertData.containsKey('isEmergency')
                  ? (alertData['isEmergency'] ?? false)
                  : false;
              bool isFalsePositive = alertData.containsKey('isFalsePositive')
                  ? (alertData['isFalsePositive'] ?? false)
                  : false;

              String formattedTime = 'Time unavailable';

              // 3. Wrap timestamp formatting inside an isolated try-catch
              try {
                if (alertData.containsKey('timestamp') &&
                    alertData['timestamp'] != null) {
                  DateTime dt = (alertData['timestamp'] as Timestamp).toDate();
                  formattedTime =
                      DateFormat('jm').format(dt) +
                      ' • ' +
                      DateFormat('yMMMd').format(dt);
                }
              } catch (e) {
                formattedTime = 'Just now';
              }

              return Card(
                key: ValueKey(alertId),
                elevation: 0,
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.grey[200]!),
                ),
                color: isFalsePositive ? Colors.grey[100] : Colors.white,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFalsePositive
                          ? Colors.grey[300]
                          : (isEmergency
                                ? const Color(0xFFFDF2F4)
                                : const Color(0xFFE8F0FE)),
                    ),
                    child: Icon(
                      isFalsePositive
                          ? Icons.block_rounded
                          : (isEmergency
                                ? Icons.gpp_maybe_rounded
                                : Icons.volume_up_rounded),
                      color: isFalsePositive
                          ? Colors.grey[600]
                          : (isEmergency ? maroonColor : navyColor),
                      size: 24,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        soundClass,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isFalsePositive
                              ? Colors.grey[600]
                              : const Color(0xFF2B2D42),
                          decoration: isFalsePositive
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (isEmergency && !isFalsePositive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: maroonColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'CRITICAL',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      isFalsePositive
                          ? 'Flagged as False Positive'
                          : formattedTime,
                      style: TextStyle(
                        fontSize: 12,
                        color: isFalsePositive ? maroonColor : Colors.grey[500],
                        fontWeight: isFalsePositive
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  trailing: !isFalsePositive
                      ? IconButton(
                          icon: const Icon(
                            Icons.outlined_flag_rounded,
                            color: Colors.grey,
                          ),
                          tooltip: 'Report False Positive',
                          onPressed: () => _showFalsePositiveDialog(
                            context,
                            alertId,
                            soundClass,
                          ),
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
