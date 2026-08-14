import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';

import '../../app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/hive_service.dart';
import '../../widgets/floating_nav.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _voiceSpeed = 'Normal';
  int _contentCount = 0;

  @override
  void initState() {
    super.initState();
    _refreshCount();
  }

  void _refreshCount() {
    _contentCount = HiveService.getAllContent().length;
    setState(() {});
  }

  void _onNavTap(int index) {
    const routes = ['/home', '/library', '/dashboard', '/settings'];
    Navigator.pushReplacementNamed(context, routes[index]);
  }

  Future<void> _clearCache() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('Delete all locally saved content?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (shouldClear != true) return;

    await Hive.box(HiveService.contentBox).clear();
    _refreshCount();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : 'Learner';
    final email = user?.email ?? 'No email';

    final initials = displayName.isNotEmpty
        ? displayName
              .split(' ')
              .where((p) => p.isNotEmpty)
              .map((p) => p[0])
              .take(2)
              .join()
              .toUpperCase()
        : 'L';

    return Scaffold(
      backgroundColor: AppTheme.baseSurface,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 108),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardSurface,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppTheme.altSurface,
                          backgroundImage: user?.photoURL != null
                              ? NetworkImage(user!.photoURL!)
                              : null,
                          child: user?.photoURL == null
                              ? Text(
                                  initials,
                                  style: GoogleFonts.poppins(
                                    color: AppTheme.primaryAccent,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: GoogleFonts.poppins(
                                  color: AppTheme.primaryText,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email,
                                style: GoogleFonts.poppins(
                                  color: AppTheme.secondaryText,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Voice Speed',
                    style: GoogleFonts.poppins(
                      color: AppTheme.primaryText,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _SpeedChip(
                        label: 'Slow',
                        active: _voiceSpeed == 'Slow',
                        onTap: () => setState(() => _voiceSpeed = 'Slow'),
                      ),
                      const SizedBox(width: 8),
                      _SpeedChip(
                        label: 'Normal',
                        active: _voiceSpeed == 'Normal',
                        onTap: () => setState(() => _voiceSpeed = 'Normal'),
                      ),
                      const SizedBox(width: 8),
                      _SpeedChip(
                        label: 'Fast',
                        active: _voiceSpeed == 'Fast',
                        onTap: () => setState(() => _voiceSpeed = 'Fast'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Storage',
                    style: GoogleFonts.poppins(
                      color: AppTheme.primaryText,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Saved documents: $_contentCount',
                          style: GoogleFonts.poppins(
                            color: AppTheme.secondaryText,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _clearCache,
                        child: Text(
                          'Clear Cache',
                          style: GoogleFonts.poppins(
                            color: AppTheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Account',
                    style: GoogleFonts.poppins(
                      color: AppTheme.primaryText,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await AuthService.signOut();
                        if (!mounted) return;
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error,
                        foregroundColor: AppTheme.cardSurface,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Sign Out',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          FloatingNav(currentIndex: 3, onTap: _onNavTap),
        ],
      ),
    );
  }
}

class _SpeedChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SpeedChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppTheme.primaryAccent : AppTheme.divider,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: active ? AppTheme.cardSurface : AppTheme.secondaryText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
