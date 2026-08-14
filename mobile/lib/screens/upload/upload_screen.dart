import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app_theme.dart';
import '../../models/content_model.dart';
import '../../services/api_service.dart';
import '../../services/hive_service.dart';
import '../../widgets/floating_nav.dart';
import '../../widgets/topic_chip.dart';

enum UploadState { idle, selected, uploading, processing, done, error }

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final ApiService _apiService = ApiService();

  UploadState _state = UploadState.idle;
  File? _selectedFile;
  ContentModel? _latestContent;
  List<ContentModel> _savedContent = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedContent();
  }

  void _loadSavedContent() {
    final all = HiveService.getAllContent();
    all.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    setState(() {
      _savedContent = all;
      if (all.isNotEmpty && _latestContent == null) {
        _latestContent = all.first;
        _state = UploadState.done;
      }
    });
  }

  void _onNavTap(int index) {
    const routes = ['/home', '/library', '/dashboard', '/settings'];
    Navigator.pushReplacementNamed(context, routes[index]);
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );

      if (result == null || result.files.single.path == null) {
        return;
      }

      setState(() {
        _selectedFile = File(result.files.single.path!);
        _state = UploadState.selected;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _state = UploadState.error;
        _errorMessage = 'Could not select file: $e';
      });
    }
  }

  Future<void> _processSelectedDocument() async {
    if (_selectedFile == null) return;

    final file = _selectedFile!;
    final fileName = file.path.split(Platform.pathSeparator).last;

    setState(() {
      _state = UploadState.uploading;
      _errorMessage = null;
    });

    try {
      final uploadResponse = await _apiService.uploadPdf(file);
      final extractedText = (uploadResponse['extracted_text'] ?? '').toString();

      if (extractedText.trim().isEmpty) {
        throw Exception('No text was extracted from this PDF.');
      }

      setState(() {
        _state = UploadState.processing;
      });

      final processResponse = await _apiService.processDocument(
        extractedText,
        fileName,
      );

      final keyPointsRaw = processResponse['key_points'] ?? processResponse['keyPoints'] ?? [];
      final topicsRaw = processResponse['topics'] ?? [];

      final content = ContentModel(
        documentName: fileName,
        extractedText: extractedText,
        summary: (processResponse['summary'] ?? '').toString(),
        keyPoints: List<String>.from(keyPointsRaw as List),
        topics: List<String>.from(topicsRaw as List),
        uploadedAt: DateTime.now(),
      );

      await HiveService.saveContent(content);

      setState(() {
        _latestContent = content;
        _state = UploadState.done;
      });
      _loadSavedContent();
    } catch (e) {
      setState(() {
        _state = UploadState.error;
        _errorMessage = e.toString();
      });
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _buildUploadZone() {
    final hasFile = _selectedFile != null;

    final inner = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: AppTheme.cardShadow,
        border: hasFile ? Border.all(color: AppTheme.primaryAccent, width: 2) : null,
      ),
      child: _state == UploadState.uploading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryAccent),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.upload_file_rounded,
                  size: 44,
                  color: AppTheme.primaryAccent,
                ),
                const SizedBox(height: 10),
                Text(
                  hasFile ? _selectedFile!.path.split(Platform.pathSeparator).last : 'Tap to browse PDF',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: hasFile ? AppTheme.primaryText : AppTheme.secondaryText,
                  ),
                ),
                if (hasFile) ...[
                  const SizedBox(height: 6),
                  Text(
                    _formatFileSize(_selectedFile!.lengthSync()),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.secondaryText,
                    ),
                  ),
                ],
              ],
            ),
    );

    if (hasFile) return inner;

    return CustomPaint(
      painter: _DashedRectPainter(color: AppTheme.primaryAccent, strokeWidth: 2),
      child: inner,
    );
  }

  Widget _buildResults(ContentModel content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Summary',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryText,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.cardSurface,
            borderRadius: BorderRadius.circular(2),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Text(
            content.summary,
            style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.primaryText),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Topics',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryText,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: content.topics.map((topic) => TopicChip(label: topic)).toList(),
        ),
        const SizedBox(height: 16),
        Text(
          'Key Points',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryText,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.cardSurface,
            borderRadius: BorderRadius.circular(2),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: content.keyPoints
                .map(
                  (point) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ',
                          style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.primaryText),
                        ),
                        Expanded(
                          child: Text(
                            point,
                            style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.primaryText),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/mode-select', arguments: content);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryAccent,
              foregroundColor: AppTheme.cardSurface,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              'Start Learning',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSavedFiles() {
    if (_savedContent.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'Saved Documents',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryText,
          ),
        ),
        const SizedBox(height: 8),
        ..._savedContent.map(
          (item) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppTheme.cardSurface,
              borderRadius: BorderRadius.circular(8),
              boxShadow: AppTheme.cardShadow,
            ),
            child: ListTile(
              title: Text(
                item.documentName,
                style: GoogleFonts.poppins(
                  color: AppTheme.primaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                item.uploadedAt.toLocal().toString(),
                style: GoogleFonts.poppins(color: AppTheme.secondaryText, fontSize: 12),
              ),
              onTap: () {
                setState(() {
                  _latestContent = item;
                  _state = UploadState.done;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.altSurface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryText),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Upload Study Material',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryText,
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 108),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _state == UploadState.uploading || _state == UploadState.processing ? null : _pickPdf,
                  child: _buildUploadZone(),
                ),
                const SizedBox(height: 12),
                if (_state == UploadState.selected || _state == UploadState.error || _state == UploadState.done)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _state == UploadState.processing || _state == UploadState.uploading
                          ? null
                          : _processSelectedDocument,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryAccent,
                        foregroundColor: AppTheme.cardSurface,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Process Document',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                  ),
                if (_state == UploadState.processing) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Analysing with AI...',
                    style: GoogleFonts.poppins(color: AppTheme.secondaryText, fontSize: 13),
                  ),
                ],
                if (_state == UploadState.error) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage ?? 'Something went wrong.',
                    style: GoogleFonts.poppins(color: AppTheme.error, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _selectedFile != null ? _processSelectedDocument : _pickPdf,
                    child: Text(
                      'Retry',
                      style: GoogleFonts.poppins(
                        color: AppTheme.primaryAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (_latestContent != null) ...[
                  const SizedBox(height: 18),
                  _buildResults(_latestContent!),
                ],
                _buildSavedFiles(),
              ],
            ),
          ),
          FloatingNav(currentIndex: 1, onTap: _onNavTap),
        ],
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _DashedRectPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    const dash = 8.0;
    const gap = 5.0;

    void drawDashedLine(Offset start, Offset end) {
      final totalLength = (end - start).distance;
      final direction = (end - start) / totalLength;
      double current = 0;
      while (current < totalLength) {
        final dashStart = start + direction * current;
        final dashEnd = start + direction * (current + dash > totalLength ? totalLength : current + dash);
        canvas.drawLine(dashStart, dashEnd, paint);
        current += dash + gap;
      }
    }

    final topLeft = const Offset(0, 0);
    final topRight = Offset(size.width, 0);
    final bottomLeft = Offset(0, size.height);
    final bottomRight = Offset(size.width, size.height);

    drawDashedLine(topLeft, topRight);
    drawDashedLine(topRight, bottomRight);
    drawDashedLine(bottomRight, bottomLeft);
    drawDashedLine(bottomLeft, topLeft);
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}