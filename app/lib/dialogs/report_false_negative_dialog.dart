import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/false_negative_report.dart';
import '../services/api_service.dart';

class ReportFalseNegativeDialog extends StatefulWidget {
  final ApiService apiService;

  const ReportFalseNegativeDialog({super.key, required this.apiService});

  @override
  State<ReportFalseNegativeDialog> createState() => _ReportFalseNegativeDialogState();
}

class _ReportFalseNegativeDialogState extends State<ReportFalseNegativeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _soundTypeCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  late DateTime _occurredAt;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _occurredAt = DateTime.now();
  }

  @override
  void dispose() {
    _soundTypeCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now(),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (time == null) return;

    setState(() {
      _occurredAt = DateTime(
        date.year, date.month, date.day, time.hour, time.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      final report = FalseNegativeReport(
        soundType: _soundTypeCtrl.text.trim().isEmpty
            ? null
            : _soundTypeCtrl.text.trim(),
        description: _descriptionCtrl.text.trim().isEmpty
            ? null
            : _descriptionCtrl.text.trim(),
        occurredAt: _occurredAt,
        deviceInfo: null,
      );

      await widget.apiService.submitFalseNegativeReport(report);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit report: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Report a Missed Sound',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _soundTypeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Sound Type (optional)',
                    hintText: 'e.g. doorbell, alarm, smoke detector',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'What happened?',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'When did it happen?',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.access_time),
                    ),
                    child: Text(
                      DateFormat.yMMMd().add_jm().format(_occurredAt),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit Report'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void showReportFalseNegativeDialog(BuildContext context, ApiService apiService) {
  showDialog(
    context: context,
    builder: (_) => ReportFalseNegativeDialog(apiService: apiService),
  );
}
