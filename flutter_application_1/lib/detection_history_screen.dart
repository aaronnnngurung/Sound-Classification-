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

  final List<String> _filterOptions = [
    'All',
    'siren',
    'car_horn',
    'crying_baby',
    'fire_alarm',
    'glass_breaking',
    'door_wood_knock',
  ];

  final Map<String, Map<String, dynamic>> _soundConfig = {
    'siren': {
      'label': 'Siren',
      'icon': Icons.emergency_rounded,
      'color': Colors.red[600],
    },
    'crying_baby': {
      'label': 'Baby Crying',
      'icon': Icons.child_care_rounded,
      'color': Colors.orange[600],
    },
    'car_horn': {
      'label': 'Car Horn',
      'icon': Icons.directions_car_rounded,
      'color': Colors.amber[700],
    },
    'fire_alarm': {
      'label': 'Fire Alarm',
      'icon': Icons.local_fire_department_rounded,
      'color': Colors.deepOrange[600],
    },
    'glass_breaking': {
      'label': 'Glass Breaking',
      'icon': Icons.crisis_alert_rounded,
      'color': Colors.purple[600],
    },
    'door_wood_knock': {
      'label': 'Knocking',
      'icon': Icons.door_front_door_rounded,
      'color': Colors.brown[600],
    },
  };

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  //  Load all records from SQLite
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

  // Apply filter locally — no new DB query needed
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

  //  Download CSV
  Future<void> _downloadHistory() async {
    if (_filteredRecords.isEmpty) {
      _showSnackBar('No records to download', isError: true);
      return;
    }

    setState(() => _isDownloading = true);

    try {
      // Build CSV rows
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

      // Save to Downloads folder
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

  //  Delete single entry
  Future<void> _deleteEntry(int id) async {
    await _db.deleteDetection(id);
    _showSnackBar('Entry deleted');
    _loadRecords(); // refresh list
  }

  // Toggle false positive
  Future<void> _toggleFalsePositive(int id, bool current) async {
    await _db.updateFalsePositive(id, !current);
    _showSnackBar(
      !current ? 'Marked as false positive' : 'Removed false positive flag',
    );
    _loadRecords(); // refresh list
  }

  // Clear all
  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Clear All History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This permanently deletes all detection records '
          'from this device.\n\n'
          'Consider downloading first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
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

  String _confidenceLabelText(double confidence) {
    if (confidence >= 0.85) return 'High Confidence';
    if (confidence >= 0.70) return 'Medium Confidence';
    return 'Low Confidence';
  }

  Color _confidenceLabelColor(double confidence) {
    if (confidence >= 0.85) return Colors.green[600]!;
    if (confidence >= 0.70) return Colors.orange[600]!;
    return Colors.red[400]!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Detection History',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadRecords,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Clear All',
            onPressed: _clearAll,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFilterRow(),
                _buildSummaryBar(),
                Expanded(
                  child: _filteredRecords.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _filterOptions.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (ctx, i) {
            final opt = _filterOptions[i];
            final selected = _selectedFilter == opt;
            final config = _soundConfig[opt];
            final color = config != null
                ? config['color'] as Color
                : Colors.blue[600]!;

            return GestureDetector(
              onTap: () => _applyFilter(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: selected ? color : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? color : Colors.grey[300]!,
                  ),
                ),
                child: Text(
                  opt == 'All' ? 'All' : (config?['label'] as String? ?? opt),
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.grey[700],
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.storage_rounded, color: Colors.blue[600], size: 18),
          const SizedBox(width: 8),
          Text(
            '${_filteredRecords.length} record'
            '${_filteredRecords.length == 1 ? '' : 's'}'
            ' — stored locally on device',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _isDownloading ? null : _downloadHistory,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _isDownloading ? Colors.grey[300] : Colors.green[600],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _isDownloading
                      ? const SizedBox(
                          height: 12,
                          width: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.download_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                  const SizedBox(width: 5),
                  Text(
                    _isDownloading ? 'Saving...' : 'CSV',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
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
    final color = (config?['color'] as Color?) ?? Colors.grey[600]!;
    final label = config?['label'] as String? ?? soundClass;
    final icon = config?['icon'] as IconData? ?? Icons.volume_up_rounded;

    return Dismissible(
      key: Key(id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.red[600],
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_rounded, color: Colors.white, size: 24),
            SizedBox(height: 4),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            title: const Text('Delete Entry?'),
            content: const Text('Remove this detection record?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isFP ? Colors.grey[50] : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isFP ? Colors.grey[300]! : color.withOpacity(0.25),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isFP ? Colors.grey[200] : color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isFP ? Colors.grey : color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isFP ? Colors.grey[500] : Colors.black87,
                          decoration: isFP ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (isFP) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'False +',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Confidence label badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _confidenceLabelColor(confidence).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _confidenceLabelColor(
                          confidence,
                        ).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      _confidenceLabelText(confidence),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _confidenceLabelColor(confidence),
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Existing confidence bar
                  Row(
                    children: [
                      Container(
                        width: 80,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: confidence,
                          child: Container(
                            decoration: BoxDecoration(
                              color: isFP ? Colors.grey[400] : color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(confidence * 100).toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatFullDateTime(timestamp),
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                isFP ? Icons.flag_rounded : Icons.flag_outlined,
                color: isFP ? Colors.orange[600] : Colors.grey[400],
                size: 20,
              ),
              tooltip: isFP
                  ? 'Remove false positive flag'
                  : 'Mark as false positive',
              onPressed: () => _toggleFalsePositive(id, isFP),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            _selectedFilter == 'All'
                ? 'No detections yet'
                : 'No ${_soundConfig[_selectedFilter]?['label'] ?? _selectedFilter} detections',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'All'
                ? 'Start sound detection to see records here'
                : 'Try selecting a different filter',
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
          if (_selectedFilter != 'All') ...[
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => _applyFilter('All'),
              child: const Text('Show All'),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green[600]),
            const SizedBox(width: 10),
            const Text(
              'Download Complete',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('History saved as a CSV file to your Downloads folder.'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.insert_drive_file_rounded,
                    color: Colors.green[600],
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      filename,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Open with Excel or Google Sheets.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
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
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatFullDateTime(DateTime dt) {
    return '${dt.day} ${_monthName(dt.month)} ${dt.year} '
        'at ${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }

  String _formatDateOnly(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  String _formatTimeOnly(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';

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
