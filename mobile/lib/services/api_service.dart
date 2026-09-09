import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ApiService {
  // Configurable via --dart-define=API_BASE_URL=https://api.yourdomain.com
  // Defaults to 192.168.1.8:8000 for Wi-Fi LAN / physical Android devices
  static String baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://socratiq-kappa.vercel.app',
  );

  // Candidate backend addresses in priority order
  static const List<String> candidateUrls = [
    'https://socratiq-kappa.vercel.app',
    'http://192.168.1.7:8000',
    'http://192.168.1.8:8000',
    'http://10.0.2.2:8000',
    'http://127.0.0.1:8000',
  ];

  static bool _isProbing = false;

  /// Fast probe to discover reachable backend host if connection fails
  static Future<String?> probeReachableHost() async {
    if (_isProbing) return baseUrl;
    _isProbing = true;
    try {
      for (final candidate in candidateUrls) {
        try {
          final probeDio = Dio(BaseOptions(
            connectTimeout: const Duration(milliseconds: 1800),
            receiveTimeout: const Duration(milliseconds: 1800),
          ));
          final res = await probeDio.get('$candidate/');
          if (res.statusCode == 200) {
            print('[API] Found reachable backend host: $candidate');
            baseUrl = candidate;
            return candidate;
          }
        } catch (_) {}
      }
    } finally {
      _isProbing = false;
    }
    return null;
  }

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

    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException err, ErrorInterceptorHandler handler) async {
          if (err.type == DioExceptionType.connectionTimeout ||
              err.type == DioExceptionType.connectionError) {
            final workingHost = await probeReachableHost();
            if (workingHost != null && workingHost != err.requestOptions.baseUrl) {
              _dio.options.baseUrl = workingHost;
              final newOptions = err.requestOptions;
              newOptions.baseUrl = workingHost;
              try {
                final response = await _dio.fetch(newOptions);
                return handler.resolve(response);
              } catch (retryError) {
                return handler.next(err);
              }
            }
          }
          return handler.next(err);
        },
      ),
    );

    _dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: false,
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
    String documentLanguage = 'en',
    String responseLanguage = 'en',
    String languageDisplayName = 'English',
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      print('[API] Starting session: mode=$mode, doc=$documentName, docLang=$documentLanguage, respLang=$responseLanguage');
      final response = await _dio.post('/session/start', data: {
        'user_id': uid,
        'document_name': documentName,
        'summary': summary,
        'key_points': keyPoints,
        'topics': topics,
        'mode': mode,
        'document_language': documentLanguage,
        'response_language': responseLanguage,
        'language_display_name': languageDisplayName,
      });
      print('[API] Session started: ${response.data}');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  Future<Map<String, dynamic>> addDocumentToSession({
    required String sessionId,
    required String documentName,
    required String summary,
    required List<String> keyPoints,
    required List<String> topics,
  }) async {
    try {
      print('[API] Adding document to session: $documentName (session $sessionId)');
      final response = await _dio.post('/session/add-document', data: {
        'session_id': sessionId,
        'document_name': documentName,
        'summary': summary,
        'key_points': keyPoints,
        'topics': topics,
      });
      print('[API] Document added to session: ${response.data}');
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
