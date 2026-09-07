import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../app_theme.dart';
import 'privacy_policy_screen.dart';
import 'terms_screen.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '1.0.0';
  String _buildNumber = '1';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() {
        _version = info.version;
        _buildNumber = info.buildNumber;
      });
    } catch (e) {
      // Non-fatal
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('About',
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
          children: [
            // App info card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                children: [
                  Image.asset('assets/images/logo.png',
                      width: 72, height: 72),
                  const SizedBox(height: 12),
                  Text('SocratiQ',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                          color: AppTheme.navyText)),
                  Text('Version $_version (Build $_buildNumber)',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppTheme.secondaryText)),
                  const SizedBox(height: 8),
                  Text('Learn Smarter. Not Harder.',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  Text('© 2026 Socratiq. All rights reserved.',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.lightText)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Legal links
            _buildLinkCard(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
            ),
            _buildLinkCard(
              icon: Icons.description_outlined,
              title: 'Terms of Service',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const TermsScreen())),
            ),
            _buildLinkCard(
              icon: Icons.email_outlined,
              title: 'Contact Support',
              subtitle: 'support@socratiq.app',
              onTap: () {},
            ),
            _buildLinkCard(
              icon: Icons.code_rounded,
              title: 'Open Source Licenses',
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'SocratiQ',
                applicationVersion: _version,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkCard({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryBlue, size: 22),
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
                            fontSize: 12,
                            color: AppTheme.secondaryText)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.lightText, size: 20),
          ],
        ),
      ),
    );
  }
}
