import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/library/library_screen.dart';
import 'screens/upload/upload_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/legal/privacy_policy_screen.dart';
import 'screens/legal/terms_screen.dart';
import 'screens/legal/about_screen.dart';
import 'screens/account/delete_account_screen.dart';

class SocratiqApp extends StatelessWidget {
  const SocratiqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SocratiQ',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
      routes: {
        '/login':          (_) => const LoginScreen(),
        '/home':           (_) => const HomeScreen(),
        '/library':        (_) => const LibraryScreen(),
        '/upload':         (_) => const UploadScreen(),
        '/dashboard':      (_) => const DashboardScreen(),
        '/settings':       (_) => const SettingsScreen(),
        '/privacy-policy': (_) => const PrivacyPolicyScreen(),
        '/terms':          (_) => const TermsScreen(),
        '/about':          (_) => const AboutScreen(),
        '/delete-account': (_) => const DeleteAccountScreen(),
      },
    );
  }
}
