import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── COLOR TOKENS ──────────────────────────────────────────────────────────
  static const Color background      = Color(0xFFF8FAFF);
  static const Color backgroundAlt   = Color(0xFFEEF2FF);
  static const Color navyText        = Color(0xFF0A0F1E);
  static const Color secondaryText   = Color(0xFF4B5675);
  static const Color lightText       = Color(0xFF8B92A5);
  static const Color primaryBlue     = Color(0xFF2355F5);
  static const Color cyanAccent      = Color(0xFF06B6D4);
  static const Color lavenderAccent  = Color(0xFF7C6FEC);
  static const Color cardWhite       = Color(0xFFFFFFFF);
  static const Color success         = Color(0xFF10B981);
  static const Color error           = Color(0xFFEF4444);
  static const Color warning         = Color(0xFFF59E0B);
  static const Color divider         = Color(0xFFE8EDF5);

  // ── GRADIENTS ─────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF2355F5), Color(0xFF1A44E0)],
  );

  static const LinearGradient cyanGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
  );

  static const LinearGradient lavenderGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF7C6FEC), Color(0xFF6D28D9)],
  );

  // Aurora — use behind AI experiences only
  static const RadialGradient auroraGradient = RadialGradient(
    center: Alignment.topCenter,
    radius: 1.8,
    colors: [
      Color(0x261E40AF), // blue 15%
      Color(0x190891B2), // cyan 10%
      Color(0x146D28D9), // lavender 8%
      Color(0xFFF8FAFF), // base
    ],
    stops: [0.0, 0.4, 0.7, 1.0],
  );

  // ── SHADOWS ───────────────────────────────────────────────────────────────
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: const Color(0xFF0A0F1E).withOpacity(0.06),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> glassShadow = [
    BoxShadow(
      color: const Color(0xFF0A0F1E).withOpacity(0.08),
      blurRadius: 32,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> buttonShadow = [
    BoxShadow(
      color: const Color(0xFF2355F5).withOpacity(0.30),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> orbGlow = [
    BoxShadow(
      color: const Color(0xFF2355F5).withOpacity(0.40),
      blurRadius: 80,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: const Color(0xFF06B6D4).withOpacity(0.20),
      blurRadius: 160,
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> navShadow = [
    BoxShadow(
      color: const Color(0xFF0A0F1E).withOpacity(0.08),
      blurRadius: 24,
      offset: const Offset(0, -4),
    ),
  ];

  // ── BORDER RADIUS ─────────────────────────────────────────────────────────
  static const double radiusXL     = 28.0;
  static const double radiusLarge  = 24.0;
  static const double radiusMedium = 20.0;
  static const double radiusSmall  = 16.0;
  static const double radiusXS     = 12.0;
  static const double radiusPill   = 999.0;

  // ── BACKWARD COMPATIBILITY ALIASES ────────────────────────────────────────
  static const Color primaryText = navyText;
  static const Color purpleAccent = lavenderAccent;
  static const Color orangeAccent = Color(0xFFF97316);
  static const Color lightBlueCard = Color(0xFFE0F2FE);
  static const Color yellowCard = Color(0xFFFEF3C7);

  static const LinearGradient screenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE8F4FF), Color(0xFFDDD6FF)],
  );

  static const LinearGradient altScreenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
  );

  static const LinearGradient purpleCardGradient = lavenderGradient;
  static const LinearGradient blueButtonGradient = primaryGradient;
  static const LinearGradient orangeCardGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFF97316), Color(0xFFEA580C)],
  );

  static List<BoxShadow> purpleCardShadow = [
    BoxShadow(
      color: const Color(0xFF7C6FEC).withOpacity(0.30),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> orangeCardShadow = [
    BoxShadow(
      color: const Color(0xFFF97316).withOpacity(0.30),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  static const double radiusCard = radiusMedium;
  static const double radiusButton = radiusPill;
  static const double radiusChip = radiusSmall;
  static const double radiusSheet = radiusXL;
  static const double radiusInput = radiusSmall;

  static const Color altSurface = backgroundAlt;
  static const Color primaryAccent = primaryBlue;

  // ── GLASSMORPHISM HELPER ──────────────────────────────────────────────────
  static Widget glassCard({
    required Widget child,
    double borderRadius = radiusLarge,
    EdgeInsets? padding,
    List<BoxShadow>? shadow,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.white,
          width: 1.5,
        ),
        boxShadow: shadow ?? glassShadow,
      ),
      child: child,
    );
  }

  // ── AURORA BACKGROUND HELPER ──────────────────────────────────────────────
  static Widget auroraBackground({required Widget child}) {
    return Container(
      decoration: const BoxDecoration(gradient: auroraGradient),
      child: child,
    );
  }

  // ── GRADIENT BUTTON HELPER ────────────────────────────────────────────────
  static Widget gradientButton({
    required String label,
    required VoidCallback onTap,
    double? width,
    LinearGradient? gradient,
    List<BoxShadow>? shadow,
    EdgeInsets padding = const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: padding,
        decoration: BoxDecoration(
          gradient: gradient ?? primaryGradient,
          borderRadius: BorderRadius.circular(radiusPill),
          boxShadow: shadow ?? buttonShadow,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ── OUTLINED GLASS BUTTON HELPER ──────────────────────────────────────────
  static Widget outlinedButton({
    required String label,
    required VoidCallback onTap,
    Color? borderColor,
    Color? textColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.90),
          borderRadius: BorderRadius.circular(radiusPill),
          border: Border.all(
            color: borderColor ?? AppTheme.primaryBlue,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: textColor ?? AppTheme.primaryBlue,
          ),
        ),
      ),
    );
  }

  // ── THEME DATA ────────────────────────────────────────────────────────────
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    textTheme: GoogleFonts.poppinsTextTheme().apply(
      bodyColor: navyText,
      displayColor: navyText,
    ),
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.light,
      background: background,
    ).copyWith(
      primary: primaryBlue,
      secondary: cyanAccent,
      tertiary: lavenderAccent,
      error: error,
      surface: cardWhite,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: navyText),
    ),
  );
}
