import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/library/library_screen.dart';
import 'screens/session/learn_screen.dart';
import 'screens/session/mode_select.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/upload/upload_screen.dart';

class SocratiqApp extends StatelessWidget {
  const SocratiqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Socratiq',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/library': (context) => const LibraryScreen(),
        '/upload': (context) => const UploadScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/mode-select': (context) => const ModeSelectScreen(),
        '/learn': (context) => const LearnScreen(),
      },
    );
  }
}
