import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_theme.dart';
import '../../models/content_model.dart';
import '../../services/api_service.dart';
import '../../widgets/swipe_back_wrapper.dart';

class TopicSummaryItem {
  final String topicName;
  final String summary;
  final List<String> keyFacts;

  const TopicSummaryItem({
    required this.topicName,
    required this.summary,
    required this.keyFacts,
  });
}

class ReviseSummaryScreen extends StatefulWidget {
  final ContentModel? content;

  const ReviseSummaryScreen({this.content, super.key});

  @override
  State<ReviseSummaryScreen> createState() => _ReviseSummaryScreenState();
}

class _ReviseSummaryScreenState extends State<ReviseSummaryScreen> {
  final _api = ApiService();
  bool _isLoading = true;
  List<TopicSummaryItem> _topicSummaries = [];

  @override
  void initState() {
    super.initState();
    _loadTopicSummaries();
  }

  Future<void> _loadTopicSummaries() async {
    final effectiveContent = widget.content ??
        (ModalRoute.of(context)?.settings.arguments as ContentModel?);

    if (effectiveContent == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final session = await _api.startSession(
        documentName: effectiveContent.documentName,
        summary: effectiveContent.summary,
        keyPoints: effectiveContent.keyPoints,
        topics: effectiveContent.topics,
        mode: 'revise',
      );

      final sessionId = session['session_id'] as String;
      final topicList = effectiveContent.topics.isNotEmpty
          ? effectiveContent.topics
          : ['Core Fundamentals', 'Theoretical Framework', 'Applications & Analysis'];

      final response = await _api.interact(
        sessionId: sessionId,
        userInput:
            'Generate a clear, high-yield summary for EVERY topic in this document (${topicList.join(", ")}).\n'
            'Format each topic strictly as:\n'
            '### Topic: [Topic Name]\n'
            '[Comprehensive 2-3 paragraph summary of this topic]\n'
            'Key Takeaways:\n'
            '• [Key takeaway 1]\n'
            '• [Key takeaway 2]\n',
        interactionType: 'text',
      );

      final tutorText = response['tutor_response'] as String? ?? '';
      final parsed = _parseTopicSummaries(tutorText, topicList, effectiveContent);

      if (mounted) {
        setState(() {
          _topicSummaries = parsed.isNotEmpty
              ? parsed
              : _buildLocalTopicSummaries(effectiveContent);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[REVISE] Error fetching topic summaries: $e');
      if (mounted) {
        setState(() {
          _topicSummaries = _buildLocalTopicSummaries(effectiveContent);
          _isLoading = false;
        });
      }
    }
  }

  List<TopicSummaryItem> _parseTopicSummaries(
      String text, List<String> fallbackTopics, ContentModel content) {
    final items = <TopicSummaryItem>[];
    final sections = text.split(RegExp(r'###\s*Topic:\s*'));

    for (final section in sections) {
      final trimmed = section.trim();
      if (trimmed.isEmpty) continue;

      final lines = trimmed.split('\n');
      final topicName = lines.first.trim();
      final rest = lines.skip(1).join('\n').trim();

      String summary = '';
      final keyFacts = <String>[];

      if (rest.contains('Key Takeaways:')) {
        final parts = rest.split('Key Takeaways:');
        summary = parts[0].trim();
        final bulletLines = parts[1].split('\n');
        for (final bl in bulletLines) {
          final clean = bl.replaceAll(RegExp(r'^[•\-\*✔]\s*'), '').trim();
          if (clean.isNotEmpty) keyFacts.add(clean);
        }
      } else {
        summary = rest;
      }

      if (topicName.isNotEmpty && summary.isNotEmpty) {
        items.add(TopicSummaryItem(
          topicName: topicName,
          summary: summary,
          keyFacts: keyFacts,
        ));
      }
    }

    return items;
  }

  List<TopicSummaryItem> _buildLocalTopicSummaries(ContentModel content) {
    final items = <TopicSummaryItem>[];
    final topics = content.topics.isNotEmpty
        ? content.topics
        : ['Core Fundamentals', 'Key Principles', 'Important Applications'];

    final keyPoints = content.keyPoints;
    final text = content.extractedText;

    for (int i = 0; i < topics.length; i++) {
      final topic = topics[i];
      final topicLower = topic.toLowerCase();

      // Find matching key points for this topic
      final matchingPoints = keyPoints.where((kp) {
        final words = topicLower.split(RegExp(r'\s+'));
        return words.any((w) => w.length > 3 && kp.toLowerCase().contains(w));
      }).toList();

      final relevantKeyFacts = matchingPoints.isNotEmpty
          ? matchingPoints
          : (keyPoints.isNotEmpty ? [keyPoints[i % keyPoints.length]] : <String>[]);

      // Construct a tailored summary for this topic
      final buffer = StringBuffer();
      buffer.writeln(
          'This topic covers essential foundations of $topic within ${content.documentName.replaceAll('.pdf', '')}.');

      // Check extracted text for sentences related to this topic
      if (text.isNotEmpty) {
        final relevantSentences = text
            .split(RegExp(r'\. |\n'))
            .map((s) => s.trim())
            .where((s) {
              final words = topicLower.split(RegExp(r'\s+'));
              return s.length > 30 &&
                  words.any((w) => w.length > 3 && s.toLowerCase().contains(w));
            })
            .take(2)
            .toList();

        if (relevantSentences.isNotEmpty) {
          buffer.writeln('\n${relevantSentences.join(". ")}.');
        } else if (content.summary.isNotEmpty) {
          buffer.writeln('\n${content.summary}');
        }
      } else if (content.summary.isNotEmpty) {
        buffer.writeln('\n${content.summary}');
      }

      items.add(TopicSummaryItem(
        topicName: topic,
        summary: buffer.toString().trim(),
        keyFacts: relevantKeyFacts,
      ));
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveContent = widget.content ??
        (ModalRoute.of(context)?.settings.arguments as ContentModel?);

    if (effectiveContent == null) {
      return SwipeBackWrapper(
        fallbackRoute: '/home',
        child: Scaffold(
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
        ),
      );
    }

    final docTitle = effectiveContent.documentName.replaceAll('.pdf', '');
    final isDark = AppTheme.isDark(context);

    return SwipeBackWrapper(
      fallbackRoute: '/home',
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(context, docTitle),
              Expanded(
                child: _isLoading
                    ? _buildLoadingState(context)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                        itemCount: _topicSummaries.length,
                        itemBuilder: (context, index) {
                          final item = _topicSummaries[index];
                          return _buildTopicSummaryCard(item, index + 1, isDark);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopicSummaryCard(
      TopicSummaryItem item, int topicNumber, bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.dynamicCard(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: isDark ? null : AppTheme.cardShadow,
        border: Border.all(
          color: isDark
              ? AppTheme.darkCardBorder
              : AppTheme.cyanAccent.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Topic header with badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: AppTheme.cyanGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Text(
                  'Topic $topicNumber',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.topicName,
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.dynamicText(context),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Topic Summary Text
          Text(
            item.summary,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              height: 1.6,
              color: AppTheme.dynamicText(context),
            ),
          ),

          // Key Takeaways for this topic
          if (item.keyFacts.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0C2430)
                    : const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: Border.all(
                  color: AppTheme.cyanAccent.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.lightbulb_outline_rounded,
                        color: AppTheme.cyanAccent,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Key takeaways',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.cyanAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...item.keyFacts.map((fact) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.only(top: 7, right: 8),
                            decoration: const BoxDecoration(
                              color: AppTheme.cyanAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              fact,
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
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
              ),
            ),
          ],
        ],
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
            onTap: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacementNamed(context, '/home');
              }
            },
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
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.dynamicText(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Topic-by-topic revision',
                  style: GoogleFonts.dmSans(
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

  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppTheme.cyanAccent,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Compiling topic summaries...',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.dynamicText(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Extracting core principles for each topic in this PDF',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppTheme.dynamicSecondaryText(context),
            ),
          ),
        ],
      ),
    );
  }
}
