import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import 'api_service.dart';

/// Reason why an STT transcription operation failed.
enum SttFailureReason {
  none,
  tooShort,
  microphoneBusy,
  noSpeechDetected,
  networkError,
  serverError,
  fileError,
}

/// Result returned by STT transcription.
class SttResult {
  final bool isSuccess;
  final String transcript;
  final SttFailureReason failureReason;
  final String? errorMessage;
  final dynamic rawResponse;

  const SttResult.success(this.transcript, {this.rawResponse})
      : isSuccess = true,
        failureReason = SttFailureReason.none,
        errorMessage = null;

  const SttResult.failure(this.failureReason, {this.errorMessage, this.rawResponse})
      : isSuccess = false,
        transcript = '';

  @override
  String toString() =>
      'SttResult(success: $isSuccess, transcript: "$transcript", failureReason: $failureReason, error: $errorMessage)';
}

/// Handles all voice I/O for Socratiq LearnScreen.
/// Recording → STT (Groq Whisper via backend)
/// TTS text → audio bytes → playback (Deepgram Aura via backend)
class VoiceService {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  bool _isRecording = false;
  bool _isPlaying = false;
  String? _recordingPath;
  StreamSubscription<PlayerState>? _playerSub;

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

  /// Start recording audio. Returns false if permission denied or recorder fails.
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

