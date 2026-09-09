import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/app_page_route.dart';
import '../legal/privacy_policy_screen.dart';
import '../legal/terms_screen.dart';
import '../legal/about_screen.dart';
import '../account/delete_account_screen.dart';
import '../../widgets/swipe_back_wrapper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  String _version = '1.0.0';
  int _voiceSpeed = 1; // 0=slow, 1=normal, 2=fast
  String _selectedVoice = 'aura-luna-en';
  ThemeMode _themeMode = ThemeMode.system;
  PermissionStatus _micPermissionStatus = PermissionStatus.denied;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAppInfo();
    const speeds = {'slow': 0, 'normal': 1, 'fast': 2};
    _voiceSpeed = speeds[ApiService.voiceSpeed] ?? 1;
    _selectedVoice = ApiService.voiceId;
    _themeMode = ThemeService.currentThemeMode;
    _checkMicPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkMicPermission();
    }
  }

  Future<void> _checkMicPermission() async {
    try {
      final status = await Permission.microphone.status;
      if (mounted) {
        setState(() => _micPermissionStatus = status);
      }
    } catch (e) {
      print('[SETTINGS] Error checking mic permission: $e');
    }
  }

  String get _micSubtitle {
    if (_micPermissionStatus.isGranted || _micPermissionStatus.isLimited) {
      return 'Enabled — tap to learn more';
    } else if (_micPermissionStatus.isPermanentlyDenied) {
      return 'Blocked — tap to open settings';
    } else if (_micPermissionStatus.isRestricted) {
      return 'Restricted by device';
    } else {
      return 'Disabled — tap to enable';
    }
  }

  Color get _micSubtitleColor {
    if (_micPermissionStatus.isGranted || _micPermissionStatus.isLimited) {
      return AppTheme.success;
    } else if (_micPermissionStatus.isPermanentlyDenied) {
      return AppTheme.error;
    } else {
      return AppTheme.warning;
    }
  }

  Future<void> _loadAppInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() => _version = '${info.version} (${info.buildNumber})');
    } catch (_) {}
  }

  Future<void> _clearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.dynamicCard(context),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
        title: Text('Clear local storage',
            style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                color: AppTheme.dynamicText(context))),
        content: Text(
          'This will delete all locally stored PDFs, summaries, and '
          'cached content from this device. Your cloud progress is safe. '
          'This cannot be undone.',
          style: GoogleFonts.dmSans(
              fontSize: 14, color: AppTheme.dynamicSecondaryText(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.dmSans(
                    color: AppTheme.dynamicSecondaryText(context))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Clear',
                style: GoogleFonts.dmSans(
                    color: AppTheme.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await Hive.box('content_box').clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Local storage cleared',
              style: GoogleFonts.dmSans(fontSize: 13)),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall)),
        ));
        setState(() {});
      }
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.dynamicCard(context),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
        title: Text('Sign out',
            style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                color: AppTheme.dynamicText(context))),
        content: Text('Your study content will remain on this device.',
            style: GoogleFonts.dmSans(
                fontSize: 14, color: AppTheme.dynamicSecondaryText(context))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.dmSans(
                    color: AppTheme.dynamicSecondaryText(context))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sign out',
                style: GoogleFonts.dmSans(
                    color: AppTheme.error, fontWeight: FontWeight.w600)),
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

  @override
  Widget build(BuildContext context) {
    final docCount = Hive.box('content_box').length;
    final isDark = AppTheme.isDark(context);

    return SwipeBackWrapper(
      fallbackRoute: '/profile',
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        extendBody: true,
        resizeToAvoidBottomInset: false,
        body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            Navigator.pushReplacementNamed(context, '/profile');
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
                      Text('SETTINGS',
                          style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 26,
                              color: AppTheme.dynamicText(context),
                              letterSpacing: 1.2)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── PREFERENCES SECTION ──────────────────────────────
                  _buildSectionLabel('PREFERENCES'),
                  _buildCard(children: [
                    // Theme Mode Selector
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSubLabel('APP THEME'),
                          const SizedBox(height: 4),
                          Text(
                            'Automatically adapts to device settings or select preferred mode.',
                            style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: AppTheme.dynamicSecondaryText(context)),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildThemeOption(
                                  ThemeMode.system, 'System', Icons.brightness_auto_rounded),
                              const SizedBox(width: 8),
                              _buildThemeOption(
                                  ThemeMode.light, 'Light', Icons.light_mode_rounded),
                              const SizedBox(width: 8),
                              _buildThemeOption(
                                  ThemeMode.dark, 'Dark', Icons.dark_mode_rounded),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _buildDivider(),

                    // Tutor Voice Speed
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSubLabel('VOICE SPEED'),
                          const SizedBox(height: 10),
                          Row(
                            children: ['Slow', 'Normal', 'Fast']
                                .asMap()
                                .entries
                                .map((e) {
                              final active = e.key == _voiceSpeed;
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() => _voiceSpeed = e.key);
                                    const speeds = ['slow', 'normal', 'fast'];
                                    ApiService.voiceSpeed = speeds[e.key];
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: EdgeInsets.only(
                                        right: e.key < 2 ? 8 : 0),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    decoration: BoxDecoration(
                                      gradient: active
                                          ? AppTheme.primaryGradient
                                          : null,
                                      color: active
                                          ? null
                                          : (isDark
                                              ? AppTheme.darkBackground
                                              : AppTheme.background),
                                      borderRadius: BorderRadius.circular(
                                          AppTheme.radiusPill),
                                      border: active
                                          ? null
                                          : Border.all(
                                              color: AppTheme.dynamicDivider(context)),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(e.value,
                                        style: GoogleFonts.dmSans(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: active
                                                ? Colors.white
                                                : AppTheme.dynamicSecondaryText(context))),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          _buildSubLabel('TUTOR VOICE'),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildVoiceChip('Luna ♀', 'aura-luna-en'),
                              _buildVoiceChip('Asteria ♀', 'aura-asteria-en'),
                              _buildVoiceChip('Stella ♀', 'aura-stella-en'),
                              _buildVoiceChip('Orion ♂', 'aura-orion-en'),
                              _buildVoiceChip('Arcas ♂', 'aura-arcas-en'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // ── PRIVACY & DATA SECTION ────────────────────────────
                  _buildSectionLabel('PRIVACY & DATA'),
                  _buildCard(children: [
                    _buildSettingRow(
                      icon: Icons.storage_rounded,
                      iconColor: AppTheme.primaryBlue,
                      title: 'Local storage',
                      subtitle: '$docCount document${docCount != 1 ? 's' : ''} on this device',
                      trailing: GestureDetector(
                        onTap: _clearCache,
                        child: Text('Clear',
                            style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppTheme.error)),
                      ),
                    ),
                    _buildDivider(),
                    _buildSettingRow(
                      icon: Icons.mic_rounded,
                      iconColor: AppTheme.cyanAccent,
                      title: 'Microphone',
                      subtitle: _micSubtitle,
                      subtitleColor: _micSubtitleColor,
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppTheme.lightText, size: 18),
                      onTap: _handleMicrophoneTap,
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // ── HELP & SUPPORT SECTION ────────────────────────────
                  _buildSectionLabel('HELP & SUPPORT'),
                  _buildCard(children: [
                    _buildSettingRow(
                      icon: Icons.email_outlined,
                      iconColor: AppTheme.primaryBlue,
                      title: 'Contact support',
                      subtitle: 'support@socratiq.app',
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppTheme.lightText, size: 18),
                      onTap: () {},
                    ),
                    _buildDivider(),
                    _buildSettingRow(
                      icon: Icons.bug_report_outlined,
                      iconColor: AppTheme.warning,
                      title: 'Report a problem',
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppTheme.lightText, size: 18),
                      onTap: () {},
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // ── LEGAL SECTION ─────────────────────────────────────
                  _buildSectionLabel('LEGAL'),
                  _buildCard(children: [
                    _buildSettingRow(
                      icon: Icons.privacy_tip_outlined,
                      iconColor: AppTheme.primaryBlue,
                      title: 'Privacy Policy',
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppTheme.lightText, size: 18),
                      onTap: () => Navigator.push(context,
                          AppPageRoute(
                              builder: (_) => const PrivacyPolicyScreen())),
                    ),
                    _buildDivider(),
                    _buildSettingRow(
                      icon: Icons.description_outlined,
                      iconColor: AppTheme.primaryBlue,
                      title: 'Terms of Service',
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppTheme.lightText, size: 18),
                      onTap: () => Navigator.push(context,
                          AppPageRoute(
                              builder: (_) => const TermsScreen())),
                    ),
                    _buildDivider(),
                    _buildSettingRow(
                      icon: Icons.info_outline_rounded,
                      iconColor: AppTheme.secondaryText,
                      title: 'About SocratiQ',
                      subtitle: 'v$_version',
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppTheme.lightText, size: 18),
                      onTap: () => Navigator.push(context,
                          AppPageRoute(
                              builder: (_) => const AboutScreen())),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // ── DANGER ZONE ───────────────────────────────────────
                  _buildSectionLabel('ACCOUNT ACTIONS'),
                  _buildCard(children: [
                    _buildSettingRow(
                      icon: Icons.logout_rounded,
                      iconColor: AppTheme.error,
                      title: 'Sign out',
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppTheme.lightText, size: 18),
                      onTap: _signOut,
                    ),
                    _buildDivider(),
                    _buildSettingRow(
                      icon: Icons.delete_forever_rounded,
                      iconColor: AppTheme.error,
                      title: 'Delete account',
                      subtitle: 'Permanently delete all data',
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppTheme.lightText, size: 18),
                      onTap: () => Navigator.push(context,
                          AppPageRoute(
                              builder: (_) => const DeleteAccountScreen())),
                    ),
                  ]),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  // ── BUILD HELPERS ─────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(label,
          style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              color: AppTheme.primaryBlue,
              letterSpacing: 1.4)),
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

  Widget _buildSubLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(label,
          style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: 1.0,
              color: AppTheme.dynamicText(context))),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: AppTheme.dynamicDivider(context),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Color? subtitleColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppTheme.dynamicText(context))),
                  if (subtitle != null)
                    Text(subtitle,
                        style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: subtitleColor != null
                                ? FontWeight.w400
                                : FontWeight.normal,
                            color: subtitleColor ??
                                AppTheme.dynamicSecondaryText(context))),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(ThemeMode mode, String label, IconData icon) {
    final active = _themeMode == mode;
    final isDark = AppTheme.isDark(context);
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          setState(() => _themeMode = mode);
          await ThemeService.setThemeMode(mode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            gradient: active ? AppTheme.primaryGradient : null,
            color: active
                ? null
                : (isDark ? AppTheme.darkBackground : AppTheme.background),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
              color: active
                  ? Colors.transparent
                  : (isDark ? AppTheme.darkCardBorder : AppTheme.divider),
            ),
            boxShadow: active ? AppTheme.buttonShadow : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: active
                    ? Colors.white
                    : AppTheme.dynamicSecondaryText(context),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: active
                      ? Colors.white
                      : AppTheme.dynamicSecondaryText(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceChip(String name, String voiceId) {
    final active = _selectedVoice == voiceId;
    final isDark = AppTheme.isDark(context);
    return GestureDetector(
      onTap: () {
        setState(() => _selectedVoice = voiceId);
        ApiService.voiceId = voiceId;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: active ? AppTheme.primaryGradient : null,
          color: active
              ? null
              : (isDark ? AppTheme.darkBackground : AppTheme.background),
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          border: Border.all(
              color: active
                  ? Colors.transparent
                  : (isDark ? AppTheme.darkCardBorder : AppTheme.divider)),
          boxShadow: active ? AppTheme.buttonShadow : null,
        ),
        child: Text(name,
            style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: active
                    ? Colors.white
                    : AppTheme.dynamicSecondaryText(context))),
      ),
    );
  }

  // ── MICROPHONE PERMISSION FLOW ─────────────────────────────────────────────

  Future<void> _handleMicrophoneTap() async {
    final status = await Permission.microphone.status;
    if (mounted) {
      setState(() => _micPermissionStatus = status);
    }

    if (!mounted) return;

    if (status.isGranted || status.isLimited) {
      _showGrantedBottomSheet();
    } else if (status.isDenied || status.isPermanentlyDenied) {
      _showDeniedBottomSheet();
    } else if (status.isRestricted) {
      _showRestrictedBottomSheet();
    } else {
      _showDeniedBottomSheet();
    }
  }

  void _showGrantedBottomSheet() {
    final isDark = AppTheme.isDark(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: AppTheme.dynamicCard(ctx),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: isDark ? Border.all(color: AppTheme.darkCardBorder) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppTheme.dynamicDivider(ctx),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      color: AppTheme.success, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Microphone Access',
                        style: GoogleFonts.dmSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.dynamicText(ctx),
                        ),
                      ),
                      Text(
                        'Permission is active',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: AppTheme.success,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Microphone access is enabled. SocratiQ uses it only for voice input during tutoring sessions. To revoke access go to Settings → Apps → SocratiQ → Permissions.',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                height: 1.5,
                color: AppTheme.dynamicSecondaryText(ctx),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Close',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeniedBottomSheet() {
    final isDark = AppTheme.isDark(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: AppTheme.dynamicCard(ctx),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: isDark ? Border.all(color: AppTheme.darkCardBorder) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppTheme.dynamicDivider(ctx),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic_off_rounded,
                      color: AppTheme.warning, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Microphone Disabled',
                        style: GoogleFonts.dmSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.dynamicText(ctx),
                        ),
                      ),
                      Text(
                        'Voice input will not work',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: AppTheme.warning,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Microphone access is disabled. Voice input will not work. To enable it, open device Settings.',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                height: 1.5,
                color: AppTheme.dynamicSecondaryText(ctx),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: isDark
                              ? AppTheme.darkCardBorder
                              : AppTheme.divider,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusPill),
                        ),
                      ),
                      child: Text(
                        'Not now',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.dynamicSecondaryText(ctx),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await openAppSettings();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusPill),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Open settings',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRestrictedBottomSheet() {
    final isDark = AppTheme.isDark(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: AppTheme.dynamicCard(ctx),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: isDark ? Border.all(color: AppTheme.darkCardBorder) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppTheme.dynamicDivider(ctx),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryText.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.block_rounded,
                      color: AppTheme.secondaryText, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Microphone Restricted',
                    style: GoogleFonts.dmSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.dynamicText(ctx),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Microphone access is restricted by your device administrator or parental controls.',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                height: 1.5,
                color: AppTheme.dynamicSecondaryText(ctx),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Close',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
