import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app_theme.dart';
import '../../models/content_model.dart';

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final content = args['content'] as ContentModel;
    final mode = (args['mode'] as String?) ?? 'learn';

    return Scaffold(
      backgroundColor: AppTheme.baseSurface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Study Mode: ${mode[0].toUpperCase()}${mode.substring(1)}',
          style: GoogleFonts.poppins(
            color: AppTheme.primaryText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                content.documentName,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: AppTheme.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Phase 3 coming soon',
                style: GoogleFonts.poppins(
                  color: AppTheme.secondaryText,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
