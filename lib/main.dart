import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/dashboard_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const SmartTurbinApp());
}

class SmartTurbinApp extends StatefulWidget {
  const SmartTurbinApp({super.key});

  @override
  State<SmartTurbinApp> createState() => _SmartTurbinAppState();
}

class _SmartTurbinAppState extends State<SmartTurbinApp> {
  bool _isDark = true;

  void _toggleTheme() => setState(() => _isDark = !_isDark);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Turbin',
      debugShowCheckedModeBanner: false,
      theme: _isDark ? buildDarkTheme() : buildLightTheme(),
      home: DashboardScreen(isDark: _isDark, onToggleTheme: _toggleTheme),
    );
  }
}
