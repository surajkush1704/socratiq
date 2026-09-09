import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_theme.dart';
import '../../models/content_model.dart';
import '../../models/mcq_model.dart';
import '../../services/api_service.dart';
import '../../services/sync_service.dart';
import '../../widgets/app_page_route.dart';
import '../../widgets/swipe_back_wrapper.dart';
import 'result_screen.dart';

class TestScreen extends StatefulWidget {
  final ContentModel content;
  final int questionCount;

  const TestScreen({
    required this.content,
    this.questionCount = 15,
    super.key,
  });

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen>
    with SingleTickerProviderStateMixin {

  final _api = ApiService();

  // ── Loading state ───────────────────────────────────────────────────────
  bool _loadingQuestions = true;
  String? _loadError;

  // ── Test state ──────────────────────────────────────────────────────────
  List<MCQModel> _questions = [];
  int _currentIndex = 0;
  final Map<int, int> _selectedAnswers = {}; // questionIndex → optionIndex
  bool _submitting = false;

  // ── Progress animation ──────────────────────────────────────────────────
  late AnimationController _progressController;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _progressAnim = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOut,
    );
    _fetchQuestions();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _fetchQuestions() async {
    try {
      setState(() {
        _loadingQuestions = true;
        _loadError = null;
      });

      print('[TEST] Fetching ${widget.questionCount} questions...');

      final rawQuestions = await _api.generateTest(
        documentName: widget.content.documentName,
        summary: widget.content.summary,
        keyPoints: widget.content.keyPoints,
        topics: widget.content.topics,
        questionCount: widget.questionCount,
      );

      final questions = rawQuestions.map((q) => MCQModel(
        question: q['question'] as String? ?? '',
        options: List<String>.from(q['options'] ?? []),
        correctIndex: q['correct_index'] as int? ?? 0,
        explanation: q['explanation'] as String? ?? '',
        difficulty: (q['difficulty'] as String? ?? 'medium').toLowerCase(),
      )).toList();

      if (questions.isEmpty) {
        setState(() {
          _loadError = 'Could not generate questions. Try again.';
          _loadingQuestions = false;
        });
        return;
      }

      setState(() {
        _questions = questions;
        _loadingQuestions = false;
      });

      // Animate first question progress bar
      _animateProgressTo(0);
      print('[TEST] ${questions.length} questions loaded');

    } catch (e) {
      print('[TEST] Fetch questions error: $e');
      final fallbackQuestions = _generateLocalQuestions(
        widget.content,
        widget.questionCount,
      );

      if (fallbackQuestions.isNotEmpty) {
        print('[TEST] Loaded ${fallbackQuestions.length} offline fallback questions');
        if (mounted) {
          setState(() {
            _questions = fallbackQuestions;
            _loadingQuestions = false;
            _loadError = null;
          });
          _animateProgressTo(0);
        }
        return;
      }

      if (mounted) {
        setState(() {
          _loadError = e.toString().replaceAll('Exception: ', '');
          _loadingQuestions = false;
        });
      }
    }
  }

