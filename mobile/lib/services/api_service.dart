import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ApiService {
  // ADB reverse tcp:8000 tcp:8000 allows 127.0.0.1:8000 to work on physical Android devices over USB & emulator
  static const String baseUrl = 'http://127.0.0.1:8000';

  // Voice preferences — updated from Settings screen
  // 'slow' | 'normal' | 'fast'
  static String voiceSpeed = 'normal';
  // Deepgram voice ID
  static String voiceId = 'aura-luna-en';

  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 120),
      sendTimeout: const Duration(seconds: 60),
    ));

    _dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: true,
      error: true,
      logPrint: (obj) => print('[DIO] $obj'),
    ));
  }

  // ── CONTENT ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> uploadPdf(File file) async {
    try {
      print('[API] Uploading PDF: ${file.path}');
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
      });
      final response = await _dio.post('/content/upload', data: formData);
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  Future<Map<String, dynamic>> processDocument(
      String extractedText, String documentName) async {
    try {
      final response = await _dio.post('/content/process', data: {
        'extracted_text': extractedText,
        'document_name': documentName,
      });
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  // ── SESSION ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> startSession({
    required String documentName,
    required String summary,
    required List<String> keyPoints,
    required List<String> topics,
    required String mode,
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      print('[API] Starting session: mode=$mode, doc=$documentName');
      final response = await _dio.post('/session/start', data: {
        'user_id': uid,
        'document_name': documentName,
        'summary': summary,
        'key_points': keyPoints,
        'topics': topics,
        'mode': mode,
      });
      print('[API] Session started: ${response.data}');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  Future<Map<String, dynamic>> interact({
    required String sessionId,
    required String userInput,
    required String interactionType,
  }) async {
    try {
      final textSub = userInput.substring(0, userInput.length.clamp(0, 50));
      print('[API] Interact: type=$interactionType, input=$textSub');
      final response = await _dio.post('/interaction/interact', data: {
        'session_id': sessionId,
        'user_input': userInput,
        'interaction_type': interactionType,
      });
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  Future<Map<String, dynamic>> endSession(String sessionId) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      final response = await _dio.post(
        '/session/end',
        queryParameters: {
          'session_id': sessionId,
          'user_id': uid,
        },
      );
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  // ── TEST SESSION ───────────────────────────────────────────────────────────

  /// Generate a full test set from document content
  /// Returns list of MCQ maps with question, options, correct_index, explanation
  Future<List<Map<String, dynamic>>> generateTest({
    required String documentName,
    required String summary,
    required List<String> keyPoints,
    required List<String> topics,
    int questionCount = 5,
  }) async {
    try {
      print('[API] Generating test: $questionCount questions for $documentName');
      final response = await _dio.post('/session/generate-test', data: {
        'document_name': documentName,
        'summary': summary,
        'key_points': keyPoints,
        'topics': topics,
        'question_count': questionCount,
      });

      final questions = List<Map<String, dynamic>>.from(
        (response.data['questions'] as List).map(
          (q) => Map<String, dynamic>.from(q),
        ),
      );

      print('[API] Generated ${questions.length} test questions');
      return questions;
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  /// Submit all test answers and get full evaluation
  Future<Map<String, dynamic>> submitTest({
    required String documentName,
    required String summary,
    required List<Map<String, dynamic>> answers,
  }) async {
    try {
      print('[API] Submitting test: ${answers.length} answers');
      final response = await _dio.post('/session/submit-test', data: {
        'document_name': documentName,
        'summary': summary,
        'answers': answers,
      });

      print('[API] Test submitted, avg score: ${response.data['avg_score']}');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  // ── ERROR HANDLING ────────────────────────────────────────────────────────

  String _handleDioError(DioException e) {
    print('[API ERROR] Type: ${e.type}');
    print('[API ERROR] Message: ${e.message}');
    print('[API ERROR] Response: ${e.response?.data}');

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.connectionError:
        return 'Cannot reach server. Make sure backend is running at $baseUrl';
      case DioExceptionType.receiveTimeout:
        return 'AI is taking too long. Try again.';
      default:
        return e.response?.data?.toString() ?? e.message ?? 'Unknown error';
    }
  }
}
