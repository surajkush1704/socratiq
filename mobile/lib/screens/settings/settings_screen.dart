import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../app_theme.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/glass_nav.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _voiceSpeed = 1; // 0=Slow, 1=Normal, 2=Fast
  String _selectedVoice = ApiService.voiceId;
  final _user = FirebaseAuth.instance.currentUser;

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
        title: Text('Clear Cache',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
            'This will delete all locally stored PDFs and content. This cannot be undone.',
            style: GoogleFonts.poppins(fontSize: 14,
                color: AppTheme.secondaryText)),
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
          content: Text('Cache cleared',
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
        content: Text('Are you sure you want to sign out?',
            style: GoogleFonts.poppins(fontSize: 14,
                color: AppTheme.secondaryText)),
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

  Widget _buildVoiceChip(String name, String voiceId) {
    final active = _selectedVoice == voiceId;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedVoice = voiceId);
        ApiService.voiceId = voiceId;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: active ? AppTheme.primaryGradient : null,
          color: active ? null : AppTheme.background,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          border: Border.all(
            color: active ? Colors.transparent : AppTheme.divider,
          ),
          boxShadow: active ? AppTheme.buttonShadow : null,
        ),
        child: Text(
          name,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: active ? Colors.white : AppTheme.secondaryText,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _user?.displayName ?? 'User';
    final email = _user?.email ?? '';
    final photo = _user?.photoURL;
    final contentBox = Hive.box('content_box');
    final docCount = contentBox.length;

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
                  Text(
                    'Settings',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 28,
                      color: AppTheme.navyText,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Profile card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusLarge),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Row(
                      children: [
                        photo != null
                            ? CircleAvatar(
                                radius: 28,
                                backgroundImage: NetworkImage(photo),
                              )
                            : Container(
                                width: 56,
                                height: 56,
                                decoration: const BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  name.isNotEmpty
                                      ? name[0].toUpperCase()
                                      : 'S',
                                  style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                  color: AppTheme.navyText,
                                ),
                              ),
                              Text(
                                email,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: AppTheme.secondaryText,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Voice speed
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMedium),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Voice Speed',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppTheme.navyText,
                          ),
                        ),
                        const SizedBox(height: 12),
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
                                  duration:
                                      const Duration(milliseconds: 200),
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
                                        : AppTheme.background,
                                    borderRadius: BorderRadius.circular(
                                        AppTheme.radiusPill),
                                    border: active
                                        ? null
                                        : Border.all(
                                            color: AppTheme.divider),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    e.value,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: active
                                          ? Colors.white
                                          : AppTheme.secondaryText,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tutor Voice
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMedium),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tutor Voice',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppTheme.navyText,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildVoiceChip('Luna', 'aura-luna-en'),
                            _buildVoiceChip('Asteria', 'aura-asteria-en'),
                            _buildVoiceChip('Stella', 'aura-stella-en'),
                            _buildVoiceChip('Orion', 'aura-orion-en'),
                            _buildVoiceChip('Arcas', 'aura-arcas-en'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Storage
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMedium),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withOpacity(0.10),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.storage_rounded,
                              color: AppTheme.primaryBlue, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Local Storage',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: AppTheme.navyText,
                                ),
                              ),
                              Text(
                                '$docCount document${docCount == 1 ? '' : 's'} stored',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppTheme.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _clearCache,
                          child: Text(
                            'Clear',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppTheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Sign out
                  GestureDetector(
                    onTap: _signOut,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                        ),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusPill),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.error.withOpacity(0.30),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Sign Out',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: GlassNav(
                currentIndex: 3,
                onTap: _onNavTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
