import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_theme.dart';
import '../../models/content_model.dart';
import '../../models/mcq_model.dart';
import '../../services/api_service.dart';
import '../../services/hive_service.dart';
import '../../services/sync_service.dart';
import '../../services/voice_service.dart';
import '../../widgets/voice_orb_painter.dart';
import '../../widgets/app_page_route.dart';
import '../permission/mic_permission_screen.dart';
import '../session/result_screen.dart';

enum VoiceState { idle, listening, thinking, speaking }

class LearnScreen extends StatefulWidget {
  final ContentModel? content;
  final String mode;

  const LearnScreen({
    this.content,
    this.mode = 'learn',
    super.key,
  });

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen>
    with TickerProviderStateMixin {

  // ── Services ───────────────────────────────────────────────────────────────
  final _api = ApiService();
  final _voice = VoiceService();

  // ── Session state ──────────────────────────────────────────────────────────
  String? _sessionId;
  bool _sessionLoading = true;
  String? _sessionError;
  final List<String> _attachedDocumentNames = [];
  bool _isUploadingPdf = false;

  // ── UI state ───────────────────────────────────────────────────────────────
  VoiceState _voiceState = VoiceState.idle;
  bool _isAiThinking = false;
  bool _isSpeakingTTS = false;
  bool _isRecording = false;
  bool _permissionDenied = false;
  String _statusLabel = 'Tap and hold mic to speak';
  DateTime? _recordingStartTime;
  Timer? _maxRecordingTimer;
  Timer? _ttsWatchdogTimer;

  // ── Transcript ─────────────────────────────────────────────────────────────
  final List<Map<String, String>> _messages = [];
  final ScrollController _scrollController = ScrollController();

  // ── Text input ────────────────────────────────────────────────────────────
  final TextEditingController _inputController = TextEditingController();
  bool _showTextInput = false; // toggle between text and voice mode

  // ── MCQ state ─────────────────────────────────────────────────────────────
  MCQModel? _currentMcq;
  final List<MCQModel> _askedQuestions = [];
  final Map<int, int> _userAnswers = {};

  // ── Session stats ─────────────────────────────────────────────────────────
  int _questionsAsked = 0;
  int _questionsCorrect = 0;
  double _scoreSum = 0.0;

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _rotationController;
  late Animation<double> _rotation;
  late AnimationController _pulseController;
  late Animation<double> _pulse;
  late AnimationController _ringsController;
  late Animation<double> _ringsAnim;
  late AnimationController _micScaleController;
  late Animation<double> _micScale;

  @override
  void initState() {
    super.initState();
    if (widget.content != null) {
      _attachedDocumentNames.add(widget.content!.documentName);
    }
    _setupAnimations();
    _checkMicPermission();
    _startSession();
  }

  void _setupAnimations() {
    // Orb rotation
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _rotation = Tween<double>(begin: 0, end: 2 * math.pi)
        .animate(_rotationController);

    // Orb pulse — used when AI is thinking or speaking
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.08).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    // Listening rings — expand outward when recording
    _ringsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _ringsAnim = CurvedAnimation(
        parent: _ringsController, curve: Curves.easeOut);

    // Mic button scale — bounces on press
    _micScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.88,
      upperBound: 1.0,
      value: 1.0,
    );
    _micScale = _micScaleController;
  }

  Future<void> _checkMicPermission() async {
    final hasPermission = await _voice.hasMicPermission();
    if (!hasPermission) {
      final granted = await _voice.requestMicPermission();
      setState(() => _permissionDenied = !granted);
      if (!granted) {
        print('[LEARN] Microphone permission denied');
      }
    }
  }

  Future<void> _startSession() async {
    try {
      setState(() {
        _sessionLoading = true;
        _sessionError = null;
        _statusLabel = 'Starting session...';
      });

      final docName = widget.content?.documentName ?? 'General Study Session';
      final summary = widget.content?.summary ?? '';
      final keyPoints = widget.content?.keyPoints ?? <String>[];
      final topics = widget.content?.topics ?? <String>[];
      final docLang = widget.content?.documentLanguage ?? 'en';
      final respLang = widget.content?.responseLanguage ?? 'en';
      final langName = widget.content?.languageDisplayName ?? 'English';

      final result = await _api.startSession(
        documentName: docName,
        summary: summary,
        keyPoints: keyPoints,
        topics: topics,
        mode: widget.mode,
        documentLanguage: docLang,
        responseLanguage: respLang,
        languageDisplayName: langName,
      );

      final sessionId = result['session_id'] as String;
      final firstMessage = result['first_message'] as String;

      setState(() {
        _sessionId = sessionId;
        _sessionLoading = false;
        _messages.add({'role': 'ai', 'content': firstMessage});
        _statusLabel = 'Tap and hold mic to speak';
      });

      print('[LEARN] Session started: $sessionId');
      _scrollToBottom();

      // Auto-play the opening message via TTS
      await _speakAiResponse(firstMessage);

    } catch (e) {
      print('[LEARN] Session start error: $e');
      final fallbackDoc = widget.content != null
          ? '"${widget.content!.documentName}"'
          : 'any topic';
      setState(() {
        _sessionLoading = false;
        _sessionError = e.toString();
        _statusLabel = 'Tap and hold mic to speak';
        _messages.add({
          'role': 'ai',
          'content': 'Hello! I\'m your AI Tutor ready to help you prepare for $fallbackDoc. '
              'What would you like to learn today? You can also upload a PDF anytime.',
        });
      });
    }
  }

  // ── VOICE RECORDING FLOW ──────────────────────────────────────────────────

  Future<void> _onMicTapDown() async {
    if (_isAiThinking || _sessionLoading) return;
    if (_permissionDenied) {
      _showPermissionDialog();
      return;
    }

    // Stop any ongoing TTS playback immediately when user taps mic to speak
    if (_isSpeakingTTS) {
      _ttsWatchdogTimer?.cancel();
      try {
        await _voice.stopPlayback();
      } catch (e) {
        print('[LEARN] Stop TTS error: $e');
      }
      setState(() {
        _isSpeakingTTS = false;
        _voiceState = VoiceState.idle;
      });
    }

    print('[LEARN] Mic pressed — starting recording');

    _micScaleController.reverse();

    final started = await _voice.startRecording();
    if (!started) {
      print('[LEARN] Recording failed to start — mic busy or permission denied');
      _micScaleController.forward();
      setState(() {
        _isRecording = false;
        _voiceState = VoiceState.idle;
        _statusLabel = _permissionDenied
            ? 'Microphone permission needed'
            : 'Microphone busy — please try again';
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _statusLabel.contains('Microphone')) {
          setState(() => _statusLabel = 'Tap and hold mic to speak');
        }
      });
      return;
    }

    _recordingStartTime = DateTime.now();

    // Maximum recording duration of 30 seconds with automatic stop-and-send
    _maxRecordingTimer?.cancel();
    _maxRecordingTimer = Timer(const Duration(seconds: 30), () {
      if (_isRecording && mounted) {
        print('[LEARN] Maximum recording duration of 30 seconds reached — auto-stopping and sending');
        _onMicTapUp();
      }
    });

    setState(() {
      _isRecording = true;
      _voiceState = VoiceState.listening;
      _statusLabel = 'Listening... (release to send)';
    });

    _ringsController.repeat();
    _rotationController.duration = const Duration(seconds: 4);
  }

  Future<void> _onMicTapUp() async {
    if (!_isRecording) return;

    _maxRecordingTimer?.cancel();
    _maxRecordingTimer = null;

    final duration = _recordingStartTime != null
        ? DateTime.now().difference(_recordingStartTime!)
        : Duration.zero;

    print('[LEARN] Mic released — duration: ${duration.inMilliseconds}ms');

    _micScaleController.forward();
    _ringsController.stop();
    _ringsController.reset();
    _rotationController.duration = const Duration(seconds: 8);

    // Minimum recording duration of 800 milliseconds
    if (duration.inMilliseconds < 800) {
      print('[LEARN] Recording duration too short (${duration.inMilliseconds}ms < 800ms) — discarding');
      await _voice.cancelRecording();
      setState(() {
        _isRecording = false;
        _voiceState = VoiceState.idle;
        _statusLabel = 'Hold for longer to speak';
      });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted && !_isRecording && !_isAiThinking && !_isSpeakingTTS) {
        setState(() => _statusLabel = 'Tap and hold mic to speak');
      }
      return;
    }

    setState(() {
      _isRecording = false;
      _voiceState = VoiceState.thinking;
      _statusLabel = 'Transcribing...';
      _isAiThinking = true;
    });

    final audioPath = await _voice.stopRecording();

    if (audioPath == null) {
      print('[LEARN] No audio recorded or file was empty');
      setState(() {
        _isAiThinking = false;
        _voiceState = VoiceState.idle;
        _statusLabel = 'No audio detected — try again';
      });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted && !_isRecording && !_isAiThinking && !_isSpeakingTTS) {
        setState(() => _statusLabel = 'Tap and hold mic to speak');
      }
      return;
    }

    final respLang = widget.content?.responseLanguage ?? 'en';
    final result = await _voice.transcribeAudio(
      audioPath,
      sessionId: _sessionId ?? '',
      language: respLang,
    );

    if (!result.isSuccess || result.transcript.trim().isEmpty) {
      print('[LEARN] STT failed: reason=${result.failureReason}, error=${result.errorMessage}');

      String failureMsg;
      switch (result.failureReason) {
        case SttFailureReason.tooShort:
          failureMsg = 'Hold for longer to speak';
          break;
        case SttFailureReason.microphoneBusy:
          failureMsg = 'Microphone busy — please try again';
          break;
        case SttFailureReason.networkError:
          failureMsg = 'Network error — please check connection';
          break;
        case SttFailureReason.noSpeechDetected:
          failureMsg = 'No speech detected — try again';
          break;
        case SttFailureReason.serverError:
          failureMsg = 'Transcription error — please try again';
          break;
        default:
          failureMsg = 'Could not hear you — try again';
      }

      setState(() {
        _isAiThinking = false;
        _voiceState = VoiceState.idle;
        _statusLabel = failureMsg;
      });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted && !_isRecording && !_isAiThinking && !_isSpeakingTTS) {
        setState(() => _statusLabel = 'Tap and hold mic to speak');
      }
      return;
    }

    final transcript = result.transcript;
    print('[LEARN] STT transcription successful: "$transcript"');

    setState(() {
      _messages.add({'role': 'user', 'content': transcript});
      _statusLabel = 'Thinking...';
    });
    _scrollToBottom();

    await _sendToSession(transcript, 'question');
  }

  Future<void> _onMicCancel() async {
    if (!_isRecording) return;
    _maxRecordingTimer?.cancel();
    _maxRecordingTimer = null;
    print('[LEARN] Mic cancelled');
    _micScaleController.forward();
    _ringsController.stop();
    _ringsController.reset();
    await _voice.cancelRecording();
    setState(() {
      _isRecording = false;
      _voiceState = VoiceState.idle;
      _statusLabel = 'Cancelled';
    });
    await Future.delayed(const Duration(seconds: 1));
    if (mounted && !_isRecording && !_isAiThinking && !_isSpeakingTTS) {
      setState(() => _statusLabel = 'Tap and hold mic to speak');
    }
  }

  // ── SESSION INTERACTION FLOW ──────────────────────────────────────────────

  Future<void> _sendToSession(String input, String type) async {
    if (_isAiThinking) return;
    if (_sessionId == null && _sessionError == null) return;

    // Stop TTS if user is interacting
    if (_isSpeakingTTS) {
      _ttsWatchdogTimer?.cancel();
      try {
        await _voice.stopPlayback();
      } catch (_) {}
      setState(() {
        _isSpeakingTTS = false;
        _voiceState = VoiceState.idle;
      });
    }

    if (type != 'request_mcq' &&
        (_messages.isEmpty || _messages.last['content'] != input)) {
      setState(() => _messages.add({'role': 'user', 'content': input}));
      _inputController.clear();
    }

    setState(() {
      _isAiThinking = true;
      _voiceState = VoiceState.thinking;
      _statusLabel = 'Thinking...';
    });
    _rotationController.duration = const Duration(seconds: 12);

    try {
      final response = await _api.interact(
        sessionId: _sessionId ?? 'offline',
        userInput: input,
        interactionType: type,
      );

      final aiMessage = response['ai_message'] as String? ?? '';
      final mcqData = response['mcq'];
      final score = response['score'] != null
          ? (response['score'] as num).toDouble()
          : null;

      setState(() {
        _isAiThinking = false;
        _rotationController.duration = const Duration(seconds: 8);

        if (aiMessage.isNotEmpty) {
          final isTriggerReasoning =
              response['trigger_reasoning'] as bool? ?? false;
          _messages.add({
            'role': 'ai',
            'content': aiMessage,
            'type': isTriggerReasoning ? 'reasoning' : 'normal',
          });
        }

        if (score != null) {
          _scoreSum += score;
          if (score >= 7) _questionsCorrect++;
          _questionsAsked++;
        }

        if (mcqData != null) {
          _currentMcq = MCQModel(
            question: mcqData['question'] as String,
            options: List<String>.from(mcqData['options']),
            correctIndex: mcqData['correct_index'] as int,
            explanation: mcqData['explanation'] as String? ?? '',
          );
          _askedQuestions.add(_currentMcq!);
          _questionsAsked++;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showMcqSheet();
          });
        }
      });

      _scrollToBottom();

      if (aiMessage.isNotEmpty) {
        await _speakAiResponse(aiMessage);
      }

    } catch (e) {
      print('[LEARN] Interact error: $e');
      setState(() {
        _isAiThinking = false;
        _voiceState = VoiceState.idle;
        _statusLabel = 'Error — try again';
        _messages.add({
          'role': 'ai',
          'content': 'Sorry, I had trouble responding. Please try again.',
        });
      });
    }
  }

  String _cleanTextForSpeech(String text) {
    var cleaned = text;
    // Remove markdown bold/italic asterisks & underscores
    cleaned = cleaned.replaceAll(RegExp(r'\*+'), '');
    cleaned = cleaned.replaceAll(RegExp(r'_+'), '');
    // Remove markdown headers (#, ##, etc.)
    cleaned = cleaned.replaceAll(RegExp(r'#+\s*'), '');
    // Remove backticks
    cleaned = cleaned.replaceAll(RegExp(r'`+'), '');
    // Remove bullet point markers at start of lines
    cleaned = cleaned.replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '');
    // Remove links [text](url) -> text
    cleaned = cleaned.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m.group(1) ?? '');
    // Collapse extra whitespaces
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned;
  }

  Future<void> _speakAiResponse(String text) async {
    if (!mounted) return;

    final spokenText = _cleanTextForSpeech(text);
    if (spokenText.isEmpty) return;

    setState(() {
      _isSpeakingTTS = true;
      _voiceState = VoiceState.speaking;
      _statusLabel = 'Speaking...';
    });
    _rotationController.duration = const Duration(seconds: 6);

    _ttsWatchdogTimer?.cancel();
    // Safety watchdog: reset speaking state after max 45 seconds if callback fails
    _ttsWatchdogTimer = Timer(const Duration(seconds: 45), () {
      if (mounted && _isSpeakingTTS) {
        print('[LEARN] TTS watchdog expired — resetting speech state');
        setState(() {
          _isSpeakingTTS = false;
          _voiceState = VoiceState.idle;
          _statusLabel = 'Tap and hold mic to speak';
        });
        _rotationController.duration = const Duration(seconds: 8);
      }
    });

    final respLang = widget.content?.responseLanguage ?? 'en';
    await _voice.speakText(
      spokenText,
      voice: ApiService.voiceId,
      speed: ApiService.voiceSpeed,
      sessionId: _sessionId ?? '',
      language: respLang,
      onStart: () {
        if (mounted) {
          setState(() {
            _isSpeakingTTS = true;
            _voiceState = VoiceState.speaking;
          });
        }
      },
      onComplete: () {
        _ttsWatchdogTimer?.cancel();
        if (mounted) {
          setState(() {
            _isSpeakingTTS = false;
            _voiceState = VoiceState.idle;
            _statusLabel = 'Tap and hold mic to speak';
          });
          _rotationController.duration = const Duration(seconds: 8);
        }
      },
      onError: () {
        _ttsWatchdogTimer?.cancel();
        if (mounted) {
          setState(() {
            _isSpeakingTTS = false;
            _voiceState = VoiceState.idle;
            _statusLabel = 'Tap and hold mic to speak';
          });
        }
      },
    );
  }

  // ── MCQ SHEET ─────────────────────────────────────────────────────────────

  void _showMcqSheet() {
    if (_currentMcq == null) return;

    _speakAiResponse(_currentMcq!.question);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MCQSheet(
        mcq: _currentMcq!,
        questionIndex: _askedQuestions.length - 1,
        onSubmit: (selectedIndex) {
          _userAnswers[_askedQuestions.length - 1] = selectedIndex;
          final selectedOption = _currentMcq!.options[selectedIndex];
          _sendToSession(selectedOption, 'answer');
        },
        onContinue: () => Navigator.pop(context),
      ),
    );
  }

  // ── IN-SESSION PDF UPLOAD (COMBINED CHAPTER) ──────────────────────────────

  Future<void> _uploadPdfInSession() async {
    if (_isUploadingPdf || _isAiThinking || _isSpeakingTTS) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result == null || result.files.single.path == null) return;

      setState(() {
        _isUploadingPdf = true;
        _statusLabel = 'Adding PDF to session chapter...';
      });

      final path = result.files.single.path!;
      final file = File(path);
      final fileName = result.files.single.name;

      // 1. Upload PDF
      final uploadResult = await _api.uploadPdf(file);
      final extractedText = uploadResult['extracted_text'] as String? ?? '';

      // 2. Process with AI
      final processResult = await _api.processDocument(extractedText, fileName);
      final summary = processResult['summary'] as String? ?? '';
      final keyPoints = List<String>.from(processResult['key_points'] ?? []);
      final topics = List<String>.from(processResult['topics'] ?? []);

      // 3. Save to local Hive so it's in Library
      final newContent = ContentModel(
        documentName: fileName,
        extractedText: extractedText,
        summary: summary,
        keyPoints: keyPoints,
        topics: topics,
      );
      await HiveService.saveContent(newContent);

      // 4. Merge into active session state on backend
      String ackMsg = 'I have added "$fileName" to our combined study chapter. We can now study it together!';
      if (_sessionId != null) {
        final addRes = await _api.addDocumentToSession(
          sessionId: _sessionId!,
          documentName: fileName,
          summary: summary,
          keyPoints: keyPoints,
          topics: topics,
        );
        ackMsg = addRes['ack_message'] as String? ?? ackMsg;
      }

      setState(() {
        _attachedDocumentNames.add(fileName);
        _isUploadingPdf = false;
        _statusLabel = 'Tap and hold mic to speak';
        _messages.add({'role': 'ai', 'content': ackMsg});
      });

      _scrollToBottom();
      await _speakAiResponse(ackMsg);

    } catch (e) {
      print('[LEARN] In-session upload error: $e');
      setState(() {
        _isUploadingPdf = false;
        _statusLabel = 'Upload failed. Tap mic to continue.';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to add PDF: $e', style: GoogleFonts.dmSans(fontSize: 13)),
          backgroundColor: AppTheme.error,
        ));
      }
    }
  }

  void _onBackPressed() {
    _endSession();
  }

  // ── END SESSION ───────────────────────────────────────────────────────────

  Future<void> _endSession() async {
    _maxRecordingTimer?.cancel();
    _maxRecordingTimer = null;
    if (_isRecording) await _voice.cancelRecording();
    if (_isSpeakingTTS) await _voice.stopPlayback();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
        title: Text('Leave session?',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        content: Text(
          'Do you want to end this study session? Your progress will be saved.',
          style: GoogleFonts.dmSans(
              fontSize: 14, color: AppTheme.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Stay',
                style: GoogleFonts.dmSans(color: AppTheme.primaryBlue)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('End',
                style: GoogleFonts.dmSans(
                    color: AppTheme.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (_sessionId != null) {
      try {
        final sessionEndResult = await _api.endSession(_sessionId!).timeout(
          const Duration(seconds: 3),
          onTimeout: () => {'duration_sec': 60},
        );
        final durationSec = sessionEndResult['duration_sec'] as int? ?? 0;

        final docName = widget.content?.documentName ??
            (_attachedDocumentNames.isNotEmpty
                ? _attachedDocumentNames.join(' + ')
                : 'General Study Session');
        final topics = widget.content?.topics ?? <String>[];

        await SyncService.syncSession(
          sessionId: _sessionId!,
          documentName: docName,
          mode: widget.mode,
          durationSec: durationSec > 0 ? durationSec : 60,
          score: _questionsAsked > 0 ? _scoreSum / _questionsAsked : 0.0,
          questionsAttempted: _questionsAsked,
          questionsCorrect: _questionsCorrect,
          topics: topics,
        ).timeout(const Duration(seconds: 3), onTimeout: () => {});
      } catch (e) {
        print('[LEARN] Session sync error (non-fatal): $e');
      }
    }

    if (!mounted) return;

    if (_askedQuestions.isNotEmpty) {
      final avgScore = _scoreSum / _questionsAsked.clamp(1, 9999);
      final effectiveDoc = widget.content ??
          ContentModel(
            documentName: _attachedDocumentNames.isNotEmpty
                ? _attachedDocumentNames.join(' + ')
                : 'General Topic Session',
            extractedText: '',
            summary: 'General audio tutoring session',
            keyPoints: [],
            topics: [],
          );

      Navigator.pushReplacement(
        context,
        AppPageRoute(
          builder: (_) => ResultScreen(
            content: effectiveDoc,
            score: avgScore,
            totalQuestions: _askedQuestions.length,
            correctAnswers: _questionsCorrect,
            questions: _askedQuestions,
            userAnswers: _userAnswers,
          ),
        ),
      );
    } else {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    }
  }

  // ── PERMISSION SCREEN ────────────────────────────────────────────────────

  void _showPermissionDialog() {
    Navigator.push(
      context,
      AppPageRoute(
        builder: (_) => MicPermissionScreen(
          onGranted: () async {
            Navigator.pop(context);
            setState(() => _permissionDenied = false);
            await _voice.requestMicPermission();
          },
          onDenied: () {
            Navigator.pop(context);
            setState(() => _permissionDenied = true);
          },
        ),
      ),
    );
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  VoiceOrbState get _orbState {
    if (_isSpeakingTTS) return VoiceOrbState.speaking;
    if (_isAiThinking) return VoiceOrbState.thinking;
    if (_isRecording) return VoiceOrbState.listening;
    switch (_voiceState) {
      case VoiceState.idle:
        return VoiceOrbState.idle;
      case VoiceState.listening:
        return VoiceOrbState.listening;
      case VoiceState.thinking:
        return VoiceOrbState.thinking;
      case VoiceState.speaking:
        return VoiceOrbState.speaking;
    }
  }

  @override
  void dispose() {
    _maxRecordingTimer?.cancel();
    _maxRecordingTimer = null;
    _ttsWatchdogTimer?.cancel();
    _ttsWatchdogTimer = null;
    _rotationController.dispose();
    _pulseController.dispose();
    _ringsController.dispose();
    _micScaleController.dispose();
    _scrollController.dispose();
    _inputController.dispose();
    _voice.stopPlayback();
    _voice.dispose();
    super.dispose();
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── Background Aurora Gradient ──
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0F172A),
                    Color(0xFF1E3A8A),
                    Color(0xFF0E7490),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),

                if (_showTextInput) ...[
                  // Full chat transcript when text input is active
                  Expanded(child: _buildTranscript()),
                  _buildContextualChips(),
                  const SizedBox(height: 10),
                  _buildTextInput(),
                  const SizedBox(height: 8),
                ] else ...[
                  // ── Hero Voice Orb Centerpiece (~50% height) ──
                  Expanded(
                    flex: 5,
                    child: Center(
                      child: VoiceOrbWidget(
                        state: _orbState,
                        rotation: _rotation,
                        pulse: _pulse,
                        ringsAnim: _ringsAnim,
                        size: 190,
                        statusLabel: _statusLabel,
                      ),
                    ),
                  ),

                  // ── Compact Scrollable Transcript Box (~35% height) ──
                  Expanded(
                    flex: 4,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.28),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.14),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: _buildTranscript(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                  _buildContextualChips(),
                  const SizedBox(height: 10),
                  _buildVoiceControls(),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── TOP BAR ───────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    final docTitle = _attachedDocumentNames.isNotEmpty
        ? (_attachedDocumentNames.length > 1
            ? 'Chapter (${_attachedDocumentNames.length} PDFs)'
            : _attachedDocumentNames.first.replaceAll('.pdf', ''))
        : (widget.content != null
            ? widget.content!.documentName.replaceAll('.pdf', '')
            : 'Open Topic');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          // Top-left Back Button
          GestureDetector(
            onTap: _onBackPressed,
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          // Topic/Mode badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.mode[0].toUpperCase() + widget.mode.substring(1),
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.cyanAccent,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text('·',
                      style: TextStyle(color: Colors.white.withOpacity(0.4))),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    docTitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.content != null && widget.content!.documentLanguage != 'en') ...[
                  const SizedBox(width: 6),
                  Text('•', style: TextStyle(color: Colors.white.withOpacity(0.4))),
                  const SizedBox(width: 6),
                  Text(
                    widget.content!.documentLanguage == 'sa' ? 'हिंदी' : 'हिंदी',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.cyanAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Spacer(),
          // In-Session PDF Upload Button
          GestureDetector(
            onTap: _uploadPdfInSession,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _isUploadingPdf
                    ? AppTheme.primaryBlue.withOpacity(0.4)
                    : Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isUploadingPdf)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  else
                    const Icon(
                      Icons.upload_file_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                  const SizedBox(width: 4),
                  Text(
                    '+ PDF',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_questionsAsked > 0)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$_questionsCorrect/$_questionsAsked ✓',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          GestureDetector(
            onTap: () => setState(() => _showTextInput = !_showTextInput),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: _showTextInput
                    ? AppTheme.cyanAccent.withOpacity(0.25)
                    : Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: _showTextInput
                      ? AppTheme.cyanAccent.withOpacity(0.5)
                      : Colors.white.withOpacity(0.15),
                ),
              ),
              child: Icon(
                _showTextInput
                    ? Icons.keyboard_rounded
                    : Icons.keyboard_alt_outlined,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
          GestureDetector(
            onTap: _endSession,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.2),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppTheme.error.withOpacity(0.4)),
              ),
              child: Text(
                'End',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.error,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── TRANSCRIPT ────────────────────────────────────────────────────────────

  Widget _buildTranscript() {
    return _sessionLoading
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                ),
                const SizedBox(height: 12),
                Text(
                  'Starting your session...',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          )
        : ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            itemCount:
                _messages.length + (_isAiThinking ? 1 : 0),
            itemBuilder: (context, i) {
              if (_isAiThinking && i == _messages.length) {
                return _buildThinkingBubble();
              }
              final msg = _messages[i];
              final isAI = msg['role'] == 'ai';
              return _buildMessageBubble(
                  msg['content'] ?? '', isAI);
            },
          );
  }

  Widget _buildMessageBubble(String text, bool isAI) {
    return Align(
      alignment:
          isAI ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isAI
              ? Colors.black.withOpacity(0.35)
              : AppTheme.primaryBlue.withOpacity(0.55),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isAI ? 4 : 18),
            bottomRight: Radius.circular(isAI ? 18 : 4),
          ),
          border: Border.all(
            color: isAI
                ? Colors.white.withOpacity(0.20)
                : AppTheme.cyanAccent.withOpacity(0.40),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: GoogleFonts.dmSans(
            fontSize: 14,
            color: Colors.white.withOpacity(0.95),
            height: 1.6,
          ),
        ),
      ),
    );
  }

  Widget _buildThinkingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: RepaintBoundary(
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              return AnimatedBuilder(
                animation: _pulseController,
                builder: (_, __) {
                  final delay = i * 0.33;
                  final val = (_pulseController.value - delay)
                      .clamp(0.0, 1.0);
                  return Container(
                    width: 8,
                    height: 8,
                    margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                    decoration: BoxDecoration(
                      color: Colors.white
                          .withOpacity(0.25 + val * 0.7),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              );
            }),
          ),
        ),
      ),
    );
  }

  // ── CONTEXTUAL CHIPS ──────────────────────────────────────────────────────

  Widget _buildContextualChips() {
    final chips = [
      ('Explain differently', 'explain_differently'),
      ('Give example', 'give_example'),
      ('Quiz me', 'request_mcq'),
      ('Go deeper', 'go_deeper'),
    ];

    final busy = _isAiThinking || _isRecording || _isSpeakingTTS;

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final chip = chips[i];
          return GestureDetector(
            onTap: busy
                ? null
                : () {
                    if (chip.$2 == 'request_mcq') {
                      _sendToSession('Quiz me', 'request_mcq');
                    } else {
                      setState(() => _messages.add({
                            'role': 'user',
                            'content': chip.$1
                          }));
                      _sendToSession(chip.$1, 'contextual');
                    }
                  },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white
                    .withOpacity(busy ? 0.06 : 0.16),
                borderRadius: BorderRadius.circular(
                    AppTheme.radiusPill),
                border: Border.all(
                    color:
                        Colors.white.withOpacity(0.2)),
              ),
              child: Text(
                chip.$1,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: Colors.white
                      .withOpacity(busy ? 0.35 : 0.9),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── VOICE CONTROLS (mic button) ───────────────────────────────────────────

  Widget _buildVoiceControls() {
    final busy = _isAiThinking || _sessionLoading;
    final canRecord = !busy && !_permissionDenied;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildGlassCircleButton(
            icon: _isSpeakingTTS
                ? Icons.volume_off_rounded
                : Icons.pause_rounded,
            size: 48,
            onTap: _isSpeakingTTS
                ? () async {
                    await _voice.stopPlayback();
                    setState(() {
                      _isSpeakingTTS = false;
                      _voiceState = VoiceState.idle;
                      _statusLabel = 'Tap and hold mic to speak';
                    });
                  }
                : null,
            active: _isSpeakingTTS,
          ),
          const SizedBox(width: 28),

          GestureDetector(
            onTapDown: canRecord ? (_) => _onMicTapDown() : null,
            onTapUp: (_) => _onMicTapUp(),
            onTapCancel: () => _onMicCancel(),
            child: AnimatedBuilder(
              animation: _micScale,
              builder: (_, __) => Transform.scale(
                scale: _micScale.value,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    gradient: canRecord
                        ? (_isRecording
                            ? LinearGradient(
                                colors: [
                                  AppTheme.cyanAccent,
                                  AppTheme.cyanAccent
                                      .withOpacity(0.7),
                                ],
                              )
                            : AppTheme.primaryGradient)
                        : null,
                    color: canRecord
                        ? null
                        : Colors.white.withOpacity(0.12),
                    shape: BoxShape.circle,
                    boxShadow: canRecord
                        ? (_isRecording
                            ? [
                                BoxShadow(
                                  color: AppTheme.cyanAccent
                                      .withOpacity(0.5),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                )
                              ]
                            : AppTheme.buttonShadow)
                        : null,
                  ),
                  child: Icon(
                    _isRecording
                        ? Icons.stop_rounded
                        : Icons.mic_rounded,
                    color: Colors.white.withOpacity(
                        canRecord ? 1.0 : 0.3),
                    size: 32,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 28),

          _buildGlassCircleButton(
            icon: Icons.keyboard_rounded,
            size: 48,
            onTap: () =>
                setState(() => _showTextInput = !_showTextInput),
            active: false,
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCircleButton({
    required IconData icon,
    required double size,
    VoidCallback? onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: active
              ? AppTheme.cyanAccent.withOpacity(0.25)
              : Colors.white.withOpacity(
                  onTap != null ? 0.18 : 0.06),
          shape: BoxShape.circle,
          border: Border.all(
            color: active
                ? AppTheme.cyanAccent.withOpacity(0.5)
                : Colors.white.withOpacity(0.2),
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white.withOpacity(
              onTap != null ? 0.9 : 0.3),
          size: size * 0.42,
        ),
      ),
    );
  }

  // ── TEXT INPUT (fallback) ─────────────────────────────────────────────────

  Widget _buildTextInput() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 12,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius:
              BorderRadius.circular(AppTheme.radiusPill),
          border: Border.all(
              color: Colors.white.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  hintText: 'Type your answer or question...',
                  hintStyle: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.4),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 10),
                ),
                maxLines: 1,
                onSubmitted: (text) {
                  if (text.trim().isNotEmpty) {
                    setState(() => _messages.add(
                        {'role': 'user', 'content': text}));
                    _sendToSession(text, 'question');
                  }
                },
                textInputAction: TextInputAction.send,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _isAiThinking
                  ? null
                  : () {
                      final text = _inputController.text;
                      if (text.trim().isNotEmpty) {
                        setState(() => _messages.add({
                              'role': 'user',
                              'content': text
                            }));
                        _sendToSession(text, 'question');
                      }
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: _isAiThinking
                      ? null
                      : AppTheme.primaryGradient,
                  color: _isAiThinking
                      ? Colors.white.withOpacity(0.1)
                      : null,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.send_rounded,
                  color: Colors.white.withOpacity(
                      _isAiThinking ? 0.3 : 1.0),
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── MCQ BOTTOM SHEET ──────────────────────────────────────────────────────────

class _MCQSheet extends StatefulWidget {
  final MCQModel mcq;
  final int questionIndex;
  final Function(int) onSubmit;
  final VoidCallback onContinue;

  const _MCQSheet({
    required this.mcq,
    required this.questionIndex,
    required this.onSubmit,
    required this.onContinue,
  });

  @override
  State<_MCQSheet> createState() => _MCQSheetState();
}

class _MCQSheetState extends State<_MCQSheet> {
  int? _selected;
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final textCol = AppTheme.dynamicText(context);
    final secCol = AppTheme.dynamicSecondaryText(context);
    final cardBg = AppTheme.dynamicCard(context);
    final borderColor = AppTheme.dynamicDivider(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard.withOpacity(0.98) : Colors.white.withOpacity(0.96),
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusXL)),
      ),
      child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: borderColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Text(
                  'Quick check',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.cyanAccent,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.mcq.question,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: textCol,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                ...List.generate(widget.mcq.options.length, (i) {
                  final sel = _selected == i;
                  final correct =
                      _submitted && i == widget.mcq.correctIndex;
                  final wrong = _submitted &&
                      sel &&
                      i != widget.mcq.correctIndex;

                  Color border = borderColor;
                  Color bg = cardBg;
                  if (sel && !_submitted) {
                    border = AppTheme.primaryBlue;
                    bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF);
                  }
                  if (correct) {
                    border = AppTheme.success;
                    bg = isDark ? const Color(0xFF064E3B).withOpacity(0.4) : const Color(0xFFECFDF5);
                  }
                  if (wrong) {
                    border = AppTheme.error;
                    bg = isDark ? const Color(0xFF7F1D1D).withOpacity(0.4) : const Color(0xFFFEF2F2);
                  }

                  return GestureDetector(
                    onTap: _submitted
                        ? null
                        : () => setState(() => _selected = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(
                            AppTheme.radiusSmall),
                        border: Border.all(
                            color: border, width: 1.5),
                        boxShadow: isDark ? [] : AppTheme.cardShadow,
                      ),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration:
                                const Duration(milliseconds: 200),
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: sel
                                  ? AppTheme.primaryBlue
                                  : (isDark ? AppTheme.darkBackgroundAlt : AppTheme.backgroundAlt),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              ['A', 'B', 'C', 'D'][i],
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: sel
                                    ? Colors.white
                                    : secCol,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.mcq.options[i],
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                fontWeight: sel
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: AppTheme.navyText,
                              ),
                            ),
                          ),
                          if (correct)
                            const Icon(Icons.check_circle_rounded,
                                color: AppTheme.success, size: 20),
                          if (wrong)
                            const Icon(Icons.cancel_rounded,
                                color: AppTheme.error, size: 20),
                        ],
                      ),
                    ),
                  );
                }),
                if (_submitted && widget.mcq.explanation.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(
                          AppTheme.radiusSmall),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                            Icons.lightbulb_outline_rounded,
                            color: AppTheme.primaryBlue,
                            size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.mcq.explanation,
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: AppTheme.secondaryText,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                if (!_submitted)
                  GestureDetector(
                    onTap: _selected == null
                        ? null
                        : () {
                            setState(() => _submitted = true);
                            widget.onSubmit(_selected!);
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      padding:
                          const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: _selected != null
                            ? AppTheme.primaryGradient
                            : null,
                        color: _selected == null
                            ? AppTheme.divider
                            : null,
                        borderRadius: BorderRadius.circular(
                            AppTheme.radiusPill),
                        boxShadow: _selected != null
                            ? AppTheme.buttonShadow
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Submit answer',
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: _selected != null
                              ? Colors.white
                              : AppTheme.lightText,
                        ),
                      ),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: widget.onContinue,
                    child: Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(
                            AppTheme.radiusPill),
                        boxShadow: AppTheme.buttonShadow,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Continue learning',
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
  }
}