  List<MCQModel> _generateLocalQuestions(ContentModel content, int targetCount) {
    final questions = <MCQModel>[];
    final keyPoints = content.keyPoints;
    final summary = content.summary;
    final topics = content.topics;

    if (keyPoints.isNotEmpty) {
      for (int i = 0; i < keyPoints.length; i++) {
        final kp = keyPoints[i];
        final otherPoints = keyPoints.where((p) => p != kp).toList();

        final options = <String>[
          kp,
          otherPoints.isNotEmpty ? 'Inverse proposition: opposite of standard behavior' : 'No relation to topic',
          'Only applies under obsolete historical frameworks',
          'Contradicts empirical observations in this chapter',
        ]..shuffle();
        final correctIdx = options.indexOf(kp);

        questions.add(MCQModel(
          question: 'According to the study material, which of the following is an established principle regarding "${topics.isNotEmpty ? topics[i % topics.length] : 'the chapter'}"?',
          options: options,
          correctIndex: correctIdx,
          explanation: kp,
          difficulty: i % 3 == 0 ? 'easy' : (i % 3 == 1 ? 'medium' : 'hard'),
        ));

        if (questions.length >= targetCount) break;

        if (otherPoints.length >= 2) {
          final q2Options = <String>[
            kp,
            'It was officially disproven by subsequent research',
            otherPoints[0],
            otherPoints[1],
          ]..shuffle();
          questions.add(MCQModel(
            question: 'Which of the following is identified as a critical concept in ${content.documentName.replaceAll('.pdf', '')}?',
            options: q2Options,
            correctIndex: q2Options.indexOf(kp),
            explanation: 'Document key principle: $kp',
            difficulty: 'medium',
          ));
        }

        if (questions.length >= targetCount) break;
      }
    }

    if (questions.length < targetCount && summary.isNotEmpty) {
      final sentences = summary
          .split(RegExp(r'\. |\n'))
          .map((s) => s.trim())
          .where((s) => s.length > 20)
          .toList();

      for (final s in sentences) {
        if (questions.length >= targetCount) break;
        final opts = <String>[
          s,
          'A disproven hypothesis rejected by the author',
          'An unrelated concept not addressed in this text',
          'The exact opposite of the conclusion presented',
        ]..shuffle();

        questions.add(MCQModel(
          question: 'Which statement accurately reflects the core analysis of this chapter?',
          options: opts,
          correctIndex: opts.indexOf(s),
          explanation: s,
          difficulty: 'easy',
        ));
      }
    }

    return questions;
  }

