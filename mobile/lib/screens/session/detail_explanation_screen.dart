import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_theme.dart';
import '../../models/content_model.dart';
import '../../services/api_service.dart';

class DetailExplanationScreen extends StatefulWidget {
  final ContentModel? content;

  const DetailExplanationScreen({this.content, super.key});

  @override
  State<DetailExplanationScreen> createState() => _DetailExplanationScreenState();
}

class _DetailExplanationScreenState extends State<DetailExplanationScreen> {
  final _api = ApiService();
  bool _isLoading = true;
  String? _detailedExplanation;

  @override
  void initState() {
    super.initState();
    _loadDetailedExplanation();
  }

  Future<void> _loadDetailedExplanation() async {
    final effectiveContent = widget.content ??
        (ModalRoute.of(context)?.settings.arguments as ContentModel?);

    if (effectiveContent == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final isIndic = effectiveContent.documentLanguage == 'sa' ||
          effectiveContent.documentLanguage == 'hi' ||
          effectiveContent.responseLanguage == 'hi';

      // Start a session with correct document and response language
      final session = await _api.startSession(
        documentName: effectiveContent.documentName,
        summary: effectiveContent.summary,
        keyPoints: effectiveContent.keyPoints,
        topics: effectiveContent.topics,
        mode: 'learn',
        documentLanguage: effectiveContent.documentLanguage,
        responseLanguage: effectiveContent.documentLanguage == 'sa'
            ? 'hi'
            : effectiveContent.responseLanguage,
        languageDisplayName: effectiveContent.languageDisplayName,
      );

      final sessionId = session['session_id'] as String;

      final prompt = isIndic
          ? 'कृपया "${effectiveContent.documentName}" के सभी मुख्य सूत्रों, सिद्धांतों और विषयों की एक अत्यंत विस्तृत, गहरी और स्पष्ट व्याख्या हिंदी भाषा में प्रस्तुत करें।\n'
            'प्रत्येक मूल संस्कृत सूत्र या श्लोक को उद्धृत करते हुए उसका शब्दार्थ, भावार्थ और व्यावहारिक उदाहरण विस्तार से समझाएं।\n'
            'निम्नलिखित शीर्षकों के साथ क्रमबद्ध व्याख्या दें:\n'
            '# १. मूल अवधारणा एवं सारांश\n'
            '# २. मुख्य सूत्रों व सिद्धांतों की गहन व्याख्या\n'
            '# ३. व्यावहारिक उदाहरण व आंतरिक तंत्र\n'
            '# ४. महत्वपूर्ण पारिभाषिक शब्दावली\n'
            '# ५. परीक्षा उपयोगी मुख्य बिंदु\n'
            'कृपया पूरी व्याख्या सरल, स्पष्ट और धाराप्रवाह हिंदी में ही दें।'
          : 'Provide an extensive, comprehensive, and detailed explanation of the entire document "${effectiveContent.documentName}".\n'
            'Format with clear section headers like:\n'
            '# 1. Executive Concept Overview\n'
            '# 2. In-Depth Theoretical Breakdown\n'
            '# 3. Step-by-Step Mechanisms & Real-World Analogies\n'
            '# 4. Critical Formulas, Laws & Definitions\n'
            '# 5. Exam Readiness & High-Yield Takeaways\n'
            'Ensure every core topic is thoroughly explained so a student gets a complete, deep understanding without needing to ask questions.';

      final response = await _api.interact(
        sessionId: sessionId,
        userInput: prompt,
        interactionType: 'text',
      );

      final explanation = (response['ai_message'] ?? response['tutor_response']) as String? ?? '';

      if (mounted) {
        setState(() {
          _detailedExplanation = explanation.trim().isNotEmpty
              ? explanation
              : _buildLocalFallback(effectiveContent);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[DETAIL_EXPLAIN] Error fetching deep explanation: $e');
      if (mounted) {
        setState(() {
          _detailedExplanation = _buildLocalFallback(effectiveContent);
          _isLoading = false;
        });
      }
    }
  }

  String _buildLocalFallback(ContentModel content) {
    final isIndic = content.documentLanguage == 'sa' ||
        content.documentLanguage == 'hi' ||
        content.responseLanguage == 'hi';

    final buffer = StringBuffer();

    if (isIndic) {
      buffer.writeln('# १. मूल अवधारणा एवं विषय परिचय\n');
      buffer.writeln(content.summary.isNotEmpty
          ? content.summary
          : 'यह अध्याय ${content.documentName.replaceAll('.pdf', '')} के मूलभूत सिद्धांतों, सूत्रों और दार्शनिक भावों को विस्तार से स्पष्ट करता है।');

      if (content.keyPoints.isNotEmpty) {
        buffer.writeln('\n\n# २. मुख्य सूत्र एवं सिद्धांत\n');
        buffer.writeln('इस पाठ के अनिवार्य और आधारभूत सिद्धांत निम्नलिखित हैं:');
        for (int i = 0; i < content.keyPoints.length; i++) {
          buffer.writeln('\n• सिद्धांत ${i + 1}: ${content.keyPoints[i]}');
          buffer.writeln('  विस्तृत व्याख्या: इस सूत्र का गहन अर्थ समझें तथा संदर्भ में इसके व्यावहारिक अनुप्रयोग का मनन करें।');
        }
      }

      if (content.extractedText.isNotEmpty) {
        buffer.writeln('\n\n# ३. मूल पाठ विश्लेषण एवं व्याख्या\n');
        final rawParagraphs = content.extractedText
            .split(RegExp(r'\n{2,}|\r\n{2,}'))
            .map((p) => p.trim())
            .where((p) =>
                p.length > 30 &&
                !p.toLowerCase().contains('page ') &&
                !p.toLowerCase().contains('copyright'))
            .take(6)
            .toList();

        if (rawParagraphs.isNotEmpty) {
          for (int i = 0; i < rawParagraphs.length; i++) {
            buffer.writeln('खंड ${i + 1}:\n${rawParagraphs[i]}\n');
          }
        } else {
          buffer.writeln(content.extractedText.length > 1000
              ? '${content.extractedText.substring(0, 1000)}...'
              : content.extractedText);
        }
      }

      buffer.writeln('\n# ४. महत्वपूर्ण परीक्षा बिंदु एवं सारांश\n');
      buffer.writeln('• मूल संस्कृत शब्दावली और पारिभाषिक अर्थों का अभ्यास करें।');
      buffer.writeln('• सूत्रों के परस्पर संबंध और दार्शनिक आधार को समझें।');
      buffer.writeln('• स्व-परीक्षण द्वारा अपनी समझ की पुष्टि करें।');
      return buffer.toString();
    }

    buffer.writeln('# 1. Executive Concept Overview\n');
    buffer.writeln(content.summary.isNotEmpty
        ? content.summary
        : 'This chapter provides foundational concepts, key mechanisms, and structured principles required for mastery of ${content.documentName.replaceAll('.pdf', '')}.');

    if (content.keyPoints.isNotEmpty) {
      buffer.writeln('\n\n# 2. Core Principles & Frameworks\n');
      buffer.writeln('The following concepts represent the essential foundations of this material:');
      for (int i = 0; i < content.keyPoints.length; i++) {
        buffer.writeln('\n• Concept ${i + 1}: ${content.keyPoints[i]}');
        buffer.writeln('  Key Mechanism: Pay careful attention to how this principle interacts with surrounding context and problem solving.');
      }
    }

    if (content.extractedText.isNotEmpty) {
      buffer.writeln('\n\n# 3. Detailed Text Analysis & Breakdown\n');
      final rawParagraphs = content.extractedText
          .split(RegExp(r'\n{2,}|\r\n{2,}'))
          .map((p) => p.trim())
          .where((p) =>
              p.length > 50 &&
              !p.toLowerCase().contains('page ') &&
              !p.toLowerCase().contains('copyright') &&
              !p.toLowerCase().contains('all rights reserved'))
          .take(5)
          .toList();

      if (rawParagraphs.isNotEmpty) {
        for (int i = 0; i < rawParagraphs.length; i++) {
          buffer.writeln('Module Section ${i + 1}:\n${rawParagraphs[i]}\n');
        }
      } else {
        buffer.writeln(content.extractedText.length > 1000
            ? '${content.extractedText.substring(0, 1000)}...'
            : content.extractedText);
      }
    }

    buffer.writeln('\n# 4. Critical Exam Tips & Definitions\n');
    buffer.writeln('• Master the core terminology and definitions highlighted above.');
    buffer.writeln('• Focus on cause-and-effect relationships between primary variables.');
    buffer.writeln('• Review key vocabulary terms before taking the test.');

    buffer.writeln('\n# 5. Study Checklist\n');
    buffer.writeln('✔ Read and understand all core principles above.');
    buffer.writeln('✔ Review quick summary cards in Revise mode.');
    buffer.writeln('✔ Complete the practice test to verify mastery.');

    return buffer.toString();
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
              child: _isLoading
                  ? _buildLoadingState(context)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                      child: _buildStructuredExplanation(
                        _detailedExplanation ?? effectiveContent.summary,
                        context,
                        isDark,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStructuredExplanation(
      String rawText, BuildContext context, bool isDark) {
    final sections = rawText.split(RegExp(r'\n(?=#\s+)'));

    if (sections.length <= 1) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.dynamicCard(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          boxShadow: isDark ? null : AppTheme.cardShadow,
          border: Border.all(color: AppTheme.dynamicDivider(context)),
        ),
        child: Text(
          rawText,
          style: GoogleFonts.dmSans(
            fontSize: 14,
            height: 1.7,
            color: AppTheme.dynamicText(context),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections.map((section) {
        final lines = section.trim().split('\n');
        final header = lines.first.replaceAll(RegExp(r'^#+\s*'), '').trim();
        final body = lines.skip(1).join('\n').trim();

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.dynamicCard(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            boxShadow: isDark ? null : AppTheme.cardShadow,
            border: Border.all(color: AppTheme.dynamicDivider(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      header,
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.dynamicText(context),
                      ),
                    ),
                  ),
                ],
              ),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  color: AppTheme.dynamicDivider(context).withOpacity(0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  body,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    height: 1.6,
                    color: AppTheme.dynamicText(context),
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
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
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.dynamicText(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Detailed PDF explanation',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppTheme.primaryBlue,
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
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Structuring detailed explanation...',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.dynamicText(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Formatting concepts, mechanisms, and deep insights',
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
