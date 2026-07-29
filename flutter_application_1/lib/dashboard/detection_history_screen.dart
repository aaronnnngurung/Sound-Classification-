import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'database_helper.dart';

class DetectionHistoryScreen extends StatefulWidget {
  const DetectionHistoryScreen({Key? key}) : super(key: key);

  @override
  State<DetectionHistoryScreen> createState() => _DetectionHistoryScreenState();
}

class _DetectionHistoryScreenState extends State<DetectionHistoryScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  final DatabaseHelper _db = DatabaseHelper.instance;

  String _selectedFilter = 'All';
  bool _isDownloading = false;
  bool _isLoading = true;

  // All records loaded from SQLite
  List<Map<String, dynamic>> _allRecords = [];
  // Records after filter applied
  List<Map<String, dynamic>> _filteredRecords = [];

  // 2026 Material 3 Design Tokens — Shared with HomePage
  static const Color _primaryColor = Color(0xFF5B7CFA);
  static const Color _primaryColorDeep = Color(0xFF4A63E0);
  static const Color _backgroundColor = Color(0xFFF8FAFC);
  static const Color _surfaceColor = Colors.white;
  static const Color _inputBgColor = Color(0xFFF1F5F9);
  static const Color _borderColor = Color(0xFFE2E8F0);
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _successColor = Color(0xFF16A34A);

  final List<String> _filterOptions = [
    'All',
    'siren',
    'crying_baby',
    'car_horn',
    'fire_alarm',
    'glass_breaking',
    'door_wood_knock',
    'clock_alarm',
    'train',
    'fireworks',
  ];

  final Map<String, Map<String, dynamic>> _soundConfig = {
    'siren': {
      'label': 'Siren',
      'icon': Icons.emergency_rounded,
      'color': Color(0xFFDC2626),
    },
    'crying_baby': {
      'label': 'Baby Cry',
      'icon': Icons.child_care_rounded,
      'color': Color(0xFFEA580C),
    },
    'car_horn': {
      'label': 'Car Horn',
      'icon': Icons.directions_car_rounded,
      'color': Color(0xFFD97706),
    },
    'fire_alarm': {
      'label': 'Fire Alarm',
      'icon': Icons.local_fire_department_rounded,
      'color': Color(0xFFE11D48),
    },
    'glass_breaking': {
      'label': 'Glass Break',
      'icon': Icons.crisis_alert_rounded,
      'color': Color(0xFF9333EA),
    },
    'door_wood_knock': {
      'label': 'Knocking',
      'icon': Icons.door_front_door_rounded,
      'color': Color(0xFF78350F),
    },
    'clock_alarm': {
      'label': 'Clock Alarm',
      'icon': Icons.alarm_rounded,
      'color': Color(0xFF1D4ED8),
    },
    'train': {
      'label': 'Train',
      'icon': Icons.train_rounded,
      'color': Color(0xFF0D9488),
    },
    'fireworks': {
      'label': 'Fireworks',
      'icon': Icons.celebration_rounded,
      'color': Color(0xFFDB2777),
    },
  };

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  // Load all records from SQLite
  Future<void> _loadRecords() async {
    if (_user == null) return;
    setState(() => _isLoading = true);

    try {
      final records = await _db.getAllDetections(_user!.uid);
      setState(() {
        _allRecords = records;
        _filteredRecords = records;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Failed to load history: $e', isError: true);
    }
  }

  // Apply filter locally
  void _applyFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      if (filter == 'All') {
        _filteredRecords = _allRecords;
      } else {
        _filteredRecords = _allRecords
            .where((r) => r['sound_class'] == filter)
            .toList();
      }
    });
  }

  // Download CSV
  Future<void> _downloadHistory() async {
    if (_filteredRecords.isEmpty) {
      _showSnackBar('No records to download', isError: true);
      return;
    }

    setState(() => _isDownloading = true);

    try {
      List<List<dynamic>> csvRows = [
        [
          'No.',
          'Sound Class',
          'Display Label',
          'Confidence (%)',
          'Date',
          'Time',
          'False Positive',
        ],
      ];

      for (int i = 0; i < _filteredRecords.length; i++) {
        final r = _filteredRecords[i];
        final timestamp = DateTime.parse(r['timestamp'] as String);
        final isFP = (r['is_false_positive'] as int) == 1;

        csvRows.add([
          i + 1,
          r['sound_class'],
          r['display_label'],
          ((r['confidence'] as double) * 100).toStringAsFixed(1),
          _formatDateOnly(timestamp),
          _formatTimeOnly(timestamp),
          isFP ? 'Yes' : 'No',
        ]);
      }

      final csvString = const ListToCsvConverter().convert(csvRows);

      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final now = DateTime.now();
      final filename =
          'SoundClass_History_'
          '${now.year}${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}'
          '.csv';

      final file = File('${directory!.path}/$filename');
      await file.writeAsString(csvString);

      if (mounted) {
        _showDownloadSuccessDialog(filename);
      }
    } catch (e) {
      _showSnackBar('Download failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _deleteEntry(int id) async {
    await _db.deleteDetection(id);
    _showSnackBar('Entry deleted');
    _loadRecords();
  }

  Future<void> _toggleFalsePositive(int id, bool current) async {
    await _db.updateFalsePositive(id, !current);
    _showSnackBar(
      !current ? 'Marked as false positive' : 'Removed false positive flag',
    );
    _loadRecords();
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Clear All History',
          style: TextStyle(fontWeight: FontWeight.w700, color: _textPrimary),
        ),
        content: const Text(
          'This permanently deletes all detection records from this device.\n\nConsider downloading CSV first.',
          style: TextStyle(color: _textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed != true || _user == null) return;
    await _db.clearAllDetections(_user!.uid);
    _showSnackBar('All history cleared');
    _loadRecords();
  }

  String _confidenceLabel(double confidence) {
    if (confidence >= 0.85) return 'High Confidence';
    if (confidence >= 0.70) return 'Medium Confidence';
    return 'Low Confidence';
  }

  Color _confidenceColor(double confidence) {
    if (confidence >= 0.85) return _successColor;
    if (confidence >= 0.70) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Column(
        children: [
          // ── Gradient Header (Matches HomePage) ──────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, topInset + 16, 20, 22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_primaryColorDeep, _primaryColor],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Detection History 📋',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Review logs and exported records',
                        style: TextStyle(
                          color: Color(0xD9FFFFFF),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                _HeaderIconButton(
                  icon: Icons.refresh_rounded,
                  onTap: _loadRecords,
                  tooltip: 'Refresh',
                ),
                const SizedBox(width: 8),
                _HeaderIconButton(
                  icon: Icons.delete_sweep_rounded,
                  onTap: _clearAll,
                  tooltip: 'Clear All',
                ),
              ],
            ),
          ),

          // ── Filter Row & Summary Card ─────────────────────────────
          _buildFilterRow(),
          _buildSummaryBar(),

          // ── Detection List ─────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: _primaryColor,
                      strokeWidth: 2.5,
                    ),
                  )
                : _filteredRecords.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        itemCount: _filteredRecords.length,
                        itemBuilder: (ctx, i) =>
                            _buildCard(_filteredRecords[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filterOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final opt = _filterOptions[i];
          final selected = _selectedFilter == opt;
          final config = _soundConfig[opt];
          final chipColor = config != null
              ? config['color'] as Color
              : _primaryColor;

          return GestureDetector(
            onTap: () => _applyFilter(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? chipColor : _surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? chipColor : _borderColor,
                  width: 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: chipColor.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : [],
              ),
              child: Text(
                opt == 'All' ? 'All' : (config?['label'] as String? ?? opt),
                style: TextStyle(
                  color: selected ? Colors.white : _textSecondary,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.storage_rounded, color: _primaryColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${_filteredRecords.length} record${_filteredRecords.length == 1 ? '' : 's'} stored on device',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
          ),
          GestureDetector(
            onTap: _isDownloading ? null : _downloadHistory,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _isDownloading ? _inputBgColor : _successColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _isDownloading
                      ? const SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.download_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                  const SizedBox(width: 6),
                  Text(
                    _isDownloading ? 'Saving...' : 'Export CSV',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> record) {
    final id = record['id'] as int;
    final soundClass = record['sound_class'] as String;
    final confidence = record['confidence'] as double;
    final timestamp = DateTime.parse(record['timestamp'] as String);
    final isFP = (record['is_false_positive'] as int) == 1;

    final config = _soundConfig[soundClass];
    final color = (config?['color'] as Color?) ?? _textSecondary;
    final label = config?['label'] as String? ?? soundClass;
    final icon = config?['icon'] as IconData? ?? Icons.volume_up_rounded;

    return Dismissible(
      key: Key(id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_rounded, color: Colors.white, size: 22),
            SizedBox(height: 2),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: _surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Delete Record?', style: TextStyle(fontWeight: FontWeight.w700)),
            content: const Text('Are you sure you want to remove this log permanently?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => _deleteEntry(id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isFP ? Color(0xFFF8FAFC) : _surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isFP ? _borderColor : color.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isFP ? Color(0xFFE2E8F0) : color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isFP ? _textSecondary : color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isFP ? _textSecondary : _textPrimary,
                          decoration: isFP ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (isFP) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'False +',
                            style: TextStyle(
                              color: Color(0xFFD97706),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Confidence badge & progress bar
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _confidenceColor(confidence).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _confidenceLabel(confidence),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _confidenceColor(confidence),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(confidence * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatFullDateTime(timestamp),
                    style: const TextStyle(fontSize: 11, color: _textSecondary),
                  ),
                ],
              ),
            ),

            // Toggle False Positive Flag
            IconButton(
              icon: Icon(
                isFP ? Icons.flag_rounded : Icons.flag_outlined,
                color: isFP ? const Color(0xFFD97706) : _borderColor,
                size: 20,
              ),
              tooltip: isFP ? 'Remove false positive' : 'Flag as false positive',
              onPressed: () => _toggleFalsePositive(id, isFP),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.history_toggle_off_rounded,
              size: 30,
              color: _primaryColor.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _selectedFilter == 'All'
                ? 'No detections recorded'
                : 'No ${_soundConfig[_selectedFilter]?['label'] ?? _selectedFilter} detections',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Start live detection to generate logs here',
            style: TextStyle(fontSize: 13, color: _textSecondary),
          ),
          if (_selectedFilter != 'All') ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => _applyFilter('All'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _borderColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Show All', style: TextStyle(color: _primaryColor)),
            ),
          ],
        ],
      ),
    );
  }

  void _showDownloadSuccessDialog(String filename) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: _successColor),
            SizedBox(width: 10),
            Text('CSV Exported', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your history file was saved to Downloads.',
              style: TextStyle(color: _textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _inputBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.insert_drive_file_rounded,
                    color: _successColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      filename,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFDC2626) : _successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatFullDateTime(DateTime dt) {
    return '${dt.day} ${_monthName(dt.month)} ${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateOnly(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  String _formatTimeOnly(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';

  String _monthName(int m) => [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ][m];
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.16),
      shape: const CircleBorder(),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}