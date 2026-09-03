import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'sync_service.dart';

class AuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  static FirebaseAuth get _auth => FirebaseAuth.instance;

  static User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (e) {
      print('[AUTH ERROR]: $e');
      return null;
    }
  }

  static bool get isLoggedIn {
    try {
      return _auth.currentUser != null;
    } catch (e) {
      print('[AUTH ERROR]: $e');
      return false;
    }
  }

  static Stream<User?> get authStateChanges {
    try {
      return _auth.authStateChanges();
    } catch (e) {
      print('[AUTH ERROR]: $e');
      return const Stream<User?>.empty();
    }
  }

  static Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await _auth.signInWithCredential(credential);

      // Sync profile after successful login
      SyncService.syncProfile().catchError((e) {
        print('[AUTH] Profile sync failed: $e');
        return <String, dynamic>{};
      });

      return result;
    } catch (e) {
      print('[AUTH ERROR]: $e');
      return null;
    }
  }

  static Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      SyncService.syncProfile().catchError((e) {
        print('[AUTH] Profile sync failed: $e');
        return <String, dynamic>{};
      });
      return result;
    } catch (e) {
      print('[AUTH ERROR]: $e');
      rethrow;
    }
  }

  static Future<UserCredential?> signUpWithEmail(String email, String password) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      SyncService.syncProfile().catchError((e) {
        print('[AUTH] Profile sync failed: $e');
        return <String, dynamic>{};
      });
      return result;
    } catch (e) {
      print('[AUTH ERROR]: $e');
      rethrow;
    }
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}