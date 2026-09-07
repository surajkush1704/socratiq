import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_theme.dart';
import '../../models/content_model.dart';
import '../../services/hive_service.dart';
import '../../services/sync_service.dart';
import '../../widgets/glass_nav.dart';
import '../session/mode_select.dart';
import '../session/learn_screen.dart';
import '../upload/upload_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<ContentModel> _allDocs = [];
  List<ContentModel> _filtered = [];
  final Map<String, String?> _docLastStudied = {};
  final TextEditingController _search = TextEditingController();
  int _filterIndex = 0; // 0=All, 1=Recent

  // Card accent colours cycling
  final _cardColors = [
    AppTheme.primaryBlue,
    AppTheme.lavenderAccent,
    AppTheme.cyanAccent,
    const Color(0xFF059669),
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(_onSearch);
  }

  void _load() {
    final docs = HiveService.getAllContent();
    setState(() {
      _allDocs = docs;
      _filtered = docs;
    });
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    for (final doc in _allDocs) {
      try {
        final history = await SyncService.getDocumentHistory(
          documentName: doc.documentName,
        );
        if (history.isNotEmpty && mounted) {
          final lastSession = history.first;
          final createdAt = lastSession['createdAt'] as String?;
          setState(() {
            _docLastStudied[doc.documentName] = SyncService.timeAgo(createdAt);
          });
        }
      } catch (e) {
        print('[LIBRARY] History load error for ${doc.documentName}: $e');
      }
    }
  }

  void _onSearch() {
    final q = _search.text.toLowerCase();
    setState(() {
      _filtered = _allDocs.where((d) =>
        d.documentName.toLowerCase().contains(q) ||
        d.topics.any((t) => t.toLowerCase().contains(q))
      ).toList();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    if (index == 0) Navigator.pushReplacementNamed(context, '/home');
    if (index == 1) return;
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LearnScreen(mode: 'learn')),
      );
    }
    if (index == 3) Navigator.pushReplacementNamed(context, '/dashboard');
    if (index == 4) Navigator.pushReplacementNamed(context, '/settings');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildSearchBar(),
                _buildFilterChips(),
                Expanded(child: _buildDocList()),
              ],
            ),
            // Floating upload pill — above GlassNav
            Positioned(
              bottom: 88,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UploadScreen()),
                  ).then((_) => _load()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      boxShadow: AppTheme.buttonShadow,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_rounded,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Upload PDF',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // GlassNav
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: GlassNav(
                currentIndex: 1,
                onTap: _onNavTap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacementNamed(context, '/home');
              }
            },
            child: Container(
              width: 38,
              height: 38,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: AppTheme.cardShadow,
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: AppTheme.navyText,
                size: 20,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'My Library',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 26,
                color: AppTheme.navyText,
                letterSpacing: -0.5,
              ),
            ),
          ),
          Text(
            '${_allDocs.length} PDFs',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppTheme.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded,
              color: AppTheme.cyanAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _search,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.navyText,
              ),
              decoration: InputDecoration(
                hintText: 'Search documents...',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.lightText,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_search.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _search.clear();
                _onSearch();
              },
              child: const Icon(Icons.close_rounded,
                  color: AppTheme.lightText, size: 18),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['All', 'Recent'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: List.generate(filters.length, (i) {
          final active = i == _filterIndex;
          return GestureDetector(
            onTap: () {
              setState(() {
                _filterIndex = i;
                if (i == 1) {
                  _filtered = List.from(_allDocs.reversed);
                } else {
                  _filtered = _allDocs;
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: active ? AppTheme.primaryBlue : Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                boxShadow: active ? AppTheme.buttonShadow : AppTheme.cardShadow,
              ),
              child: Text(
                filters[i],
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: active ? Colors.white : AppTheme.secondaryText,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDocList() {
    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.library_books_rounded,
                size: 56, color: AppTheme.divider),
            const SizedBox(height: 16),
            Text(
              _search.text.isEmpty
                  ? 'No documents yet'
                  : 'No results found',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: AppTheme.navyText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _search.text.isEmpty
                  ? 'Upload your first PDF to get started'
                  : 'Try a different search term',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.secondaryText,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 160),
      itemCount: _filtered.length,
      itemBuilder: (context, index) {
        final doc = _filtered[index];
        final color = _cardColors[index % _cardColors.length];
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ModeSelectScreen(content: doc),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Row(
              children: [
                // Coloured icon box
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusXS),
                  ),
                  child: Icon(
                    Icons.picture_as_pdf_rounded,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                // Doc info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.documentName.replaceAll('.pdf', ''),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppTheme.navyText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _docLastStudied[doc.documentName] != null
                            ? 'Studied ${_docLastStudied[doc.documentName]} · ${doc.topics.take(2).join(' · ')}'
                            : doc.topics.isNotEmpty
                                ? doc.topics.take(2).join(' · ')
                                : 'No topics extracted',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.secondaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Topic chips row
                      if (doc.topics.isNotEmpty)
                        Wrap(
                          spacing: 6,
                          children: doc.topics.take(3).map((t) =>
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                t,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: color,
                                ),
                              ),
                            ),
                          ).toList(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded,
                    color: AppTheme.lightText, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
