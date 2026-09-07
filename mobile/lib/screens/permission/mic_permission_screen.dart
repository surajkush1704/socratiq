import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../app_theme.dart';

class MicPermissionScreen extends StatelessWidget {
  final VoidCallback onGranted;
  final VoidCallback onDenied;

  const MicPermissionScreen({
    required this.onGranted,
    required this.onDenied,
    super.key,
  });

  Future<void> _requestPermission(BuildContext context) async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      onGranted();
    } else if (status.isPermanentlyDenied) {
      // Show settings redirect
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
          title: Text('Microphone Access Required',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          content: Text(
            'Microphone access was permanently denied. '
            'Please enable it in Settings → Apps → Socratiq → Permissions.',
            style: GoogleFonts.poppins(fontSize: 14,
                color: AppTheme.secondaryText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: GoogleFonts.poppins(color: AppTheme.secondaryText)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: Text('Open Settings',
                  style: GoogleFonts.poppins(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
      onDenied();
    } else {
      onDenied();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.auroraGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mic_rounded,
                    color: AppTheme.primaryBlue,
                    size: 52,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Microphone Access',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                    color: AppTheme.navyText,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Socratiq uses your microphone so you can '
                  'speak to your AI tutor — just like talking '
                  'to a real teacher.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: AppTheme.secondaryText,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),
                // What it's used for
                _buildUsageRow(
                  Icons.record_voice_over_rounded,
                  'Voice questions to your tutor',
                ),
                _buildUsageRow(
                  Icons.hearing_rounded,
                  'Speak answers to MCQ questions',
                ),
                _buildUsageRow(
                  Icons.lock_rounded,
                  'Audio is never stored or shared',
                ),
                const SizedBox(height: 40),
                AppTheme.gradientButton(
                  label: 'Allow Microphone Access',
                  width: double.infinity,
                  onTap: () => _requestPermission(context),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: onDenied,
                  child: Text(
                    'Not now — I\'ll use text instead',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppTheme.secondaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUsageRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primaryBlue, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.navyText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
