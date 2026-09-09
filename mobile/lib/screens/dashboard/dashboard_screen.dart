import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../../app_theme.dart';
import '../../services/hive_service.dart';
import '../../services/sync_service.dart';
import '../../widgets/glass_nav.dart';
import '../../widgets/app_page_route.dart';
import '../session/learn_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {

  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _recentSessions = [];
  bool _loading = true;

  late AnimationController _barController;
  late Animation<double> _barAnim;

  @override
  void initState() {
    super.initState();
    _barController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _barAnim = CurvedAnimation(
        parent: _barController, curve: Curves.easeOut);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
    });
    try {
      final stats = await SyncService.getUserStats();
      final sessions = await SyncService.getRecentActivity(limit: 8);
      if (mounted) {
        setState(() {
          _stats = stats;
          _recentSessions = sessions;
          _loading = false;
        });
        _barController.reset();
        _barController.forward();
      }
    } catch (e) {
      print('[DASHBOARD] Load error: $e');
      if (mounted) setState(() { _loading = false; });
    }
  }

  void _onNavTap(int index) {
    if (index == 0) Navigator.pushReplacementNamed(context, '/home');
    if (index == 1) Navigator.pushReplacementNamed(context, '/library');
    if (index == 2) {
      Navigator.push(
        context,
        AppPageRoute(builder: (_) => const LearnScreen(mode: 'learn')),
      );
    }
    if (index == 3) return;
    if (index == 4) Navigator.pushReplacementNamed(context, '/settings');
  }

  @override
  void dispose() {
    _barController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: AppTheme.primaryBlue,
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _loading ? _buildShimmerStreak() : _buildStreakHero(),
                    const SizedBox(height: 16),
                    _loading ? _buildShimmerRow() : _buildBentoStats(),
                    const SizedBox(height: 20),
                    _buildWeeklyActivity(),
                    const SizedBox(height: 20),
                    _buildAccuracyCard(),
                    const SizedBox(height: 20),
                    _buildTopicMastery(),
                    const SizedBox(height: 20),
                    if (_recentSessions.isNotEmpty) _buildSessionHistory(),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: GlassNav(currentIndex: 3, onTap: _onNavTap),
          ),
        ],
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final isDark = AppTheme.isDark(context);
    return Row(
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
            width: 38,
            height: 38,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: AppTheme.dynamicCard(context),
              shape: BoxShape.circle,
              border: isDark
                  ? Border.all(color: AppTheme.darkCardBorder)
                  : null,
              boxShadow: isDark ? null : AppTheme.cardShadow,
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              color: AppTheme.dynamicText(context),
              size: 20,
            ),
          ),
        ),
        Expanded(
          child: Text(
            'PROGRESS',
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 26,
              color: AppTheme.dynamicText(context),
              letterSpacing: 1.2,
            ),
          ),
        ),
        if (!_loading)
          GestureDetector(
            onTap: _loadData,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.dynamicCard(context),
                shape: BoxShape.circle,
                border: isDark
                    ? Border.all(color: AppTheme.darkCardBorder)
                    : null,
                boxShadow: isDark ? null : AppTheme.cardShadow,
              ),
              child: Icon(Icons.refresh_rounded,
                  color: AppTheme.dynamicText(context), size: 18),
            ),
          ),
      ],
    );
  }

  // ── STREAK HERO ───────────────────────────────────────────────────────────

  Widget _buildStreakHero() {
    final streak = _stats['streak'] ?? 0;
    final longest = _stats['longestStreak'] ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A8A), Color(0xFF2355F5)],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.buttonShadow,
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 52)),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$streak',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 48,
                  color: Colors.white,
                  letterSpacing: -0.5,
                  height: 1.0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                'day streak',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.75),
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                streak == 0
                    ? 'Study today to start!'
                    : 'Keep it up! 🚀',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Best: $longest days',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── BENTO STATS ───────────────────────────────────────────────────────────

  Widget _buildBentoStats() {
    final sessions = _stats['totalSessions'] ?? 0;
    final totalTimeSec = _stats['totalStudyTimeSec'] ?? 0;
    final todayTimeSec = _stats['todayTimeSec'] ?? 0;
    final todaySessions = _stats['todaySessions'] ?? 0;
    final isDark = AppTheme.isDark(context);

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.dynamicCard(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: isDark ? Border.all(color: AppTheme.darkCardBorder) : null,
              boxShadow: isDark ? null : AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📚',
                    style: TextStyle(fontSize: 28)),
                const SizedBox(height: 8),
                Text(
                  '$sessions',
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 30,
                    color: AppTheme.dynamicText(context),
                    height: 1.0,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  'total sessions',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppTheme.dynamicSecondaryText(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Today: $todaySessions session${todaySessions != 1 ? 's' : ''}',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: isDark ? Border.all(color: AppTheme.darkCardBorder) : null,
                  boxShadow: isDark ? null : AppTheme.cardShadow,
                ),
                child: Row(
                  children: [
                    const Text('⏱',
                        style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          SyncService.formatDuration(totalTimeSec),
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppTheme.dynamicText(context),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          'total study time',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: AppTheme.dynamicSecondaryText(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F2537) : const Color(0xFFECFEFF),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: isDark ? Border.all(color: AppTheme.darkCardBorder) : null,
                  boxShadow: isDark ? null : AppTheme.cardShadow,
                ),
                child: Row(
                  children: [
                    const Text('📅',
                        style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          SyncService.formatDuration(todayTimeSec),
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppTheme.dynamicText(context),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          'studied today',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: AppTheme.dynamicSecondaryText(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── WEEKLY ACTIVITY CHART ─────────────────────────────────────────────────

  Widget _buildWeeklyActivity() {
    final weeklyData = _stats['weeklyData'] as List? ?? [];
    if (weeklyData.isEmpty && !_loading) {
      return _buildEmptyWeekly();
    }

    final isDark = AppTheme.isDark(context);
    final maxSec = weeklyData.isEmpty
        ? 1
        : (weeklyData
                .map((d) => (d['totalTimeSec'] as int? ?? 0))
                .reduce((a, b) => a > b ? a : b) +
            1);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.dynamicCard(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: isDark ? Border.all(color: AppTheme.darkCardBorder) : null,
        boxShadow: isDark ? null : AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'THIS WEEK',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 1.4,
                  color: AppTheme.primaryBlue,
                ),
              ),
              Text(
                'Total: ${SyncService.formatDuration(
                  weeklyData.fold<int>(0, (sum, d) =>
                    sum + (d['totalTimeSec'] as int? ?? 0)),
                )}',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppTheme.dynamicSecondaryText(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_loading)
            _buildShimmerBars()
          else
            AnimatedBuilder(
              animation: _barAnim,
              builder: (_, __) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: weeklyData.asMap().entries.map((e) {
                    final d = e.value as Map;
                    final timeSec = d['totalTimeSec'] as int? ?? 0;
                    final frac = (timeSec / maxSec) * _barAnim.value;
                    final dayLabel = d['dayLabel'] as String? ?? '?';
                    final sessions = d['sessions'] as int? ?? 0;
                    final isToday = e.key == 6;

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (timeSec > 0)
                              Text(
                                SyncService.formatDuration(timeSec),
                                style: GoogleFonts.dmSans(
                                  fontSize: 8,
                                  color: isToday
                                      ? AppTheme.primaryBlue
                                      : AppTheme.secondaryText,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            const SizedBox(height: 4),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeOut,
                              width: double.infinity,
                              height: frac > 0
                                  ? (80 * frac).clamp(4.0, 80.0)
                                  : 4,
                              decoration: BoxDecoration(
                                gradient: timeSec > 0
                                    ? AppTheme.primaryGradient
                                    : null,
                                color: timeSec == 0
                                    ? AppTheme.divider
                                    : null,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              dayLabel,
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                fontWeight: isToday
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: isToday
                                    ? AppTheme.primaryBlue
                                    : AppTheme.secondaryText,
                              ),
                            ),
                            if (sessions > 0)
                              Text(
                                '$sessions',
                                style: GoogleFonts.dmSans(
                                  fontSize: 9,
                                  color: AppTheme.cyanAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            else
                              const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyWeekly() {
    final isDark = AppTheme.isDark(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.dynamicCard(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: isDark ? Border.all(color: AppTheme.darkCardBorder) : null,
        boxShadow: isDark ? null : AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Icon(Icons.bar_chart_rounded,
              size: 40, color: AppTheme.dynamicDivider(context)),
          const SizedBox(height: 12),
          Text(
            'No activity this week',
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: AppTheme.dynamicText(context),
            ),
          ),
          Text(
            'Complete a session to see your chart',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppTheme.dynamicSecondaryText(context),
            ),
          ),
        ],
      ),
    );
  }

  // ── ACCURACY CARD ─────────────────────────────────────────────────────────

  Widget _buildAccuracyCard() {
    final avgScore = _stats['avgScore'] is int
        ? (_stats['avgScore'] as int).toDouble()
        : (_stats['avgScore'] ?? 0.0) as double;
    final attempted = _stats['totalQuestionsAttempted'] ?? 0;
    final correct = _stats['totalQuestionsCorrect'] ?? 0;
    final accuracy = attempted > 0 ? (correct / attempted * 100) : 0.0;
    final isDark = AppTheme.isDark(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.dynamicCard(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: isDark ? Border.all(color: AppTheme.darkCardBorder) : null,
        boxShadow: isDark ? null : AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PERFORMANCE',
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 1.4,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Accuracy ring
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: accuracy / 100,
                      strokeWidth: 7,
                      backgroundColor: AppTheme.dynamicDivider(context),
                      valueColor: AlwaysStoppedAnimation(
                        accuracy >= 70
                            ? AppTheme.success
                            : accuracy >= 50
                                ? AppTheme.primaryBlue
                                : AppTheme.warning,
                      ),
                    ),
                    Text(
                      '${accuracy.round()}%',
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.dynamicText(context),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatRow('Avg Score',
                        avgScore > 0 ? '${avgScore.toStringAsFixed(1)}/10' : '—'),
                    _buildStatRow('Questions', '$attempted attempted'),
                    _buildStatRow('Correct', '$correct answers'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppTheme.dynamicSecondaryText(context),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.dynamicText(context),
            ),
          ),
        ],
      ),
    );
  }

  // ── TOPIC MASTERY ─────────────────────────────────────────────────────────

  Widget _buildTopicMastery() {
    final docs = HiveService.getAllContent();
    if (docs.isEmpty) return const SizedBox.shrink();

    final allTopics = docs.expand((d) => d.topics).toSet().take(6).toList();
    if (allTopics.isEmpty) return const SizedBox.shrink();
    final isDark = AppTheme.isDark(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.dynamicCard(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: isDark ? Border.all(color: AppTheme.darkCardBorder) : null,
        boxShadow: isDark ? null : AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOPIC MASTERY',
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 1.4,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Based on your session scores',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppTheme.dynamicSecondaryText(context),
            ),
          ),
          const SizedBox(height: 16),
          ...allTopics.map((topic) {
            final avgScore = _stats['avgScore'] is int
                ? (_stats['avgScore'] as int).toDouble()
                : (_stats['avgScore'] ?? 0.0) as double;
            final mastery = (avgScore / 10).clamp(0.0, 1.0);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          topic,
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppTheme.dynamicText(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        mastery > 0
                            ? '${(mastery * 100).round()}%'
                            : 'Not studied',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: mastery >= 0.7
                              ? AppTheme.success
                              : mastery >= 0.5
                                  ? AppTheme.primaryBlue
                                  : AppTheme.secondaryText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: mastery,
                      minHeight: 6,
                      backgroundColor: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFEEF2FF),
                      valueColor: AlwaysStoppedAnimation(
                        mastery >= 0.7
                            ? AppTheme.success
                            : mastery >= 0.5
                                ? AppTheme.primaryBlue
                                : AppTheme.cyanAccent,
                      ),
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

  // ── SESSION HISTORY ───────────────────────────────────────────────────────

  Widget _buildSessionHistory() {
    final isDark = AppTheme.isDark(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SESSION HISTORY',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 1.4,
            color: AppTheme.primaryBlue,
          ),
        ),
        const SizedBox(height: 12),
        ..._recentSessions.take(6).map((session) {
          final mode = session['mode'] as String? ?? 'learn';
          final docName =
              (session['documentName'] as String? ?? 'Unknown')
                  .replaceAll('.pdf', '');
          final score = session['score'] is int
              ? (session['score'] as int).toDouble()
              : session['score'] as double? ?? 0.0;
          final durationSec = session['durationSec'] as int? ?? 0;
          final createdAt = session['createdAt'] as String?;
          final questionsAttempted =
              session['questionsAttempted'] as int? ?? 0;

          final modeColor = mode == 'test'
              ? AppTheme.warning
              : mode == 'revise'
                  ? AppTheme.cyanAccent
                  : AppTheme.primaryBlue;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.dynamicCard(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: isDark ? Border.all(color: AppTheme.darkCardBorder) : null,
              boxShadow: isDark ? null : AppTheme.cardShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: modeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    mode == 'test'
                        ? Icons.quiz_rounded
                        : mode == 'revise'
                            ? Icons.refresh_rounded
                            : Icons.menu_book_rounded,
                    color: modeColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        docName,
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.dynamicText(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${mode[0].toUpperCase()}${mode.substring(1)} · '
                        '${SyncService.formatDuration(durationSec)} · '
                        '$questionsAttempted questions',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: AppTheme.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (score > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (score >= 7
                                  ? AppTheme.success
                                  : score >= 5
                                      ? AppTheme.primaryBlue
                                      : AppTheme.warning)
                              .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${score.toStringAsFixed(1)}/10',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: score >= 7
                                ? AppTheme.success
                                : score >= 5
                                    ? AppTheme.primaryBlue
                                    : AppTheme.warning,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    const SizedBox(height: 3),
                    Text(
                      SyncService.timeAgo(createdAt),
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppTheme.lightText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ── SHIMMER STATES ────────────────────────────────────────────────────────

  Widget _buildShimmerStreak() {
    return Shimmer.fromColors(
      baseColor: AppTheme.divider,
      highlightColor: const Color(0xFFF8FAFC),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
      ),
    );
  }

  Widget _buildShimmerRow() {
    return Shimmer.fromColors(
      baseColor: AppTheme.divider,
      highlightColor: const Color(0xFFF8FAFC),
      child: Row(
        children: List.generate(3, (i) => Expanded(
          child: Container(
            height: 90,
            margin: EdgeInsets.only(right: i < 2 ? 10 : 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
        )),
      ),
    );
  }

  Widget _buildShimmerBars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (i) => Shimmer.fromColors(
        baseColor: AppTheme.divider,
        highlightColor: const Color(0xFFF8FAFC),
        child: Container(
          width: 28,
          height: (i % 3 + 1) * 20.0,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      )),
    );
  }
}
