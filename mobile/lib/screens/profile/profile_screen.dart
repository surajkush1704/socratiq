import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/sync_service.dart';
import '../../widgets/glass_nav.dart';
import '../../widgets/socratiq_avatar.dart';
import '../../widgets/app_page_route.dart';
import '../account/edit_profile_screen.dart';
import '../session/learn_screen.dart';
import '../settings/settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _username = '';
  int _avatarId = 0;
  int _streak = 0;
  int _totalSessions = 0;
  int _totalStudyTimeSec = 0;
  double _avgScore = 0.0;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final profile = await SyncService.getProfile(user.uid);
        if (mounted) {
          setState(() {
            _username = (profile['username'] as String? ?? '').replaceAll('@', '');
            _avatarId = (profile['avatarId'] as num?)?.toInt() ?? 0;
            _streak = (profile['streak'] as num?)?.toInt() ?? 0;
            _totalSessions = (profile['totalSessions'] as num?)?.toInt() ?? 0;
            _totalStudyTimeSec = (profile['totalStudyTimeSec'] as num?)?.toInt() ?? 0;
            _avgScore = (profile['avgScore'] as num?)?.toDouble() ?? 0.0;
          });
        }
      } catch (e) {
        debugPrint('[PROFILE] Error loading profile data: $e');
      }
    }
  }

  Future<void> _refreshProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.reload();
      await _loadProfileData();
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
    if (index == 3) Navigator.pushReplacementNamed(context, '/dashboard');
    if (index == 4) return;
  }

  Future<void> _confirmSignOut() async {
    final isDark = AppTheme.isDark(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.dynamicCard(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          side: isDark ? const BorderSide(color: AppTheme.darkCardBorder) : BorderSide.none,
        ),
        title: Text(
          'Sign out',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppTheme.dynamicText(context),
          ),
        ),
        content: Text(
          'Are you sure you want to sign out of SocratiQ?',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            color: AppTheme.dynamicSecondaryText(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.dmSans(
                color: AppTheme.dynamicSecondaryText(context),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Sign out',
              style: GoogleFonts.dmSans(
                color: AppTheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
      }
    }
  }

  String _formatStudyTime(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final remainingMins = minutes % 60;
    return remainingMins > 0 ? '${hours}h ${remainingMins}m' : '${hours}h';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = (user?.displayName != null && user!.displayName!.trim().isNotEmpty)
        ? user.displayName!.trim()
        : 'User';
    final email = user?.email ?? '';
    final photo = user?.photoURL;

    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Row with Back Button
                    Row(
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
                          'PROFILE',
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 26,
                            color: AppTheme.dynamicText(context),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── 1. PROFILE CARD (with direct Edit button) ─────────────
                    _buildProfileCard(photo, name, email),
                    const SizedBox(height: 20),

                  // ── 2. LEARNING STATS OVERVIEW ────────────────────────────
                  _buildSectionLabel('LEARNING JOURNEY'),
                  _buildStatsGrid(),
                  const SizedBox(height: 20),

                  // ── 3. SETTINGS SECTION ───────────────────────────────────
                  _buildSectionLabel('PREFERENCES'),
                  _buildCard(
                    children: [
                      _buildMenuRow(
                        icon: Icons.settings_rounded,
                        iconColor: AppTheme.primaryBlue,
                        title: 'Settings',
                        subtitle: 'Theme, tutor voice, privacy, support & legal',
                        onTap: () async {
                          await Navigator.push(
                            context,
                            AppPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          );
                          if (mounted) {
                            await _refreshProfile();
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── 4. ACCOUNT ACTIONS ────────────────────────────────────
                  _buildSectionLabel('ACCOUNT ACTIONS'),
                  _buildCard(
                    children: [
                      _buildMenuRow(
                        icon: Icons.logout_rounded,
                        iconColor: AppTheme.error,
                        title: 'Sign out',
                        subtitle: 'Safely sign out of your account',
                        titleColor: AppTheme.error,
                        onTap: _confirmSignOut,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // GlassNav pinned at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: GlassNav(
              currentIndex: 4,
              onTap: _onNavTap,
            ),
          ),
        ],
      ),
    ),
  );
}

  // ─── PROFILE CARD ─────────────────────────────────────────────────────────

  Widget _buildProfileCard(String? photo, String name, String email) {
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar
          SocratiqAvatar(
            size: 60,
            avatarId: _avatarId,
            photoUrl: photo,
            displayName: name,
          ),
          const SizedBox(width: 16),

          // Name, Email, Username
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: AppTheme.dynamicText(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  email,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: AppTheme.dynamicSecondaryText(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_username.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '@$_username',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryBlue,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),

          // Pencil Edit Button
          GestureDetector(
            onTap: () async {
              final result = await Navigator.push(
                context,
                AppPageRoute(
                  builder: (_) => const EditProfileScreen(),
                ),
              );
              if (result == true && mounted) {
                await _refreshProfile();
              }
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.primaryBlue.withValues(alpha: 0.20)
                    : AppTheme.primaryBlue.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.edit_rounded,
                color: AppTheme.primaryBlue,
                size: 19,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── STATS GRID ───────────────────────────────────────────────────────────

  Widget _buildStatsGrid() {
    final isDark = AppTheme.isDark(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.dynamicCard(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: isDark ? Border.all(color: AppTheme.darkCardBorder) : null,
        boxShadow: isDark ? null : AppTheme.cardShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('🔥', '$_streak', 'Streak'),
          _buildStatDivider(),
          _buildStatItem('📚', '$_totalSessions', 'Sessions'),
          _buildStatDivider(),
          _buildStatItem('⏱️', _formatStudyTime(_totalStudyTimeSec), 'Study Time'),
          _buildStatDivider(),
          _buildStatItem('⭐', _avgScore > 0 ? _avgScore.toStringAsFixed(1) : '--', 'Avg Score'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: AppTheme.dynamicText(context),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            color: AppTheme.dynamicSecondaryText(context),
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 36,
      color: AppTheme.dynamicDivider(context),
    );
  }

  // ─── UI HELPERS ───────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontWeight: FontWeight.w700,
          fontSize: 11,
          color: AppTheme.primaryBlue,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    final isDark = AppTheme.isDark(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.dynamicCard(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: isDark ? Border.all(color: AppTheme.darkCardBorder) : null,
        boxShadow: isDark ? null : AppTheme.cardShadow,
      ),
      child: Column(children: children),
    );
  }

  Widget _buildMenuRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Color? titleColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: titleColor ?? AppTheme.dynamicText(context),
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppTheme.dynamicSecondaryText(context),
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.lightText,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
