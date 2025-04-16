import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';

import 'Service/SplashScreen.dart';
import 'Service/NotificationService.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load env file
  await dotenv.load(fileName: ".env");

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.init();

  // Set up periodic cleanup setiap 12 jam
  Timer.periodic(Duration(hours: 12), (timer) async {
    print('Running scheduled notification cleanup');
    await notificationService.cleanupOldNotifications();
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
        useMaterial3: true,
      ),
      home: SplashScreen(),
    );
  }
}

final Color WarnaUtama = Color(0xFF0B192C);
final Color WarnaUtama2 = Color(0xFF252B48);
final Color WarnaSecondary = Color(0xFFEBF400);

// 1E3E62 0B192C
// 252B48 4E4062
