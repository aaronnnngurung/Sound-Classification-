import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BackgroundPermissionHelper {
  // Detect phone brand at runtime
  static const _platform = MethodChannel('com.soundclass/haptic');

  // Show the correct instructions
  // based on the phone brand
  static Future<void> showDialog(BuildContext context) async {
    // Get device brand from native
    String brand = 'unknown';
    try {
      final result = await _platform.invokeMethod<String>('getDeviceBrand');
      brand = (result ?? 'unknown').toLowerCase();
    } catch (e) {
      brand = 'unknown';
    }

    print('Device brand detected: $brand');

    if (!context.mounted) return;

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'background_permission',
      pageBuilder: (ctx, _, __) => _BackgroundPermissionDialog(brand: brand),
    );
  }

  static Future<void> openAppSettings() async {
    try {
      await _platform.invokeMethod('openSettings');
    } catch (e) {
      print('Cannot open settings: $e');
    }
  }
}

class _BackgroundPermissionDialog extends StatelessWidget {
  final String brand;

  const _BackgroundPermissionDialog({required this.brand});

  // Get brand-specific instructions
  List<String> get _steps {
    if (brand.contains('xiaomi') ||
        brand.contains('redmi') ||
        brand.contains('poco')) {
      return [
        'Settings → Apps → Manage Apps → SoundClass',
        'Tap Battery Saver → No Restrictions',
        'Tap Other Permissions → '
            'Run in Background → Allow',
        'Enable Autostart on the same page',
      ];
    } else if (brand.contains('samsung')) {
      return [
        'Settings → Apps → SoundClass',
        'Tap Battery → '
            'select Unrestricted',
        'Go back → tap Mobile data → '
            'Allow background data usage',
        'Settings → Device Care → Battery → '
            'App Power Management → '
            'Add SoundClass to excluded list',
      ];
    } else if (brand.contains('oppo') ||
        brand.contains('realme') ||
        brand.contains('oneplus')) {
      return [
        'Settings → Battery → '
            'Battery Optimization',
        'Find SoundClass → '
            'tap Don\'t Optimize',
        'Settings → Apps → SoundClass → '
            'Battery → Allow background activity',
        'Settings → Apps → SoundClass → '
            'Enable Auto Launch',
      ];
    } else if (brand.contains('vivo') || brand.contains('iqoo')) {
      return [
        'Settings → More Settings → '
            'Applications → SoundClass',
        'Tap Autostart → Enable',
        'Settings → Battery → '
            'High Background Power Consumption → '
            'Add SoundClass',
        'Tap Background App Refresh → Allow',
      ];
    } else if (brand.contains('huawei') || brand.contains('honor')) {
      return [
        'Settings → Apps → SoundClass',
        'Tap Battery → '
            'Enable App Launch → '
            'turn off Automatic management',
        'Enable Auto-launch, '
            'Secondary launch, Run in background',
        'Settings → Battery → '
            'More Battery Settings → '
            'Close after screen lock → Disable',
      ];
    } else {
      // Generic instructions for all other brands
      // Sony, Nokia, Motorola, Google Pixel etc.
      return [
        'Settings → Apps → SoundClass',
        'Tap Battery → '
            'select Unrestricted or '
            'Don\'t optimize',
        'Settings → Battery → '
            'Battery Optimization → '
            'SoundClass → Don\'t Optimize',
        'Make sure Background App Refresh '
            'is enabled for SoundClass',
      ];
    }
  }

  String get _brandName {
    if (brand.contains('xiaomi')) return 'Xiaomi';
    if (brand.contains('redmi')) return 'Redmi';
    if (brand.contains('poco')) return 'POCO';
    if (brand.contains('samsung')) return 'Samsung';
    if (brand.contains('oppo')) return 'OPPO';
    if (brand.contains('realme')) return 'Realme';
    if (brand.contains('oneplus')) return 'OnePlus';
    if (brand.contains('vivo')) return 'Vivo';
    if (brand.contains('iqoo')) return 'iQOO';
    if (brand.contains('huawei')) return 'Huawei';
    if (brand.contains('honor')) return 'Honor';
    return 'Your phone';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.battery_alert_rounded, color: Colors.orange[600]),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Allow Background Access',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Explanation banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Text(
                '$_brandName phones restrict '
                'background apps by default. '
                'SoundClass needs background '
                'access to detect sounds when '
                'you switch to other apps.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.orange[900],
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Steps
            ..._steps.asMap().entries.map(
              (entry) => _buildStep('${entry.key + 1}', entry.value),
            ),

            const SizedBox(height: 12),
            Text(
              'You only need to do this once.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Skip for now',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            BackgroundPermissionHelper.openAppSettings();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange[600],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Open Settings'),
        ),
      ],
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.orange[600],
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
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
