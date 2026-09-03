import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_theme.dart';
import '../../models/content_model.dart';
import '../../models/mcq_model.dart';

class ResultScreen extends StatefulWidget {
  final ContentModel content;
  final double score;
  final int totalQuestions;
  final int correctAnswers;
  final List<MCQModel> questions;
  final Map<int, int> userAnswers;
  // Optional params from backend test submission
  final List<String>? weakTopics;
  final String? performanceLabel;

  const ResultScreen({
    required this.content,
    required this.score,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.questions,
    required this.userAnswers,
    this.weakTopics,
    this.performanceLabel,
    super.key,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scoreAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scoreAnim = Tween<double>(begin: 0, end: widget.score)
        .animate(CurvedAnimation(
            parent: _controller, curve: Curves.easeOut));
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _performanceMessage {
    // Prefer backend performance label if available
    if (widget.performanceLabel != null) {
      switch (widget.performanceLabel) {
        case 'Excellent': return 'Excellent! 🎉';
        case 'Good': return 'Good work! 👍';
        case 'Fair': return 'Keep practicing 💪';
        case 'Needs Revision': return 'More study needed 📚';
      }
    }
    // Fallback: compute from score
    if (widget.score >= 8) return 'Excellent! 🎉';
    if (widget.score >= 6) return 'Good work! 👍';
    if (widget.score >= 4) return 'Keep practicing 💪';
    return 'More study needed 📚';
  }

  Color get _performanceColor {
    if (widget.score >= 8) return AppTheme.success;
    if (widget.score >= 6) return AppTheme.primaryBlue;
    if (widget.score >= 4) return AppTheme.warning;
    return AppTheme.error;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFEEF2FF),
              Color(0xFFE0E7FF),
              Color(0xFFF8FAFF),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                children: [
                  _buildTopBar(context),
                  const SizedBox(height: 40),
                  _buildScoreSection(),
                  const SizedBox(height: 32),
                  _buildBreakdownCard(),
                  const SizedBox(height: 16),
                  if (_getWeakTopics().isNotEmpty) _buildWeakTopicsCard(),
                  const SizedBox(height: 32),
                  _buildCTAButtons(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        Text(
          'Results',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 24,
            color: AppTheme.navyText,
          ),
        ),
        const Spacer(),
        Text(
          widget.content.documentName.replaceAll('.pdf', ''),
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppTheme.secondaryText,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildScoreSection() {
    return Column(
      children: [
        // Animated score ring
        SizedBox(
          width: 160,
          height: 160,
          child: AnimatedBuilder(
            animation: _scoreAnim,
            builder: (_, __) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    painter: _ScoreRingPainter(
                      progress: (_scoreAnim.value / 10).clamp(0.0, 1.0),
                      color: _performanceColor,
                    ),
                    size: const Size(160, 160),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _scoreAnim.value.toStringAsFixed(1),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w900,
                          fontSize: 48,
                          color: AppTheme.navyText,
                          letterSpacing: -2,
                        ),
                      ),
                      Text(
                        'out of 10',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: _performanceColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          ),
          child: Text(
            _performanceMessage,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: _performanceColor,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${widget.correctAnswers} of ${widget.totalQuestions} correct',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppTheme.secondaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Question Breakdown',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppTheme.navyText,
            ),
          ),
          const SizedBox(height: 16),
          ...widget.questions.asMap().entries.map((e) {
            final i = e.key;
            final q = e.value;
            final userAns = widget.userAnswers[i];
            final correct = userAns == q.correctIndex;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: correct
                          ? AppTheme.success.withOpacity(0.12)
                          : AppTheme.error.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      correct
                          ? Icons.check_rounded
                          : Icons.close_rounded,
                      color: correct ? AppTheme.success : AppTheme.error,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      q.question,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppTheme.secondaryText,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  List<String> _getWeakTopics() {
    // Prefer backend-computed weak topics if available
    if (widget.weakTopics != null && widget.weakTopics!.isNotEmpty) {
      return widget.weakTopics!;
    }
    // Fallback: compute from wrong answers locally
    final wrong = <int>[];
    widget.userAnswers.forEach((i, ans) {
      if (i < widget.questions.length &&
          ans != widget.questions[i].correctIndex) {
        wrong.add(i);
      }
    });
    return widget.content.topics.take(wrong.length).toList();
  }

  Widget _buildWeakTopicsCard() {
    final weak = _getWeakTopics();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.warning.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded,
                  color: AppTheme.warning, size: 20),
              const SizedBox(width: 8),
              Text(
                'Areas to revise',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppTheme.navyText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: weak.map((t) => Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
              child: Text(
                t,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.warning,
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCTAButtons(BuildContext context) {
    return Column(
      children: [
        AppTheme.gradientButton(
          label: 'Study Again',
          width: double.infinity,
          onTap: () => Navigator.pop(context),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => Navigator.pushNamedAndRemoveUntil(
              context, '/home', (r) => false),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              boxShadow: AppTheme.cardShadow,
              border: Border.all(color: AppTheme.divider),
            ),
            alignment: Alignment.center,
            child: Text(
              'Go Home',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: AppTheme.navyText,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Score ring custom painter
class _ScoreRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ScoreRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Background ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFFE8EDF5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ScoreRingPainter old) =>
      old.progress != progress || old.color != color;
}
