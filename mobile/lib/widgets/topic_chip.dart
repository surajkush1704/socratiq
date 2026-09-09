import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';

class TopicChip extends StatelessWidget {
  final String label;
  final Color? color;

  const TopicChip({required this.label, this.color, super.key});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primaryBlue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: c.withOpacity(0.20), width: 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: c,
        ),
      ),
    );
  }
}
