import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_theme.dart';
import '../../models/content_model.dart';
import '../../models/mcq_model.dart';
import '../../services/api_service.dart';
import '../../services/sync_service.dart';
import 'result_screen.dart';

class TestScreen extends StatefulWidget {
  final ContentModel content;
  final int questionCount;

  const TestScreen({
    required this.content,
    this.questionCount = 5,
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
      setState(() {
        _loadError = e.toString().replaceAll('Exception: ', '');
        _loadingQuestions = false;
      });
    }
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
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          content: Text(
            'You have not answered all questions. '
            'Unanswered questions will be marked wrong.',
            style: GoogleFonts.poppins(
                fontSize: 14, color: AppTheme.secondaryText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Go Back',
                  style: GoogleFonts.poppins(
                      color: AppTheme.primaryBlue)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Submit Anyway',
                  style: GoogleFonts.poppins(
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
        MaterialPageRoute(
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
      print('[TEST] Submit error: $e');
      setState(() => _submitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Failed to submit test: ${e.toString().replaceAll('Exception: ', '')}',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: _loadingQuestions
            ? _buildLoadingState()
            : _loadError != null
                ? _buildErrorState()
                : _buildTestUI(),
      ),
    );
  }

  // ── LOADING STATE ─────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1E3A8A).withOpacity(0.06),
            AppTheme.background,
          ],
        ),
      ),
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
                backgroundColor: AppTheme.divider,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Preparing your test...',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppTheme.navyText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Generating ${widget.questionCount} questions\nfrom your document',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.secondaryText,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            // Loading stages text
            _buildLoadingStages(),
          ],
        ),
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
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppTheme.cyanAccent,
            fontWeight: FontWeight.w500,
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
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: AppTheme.navyText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _loadError ?? 'Unknown error',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.secondaryText,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          AppTheme.gradientButton(
            label: 'Try Again',
            width: 200,
            onTap: _fetchQuestions,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Text(
              'Go Back',
              style: GoogleFonts.poppins(
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
          // Close button
          GestureDetector(
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMedium)),
                  title: Text('Exit Test?',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700)),
                  content: Text(
                    'Your progress will be lost.',
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppTheme.secondaryText),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('Continue',
                          style: GoogleFonts.poppins(
                              color: AppTheme.primaryBlue)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text('Exit',
                          style: GoogleFonts.poppins(
                              color: AppTheme.error,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              );
              if (confirm == true && mounted) Navigator.pop(context);
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: AppTheme.cardShadow,
              ),
              child: const Icon(Icons.close_rounded,
                  color: AppTheme.navyText, size: 20),
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
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppTheme.navyText,
                  ),
                ),
                Text(
                  '$answeredCount answered',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.secondaryText,
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
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
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
                              : AppTheme.divider,
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
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryBlue,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            question.question,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: AppTheme.navyText,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildOptions(MCQModel question, int? selectedIdx) {
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
                ? AppTheme.primaryBlue.withOpacity(0.06)
                : Colors.white,
            borderRadius:
                BorderRadius.circular(AppTheme.radiusSmall),
            border: Border.all(
              color: selected
                  ? AppTheme.primaryBlue
                  : AppTheme.divider,
              width: selected ? 2 : 1.5,
            ),
            boxShadow: AppTheme.cardShadow,
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
                      : AppTheme.backgroundAlt,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  ['A', 'B', 'C', 'D'][i],
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: selected
                        ? Colors.white
                        : AppTheme.secondaryText,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Option text
              Expanded(
                child: Text(
                  question.options[i],
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: selected
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: selected
                        ? AppTheme.navyText
                        : AppTheme.secondaryText,
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
                          style: GoogleFonts.poppins(
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
                              isLast ? 'Finish Test' : 'Next',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
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
              style: GoogleFonts.poppins(
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
                      : AppTheme.divider,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}
