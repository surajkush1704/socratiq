import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app_theme.dart';
import '../../models/content_model.dart';

class ModeSelectScreen extends StatelessWidget {
  const ModeSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final content = ModalRoute.of(context)!.settings.arguments as ContentModel;

    return Scaffold(
      backgroundColor: AppTheme.baseSurface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              content.documentName,
              style: GoogleFonts.poppins(
                color: AppTheme.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'How do you want to study?',
              style: GoogleFonts.poppins(
                color: AppTheme.secondaryText,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            _ModeCard(
              icon: Icons.menu_book_rounded,
              iconColor: AppTheme.primaryAccent,
              title: 'Learn',
              description: 'I\'ll explain everything step by step',
              buttonColor: AppTheme.primaryAccent,
              onStart: () => Navigator.pushNamed(
                context,
                '/learn',
                arguments: {'content': content, 'mode': 'learn'},
              ),
            ),
            _ModeCard(
              icon: Icons.bolt_rounded,
              iconColor: AppTheme.secondaryAccent,
              title: 'Revise',
              description: 'Quick questions, no explanation',
              buttonColor: AppTheme.secondaryAccent,
              backgroundColor: AppTheme.altSurface,
              onStart: () => Navigator.pushNamed(
                context,
                '/learn',
                arguments: {'content': content, 'mode': 'revise'},
              ),
            ),
            _ModeCard(
              icon: Icons.track_changes_rounded,
              iconColor: AppTheme.primaryText,
              title: 'Test',
              description: 'Full scored test, no hints given',
              buttonColor: AppTheme.primaryText,
              onStart: () => Navigator.pushNamed(
                context,
                '/learn',
                arguments: {'content': content, 'mode': 'test'},
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final Color buttonColor;
  final Color? backgroundColor;
  final VoidCallback onStart;

  const _ModeCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.buttonColor,
    required this.onStart,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: AppTheme.primaryText,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    color: AppTheme.secondaryText,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: onStart,
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: AppTheme.cardSurface,
              shape: const StadiumBorder(),
            ),
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }
}
