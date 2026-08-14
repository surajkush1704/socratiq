import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app_theme.dart';
import '../../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final route = AuthService.isLoggedIn ? '/home' : '/login';
    Navigator.pushReplacementNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.altSurface,
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Socratiq',
                    style: GoogleFonts.poppins(
                      color: AppTheme.primaryAccent,
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Learn smarter. Not harder.',
                    style: GoogleFonts.poppins(
                      color: AppTheme.secondaryText,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const LinearProgressIndicator(
            color: AppTheme.secondaryAccent,
            backgroundColor: AppTheme.divider,
            minHeight: 2,
          ),
        ],
      ),
    );
  }
}
