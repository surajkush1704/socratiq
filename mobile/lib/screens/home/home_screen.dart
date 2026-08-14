import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app_theme.dart';
import '../../models/content_model.dart';
import '../../services/hive_service.dart';
import '../../widgets/floating_nav.dart';
import '../../widgets/topic_chip.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ContentModel> _content = [];

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  void _loadContent() {
    final all = HiveService.getAllContent();
    all.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    setState(() => _content = all);
  }

  void _onNavTap(int index) {
    const routes = ['/home', '/library', '/dashboard', '/settings'];
    Navigator.pushReplacementNamed(context, routes[index]);
  }

  Future<void> _goToUpload() async {
    await Navigator.pushNamed(context, '/upload');
    _loadContent();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!.trim()
        : 'Learner';

    return Scaffold(
      backgroundColor: AppTheme.baseSurface,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 108),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Good morning, $name',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryText,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.altSurface,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '?? 0 day streak',
                          style: GoogleFonts.poppins(
                            color: AppTheme.primaryAccent,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: const [
                      Expanded(
                        child: _StatCard(value: '0', label: 'Today\'s Time'),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(value: '0', label: 'Sessions Done'),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(value: '0', label: 'Avg Score'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Quick Actions',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryText,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _goToUpload,
                          style: ElevatedButton.styleFrom(
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Upload PDF'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pushReplacementNamed(
                            context,
                            '/library',
                          ),
                          style: OutlinedButton.styleFrom(
                            shape: const StadiumBorder(),
                            side: const BorderSide(
                              color: AppTheme.primaryAccent,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            'My Library',
                            style: GoogleFonts.poppins(
                              color: AppTheme.primaryAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Recent Topics',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryText,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_content.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'No documents yet. Upload a PDF to get started.',
                        style: GoogleFonts.poppins(
                          color: AppTheme.secondaryText,
                        ),
                      ),
                    )
                  else
                    ..._content.map(
                      (item) => GestureDetector(
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/mode-select',
                          arguments: item,
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.cardSurface,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.documentName,
                                style: GoogleFonts.poppins(
                                  color: AppTheme.primaryText,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: item.topics
                                    .map((topic) => TopicChip(label: topic))
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          FloatingNav(currentIndex: 0, onTap: _onNavTap),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;

  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              color: AppTheme.primaryAccent,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: AppTheme.secondaryText,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
