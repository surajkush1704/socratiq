import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'api_service.dart';

/// SyncService — all Firestore data operations via backend API.
/// Never calls Firestore directly from Flutter.
/// All reads and writes go through FastAPI sync endpoints.
class SyncService {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiService.baseUrl,
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 30),
  ));

  static String get _uid =>
      FirebaseAuth.instance.currentUser?.uid ?? '';

  static String get _name =>
      FirebaseAuth.instance.currentUser?.displayName ?? '';

  static String get _email =>
      FirebaseAuth.instance.currentUser?.email ?? '';

  // ── PROFILE SYNC ────────────────────────────────────────────────────────

  /// Called on app launch after Firebase Auth completes, or on profile update.
  /// Creates user profile in Firestore if first time, updates otherwise.
  static Future<Map<String, dynamic>> syncProfile({
    String? name,
    String? username,
    int? avatarId,
  }) async {
    if (_uid.isEmpty) return {};
    try {
      print('[SYNC] Syncing profile for uid: ${_uid.substring(0, 8)}...');
      final payload = <String, dynamic>{
        'uid': _uid,
        'name': name ?? _name,
        'email': _email,
        'device_id': 'flutter_android',
      };
      if (username != null) {
        payload['username'] = username;
      }
      if (avatarId != null) {
        payload['avatar_id'] = avatarId;
      }
      final response = await _dio.post('/sync/profile', data: payload);
      print('[SYNC] Profile synced');
      return Map<String, dynamic>.from(response.data['profile'] ?? {});
    } catch (e) {
      print('[SYNC] Profile sync error: $e');
      return {};
    }
  }

  /// Fetch user profile from backend /sync/profile/{uid}
  static Future<Map<String, dynamic>> getProfile([String? uid]) async {
    final targetUid = uid ?? _uid;
    if (targetUid.isEmpty) return {};
    try {
      final response = await _dio.get('/sync/profile/$targetUid');
      return Map<String, dynamic>.from(response.data['profile'] ?? {});
    } catch (e) {
      print('[SYNC] Fetch profile error: $e');
      return {};
    }
  }

  // ── SESSION SYNC ────────────────────────────────────────────────────────

  /// Called after every completed study session.
  /// Writes session to Firestore and updates streak.
  /// Returns new streak count and updated stats.
  static Future<Map<String, dynamic>> syncSession({
    required String sessionId,
    required String documentName,
    required String mode,
    required int durationSec,
    required double score,
    required int questionsAttempted,
    required int questionsCorrect,
    required List<String> topics,
  }) async {
    if (_uid.isEmpty) {
      print('[SYNC] No user logged in — skipping session sync');
      return {};
    }

    try {
      print('[SYNC] Syncing session: $sessionId, score=$score, '
          'duration=${durationSec}s, questions=$questionsAttempted');

      final response = await _dio.post('/sync/session', data: {
        'uid': _uid,
        'session_id': sessionId,
        'document_name': documentName,
        'mode': mode,
        'duration_sec': durationSec,
        'score': score,
        'questions_attempted': questionsAttempted,
        'questions_correct': questionsCorrect,
        'topics': topics,
      });

      final result = Map<String, dynamic>.from(response.data);
      print('[SYNC] Session synced: streak=${result['new_streak']}, '
          'total_sessions=${result['total_sessions']}');
      return result;
    } catch (e) {
      print('[SYNC] Session sync error: $e');
      return {};
    }
  }

  // ── STATS READ ──────────────────────────────────────────────────────────

  /// Returns all stats for the dashboard screen.
  /// Includes streak, totals, today's stats, and 7-day weekly data.
  static Future<Map<String, dynamic>> getUserStats() async {
    if (_uid.isEmpty) return _emptyStats();
    try {
      print('[SYNC] Fetching stats for uid: ${_uid.substring(0, 8)}...');
      final response = await _dio.get('/sync/stats/$_uid');
      final stats = Map<String, dynamic>.from(response.data['stats'] ?? {});
      print('[SYNC] Stats fetched: streak=${stats['streak']}, '
          'sessions=${stats['totalSessions']}');
      return stats;
    } catch (e) {
      print('[SYNC] Stats fetch error: $e');
      return _emptyStats();
    }
  }

  static Map<String, dynamic> _emptyStats() => {
    'streak': 0,
    'longestStreak': 0,
    'totalSessions': 0,
    'totalStudyTimeSec': 0,
    'avgScore': 0.0,
    'totalQuestionsAttempted': 0,
    'totalQuestionsCorrect': 0,
    'todayTimeSec': 0,
    'todaySessions': 0,
    'weeklyData': <Map<String, dynamic>>[],
  };

  // ── ACTIVITY READ ────────────────────────────────────────────────────────

  /// Returns recent session logs for activity feed on home screen.
  static Future<List<Map<String, dynamic>>> getRecentActivity({
    int limit = 5,
  }) async {
    if (_uid.isEmpty) return [];
    try {
      print('[SYNC] Fetching activity, limit=$limit');
      final response = await _dio.get(
        '/sync/activity/$_uid',
        queryParameters: {'limit': limit},
      );
      final sessions = response.data['sessions'] as List? ?? [];
      return sessions
          .map((s) => Map<String, dynamic>.from(s))
          .toList();
    } catch (e) {
      print('[SYNC] Activity fetch error: $e');
      return [];
    }
  }

  // ── DOCUMENT HISTORY ─────────────────────────────────────────────────────

  /// Returns sessions for a specific document.
  /// Used in Library to show last studied date and score per doc.
  static Future<List<Map<String, dynamic>>> getDocumentHistory({
    required String documentName,
    int limit = 3,
  }) async {
    if (_uid.isEmpty) return [];
    try {
      final response = await _dio.get(
        '/sync/document-history/$_uid',
        queryParameters: {
          'document_name': documentName,
          'limit': limit,
        },
      );
      final sessions = response.data['sessions'] as List? ?? [];
      return sessions
          .map((s) => Map<String, dynamic>.from(s))
          .toList();
    } catch (e) {
      print('[SYNC] Document history error: $e');
      return [];
    }
  }

  // ── HELPERS ──────────────────────────────────────────────────────────────

  /// Formats seconds to human-readable string: "2h 30m" or "45m"
  static String formatDuration(int seconds) {
    if (seconds <= 0) return '0m';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  /// Formats score 0-10 to display string
  static String formatScore(double score) {
    if (score <= 0) return '—';
    return score.toStringAsFixed(1);
  }

  /// Returns time-ago string from ISO date string
  static String timeAgo(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'yesterday';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}
