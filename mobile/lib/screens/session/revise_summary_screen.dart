import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_theme.dart';
import '../../models/content_model.dart';
import '../../services/voice_service.dart';
import 'test_screen.dart';
import 'learn_screen.dart';

class ReviseSummaryScreen extends StatefulWidget {
  final ContentModel? content;

  const ReviseSummaryScreen({this.content, super.key});

  @override
  State<ReviseSummaryScreen> createState() => _ReviseSummaryScreenState();
}

class _ReviseSummaryScreenState extends State<ReviseSummaryScreen> {
  final _voice = VoiceService();
  bool _isPlayingAudio = false;

  @override
  void dispose() {
    _voice.stopPlayback();
    super.dispose();
  }

  Future<void> _toggleAudio(String text) async {
    if (_isPlayingAudio) {
      await _voice.stopPlayback();
      setState(() => _isPlayingAudio = false);
    } else {
      if (text.isEmpty) return;
      setState(() => _isPlayingAudio = true);
      try {
        await _voice.speak(text);
      } finally {
        if (mounted) setState(() => _isPlayingAudio = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveContent = widget.content ??
        (ModalRoute.of(context)?.settings.arguments as ContentModel?);

    if (effectiveContent == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(context, 'Document'),
              const Expanded(
                child: Center(child: Text('No document selected')),
              ),
            ],
          ),
        ),
      );
    }

    final docTitle = effectiveContent.documentName.replaceAll('.pdf', '');
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context, docTitle),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // High-yield Summary Hero
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [const Color(0xFF0E2A38), const Color(0xFF082032)]
                              : [const Color(0xFFECFEFF), const Color(0xFFE0F2FE)],
                        ),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusLarge),
                        border: Border.all(
                            color: AppTheme.cyanAccent.withOpacity(0.35)),
                        boxShadow: isDark ? null : AppTheme.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppTheme.cyanAccent.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.bolt_rounded,
                                  color: AppTheme.cyanAccent,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Simplified Executive Summary',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: AppTheme.dynamicText(context),
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () => _toggleAudio(effectiveContent.summary),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.dynamicCard(context),
                                    shape: BoxShape.circle,
                                    border: isDark
                                        ? Border.all(color: AppTheme.darkCardBorder)
                                        : null,
                                    boxShadow: isDark ? null : AppTheme.cardShadow,
                                  ),
                                  child: Icon(
                                    _isPlayingAudio
                                        ? Icons.stop_rounded
                                        : Icons.volume_up_rounded,
                                    color: AppTheme.cyanAccent,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            effectiveContent.summary.isNotEmpty
                                ? effectiveContent.summary
                                : 'No summary generated yet.',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              height: 1.65,
                              color: AppTheme.dynamicText(context),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Quick Flash Takeaways
                    if (effectiveContent.keyPoints.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.lightbulb_outline_rounded,
                            color: AppTheme.warning,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Must-Remember Key Facts',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.dynamicText(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ...effectiveContent.keyPoints.asMap().entries.map((entry) {
                        final index = entry.key;
                        final point = entry.value;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.dynamicCard(context),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMedium),
                            boxShadow: isDark ? null : AppTheme.cardShadow,
                            border: Border.all(
                                color: isDark
                                    ? AppTheme.darkCardBorder
                                    : const Color(0xFFF1F5F9)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppTheme.cyanAccent.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${index + 1}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.cyanAccent,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  point,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    height: 1.55,
                                    color: AppTheme.dynamicText(context),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],

                    const SizedBox(height: 20),

                    // Core Topics Cloud
                    if (effectiveContent.topics.isNotEmpty) ...[
                      Text(
                        'Core Concepts Tested',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.navyText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: effectiveContent.topics.map((topic) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusPill),
                              border: Border.all(
                                  color: AppTheme.cyanAccent.withOpacity(0.3)),
                              boxShadow: AppTheme.cardShadow,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_rounded,
                                  size: 14,
                                  color: AppTheme.cyanAccent,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  topic,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.navyText,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: AppTheme.gradientButton(
                label: 'Test Knowledge (15Q)',
                gradient: AppTheme.cyanGradient,
                onTap: () {
                  final count =
                      effectiveContent.extractedText.length > 5000 ? 20 : 15;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TestScreen(
                        content: effectiveContent,
                        questionCount: count,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LearnScreen(
                      content: effectiveContent,
                      mode: 'revise',
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkBackgroundAlt : AppTheme.backgroundAlt,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  border: Border.all(color: AppTheme.dynamicDivider(context)),
                ),
                child: const Icon(
                  Icons.mic_rounded,
                  color: AppTheme.primaryBlue,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, String title) {
    final isDark = AppTheme.isDark(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.dynamicCard(context),
                shape: BoxShape.circle,
                border: isDark ? Border.all(color: AppTheme.darkCardBorder) : null,
                boxShadow: isDark ? null : AppTheme.cardShadow,
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: AppTheme.dynamicText(context),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.dynamicText(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Quick Revision Summary',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.cyanAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
