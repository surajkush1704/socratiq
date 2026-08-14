import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color baseSurface = Color(0xFFFAFAF7);
  static const Color altSurface = Color(0xFFF0F4FF);
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color primaryAccent = Color(0xFF2563EB);
  static const Color secondaryAccent = Color(0xFF38BDF8);
  static const Color primaryText = Color(0xFF1E293B);
  static const Color secondaryText = Color(0xFF64748B);
  static const Color divider = Color(0xFFF1F5F9);
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF22C55E);

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 32,
      offset: Offset(0, 8),
    ),
  ];

  static List<BoxShadow> navShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.16),
      blurRadius: 48,
      offset: Offset(0, 16),
    ),
  ];

  static ThemeData get theme => ThemeData(
    scaffoldBackgroundColor: baseSurface,
    textTheme: GoogleFonts.poppinsTextTheme(),
    colorScheme: ColorScheme.light(
      primary: primaryAccent,
      secondary: secondaryAccent,
      error: error,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryAccent,
        foregroundColor: Colors.white,
        shape: StadiumBorder(),
        textStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),
  );
}
