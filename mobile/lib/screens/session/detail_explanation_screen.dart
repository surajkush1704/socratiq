import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_theme.dart';
import '../../models/content_model.dart';
import '../../services/api_service.dart';
import '../../services/voice_service.dart';
import 'learn_screen.dart';

class DetailExplanationScreen extends StatefulWidget {
  final ContentModel? content;

  const DetailExplanationScreen({this.content, super.key});

  @override
  State<DetailExplanationScreen> createState() => _DetailExplanationScreenState();
}

class _DetailExplanationScreenState extends State<DetailExplanationScreen> {
  final _api = ApiService();
  final _voice = VoiceService();
  bool _isLoading = true;
  String? _detailedExplanation;
  bool _isPlayingAudio = false;

  @override
  void initState() {
    super.initState();
    _loadDetailedExplanation();
  }

  @override
  void dispose() {
    _voice.stopPlayback();
    super.dispose();
  }

  Future<void> _loadDetailedExplanation() async {
    final effectiveContent = widget.content ??
        (ModalRoute.of(context)?.settings.arguments as ContentModel?);

    if (effectiveContent == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Start a temporary session to ask for an in-depth pedagogical breakdown
      final session = await _api.startSession(
        documentName: effectiveContent.documentName,
        summary: effectiveContent.summary,
        keyPoints: effectiveContent.keyPoints,
        topics: effectiveContent.topics,
        mode: 'learn',
      );

      final sessionId = session['session_id'] as String;
      final response = await _api.interact(
        sessionId: sessionId,
        userInput:
            'Please give me a complete, structured, and in-depth pedagogical explanation of all main concepts, principles, and key examples in this document. Break it into clear sections with simple analogies.',
        interactionType: 'text',
      );

      final explanation = response['tutor_response'] as String? ??
          effectiveContent.summary;

      if (mounted) {
        setState(() {
          _detailedExplanation = explanation;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[DETAIL_EXPLAIN] Error fetching deep explanation: $e');
      if (mounted) {
        setState(() {
          // Graceful fallback using local document content
          _detailedExplanation = _buildLocalFallback(effectiveContent);
          _isLoading = false;
        });
      }
    }
  }

  String _buildLocalFallback(ContentModel content) {
    final buffer = StringBuffer();
    buffer.writeln(content.summary);
    if (content.keyPoints.isNotEmpty) {
      buffer.writeln('\n\nCore Principles & Concepts:');
      for (final kp in content.keyPoints) {
        buffer.writeln('• $kp');
      }
    }
    return buffer.toString();
  }

  Future<void> _toggleAudio() async {
    if (_isPlayingAudio) {
      await _voice.stopPlayback();
      setState(() => _isPlayingAudio = false);
    } else {
      final text = _detailedExplanation ?? widget.content?.summary ?? '';
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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context, docTitle),
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Topic badges
                          if (effectiveContent.topics.isNotEmpty) ...[
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: effectiveContent.topics.take(4).map((t) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryBlue.withOpacity(0.08),
                                    borderRadius:
                                        BorderRadius.circular(AppTheme.radiusPill),
                                    border: Border.all(
                                        color: AppTheme.primaryBlue
                                            .withOpacity(0.2)),
                                  ),
                                  child: Text(
                                    t,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Audio listen card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primaryBlue.withOpacity(0.08),
                                  AppTheme.cyanAccent.withOpacity(0.08),
                                ],
                              ),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMedium),
                              border: Border.all(
                                  color: AppTheme.primaryBlue.withOpacity(0.15)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: const BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      _isPlayingAudio
                                          ? Icons.stop_rounded
                                          : Icons.volume_up_rounded,
                                      color: Colors.white,
                                    ),
                                    onPressed: _toggleAudio,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _isPlayingAudio
                                            ? 'Reading Explanation...'
                                            : 'Listen to Audio Lesson',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: AppTheme.dynamicText(context),
                                        ),
                                      ),
                                      Text(
                                        'Powered by Neural AI Voice',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: AppTheme.dynamicSecondaryText(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Detailed Explanation Header
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppTheme.lavenderAccent.withOpacity(0.15),
                                  borderRadius:
                                      BorderRadius.circular(AppTheme.radiusXS),
                                ),
                                child: const Icon(
                                  Icons.auto_stories_rounded,
                                  color: AppTheme.lavenderAccent,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'In-Depth Breakdown',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.dynamicText(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Main Explanation Content Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.dynamicCard(context),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusLarge),
                              boxShadow: AppTheme.isDark(context) ? null : AppTheme.cardShadow,
                              border: Border.all(color: AppTheme.dynamicDivider(context)),
                            ),
                            child: Text(
                              _detailedExplanation ??
                                  effectiveContent.summary,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                height: 1.7,
                                color: AppTheme.dynamicText(context),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Key Concepts Section
                          if (effectiveContent.keyPoints.isNotEmpty) ...[
                            Text(
                              'Key Insights & Takeaways',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.dynamicText(context),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...effectiveContent.keyPoints.map((point) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppTheme.dynamicCard(context),
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusMedium),
                                  boxShadow: AppTheme.isDark(context) ? null : AppTheme.cardShadow,
                                  border: Border.all(
                                      color: AppTheme.dynamicDivider(context)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: AppTheme.success,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        point,
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          height: 1.5,
                                          color: AppTheme.dynamicSecondaryText(context),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
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
          color: AppTheme.dynamicCard(context),
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
                label: 'Talk to Tutor About This',
                gradient: AppTheme.lavenderGradient,
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
                  'Detailed Explanation',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Analyzing and structuring explanation...',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.navyText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Preparing concepts, theorems & examples',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppTheme.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}