  void _animateProgressTo(int questionIndex) {
    if (_questions.isEmpty) return;
    final target = (questionIndex + 1) / _questions.length;
    _progressAnim = Tween<double>(
      begin: _progressAnim.value,
      end: target,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOut,
    ));
    _progressController.reset();
    _progressController.forward();
  }

  void _selectOption(int optionIndex) {
    setState(() => _selectedAnswers[_currentIndex] = optionIndex);
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() => _currentIndex++);
      _animateProgressTo(_currentIndex);
    }
  }

  void _previousQuestion() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _animateProgressTo(_currentIndex);
    }
  }

  Future<void> _finishTest() async {
    // Check if all questions answered
    final unanswered = _questions.length - _selectedAnswers.length;
    if (unanswered > 0) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
          title: Text(
            '$unanswered question${unanswered > 1 ? 's' : ''} unanswered',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
          ),
          content: Text(
            'You have not answered all questions. '
            'Unanswered questions will be marked wrong.',
            style: GoogleFonts.dmSans(
                fontSize: 14, color: AppTheme.secondaryText, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Go back',
                  style: GoogleFonts.dmSans(
                      color: AppTheme.primaryBlue, fontWeight: FontWeight.w600)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Submit anyway',
                  style: GoogleFonts.dmSans(
                      color: AppTheme.error,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => _submitting = true);

    try {
      // Build answers payload for backend
      final answers = <Map<String, dynamic>>[];
      for (int i = 0; i < _questions.length; i++) {
        final q = _questions[i];
        final selectedIdx = _selectedAnswers[i] ?? -1;
        final selectedAnswer = selectedIdx >= 0 && selectedIdx < q.options.length
            ? q.options[selectedIdx]
            : 'No answer';

        answers.add({
          'question': q.question,
          'correct_answer': q.options[q.correctIndex],
          'user_answer': selectedAnswer,
          'selected_index': selectedIdx >= 0 ? selectedIdx : q.correctIndex + 1,
          'correct_index': q.correctIndex,
        });
      }

      print('[TEST] Submitting ${answers.length} answers to backend...');

      final result = await _api.submitTest(
        documentName: widget.content.documentName,
        summary: widget.content.summary,
        answers: answers,
      );

      print('[TEST] Result received: avg=${result['avg_score']}');

      if (!mounted) return;

      // Convert backend result to ResultScreen format
      final avgScoreOutOf10 = (result['avg_score'] as num).toDouble() / 10;
      final correctCount = result['correct_count'] as int;
      final weakTopics = List<String>.from(result['weak_topics'] ?? []);
      final performanceLabel = result['performance_label'] as String? ?? 'Fair';

      // Sync test session to Firestore
      SyncService.syncSession(
        sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
        documentName: widget.content.documentName,
        mode: 'test',
        durationSec: 300, // placeholder — test duration tracking in Phase 7
        score: avgScoreOutOf10,
        questionsAttempted: _questions.length,
        questionsCorrect: correctCount,
        topics: widget.content.topics,
      ).then((r) => print('[TEST] Session synced: streak=${r['new_streak']}'))
       .catchError((e) => print('[TEST] Sync error (non-fatal): $e'));

      Navigator.pushReplacement(
        context,
        AppPageRoute(
          builder: (_) => ResultScreen(
            content: widget.content,
            score: avgScoreOutOf10,
            totalQuestions: _questions.length,
            correctAnswers: correctCount,
            questions: _questions,
            userAnswers: _selectedAnswers,
            weakTopics: weakTopics,
            performanceLabel: performanceLabel,
          ),
        ),
      );

    } catch (e) {
      print('[TEST] Submit error: $e — computing score locally');
      int localCorrect = 0;
      for (int i = 0; i < _questions.length; i++) {
        if (_selectedAnswers[i] == _questions[i].correctIndex) {
          localCorrect++;
        }
      }
      final localScoreOutOf10 = _questions.isNotEmpty
          ? (localCorrect / _questions.length) * 10.0
          : 0.0;
      final label = localScoreOutOf10 >= 8.0
          ? 'Excellent'
          : (localScoreOutOf10 >= 5.0 ? 'Good' : 'Needs Practice');

      if (mounted) {
        setState(() => _submitting = false);
        Navigator.pushReplacement(
          context,
          AppPageRoute(
            builder: (_) => ResultScreen(
              content: widget.content,
              score: localScoreOutOf10,
              totalQuestions: _questions.length,
              correctAnswers: localCorrect,
              questions: _questions,
              userAnswers: _selectedAnswers,
              weakTopics: widget.content.topics,
              performanceLabel: label,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SwipeBackWrapper(
      fallbackRoute: '/home',
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: _loadingQuestions
              ? _buildLoadingState()
              : _loadError != null
                  ? _buildErrorState()
                  : _buildTestUI(),
        ),
      ),
    );
  }

  // ── LOADING STATE ─────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    final isDark = AppTheme.isDark(context);
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final textCol = AppTheme.dynamicText(context);
    final secCol = AppTheme.dynamicSecondaryText(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1E3A8A).withOpacity(isDark ? 0.25 : 0.06),
            bg,
          ],
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                Text(
                  'Cancel',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.dynamicSecondaryText(context),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated loading indicator
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: const AlwaysStoppedAnimation(
                          AppTheme.primaryBlue),
                      backgroundColor: isDark ? AppTheme.darkDivider : AppTheme.divider,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Preparing your test...',
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: textCol,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Generating ${widget.questionCount} questions\nfrom your document',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: secCol,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Loading stages text
                  _buildLoadingStages(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingStages() {
    final stages = [
      'Reading document content...',
      'Forming questions...',
      'Checking difficulty balance...',
      'Almost ready...',
    ];

    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: stages.length - 1),
      duration: const Duration(seconds: 4),
      builder: (_, value, __) {
        return Text(
          stages[value.clamp(0, stages.length - 1)],
          style: GoogleFonts.dmSans(
            fontSize: 13,
            color: AppTheme.cyanAccent,
            fontWeight: FontWeight.w400,
          ),
        );
      },
    );
  }

  // ── ERROR STATE ───────────────────────────────────────────────────────────

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.error.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline_rounded,
                color: AppTheme.error, size: 40),
          ),
          const SizedBox(height: 20),
          Text(
            'Could not generate test',
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppTheme.navyText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _loadError ?? 'Unknown error',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: AppTheme.secondaryText,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          AppTheme.gradientButton(
            label: 'Try again',
            width: 200,
            onTap: _fetchQuestions,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacementNamed(context, '/home');
              }
            },
            child: Text(
              'Go back',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── TEST UI ───────────────────────────────────────────────────────────────

  Widget _buildTestUI() {
    if (_questions.isEmpty) return _buildErrorState();

    final question = _questions[_currentIndex];
    final selectedIdx = _selectedAnswers[_currentIndex];
    final isLast = _currentIndex == _questions.length - 1;
    final answeredCount = _selectedAnswers.length;

    return Column(
      children: [
        _buildTestTopBar(answeredCount),
        _buildProgressBar(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildQuestionCard(question),
                const SizedBox(height: 20),
                ..._buildOptions(question, selectedIdx),
                const SizedBox(height: 32),
                _buildNavigationRow(isLast, selectedIdx),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTestTopBar(int answeredCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          // Back / Exit button
          GestureDetector(
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMedium)),
                  title: Text('Exit test?',
                      style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700)),
                  content: Text(
                    'Your progress will be lost.',
                    style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: AppTheme.secondaryText,
                        height: 1.5),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('Continue',
                          style: GoogleFonts.dmSans(
                              color: AppTheme.primaryBlue,
                              fontWeight: FontWeight.w600)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text('Exit',
                          style: GoogleFonts.dmSans(
                              color: AppTheme.error,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              );
              if (confirm == true && mounted) {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushReplacementNamed(context, '/home');
                }
              }
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.dynamicCard(context),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.dynamicDivider(context)),
                boxShadow: AppTheme.isDark(context) ? [] : AppTheme.cardShadow,
              ),
              child: Icon(Icons.arrow_back_rounded,
                  color: AppTheme.dynamicText(context), size: 20),
            ),
          ),
          const SizedBox(width: 16),
          // Question counter
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Question ${_currentIndex + 1} of ${_questions.length}',
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppTheme.dynamicText(context),
                  ),
                ),
                Text(
                  '$answeredCount answered',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppTheme.dynamicSecondaryText(context),
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
          // Answered count chip
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.10),
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            ),
            child: Text(
              '$answeredCount/${_questions.length}',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryBlue,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final isDark = AppTheme.isDark(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: AnimatedBuilder(
        animation: _progressAnim,
        builder: (_, __) => Column(
          children: [
            // Segmented progress — one segment per question
            Row(
              children: List.generate(_questions.length, (i) {
                final answered = _selectedAnswers.containsKey(i);
                final current = i == _currentIndex;
                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 6,
                    margin: EdgeInsets.only(
                        right: i < _questions.length - 1 ? 4 : 0),
                    decoration: BoxDecoration(
                      color: answered
                          ? AppTheme.primaryBlue
                          : current
                              ? AppTheme.primaryBlue.withOpacity(0.35)
                              : (isDark ? AppTheme.darkDivider : AppTheme.divider),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(MCQModel question) {
    final isDark = AppTheme.isDark(context);
    final diff = question.difficulty.toLowerCase();
    Color diffColor;
    Color diffBg;
    String diffLabel;
    IconData diffIcon;

    if (diff == 'easy') {
      diffColor = const Color(0xFF059669);
      diffBg = isDark ? const Color(0xFF064E3B).withOpacity(0.4) : const Color(0xFFD1FAE5);
      diffLabel = 'Easy';
      diffIcon = Icons.sentiment_satisfied_alt_rounded;
    } else if (diff == 'hard') {
      diffColor = const Color(0xFFDC2626);
      diffBg = isDark ? const Color(0xFF7F1D1D).withOpacity(0.4) : const Color(0xFFFEE2E2);
      diffLabel = 'Hard';
      diffIcon = Icons.local_fire_department_rounded;
    } else {
      diffColor = const Color(0xFFD97706);
      diffBg = isDark ? const Color(0xFF78350F).withOpacity(0.4) : const Color(0xFFFEF3C7);
      diffLabel = 'Medium';
      diffIcon = Icons.trending_up_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.dynamicCard(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.dynamicDivider(context)),
        boxShadow: isDark ? [] : AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Question number badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Text(
                  'Q${_currentIndex + 1}',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryBlue,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Difficulty badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: diffBg,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(diffIcon, size: 13, color: diffColor),
                    const SizedBox(width: 4),
                    Text(
                      diffLabel,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: diffColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            question.question,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppTheme.dynamicText(context),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildOptions(MCQModel question, int? selectedIdx) {
    final isDark = AppTheme.isDark(context);
    final cardBg = AppTheme.dynamicCard(context);
    final borderColor = AppTheme.dynamicDivider(context);
    final textCol = AppTheme.dynamicText(context);
    final secCol = AppTheme.dynamicSecondaryText(context);

    return List.generate(question.options.length, (i) {
      final selected = selectedIdx == i;

      return GestureDetector(
        onTap: () => _selectOption(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primaryBlue.withOpacity(isDark ? 0.18 : 0.06)
                : cardBg,
            borderRadius:
                BorderRadius.circular(AppTheme.radiusSmall),
            border: Border.all(
              color: selected
                  ? AppTheme.primaryBlue
                  : borderColor,
              width: selected ? 2 : 1.5,
            ),
            boxShadow: isDark ? [] : AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              // Option letter circle
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.primaryBlue
                      : (isDark ? AppTheme.darkBackgroundAlt : AppTheme.backgroundAlt),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  ['A', 'B', 'C', 'D'][i],
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: selected
                        ? Colors.white
                        : secCol,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Option text
              Expanded(
                child: Text(
                  question.options[i],
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: selected
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: selected
                        ? textCol
                        : secCol,
                    height: 1.4,
                  ),
                ),
              ),
              // Selected check
              if (selected)
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 14),
                ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildNavigationRow(bool isLast, int? selectedIdx) {
    return Column(
      children: [
        // Previous / Next row
        Row(
          children: [
            // Previous button (hidden on first question)
            if (_currentIndex > 0)
              Expanded(
                child: GestureDetector(
                  onTap: _previousQuestion,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusPill),
                      border: Border.all(color: AppTheme.divider),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.arrow_back_rounded,
                            color: AppTheme.navyText, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Previous',
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppTheme.navyText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_currentIndex > 0) const SizedBox(width: 12),
            // Next / Finish button
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: _submitting
                    ? null
                    : isLast
                        ? _finishTest
                        : (selectedIdx != null ? _nextQuestion : null),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: (selectedIdx != null || isLast)
                        ? AppTheme.primaryGradient
                        : null,
                    color: (selectedIdx == null && !isLast)
                        ? AppTheme.divider
                        : null,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusPill),
                    boxShadow: (selectedIdx != null || isLast)
                        ? AppTheme.buttonShadow
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isLast ? 'Finish test' : 'Next',
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: (selectedIdx != null || isLast)
                                    ? Colors.white
                                    : AppTheme.lightText,
                              ),
                            ),
                            if (!isLast) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: selectedIdx != null
                                    ? Colors.white
                                    : AppTheme.lightText,
                                size: 18,
                              ),
                            ],
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
        // Skip hint text
        if (selectedIdx == null && !isLast)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Select an answer to continue',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppTheme.lightText,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        // Question dot navigator
        const SizedBox(height: 20),
        _buildDotNavigator(),
      ],
    );
  }

  Widget _buildDotNavigator() {
    final isDark = AppTheme.isDark(context);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      children: List.generate(_questions.length, (i) {
        final answered = _selectedAnswers.containsKey(i);
        final current = i == _currentIndex;
        return GestureDetector(
          onTap: () {
            setState(() => _currentIndex = i);
            _animateProgressTo(i);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: current ? 24 : 10,
            height: 10,
            decoration: BoxDecoration(
              color: current
                  ? AppTheme.primaryBlue
                  : answered
                      ? AppTheme.cyanAccent
                      : (isDark ? AppTheme.darkDivider : AppTheme.divider),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}
