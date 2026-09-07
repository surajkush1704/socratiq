import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../../app_theme.dart';
import '../../services/api_service.dart';
import '../../services/hive_service.dart';
import '../../models/content_model.dart';
import '../../widgets/topic_chip.dart';
import '../session/mode_select.dart';

enum _UploadState { idle, selected, processing, done, error }

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen>
    with SingleTickerProviderStateMixin {
  _UploadState _state = _UploadState.idle;
  File? _file;
  String _fileName = '';
  String _fileSize = '';
  String _errorMessage = '';
  ContentModel? _result;

  // Processing stage animation
  int _processingStage = 0;
  late AnimationController _stageController;
  final List<String> _stages = [
    'Reading document...',
    'Understanding concepts...',
    'Preparing your tutor...',
    'Creating questions...',
  ];

  final _api = ApiService();

  @override
  void initState() {
    super.initState();
    _stageController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _stageController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    final file = File(path);
    final bytes = await file.length();
    final kb = (bytes / 1024).toStringAsFixed(1);
    setState(() {
      _file = file;
      _fileName = result.files.single.name;
      _fileSize = '$kb KB';
      _state = _UploadState.selected;
      _errorMessage = '';
    });
  }

  Future<void> _processDocument() async {
    if (_file == null) return;
    setState(() {
      _state = _UploadState.processing;
      _processingStage = 0;
    });

    // Cycle through stages visually
    _cycleStages();

    try {
      // Upload PDF
      final uploadResult = await _api.uploadPdf(_file!);
      setState(() => _processingStage = 1);

      // Process with AI
      final processResult = await _api.processDocument(
        uploadResult['extracted_text'] ?? '',
        _fileName,
      );
      setState(() => _processingStage = 3);

      // Save to Hive
      final content = ContentModel(
        documentName: _fileName,
        extractedText: uploadResult['extracted_text'] ?? '',
        summary: processResult['summary'] ?? '',
        keyPoints: List<String>.from(processResult['key_points'] ?? []),
        topics: List<String>.from(processResult['topics'] ?? []),
        uploadedAt: DateTime.now(),
      );
      await HiveService.saveContent(content);

      if (mounted) {
        setState(() {
          _result = content;
          _state = _UploadState.done;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _UploadState.error;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _cycleStages() async {
    for (int i = 0; i < _stages.length; i++) {
      await Future.delayed(const Duration(milliseconds: 1800));
      if (mounted && _state == _UploadState.processing) {
        setState(() => _processingStage = i);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final bg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bg,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1E3A8A).withOpacity(isDark ? 0.25 : 0.08),
              const Color(0xFF0891B2).withOpacity(isDark ? 0.15 : 0.05),
              bg,
              bg,
            ],
            stops: const [0.0, 0.25, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBackButton(),
                const SizedBox(height: 24),
                _buildHeading(),
                const SizedBox(height: 32),
                _buildMainArea(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    final isDark = AppTheme.isDark(context);
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.dynamicCard(context),
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.dynamicDivider(context)),
          boxShadow: isDark ? [] : AppTheme.cardShadow,
        ),
        child: Icon(Icons.arrow_back_rounded,
            color: AppTheme.dynamicText(context), size: 20),
      ),
    );
  }

  Widget _buildHeading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Give SocratiQ',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 28,
            color: AppTheme.dynamicText(context),
            letterSpacing: -0.5,
          ),
        ),
        Text(
          'something to teach.',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 28,
            color: AppTheme.primaryBlue,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Upload any PDF — textbook, notes, or chapter.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppTheme.dynamicSecondaryText(context),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildMainArea() {
    switch (_state) {
      case _UploadState.idle:
        return _buildUploadZone(false);
      case _UploadState.selected:
        return Column(
          children: [
            _buildUploadZone(true),
            const SizedBox(height: 20),
            AppTheme.gradientButton(
              label: 'Process Document',
              width: double.infinity,
              onTap: _processDocument,
            ),
          ],
        );
      case _UploadState.processing:
        return _buildProcessingState();
      case _UploadState.done:
        return _buildDoneState();
      case _UploadState.error:
        return Column(
          children: [
            _buildUploadZone(false),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                border: Border.all(
                    color: AppTheme.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppTheme.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppTheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppTheme.gradientButton(
              label: 'Try Again',
              width: double.infinity,
              onTap: () => setState(() => _state = _UploadState.idle),
            ),
          ],
        );
    }
  }

  Widget _buildUploadZone(bool fileSelected) {
    final isDark = AppTheme.isDark(context);
    final cardBg = AppTheme.dynamicCard(context);
    final borderColor = AppTheme.dynamicDivider(context);
    final textCol = AppTheme.dynamicText(context);
    final secCol = AppTheme.dynamicSecondaryText(context);

    return GestureDetector(
      onTap: fileSelected ? null : _pickFile,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          boxShadow: isDark ? [] : AppTheme.cardShadow,
          border: Border.all(
            color: fileSelected
                ? AppTheme.primaryBlue
                : borderColor,
            width: fileSelected ? 2 : 1.5,
            style: fileSelected
                ? BorderStyle.solid
                : BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!fileSelected) ...[
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.upload_file_rounded,
                  color: AppTheme.primaryBlue,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Choose PDF',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: textCol,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap to browse from your device',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: secCol,
                ),
              ),
            ] else ...[
              const Icon(Icons.picture_as_pdf_rounded,
                  color: AppTheme.error, size: 48),
              const SizedBox(height: 12),
              Text(
                _fileName,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: textCol,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _fileSize,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: secCol,
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _pickFile,
                child: Text(
                  'Change file',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E3A8A),
            Color(0xFF0E7490),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.orbGlow,
      ),
      child: Column(
        children: [
          // Owl animation placeholder
          Image.asset(
            'assets/images/logo.png',
            width: 100,
            height: 100,
          ),
          const SizedBox(height: 24),
          // Stage indicators
          ..._stages.asMap().entries.map((e) {
            final done = e.key < _processingStage;
            final active = e.key == _processingStage;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: done
                          ? AppTheme.success
                          : active
                              ? Colors.white
                              : Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: done
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 14)
                        : active
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: Padding(
                                  padding: EdgeInsets.all(4),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                              )
                            : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    e.value,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: active
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: done || active
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDoneState() {
    if (_result == null) return const SizedBox.shrink();
    final isDark = AppTheme.isDark(context);
    final cardBg = AppTheme.dynamicCard(context);
    final borderColor = AppTheme.dynamicDivider(context);
    final textCol = AppTheme.dynamicText(context);
    final secCol = AppTheme.dynamicSecondaryText(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Success header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.success.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: AppTheme.success.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: AppTheme.success, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your tutor is ready!',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: textCol,
                      ),
                    ),
                    Text(
                      _fileName.replaceAll('.pdf', ''),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: secCol,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Summary card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: borderColor),
            boxShadow: isDark ? [] : AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Summary',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: textCol,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _result!.summary,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: secCol,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Topics
        Text(
          'Detected Topics',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: textCol,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _result!.topics.map((t) => TopicChip(label: t)).toList(),
        ),
        const SizedBox(height: 16),
        // Key points
        if (_result!.keyPoints.isNotEmpty) ...[
          Text(
            'Key Concepts',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: textCol,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(color: borderColor),
              boxShadow: isDark ? [] : AppTheme.cardShadow,
            ),
            child: Column(
              children: _result!.keyPoints.take(5).map((kp) =>
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 6, right: 10),
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          kp,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: secCol,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ).toList(),
            ),
          ),
        ],
        const SizedBox(height: 24),
        // CTA
        AppTheme.gradientButton(
          label: 'Start Learning',
          width: double.infinity,
          onTap: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ModeSelectScreen(content: _result!),
            ),
          ),
        ),
      ],
    );
  }
}
