import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_theme.dart';
import '../../models/content_model.dart';
import 'learn_screen.dart';
import 'test_screen.dart';

class ModeSelectScreen extends StatelessWidget {
  final ContentModel? content;

  const ModeSelectScreen({this.content, super.key});

  @override
  Widget build(BuildContext context) {
    final ContentModel? effectiveContent = content ?? (ModalRoute.of(context)?.settings.arguments as ContentModel?);

    if (effectiveContent == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Center(
            child: Text(
              'No document selected',
              style: GoogleFonts.poppins(color: AppTheme.secondaryText),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: AppTheme.navyText, size: 20),
                ),
              ),
              const SizedBox(height: 24),
              // Title
              Text(
                effectiveContent.documentName.replaceAll('.pdf', ''),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  color: AppTheme.navyText,
                  letterSpacing: -0.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'How do you want to study?',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: AppTheme.secondaryText,
                ),
              ),
              const SizedBox(height: 32),
              // Mode cards
              Expanded(
                child: Column(
                  children: [
                    _buildModeCard(
                      context: context,
                      bgColor: const Color(0xFFEEF2FF),
                      iconColor: AppTheme.primaryBlue,
                      icon: Icons.menu_book_rounded,
                      title: 'Learn',
                      description:
                          'I explain concepts step by step,\nthen quiz you to check understanding.',
                      buttonLabel: 'Start Learning',
                      buttonGradient: AppTheme.primaryGradient,
                      mode: 'learn',
                      targetContent: effectiveContent,
                    ),
                    const SizedBox(height: 14),
                    _buildModeCard(
                      context: context,
                      bgColor: const Color(0xFFECFEFF),
                      iconColor: AppTheme.cyanAccent,
                      icon: Icons.refresh_rounded,
                      title: 'Revise',
                      description:
                          'Skip the explanation.\nJump straight to questions for quick revision.',
                      buttonLabel: 'Start Revising',
                      buttonGradient: AppTheme.cyanGradient,
                      mode: 'revise',
                      targetContent: effectiveContent,
                    ),
                    const SizedBox(height: 14),
                    _buildModeCard(
                      context: context,
                      bgColor: const Color(0xFFF5F3FF),
                      iconColor: AppTheme.lavenderAccent,
                      icon: Icons.quiz_rounded,
                      title: 'Test Yourself',
                      description:
                          'Full scored test with no hints.\nResults and feedback at the end.',
                      buttonLabel: 'Start Test',
                      buttonGradient: AppTheme.lavenderGradient,
                      mode: 'test',
                      targetContent: effectiveContent,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required BuildContext context,
    required Color bgColor,
    required Color iconColor,
    required IconData icon,
    required String title,
    required String description,
    required String buttonLabel,
    required LinearGradient buttonGradient,
    required String mode,
    required ContentModel targetContent,
  }) {
    return Expanded(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusXS),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: AppTheme.navyText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.secondaryText,
                height: 1.55,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {
                if (mode == 'test') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TestScreen(
                        content: targetContent,
                        questionCount: 5,
                      ),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LearnScreen(
                        content: targetContent,
                        mode: mode,
                      ),
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 12, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: buttonGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withOpacity(0.30),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Text(
                  buttonLabel,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
