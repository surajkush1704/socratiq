import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_theme.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Terms of Service',
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
            _buildSection('Acceptance',
                'By using Socratiq you agree to these terms. '
                'If you do not agree, please do not use the app.'),
            _buildSection('Acceptable Use', [
              'Use the app for lawful purposes only',
              'Do not attempt to reverse engineer the app',
              'Do not upload illegal or harmful content',
              'Do not attempt to bypass security measures',
              'Do not use the service to harm others',
            ]),
            _buildSection('AI-Generated Content',
                'Socratiq uses AI to generate educational content. '
                'AI responses are based on your uploaded materials. '
                'We cannot guarantee 100% accuracy. '
                'Do not rely solely on AI for critical decisions.'),
            _buildSection('Account Responsibilities',
                'You are responsible for maintaining the security '
                'of your account credentials. Notify us immediately '
                'of any unauthorized access.'),
            _buildSection('Intellectual Property',
                'The Socratiq app, design, and branding are '
                'owned by the developer. Your uploaded content '
                'remains yours — we do not claim ownership.'),
            _buildSection('Service Availability',
                'We aim for high availability but cannot guarantee '
                'uninterrupted service. AI services depend on '
                'third-party providers.'),
            _buildSection('Limitation of Liability',
                'Socratiq is provided as-is. We are not liable '
                'for educational outcomes or decisions made '
                'based on AI-generated content.'),
            _buildSection('Termination',
                'We may terminate accounts that violate these terms. '
                'You may delete your account at any time from Settings.'),
            _buildSection('Changes',
                'We may update these terms. Continued use after '
                'changes constitutes acceptance.'),
            _buildSection('Contact',
                'legal@socratiq.app'),
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
          Text(title,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppTheme.navyText)),
          const SizedBox(height: 8),
          if (content is String)
            Text(content,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.secondaryText,
                    height: 1.6))
          else if (content is List<String>)
            ...content.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6, height: 6,
                    margin: const EdgeInsets.only(top: 7, right: 10),
                    decoration: const BoxDecoration(
                        color: AppTheme.primaryBlue,
                        shape: BoxShape.circle),
                  ),
                  Expanded(
                    child: Text(item,
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppTheme.secondaryText,
                            height: 1.5)),
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }
}
