import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_nav.dart';
import '../legal/privacy_policy_screen.dart';
import '../legal/terms_screen.dart';
import '../legal/about_screen.dart';
import '../account/delete_account_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _voiceSpeed = 1; // 0=Slow, 1=Normal, 2=Fast
  String _selectedVoice = 'aura-luna-en';
  String _version = '1.0.0';
  final _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() => _version = info.version);
    } catch (_) {}
  }

  void _onNavTap(int index) {
    if (index == 0) Navigator.pushReplacementNamed(context, '/home');
    if (index == 1) Navigator.pushReplacementNamed(context, '/library');
    if (index == 2) Navigator.pushReplacementNamed(context, '/dashboard');
  }

  Future<void> _clearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
        title: Text('Clear Local Storage',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          'This will delete all locally stored PDFs, summaries, and '
          'cached content from this device. Your cloud progress is safe. '
          'This cannot be undone.',
          style: GoogleFonts.poppins(
              fontSize: 14, color: AppTheme.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: AppTheme.secondaryText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Clear',
                style: GoogleFonts.poppins(
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
              style: GoogleFonts.poppins(fontSize: 13)),
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
        title: Text('Sign Out',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('Your study content will remain on this device.',
            style: GoogleFonts.poppins(
                fontSize: 14, color: AppTheme.secondaryText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: AppTheme.secondaryText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sign Out',
                style: GoogleFonts.poppins(
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
    final name = _user?.displayName ?? 'User';
    final email = _user?.email ?? '';
    final photo = _user?.photoURL;
    final docCount = Hive.box('content_box').length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text('Settings',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 28,
                          color: AppTheme.navyText,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 20),

                  // ── ACCOUNT SECTION ──────────────────────────────────
                  _buildSectionLabel('Account'),
                  _buildProfileCard(photo, name, email),
                  const SizedBox(height: 16),

                  // ── PREFERENCES SECTION ──────────────────────────────
                  _buildSectionLabel('Preferences'),
                  _buildCard(children: [
                    _buildSubLabel('Tutor Voice Speed'),
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
                                color: active ? null : AppTheme.background,
                                borderRadius: BorderRadius.circular(
                                    AppTheme.radiusPill),
                                border: active
                                    ? null
                                    : Border.all(color: AppTheme.divider),
                              ),
                              alignment: Alignment.center,
                              child: Text(e.value,
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: active
                                          ? Colors.white
                                          : AppTheme.secondaryText)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    _buildSubLabel('Tutor Voice'),
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
                  ]),
                  const SizedBox(height: 16),

                  // ── PRIVACY & DATA SECTION ────────────────────────────
                  _buildSectionLabel('Privacy & Data'),
                  _buildCard(children: [
                    _buildSettingRow(
                      icon: Icons.storage_rounded,
                      iconColor: AppTheme.primaryBlue,
                      title: 'Local Storage',
                      subtitle: '$docCount document${docCount != 1 ? 's' : ''} on this device',
                      trailing: GestureDetector(
                        onTap: _clearCache,
                        child: Text('Clear',
                            style: GoogleFonts.poppins(
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
                      subtitle: 'Used for voice input only',
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppTheme.lightText, size: 18),
                      onTap: () {},
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // ── HELP & SUPPORT SECTION ────────────────────────────
                  _buildSectionLabel('Help & Support'),
                  _buildCard(children: [
                    _buildSettingRow(
                      icon: Icons.email_outlined,
                      iconColor: AppTheme.primaryBlue,
                      title: 'Contact Support',
                      subtitle: 'support@socratiq.app',
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppTheme.lightText, size: 18),
                      onTap: () {},
                    ),
                    _buildDivider(),
                    _buildSettingRow(
                      icon: Icons.bug_report_outlined,
                      iconColor: AppTheme.warning,
                      title: 'Report a Problem',
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppTheme.lightText, size: 18),
                      onTap: () {},
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // ── LEGAL SECTION ─────────────────────────────────────
                  _buildSectionLabel('Legal'),
                  _buildCard(children: [
                    _buildSettingRow(
                      icon: Icons.privacy_tip_outlined,
                      iconColor: AppTheme.primaryBlue,
                      title: 'Privacy Policy',
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppTheme.lightText, size: 18),
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(
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
                          MaterialPageRoute(
                              builder: (_) => const TermsScreen())),
                    ),
                    _buildDivider(),
                    _buildSettingRow(
                      icon: Icons.info_outline_rounded,
                      iconColor: AppTheme.secondaryText,
                      title: 'About Socratiq',
                      subtitle: 'v$_version',
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppTheme.lightText, size: 18),
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const AboutScreen())),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // ── DANGER ZONE ───────────────────────────────────────
                  _buildSectionLabel('Account Actions'),
                  _buildCard(children: [
                    _buildSettingRow(
                      icon: Icons.logout_rounded,
                      iconColor: AppTheme.error,
                      title: 'Sign Out',
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppTheme.lightText, size: 18),
                      onTap: _signOut,
                    ),
                    _buildDivider(),
                    _buildSettingRow(
                      icon: Icons.delete_forever_rounded,
                      iconColor: AppTheme.error,
                      title: 'Delete Account',
                      subtitle: 'Permanently delete all data',
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppTheme.lightText, size: 18),
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const DeleteAccountScreen())),
                    ),
                  ]),
                  const SizedBox(height: 32),
                ],
              ),
            ),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: GlassNav(currentIndex: 3, onTap: _onNavTap),
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
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppTheme.primaryBlue,
              letterSpacing: 0.5)),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSubLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(label,
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppTheme.navyText)),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: AppTheme.divider,
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
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
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppTheme.navyText)),
                  if (subtitle != null)
                    Text(subtitle,
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppTheme.secondaryText)),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(String? photo, String name, String email) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          photo != null
              ? CircleAvatar(radius: 28, backgroundImage: NetworkImage(photo))
              : Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'S',
                    style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: AppTheme.navyText)),
                Text(email,
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: AppTheme.secondaryText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceChip(String name, String voiceId) {
    final active = _selectedVoice == voiceId;
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
          color: active ? null : AppTheme.background,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          border: Border.all(
              color: active ? Colors.transparent : AppTheme.divider),
          boxShadow: active ? AppTheme.buttonShadow : null,
        ),
        child: Text(name,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: active ? Colors.white : AppTheme.secondaryText)),
      ),
    );
  }
}
