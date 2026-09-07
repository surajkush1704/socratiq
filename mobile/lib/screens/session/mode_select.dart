import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_theme.dart';
import '../../models/content_model.dart';
import 'detail_explanation_screen.dart';
import 'revise_summary_screen.dart';
import 'learn_screen.dart';
import 'test_screen.dart';

class ModeSelectScreen extends StatelessWidget {
  final ContentModel? content;

  const ModeSelectScreen({this.content, super.key});

  @override
  Widget build(BuildContext context) {
    final ContentModel? effectiveContent = content ??
        (ModalRoute.of(context)?.settings.arguments as ContentModel?);

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

    final testCount =
        effectiveContent.extractedText.length > 5000 ? 20 : 15;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
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
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: AppTheme.navyText,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Document Title & Subtitle
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
                'Select study format for this chapter',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.secondaryText,
                ),
              ),
              const SizedBox(height: 24),

              // 1. Learn Mode Card
              _buildModeCard(
                context: context,
                bgColor: const Color(0xFFEEF2FF),
                iconColor: AppTheme.primaryBlue,
                icon: Icons.auto_stories_rounded,
                title: 'Learn',
                badgeText: 'Step-by-Step Breakdown',
                description:
                    'Read an in-depth, structured explanation of all key concepts, theorems, and real-world examples.',
                buttonLabel: 'Read Detailed Explanation',
                buttonGradient: AppTheme.primaryGradient,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetailExplanationScreen(
                        content: effectiveContent,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),

              // 2. Revise Mode Card
              _buildModeCard(
                context: context,
                bgColor: const Color(0xFFECFEFF),
                iconColor: AppTheme.cyanAccent,
                icon: Icons.bolt_rounded,
                title: 'Revise',
                badgeText: 'Simple High-Yield Summary',
                description:
                    'Quick revision notes, simplified core takeaways, and flash-summary cards for rapid retention.',
                buttonLabel: 'Open Quick Summary',
                buttonGradient: AppTheme.cyanGradient,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReviseSummaryScreen(
                        content: effectiveContent,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),

              // 3. Talk to Tutor Mode Card
              _buildModeCard(
                context: context,
                bgColor: const Color(0xFFFAF5FF),
                iconColor: AppTheme.lavenderAccent,
                icon: Icons.record_voice_over_rounded,
                title: 'Talk to Tutor',
                badgeText: 'Interactive AI Voice',
                description:
                    'Live conversational audio session. Discuss doubts, practice answering questions, and receive verbal feedback.',
                buttonLabel: 'Start Voice Session',
                buttonGradient: AppTheme.lavenderGradient,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LearnScreen(
                        content: effectiveContent,
                        mode: 'learn',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),

              // 4. Test Yourself Mode Card
              _buildModeCard(
                context: context,
                bgColor: const Color(0xFFFFFBEB),
                iconColor: const Color(0xFFD97706),
                icon: Icons.assignment_turned_in_rounded,
                title: 'Test Yourself',
                badgeText: '$testCount Questions · 5E / 5M / 5H',
                description:
                    'Adaptive scored test with balanced difficulty tiers (Easy, Medium, Hard). Complete test analysis at the end.',
                buttonLabel: 'Start $testCount-Question Test',
                buttonGradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TestScreen(
                        content: effectiveContent,
                        questionCount: testCount,
                      ),
                    ),
                  );
                },
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
    required String badgeText,
    required String description,
    required String buttonLabel,
    required LinearGradient buttonGradient,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: iconColor.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusXS),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: AppTheme.navyText,
                      ),
                    ),
                    Text(
                      badgeText,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        color: iconColor,
                      ),
                    ),
                  ],
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
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 20),
              decoration: BoxDecoration(
                gradient: buttonGradient,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                boxShadow: [
                  BoxShadow(
                    color: iconColor.withOpacity(0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                buttonLabel,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
