import 'package:flutter/material.dart';
import 'package:flutter_application_1/smartwatch/smartch_screen.dart';
import 'package:flutter_application_1/smartwatch/watch_sync_service.dart';
import 'package:flutter_application_1/smartwatch/watch_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await WatchNotificationService.instance.init();
  await WatchSyncService.instance.initializeWatchListener();

  runApp(const SmartwatchApp());
}

class SmartwatchApp extends StatelessWidget {
  const SmartwatchApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          surface: Colors.black,
          onSurface: Colors.white,
        ),
      ),
      home: const SmartwatchScreen(),
    );
  }
}