import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Privacy Policy',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppTheme.navyText)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.navyText),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('Last Updated', 'April 2026'),
            _buildSection('Who We Are',
                'Socratiq is an AI-powered personal tutoring application. '
                'Your data is handled with care and kept private.'),
            _buildSection('What We Collect', [
              'Name and email address — for your account',
              'Study session data — scores, time studied, topics',
              'Uploaded PDF content — stored locally on your device only',
              'Voice audio — processed for speech-to-text, not stored',
              'Device information — for app functionality',
            ]),
            _buildSection('What We Do NOT Collect', [
              'Your PDF content is never uploaded to our servers',
              'Your voice audio is not stored after transcription',
              'We do not sell your data to any third party',
              'We do not use your study data for advertising',
            ]),
            _buildSection('Third-Party Services', [
              'Firebase (Google) — authentication and database',
              'Groq — voice transcription (audio is not stored)',
              'Deepgram — text-to-speech (no data retained)',
              'Google Gemini — AI tutoring responses',
              'Mistral AI — question generation',
              'Cloudflare — AI inference',
            ]),
            _buildSection('Your Rights', [
              'Access your data — view in the app dashboard',
              'Delete your data — Settings → Delete Account',
              'Export your data — contact support',
              'Correct your data — edit in profile settings',
            ]),
            _buildSection('Data Security',
                'All communication uses HTTPS encryption. '
                'Your study content never leaves your device. '
                'Only progress statistics are stored in the cloud.'),
            _buildSection('Children\'s Privacy',
                'Socratiq is not directed to children under 13. '
                'We do not knowingly collect data from children.'),
            _buildSection('Contact',
                'For privacy questions or data deletion requests:\n'
                'privacy@socratiq.app'),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, dynamic content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppTheme.navyText,
            ),
          ),
          const SizedBox(height: 8),
          if (content is String)
            Text(
              content,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.secondaryText,
                height: 1.6,
              ),
            )
          else if (content is List<String>)
            ...content.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 7, right: 10),
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryBlue,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppTheme.secondaryText,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }
}
