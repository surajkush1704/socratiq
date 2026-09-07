import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_theme.dart';

import '../../services/sync_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();

    Timer(const Duration(milliseconds: 2500), () async {
      if (!mounted) return;
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Sync profile in background — don't block navigation
        SyncService.syncProfile().then((_) {
          print('[SPLASH] Profile synced on launch');
        }).catchError((e) {
          print('[SPLASH] Profile sync failed (non-fatal): $e');
        });
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final textCol = AppTheme.dynamicText(context);
    final secCol = AppTheme.dynamicSecondaryText(context);
    final cardBg = AppTheme.dynamicCard(context);
    final borderColor = AppTheme.dynamicDivider(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.dynamicAuroraGradient(context)),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: SlideTransition(
              position: _slideUp,
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // ── OWL LOGO ──────────────────────────────────────────────
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: AppTheme.orbGlow,
                    ),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Container(
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryBlue,
                          shape: BoxShape.circle,
                        ),
                        child: const Text('🎓', style: TextStyle(fontSize: 60)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── APP NAME ──────────────────────────────────────────────
                  Text(
                    'SocratiQ',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w900,
                      fontSize: 40,
                      color: textCol,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Learn Smarter. Not Harder.',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w400,
                      fontSize: 16,
                      color: secCol,
                    ),
                  ),

                  const Spacer(flex: 1),

                  // ── ILLUSTRATION AREA ─────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Books stack
                        const Align(
                          alignment: Alignment.bottomLeft,
                          child: Text('📚', style: TextStyle(fontSize: 72)),
                        ),
                        // PDF tablet card
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: 90,
                            height: 110,
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusSmall),
                              border: Border.all(color: borderColor),
                              boxShadow: isDark ? [] : AppTheme.cardShadow,
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.picture_as_pdf_rounded,
                                  color: Color(0xFFEF4444),
                                  size: 36,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Speech bubble with mic + waveform
                        Align(
                          alignment: Alignment.topRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: borderColor),
                              boxShadow: isDark ? [] : AppTheme.cardShadow,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.mic_rounded,
                                  color: AppTheme.primaryBlue,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                ...List.generate(5, (i) {
                                  final heights = [6.0, 12.0, 8.0, 14.0, 6.0];
                                  return Container(
                                    width: 3,
                                    height: heights[i],
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 1.5),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryBlue,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 1),

                  // ── DESCRIPTION ───────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Turn your notes into a personal tutor\n— just upload, ask and learn.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w400,
                        fontSize: 14,
                        color: secCol,
                        height: 1.6,
                      ),
                    ),
                  ),

                  const Spacer(flex: 1),

                  // ── PAGE DOTS ─────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 24,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkDivider : AppTheme.divider,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkDivider : AppTheme.divider,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