      print('[VOICE] Starting recorder at path: $_recordingPath (AudioEncoder.wav, 16kHz, mono)');
      await _recorder.start(config, path: _recordingPath!);
      _isRecording = true;
      print('[VOICE] Recording started successfully: $_recordingPath');
      return true;

    } catch (e) {
      print('[VOICE] Start recording error: $e');
      _isRecording = false;
      return false;
    }
  }

  /// Stop recording and return the audio file path after ensuring buffer is flushed.
  Future<String?> stopRecording() async {
    try {
      if (!_isRecording) {
        print('[VOICE] Not recording — nothing to stop');
        return null;
      }

      final path = await _recorder.stop();
      _isRecording = false;
      print('[VOICE] Recorder stop completed. Raw path: $path');

      if (path == null) {
        print('[VOICE] Recorder returned null path');
        return null;
      }

      // Add 200ms delay to ensure OS has flushed the audio buffer to disk
      print('[VOICE] Waiting 200ms for OS to flush audio buffer to file...');
      await Future.delayed(const Duration(milliseconds: 200));

      final file = File(path);
      if (await file.exists()) {
        final size = await file.length();
        final ext = path.split('.').last.toLowerCase();
        print('[VOICE] Recording stopped: path=$path, extension=.$ext, size=$size bytes');

        if (size < 5000) {
          print('[VOICE] WARNING: File size is $size bytes (< 5000 bytes). Recording itself may be failing or silent.');
        }

        if (size < 400) {
          print('[VOICE] Recording file too small ($size bytes) — ignoring');
          return null;
        }
        return path;
      } else {
        print('[VOICE] Recording file not found on disk at $path');
        return null;
      }
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
  Future<SttResult> transcribeAudio(
    String audioPath, {
    String sessionId = '',
    String language = 'en',
  }) async {
    try {
      final file = File(audioPath);
      if (!await file.exists()) {
        print('[VOICE] Audio file not found: $audioPath');
        return const SttResult.failure(
          SttFailureReason.fileError,
          errorMessage: 'Audio file not found on device',
        );
      }

      final fileSize = await file.length();
      final ext = audioPath.split('.').last.toLowerCase();
      print('[VOICE] Upload started to ${ApiService.baseUrl}/voice/stt');
      print('[VOICE] Uploading audio: path=$audioPath, extension=.$ext, size=$fileSize bytes, lang=$language');

      final dio = Dio(BaseOptions(
        baseUrl: ApiService.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
      ));

      final fileName = audioPath.split(RegExp(r'[\\/]')).last;
      final formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(
          audioPath,
          filename: fileName,
        ),
        'session_id': sessionId,
        'language': language,
      });

      print('[VOICE] Sending POST /voice/stt with 60s receiveTimeout...');
      final response = await dio.post('/voice/stt', data: formData);

      print('[VOICE] Response received. HTTP Status: ${response.statusCode}');
      print('[VOICE] Raw STT response body: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) {
          final success = data['success'] as bool? ?? false;
          final transcript = (data['transcript'] as String? ?? '').trim();
          final error = data['error'] as String?;

          print('[VOICE] STT parsed response: success=$success, transcript="$transcript", error="$error"');

          if (!success || transcript.isEmpty) {
            print('[VOICE] STT returned empty transcript or success: false (reason: $error)');
            return SttResult.failure(
              SttFailureReason.noSpeechDetected,
              errorMessage: error ?? 'No speech detected in audio',
              rawResponse: data,
            );
          }

          print('[VOICE] STT transcript content: "$transcript"');
          return SttResult.success(transcript, rawResponse: data);
        } else {
          print('[VOICE] Unexpected response data type: ${data.runtimeType}');
          return SttResult.failure(
            SttFailureReason.serverError,
            errorMessage: 'Unexpected server response format',
            rawResponse: data,
          );
        }
      } else {
        print('[VOICE] STT unexpected status code: ${response.statusCode}');
        return SttResult.failure(
          SttFailureReason.serverError,
          errorMessage: 'Server returned ${response.statusCode}',
          rawResponse: response.data,
        );
      }
    } on DioException catch (e) {
      print('[VOICE] STT Dio error: type=${e.type}, message=${e.message}, response=${e.response?.data}');
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionError) {
        return SttResult.failure(
          SttFailureReason.networkError,
          errorMessage: 'Network timeout or connection error: ${e.type}',
          rawResponse: e.response?.data,
        );
      }
      if (e.response != null && e.response!.statusCode != null) {
        final statusCode = e.response!.statusCode!;
        final responseData = e.response!.data;
        print('[VOICE] STT error response HTTP $statusCode: $responseData');
        return SttResult.failure(
          SttFailureReason.serverError,
          errorMessage: 'HTTP $statusCode: $responseData',
          rawResponse: responseData,
        );
      }
      return SttResult.failure(
        SttFailureReason.networkError,
        errorMessage: e.message,
        rawResponse: e.response?.data,
      );
    } catch (e, stack) {
      print('[VOICE] STT error: $e\n$stack');
      return SttResult.failure(
        SttFailureReason.serverError,
        errorMessage: e.toString(),
      );
    }
  }

  /// Convenience alias for speakText
  Future<bool> speak(String text, {String language = 'en'}) => speakText(text, language: language);

  /// Send text to backend /voice/tts and play the returned audio
  Future<bool> speakText(
    String text, {
    String voice = 'aura-luna-en',
    String speed = 'normal',
    String sessionId = '',
    String language = 'en',
    VoidCallback? onStart,
    VoidCallback? onComplete,
    VoidCallback? onError,
  }) async {
    try {
      if (text.trim().isEmpty) return false;

      if (_isPlaying) {
        await stopPlayback();
      }

      print('[VOICE] Requesting TTS: "${text.substring(0, text.length.clamp(0, 60))}..." (lang=$language)');

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
        'language': language,
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

      await _playerSub?.cancel();
      _playerSub = _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _isPlaying = false;
          _playerSub?.cancel();
          _playerSub = null;
          onComplete?.call();
        }
      });

      await _player.setFilePath(tempFile.path);
      await _player.play();

      return true;

    } catch (e) {
      print('[VOICE] TTS playback error: $e');
      _isPlaying = false;
      await _playerSub?.cancel();
      _playerSub = null;
      onError?.call();
      return false;
    }
  }

  /// Stop current audio playback
  Future<void> stopPlayback() async {
    try {
      await _playerSub?.cancel();
      _playerSub = null;
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
