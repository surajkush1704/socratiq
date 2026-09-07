import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import 'api_service.dart';

/// Handles all voice I/O for Socratiq LearnScreen.
/// Recording → STT (Groq Whisper via backend)
/// TTS text → audio bytes → playback (Deepgram Aura via backend)
class VoiceService {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  bool _isRecording = false;
  bool _isPlaying = false;
  String? _recordingPath;

  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;

  // ── PERMISSIONS ────────────────────────────────────────────────────────────

  Future<bool> requestMicPermission() async {
    final status = await Permission.microphone.request();
    print('[VOICE] Microphone permission: ${status.name}');
    return status.isGranted;
  }

  Future<bool> hasMicPermission() async {
    return await Permission.microphone.isGranted;
  }

  // ── RECORDING ──────────────────────────────────────────────────────────────

  /// Start recording audio. Returns false if permission denied.
  Future<bool> startRecording() async {
    try {
      final hasPermission = await hasMicPermission();
      if (!hasPermission) {
        final granted = await requestMicPermission();
        if (!granted) {
          print('[VOICE] Microphone permission denied');
          return false;
        }
      }

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _recordingPath = '${tempDir.path}/socratiq_recording_$timestamp.wav';

      const config = RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      );

      await _recorder.start(config, path: _recordingPath!);
      _isRecording = true;
      print('[VOICE] Recording started: $_recordingPath');
      return true;

    } catch (e) {
      print('[VOICE] Start recording error: $e');
      _isRecording = false;
      return false;
    }
  }

  /// Stop recording and return the audio file path.
  Future<String?> stopRecording() async {
    try {
      if (!_isRecording) {
        print('[VOICE] Not recording — nothing to stop');
        return null;
      }

      final path = await _recorder.stop();
      _isRecording = false;
      print('[VOICE] Recording stopped: $path');

      if (path == null) return null;

      final file = File(path);
      if (await file.exists()) {
        final size = await file.length();
        print('[VOICE] Recording file size: $size bytes');
        if (size < 400) {
          print('[VOICE] Recording too short — ignoring');
          return null;
        }
        return path;
      }
      return null;
    } catch (e) {
      print('[VOICE] Stop recording error: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Cancel recording without saving
  Future<void> cancelRecording() async {
    try {
      if (_isRecording) {
        await _recorder.cancel();
        _isRecording = false;
        print('[VOICE] Recording cancelled');
      }
    } catch (e) {
      print('[VOICE] Cancel recording error: $e');
    }
  }

  // ── STT — SEND AUDIO TO BACKEND ───────────────────────────────────────────

  /// Send recorded audio file to backend /voice/stt
  Future<String?> transcribeAudio(String audioPath) async {
    try {
      final file = File(audioPath);
      if (!await file.exists()) {
        print('[VOICE] Audio file not found: $audioPath');
        return null;
      }

      final fileSize = await file.length();
      print('[VOICE] Sending audio for STT: $audioPath ($fileSize bytes)');

      final dio = Dio(BaseOptions(
        baseUrl: ApiService.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
      ));

      final formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(
          audioPath,
          filename: audioPath.split('/').last,
        ),
        'session_id': '',
      });

      final response = await dio.post('/voice/stt', data: formData);

      if (response.statusCode == 200) {
        final transcript = response.data['transcript'] as String? ?? '';
        final success = response.data['success'] as bool? ?? false;

        if (!success || transcript.isEmpty) {
          print('[VOICE] STT returned empty transcript');
          return null;
        }

        print('[VOICE] STT transcript: "$transcript"');
        return transcript;
      } else {
        print('[VOICE] STT error: ${response.statusCode}');
        return null;
      }
    } on DioException catch (e) {
      print('[VOICE] STT Dio error: ${e.type} — ${e.message}');
      return null;
    } catch (e) {
      print('[VOICE] STT error: $e');
      return null;
    }
  }

  /// Convenience alias for speakText
  Future<bool> speak(String text) => speakText(text);

  /// Send text to backend /voice/tts and play the returned audio
  Future<bool> speakText(
    String text, {
    String voice = 'aura-luna-en',
    String speed = 'normal',
    String sessionId = '',
    VoidCallback? onStart,
    VoidCallback? onComplete,
    VoidCallback? onError,
  }) async {
    try {
      if (text.trim().isEmpty) return false;

      if (_isPlaying) {
        await stopPlayback();
      }

      print('[VOICE] Requesting TTS: "${text.substring(0, text.length.clamp(0, 60))}..."');

      final dio = Dio(BaseOptions(
        baseUrl: ApiService.baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        responseType: ResponseType.bytes,
      ));

      final formData = FormData.fromMap({
        'text': text.trim(),
        'voice': voice,
        'speed': speed,
        'session_id': sessionId,
      });

      final response = await dio.post(
        '/voice/tts',
        data: formData,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode != 200) {
        print('[VOICE] TTS error status: ${response.statusCode}');
        onError?.call();
        return false;
      }

      final audioBytes = response.data as Uint8List;
      print('[VOICE] Received TTS audio: ${audioBytes.length} bytes');

      if (audioBytes.isEmpty) {
        print('[VOICE] TTS returned empty audio');
        onError?.call();
        return false;
      }

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempFile = File('${tempDir.path}/tts_$timestamp.mp3');
      await tempFile.writeAsBytes(audioBytes);

      print('[VOICE] Playing TTS audio from: ${tempFile.path}');

      _isPlaying = true;
      onStart?.call();

      _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _isPlaying = false;
          onComplete?.call();
        }
      });

      await _player.setFilePath(tempFile.path);
      await _player.play();

      return true;

    } catch (e) {
      print('[VOICE] TTS playback error: $e');
      _isPlaying = false;
      onError?.call();
      return false;
    }
  }

  /// Stop current audio playback
  Future<void> stopPlayback() async {
    try {
      await _player.stop();
      _isPlaying = false;
      print('[VOICE] Playback stopped');
    } catch (e) {
      print('[VOICE] Stop playback error: $e');
    }
  }

  /// Pause playback
  Future<void> pausePlayback() async {
    try {
      await _player.pause();
      print('[VOICE] Playback paused');
    } catch (e) {
      print('[VOICE] Pause error: $e');
    }
  }

  /// Resume playback
  Future<void> resumePlayback() async {
    try {
      await _player.play();
      print('[VOICE] Playback resumed');
    } catch (e) {
      print('[VOICE] Resume error: $e');
    }
  }

  // ── CLEANUP ────────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    try {
      if (_isRecording) await _recorder.cancel();
      if (_isPlaying) await _player.stop();
      await _recorder.dispose();
      await _player.dispose();
      print('[VOICE] VoiceService disposed');
    } catch (e) {
      print('[VOICE] Dispose error: $e');
    }
  }
}
