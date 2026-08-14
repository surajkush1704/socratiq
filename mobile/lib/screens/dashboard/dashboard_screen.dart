import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app_theme.dart';
import '../../models/content_model.dart';
import '../../services/hive_service.dart';
import '../../widgets/floating_nav.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<ContentModel> _content = [];

  @override
  void initState() {
    super.initState();
    _content = HiveService.getAllContent();
  }

  void _onNavTap(int index) {
    const routes = ['/home', '/library', '/dashboard', '/settings'];
    Navigator.pushReplacementNamed(context, routes[index]);
  }

  @override
  Widget build(BuildContext context) {
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
                  Text(
                    'Your Progress',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardSurface,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Row(
                      children: [
                        const Text('??', style: TextStyle(fontSize: 32)),
                        const SizedBox(width: 14),
                        Text(
                          '0',
                          style: GoogleFonts.poppins(
                            color: AppTheme.primaryAccent,
                            fontSize: 48,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'day streak',
                          style: GoogleFonts.poppins(
                            color: AppTheme.secondaryText,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Row(
                    children: [
                      Expanded(child: _SmallStatTile(title: 'Total Sessions', value: '0')),
                      SizedBox(width: 8),
                      Expanded(child: _SmallStatTile(title: 'Total Time', value: '0')),
                      SizedBox(width: 8),
                      Expanded(child: _SmallStatTile(title: 'Avg Score', value: '0')),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Topic Performance',
                    style: GoogleFonts.poppins(
                      color: AppTheme.primaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_content.isEmpty)
                    Text(
                      'No content yet. Upload a PDF to begin tracking progress.',
                      style: GoogleFonts.poppins(color: AppTheme.secondaryText),
                    )
                  else
                    ..._content.map(
                      (item) => Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.cardSurface,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.documentName,
                                style: GoogleFonts.poppins(
                                  color: AppTheme.primaryText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppTheme.altSurface,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '—',
                                style: GoogleFonts.poppins(
                                  color: AppTheme.primaryAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          FloatingNav(currentIndex: 2, onTap: _onNavTap),
        ],
      ),
    );
  }
}

class _SmallStatTile extends StatelessWidget {
  final String title;
  final String value;

  const _SmallStatTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              color: AppTheme.primaryAccent,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: AppTheme.secondaryText,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}