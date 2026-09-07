import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../../app_theme.dart';
import '../../models/content_model.dart';
import '../../services/hive_service.dart';
import '../../services/sync_service.dart';
import '../../widgets/glass_nav.dart';
import '../session/mode_select.dart';
import '../session/learn_screen.dart';
import '../upload/upload_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Data state
  List<ContentModel> _documents = [];
  Map<String, dynamic> _userStats = {};
  bool _isLoadingStats = true;
  String _greeting = 'Welcome back';

  // Auth user
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    _setGreeting();
    _loadLocalData();
    _loadCloudData();
  }

  void _setGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      _greeting = 'Good morning';
    } else if (hour < 17) {
      _greeting = 'Good afternoon';
    } else {
      _greeting = 'Good evening';
    }
  }

  void _loadLocalData() {
    final docs = HiveService.getAllContent();
    if (mounted) {
      setState(() {
        _documents = docs;
      });
    }
  }

  Future<void> _loadCloudData() async {
    try {
      final stats = await SyncService.getUserStats();
      if (mounted) {
        setState(() {
          _userStats = stats;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  void _onNavTap(int index) {
    if (index == 0) return;
    if (index == 1) Navigator.pushReplacementNamed(context, '/library');
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LearnScreen(mode: 'learn')),
      );
    }
    if (index == 3) Navigator.pushReplacementNamed(context, '/dashboard');
    if (index == 4) Navigator.pushReplacementNamed(context, '/settings');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
              color: AppTheme.primaryBlue,
              onRefresh: () async {
                _loadLocalData();
                await _loadCloudData();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopBar(),
                    _buildHeroCard(),
                    _buildBentoRow1(),
                    _buildBentoRow2(),
                    _buildRecentSection(),
                    _buildStatsSection(),
                  ],
                ),
              ),
            ),
          ),

          // GlassNav pinned at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: GlassNav(
              currentIndex: 0,
              onTap: _onNavTap,
            ),
          ),
        ],
      ),
    );
  }

  // ─── 1. TOP BAR ────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    String name = 'there';
    if (_user?.displayName != null && _user!.displayName!.trim().isNotEmpty) {
      name = _user!.displayName!.trim().split(' ').first;
    } else if (_user?.email != null && _user!.email!.trim().isNotEmpty) {
      final prefix = _user!.email!.split('@').first;
      name = prefix.isNotEmpty
          ? '${prefix[0].toUpperCase()}${prefix.substring(1)}'
          : 'Learner';
    }
    final photoUrl = _user?.photoURL;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pushReplacementNamed(context, '/settings'),
            child: photoUrl != null
                ? CircleAvatar(
                    radius: 20,
                    backgroundImage: NetworkImage(photoUrl),
                  )
                : Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'S',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_greeting, $name',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: AppTheme.navyText,
                  ),
                ),
                Text(
                  'Level up 🚀',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w400,
                    fontSize: 13,
                    color: AppTheme.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          _buildIconButton(Icons.search_rounded, () => Navigator.pushReplacementNamed(context, '/library')),
          const SizedBox(width: 8),
          _buildIconButton(Icons.notifications_none_rounded, () {}),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: AppTheme.cardShadow,
        ),
        child: Icon(icon, color: AppTheme.navyText, size: 20),
      ),
    );
  }

  // ─── 2. AI TUTOR HERO CARD ──────────────────────────────────────────────────

  Widget _buildHeroCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A8A), Color(0xFF0E7490), Color(0xFF4338CA)],
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Your Personal AI Tutor',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppTheme.cyanAccent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ready to learn?',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ask anything from your PDFs',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w400,
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.75),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Inverted Talk to Tutor CTA
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LearnScreen(mode: 'learn'),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Text(
                          'Talk to Tutor',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: AppTheme.navyText,
                          ),
                        ),
                      ),
                    ),
                    // Upload PDF Outlined Button
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const UploadScreen()),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                          border: Border.all(color: Colors.white.withOpacity(0.7), width: 1.5),
                        ),
                        child: Text(
                          'Upload PDF',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Image.asset(
            'assets/images/logo.png',
            width: 94,
            height: 94,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.school_rounded,
              size: 75,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ─── 3. BENTO ROW 1: CONTINUE + QUICK ACTION ────────────────────────────────

  Widget _buildBentoRow1() {
    final hasDocs = _documents.isNotEmpty;
    final lastDoc = hasDocs ? _documents.last : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Continue Learning Card (Flex 2)
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: hasDocs && lastDoc != null
                  ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ModeSelectScreen(content: lastDoc),
                        ),
                      )
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const UploadScreen()),
                      ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: !hasDocs
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.upload_file_rounded, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Start Study',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                  color: AppTheme.cyanAccent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Upload a PDF to start learning',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppTheme.navyText,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Upload now →',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Continue',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                  color: AppTheme.cyanAccent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            lastDoc!.documentName,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppTheme.navyText,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: const LinearProgressIndicator(
                              value: 0.4,
                              backgroundColor: Color(0xFFE2E8F0),
                              valueColor: AlwaysStoppedAnimation(AppTheme.primaryBlue),
                              minHeight: 4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Resume →',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Quick Action Quiz Card (Flex 1)
          Expanded(
            flex: 1,
            child: GestureDetector(
              onTap: () => Navigator.pushReplacementNamed(context, '/library'),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppTheme.buttonShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.quiz_rounded, color: Colors.white, size: 28),
                    const SizedBox(height: 8),
                    Text(
                      'Quiz Me',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Test yourself',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 4. BENTO ROW 2: LIBRARY + ASK AI + PROGRESS ────────────────────────────

  Widget _buildBentoRow2() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: [
          // Library Card
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.pushReplacementNamed(context, '/library'),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundAlt,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.menu_book_rounded, color: AppTheme.primaryBlue, size: 24),
                    const SizedBox(height: 6),
                    Text(
                      'Library',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppTheme.navyText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Ask AI Card
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LearnScreen(mode: 'learn'),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: AppTheme.lavenderAccent, size: 24),
                    const SizedBox(height: 6),
                    Text(
                      'Ask AI',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppTheme.navyText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Progress Card
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.pushReplacementNamed(context, '/dashboard'),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFEFF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.bar_chart_rounded, color: AppTheme.cyanAccent, size: 24),
                    const SizedBox(height: 6),
                    Text(
                      'Progress',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppTheme.navyText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 5. RECENT PDFs ────────────────────────────────────────────────────────

  Widget _buildRecentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Materials',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: AppTheme.navyText,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pushReplacementNamed(context, '/library'),
                child: Text(
                  'See all',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
        ),
        _documents.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Center(
                  child: Text(
                    'Upload your first PDF',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppTheme.secondaryText,
                    ),
                  ),
                ),
              )
            : SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _documents.length,
                  itemBuilder: (context, index) {
                    final doc = _documents[index];
                    final gradients = [
                      AppTheme.primaryGradient,
                      AppTheme.lavenderGradient,
                      AppTheme.cyanGradient,
                    ];
                    final gradient = gradients[index % gradients.length];

                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ModeSelectScreen(content: doc),
                        ),
                      ),
                      child: Container(
                        width: 200,
                        margin: const EdgeInsets.only(right: 12, bottom: 4),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: gradient,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.picture_as_pdf_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    doc.documentName.replaceAll('.pdf', ''),
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: AppTheme.navyText,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    doc.topics.isNotEmpty ? doc.topics.first : 'Study Module',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: AppTheme.secondaryText,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Open →',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ─── 6. STATS STRIP ─────────────────────────────────────────────────────────

  Widget _buildStatsSection() {
    final streak = _userStats['streak'] ?? 0;
    final todaySec = _userStats['todayTimeSec'] ?? 0;
    final todayMin = (todaySec / 60).round();
    final sessions = _userStats['totalSessions'] ?? 0;
    final avgScore = (_userStats['avgScore'] ?? 0.0) is int
        ? (_userStats['avgScore'] as int).toDouble()
        : (_userStats['avgScore'] ?? 0.0) as double;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Your Stats',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: AppTheme.navyText,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _buildStatChip(
                emoji: '🔥',
                value: streak > 0 ? '$streak' : '0',
                label: streak > 0 ? 'day streak' : 'Start today!',
                isLoading: _isLoadingStats,
              ),
              _buildStatChip(
                emoji: '⏱',
                value: todayMin > 0 ? '${todayMin}m' : '0m',
                label: 'today',
                isLoading: _isLoadingStats,
              ),
              _buildStatChip(
                emoji: '📚',
                value: '$sessions',
                label: 'sessions',
                isLoading: _isLoadingStats,
              ),
              _buildStatChip(
                emoji: '🎯',
                value: avgScore > 0 ? avgScore.toStringAsFixed(1) : '—',
                label: 'avg score',
                isLoading: _isLoadingStats,
                valueColor: avgScore >= 7
                    ? AppTheme.success
                    : avgScore >= 5
                        ? AppTheme.primaryBlue
                        : avgScore > 0
                            ? AppTheme.warning
                            : AppTheme.primaryBlue,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip({
    required String emoji,
    required String value,
    required String label,
    bool isLoading = false,
    Color? valueColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 12, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: isLoading
          ? Shimmer.fromColors(
              baseColor: const Color(0xFFE2E8F0),
              highlightColor: const Color(0xFFF8FAFC),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 60, height: 20, color: Colors.white),
                  const SizedBox(height: 4),
                  Container(width: 40, height: 12, color: Colors.white),
                ],
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 4),
                    Text(
                      value,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: valueColor ?? AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w400,
                    fontSize: 11,
                    color: AppTheme.secondaryText,
                  ),
                ),
              ],
            ),
    );
  }
}
