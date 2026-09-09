import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dio/dio.dart';
import 'api_service.dart';
import 'sync_service.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiService.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  static User? get currentUser => _auth.currentUser;
  static bool get isLoggedIn => _auth.currentUser != null;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── GOOGLE SIGN IN ─────────────────────────────────────────────────────────

  static Future<UserCredential?> signInWithGoogle() async {
    try {
      // Clear previous cached session in case of prior aborted state
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // User cancelled

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        throw Exception(
          'Google authentication returned no tokens. '
          'Please ensure SHA-1 fingerprint is registered in Firebase Console.',
        );
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await _auth.signInWithCredential(credential);

      // Notify backend — applies rate limiting and logs login
      await _notifyBackendLogin(
        uid: result.user?.uid ?? '',
        email: result.user?.email ?? '',
        name: result.user?.displayName ?? '',
        provider: 'google',
      );

      // Sync Firestore profile
      SyncService.syncProfile().catchError((e) {
        print('[AUTH] Profile sync failed: $e');
        return <String, dynamic>{};
      });

      return result;
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        final detail = e.response?.data['detail'];
        final retryAfter = detail is Map ? (detail['retry_after'] ?? 300) : 300;
        throw AuthRateLimitException(
          'Too many login attempts. '
          'Please wait ${_formatWait(retryAfter)}.',
          retryAfterSeconds: retryAfter,
        );
      }
      rethrow;
    } catch (e) {
      print('[AUTH ERROR]: $e');
      rethrow;
    }
  }

  // ── EMAIL SIGN IN ──────────────────────────────────────────────────────────

  static Future<UserCredential?> signInWithEmail(
      String email, String password) async {
    try {
      // Check rate limit on backend BEFORE Firebase attempt
      // This prevents Firebase from seeing excessive attempts
      await _checkLoginRateLimit(email: email);

      final result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);

      await _notifyBackendLogin(
        uid: result.user?.uid ?? '',
        email: email,
        name: result.user?.displayName ?? '',
        provider: 'email',
      );

      SyncService.syncProfile().catchError((e) {
        print('[AUTH] Profile sync: $e');
        return <String, dynamic>{};
      });
      return result;
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        final detail = e.response?.data['detail'];
        final retryAfter = detail is Map ? (detail['retry_after'] ?? 300) : 300;
        throw AuthRateLimitException(
          'Too many login attempts. '
          'Please wait ${_formatWait(retryAfter)}.',
          retryAfterSeconds: retryAfter,
        );
      }
      rethrow;
    } catch (e) {
      print('[AUTH ERROR]: $e');
      rethrow;
    }
  }

  // ── EMAIL SIGN UP ──────────────────────────────────────────────────────────

  static Future<UserCredential?> signUpWithEmail(
      String email, String password) async {
    try {
      await _checkLoginRateLimit(email: email);
      final result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);

      await _notifyBackendLogin(
        uid: result.user?.uid ?? '',
        email: email,
        name: '',
        provider: 'email',
      );

      SyncService.syncProfile().catchError((e) {
        print('[AUTH] Profile sync: $e');
        return <String, dynamic>{};
      });
      return result;
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw AuthRateLimitException(
          'Too many attempts. Please try again later.',
          retryAfterSeconds: 300,
        );
      }
      rethrow;
    } catch (e) {
      print('[AUTH ERROR]: $e');
      rethrow;
    }
  }

  // ── PASSWORD RESET ─────────────────────────────────────────────────────────

  static Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print('[AUTH ERROR] Password reset error: $e');
      rethrow;
    }
  }

  // ── SIGN OUT ───────────────────────────────────────────────────────────────

  static Future<void> signOut() async {
    final uid = currentUser?.uid ?? '';
    if (uid.isNotEmpty) {
      try {
        await _dio.post('/auth/logout', queryParameters: {'uid': uid});
      } catch (e) {
        print('[AUTH] Logout notify failed: $e');
      }
    }
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ── ACCOUNT DELETION ──────────────────────────────────────────────────────

  static Future<void> deleteAccount() async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('No user logged in');

    try {
      // 1. Delete all Firestore data via backend with Firebase auth token
      final token = await _auth.currentUser?.getIdToken();
      final options = token != null
          ? Options(headers: {'Authorization': 'Bearer $token'})
          : null;
      await _dio.delete('/auth/account/$uid', options: options);
      print('[AUTH] Firestore data deleted for $uid');

      // 2. Delete Firebase Auth user
      await _auth.currentUser?.delete();
      print('[AUTH] Firebase Auth user deleted');

      // 3. Sign out of Google
      await _googleSignIn.signOut();
    } catch (e) {
      print('[AUTH] Account deletion error: $e');
      rethrow;
    }
  }

  // ── PRIVATE HELPERS ───────────────────────────────────────────────────────

  static Future<void> _notifyBackendLogin({
    required String uid,
    required String email,
    required String name,
    required String provider,
  }) async {
    try {
      await _dio.post('/auth/login', data: {
        'uid': uid,
        'email': email,
        'name': name,
        'provider': provider,
      });
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) rethrow;
      // Non-fatal — log but don't block login
      print('[AUTH] Backend login notify failed: ${e.message}');
    }
  }

  static Future<void> _checkLoginRateLimit({required String email}) async {
    try {
      // Lightweight pre-check
      await _dio.post('/auth/login', data: {
        'uid': 'pre_check',
        'email': email,
        'name': '',
        'provider': 'pre_check',
      });
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) rethrow;
      // Other errors are non-fatal for rate limit check
    }
  }

  static String _formatWait(int seconds) {
    if (seconds < 60) return '$seconds seconds';
    final min = (seconds / 60).ceil();
    return '$min minute${min > 1 ? 's' : ''}';
  }
}

// ── CUSTOM EXCEPTIONS ─────────────────────────────────────────────────────────

class AuthRateLimitException implements Exception {
  final String message;
  final int retryAfterSeconds;
  AuthRateLimitException(this.message, {required this.retryAfterSeconds});

  @override
  String toString() => message;
}