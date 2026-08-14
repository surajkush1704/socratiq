import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app_theme.dart';
import '../../models/content_model.dart';
import '../../services/hive_service.dart';
import '../../widgets/floating_nav.dart';
import '../../widgets/topic_chip.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<ContentModel> _all = [];
  List<ContentModel> _filtered = [];

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilter);
    _searchController.dispose();
    super.dispose();
  }

  void _load() {
    final all = HiveService.getAllContent();
    all.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    _all = all;
    _applyFilter();
  }

  void _applyFilter() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = _all
          .where((c) => c.documentName.toLowerCase().contains(q))
          .toList();
    });
  }

  void _onNavTap(int index) {
    const routes = ['/home', '/library', '/dashboard', '/settings'];
    Navigator.pushReplacementNamed(context, routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.baseSurface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'My Library',
          style: GoogleFonts.poppins(
            color: AppTheme.primaryText,
            fontWeight: FontWeight.w700,
            fontSize: 28,
          ),
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 108),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search documents',
                    filled: true,
                    fillColor: AppTheme.divider,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _filtered.isEmpty
                      ? Center(
                          child: Text(
                            'No documents found.',
                            style: GoogleFonts.poppins(
                              color: AppTheme.secondaryText,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final item = _filtered[index];
                            return GestureDetector(
                              onTap: () => Navigator.pushNamed(
                                context,
                                '/mode-select',
                                arguments: item,
                              ),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.cardSurface,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: AppTheme.cardShadow,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.picture_as_pdf_rounded,
                                      color: AppTheme.primaryAccent,
                                      size: 28,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.documentName,
                                            style: GoogleFonts.poppins(
                                              color: AppTheme.primaryText,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: item.topics
                                                .map(
                                                  (topic) =>
                                                      TopicChip(label: topic),
                                                )
                                                .toList(),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: AppTheme.secondaryText,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: 96,
            child: FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.pushNamed(context, '/upload');
                _load();
              },
              backgroundColor: AppTheme.primaryAccent,
              foregroundColor: AppTheme.cardSurface,
              label: Text(
                'Upload',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              icon: const Icon(Icons.add),
            ),
          ),
          FloatingNav(currentIndex: 1, onTap: _onNavTap),
        ],
      ),
    );
  }
}
