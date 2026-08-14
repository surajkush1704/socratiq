import 'dart:io';

import 'package:dio/dio.dart';

class ApiService {
  static const String baseUrl = 'http://10.235.1.173:8000';

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 120),
      sendTimeout: const Duration(seconds: 60),
    ),
  );

  Future<Map<String, dynamic>> uploadPdf(File file) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split(Platform.pathSeparator).last,
        ),
      });

      final response = await _dio.post('/content/upload', data: formData);
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      final detail = e.response?.data;
      throw Exception('Upload failed: ${detail ?? e.message}');
    } catch (e) {
      throw Exception('Upload failed: $e');
    }
  }

  Future<Map<String, dynamic>> processDocument(
    String extractedText,
    String documentName,
  ) async {
    try {
      final response = await _dio.post(
        '/content/process',
        data: {'extracted_text': extractedText, 'document_name': documentName},
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      final detail = e.response?.data;
      throw Exception('Processing failed: ${detail ?? e.message}');
    } catch (e) {
      throw Exception('Processing failed: $e');
    }
  }
}
