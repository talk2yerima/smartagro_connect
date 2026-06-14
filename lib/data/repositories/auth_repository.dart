import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/app_user.dart';
import '../services/firestore_service.dart';
import '../services/secure_token_store.dart';

/// Authentication + session management.
///
/// Behaviour depends on whether Firebase was successfully initialised at
/// startup (see main.dart):
///   • Firebase available → uses FirebaseAuth for real sign-in flows.
///   • Firebase NOT available → falls back to demo mode (any password ≥ 6
///     chars works, role is taken from the caller's [demoRole] param).
///
/// Replace `firebase_options.dart` with real values from `flutterfire configure`
/// to activate the Firebase path.
class AuthRepository {
  AuthRepository({
    required SecureTokenStore secure,
    required SharedPreferences prefs,
    required FirestoreService firestore,
  })  : _secure = secure,
        _prefs = prefs,
        _firestore = firestore;

  final SecureTokenStore _secure;
  final SharedPreferences _prefs;
  final FirestoreService _firestore;

  static const _kUserJson = 'session_user_json';
  static const _kUserRole = 'session_user_role';

  // ── Firebase availability check ──────────────────────────────────────────

  bool get _firebaseReady {
    try {
      if (Firebase.apps.isEmpty) return false;
      final key = Firebase.app().options.apiKey;
      // Placeholder keys mean `flutterfire configure` hasn't been run yet.
      // Fall back to demo mode so login still works during development.
      return key.isNotEmpty &&
          !key.startsWith('YOUR_') &&
          !key.startsWith('REPLACE_');
    } catch (_) {
      return false;
    }
  }

  fb.FirebaseAuth get _auth => fb.FirebaseAuth.instance;

  // ── Public API ───────────────────────────────────────────────────────────

  AppUser? get currentSessionUser {
    final raw = _prefs.getString(_kUserJson);
    if (raw == null) return null;
    try {
      return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<AppUser> loginWithEmail({
    required String email,
    required String password,
    UserRole demoRole = UserRole.farmer,
  }) async {
    if (_firebaseReady) {
      return _loginFirebase(email, password, role: demoRole);
    }
    if (password.length < 6) throw const AuthFailure('Minimum 6 characters');
    return _loginDemo(email, role: demoRole);
  }

  Future<AppUser> registerWithEmail({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    if (_firebaseReady) {
      return _registerFirebase(name: name, email: email, password: password, role: role);
    }
    return _registerDemo(name: name, email: email, role: role);
  }

  Future<void> sendPasswordReset(String email) async {
    if (_firebaseReady) {
      try {
        await _auth.sendPasswordResetEmail(email: email);
      } on fb.FirebaseAuthException catch (e) {
        throw AuthFailure(_mapFirebaseError(e));
      }
    } else {
      if (kDebugMode) debugPrint('[Auth] Password reset (demo): $email');
    }
  }

  Future<void> verifyOtp({required String code}) async {
    if (code.length < 4) throw const ValidationFailure('Enter a valid OTP');
    // Wire to Firebase phone auth / custom OTP gateway when ready.
  }

  Future<AppUser> googleSignIn() async {
    if (_firebaseReady) {
      return _googleSignInFirebase();
    }
    return _googleSignInDemo();
  }

  Future<void> logout() async {
    if (_firebaseReady) {
      try {
        await GoogleSignIn().signOut();
        await _auth.signOut();
      } catch (_) {}
    }
    await _secure.clear();
    await _prefs.remove(_kUserJson);
    await _prefs.remove(_kUserRole);
  }

  /// Returns a fresh Firebase ID token for use in API request headers.
  /// Returns null in demo mode or when no user is signed in.
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    if (!_firebaseReady) return await _secure.readAccess();
    try {
      return await _auth.currentUser?.getIdToken(forceRefresh);
    } catch (_) {
      return null;
    }
  }

  // ── Firebase paths ────────────────────────────────────────────────────────

  Future<AppUser> _loginFirebase(
    String email,
    String password, {
    required UserRole role,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Role comes from Firestore; fall back to the UI chip for accounts that
      // pre-date the Firestore profile and save it so subsequent logins lock in.
      final savedRole = await _firestore.getUserRole(cred.user!.uid);
      final effectiveRole = savedRole ?? role;
      if (savedRole == null) {
        await _firestore.saveUserProfile(
          cred.user!.uid,
          name: cred.user!.displayName ?? email.split('@').first,
          email: email,
          role: effectiveRole,
        );
      }
      final user = await _buildUserFromFirebase(cred.user!, role: effectiveRole);
      await _persistLocal(user);
      return user;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthFailure(_mapFirebaseError(e));
    }
  }

  Future<AppUser> _registerFirebase({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await cred.user?.updateDisplayName(name);
      await cred.user?.sendEmailVerification();
      // Persist the chosen role to Firestore so login always restores it.
      await _firestore.saveUserProfile(
        cred.user!.uid,
        name: name,
        email: email,
        role: role,
      );
      final user = await _buildUserFromFirebase(cred.user!, role: role, nameOverride: name);
      await _persistLocal(user);
      return user;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthFailure(_mapFirebaseError(e));
    }
  }

  Future<AppUser> _googleSignInFirebase() async {
    try {
      final gUser = await GoogleSignIn().signIn();
      if (gUser == null) throw const AuthFailure('Google sign-in cancelled');
      final gAuth = await gUser.authentication;
      final credential = fb.GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );
      final cred = await _auth.signInWithCredential(credential);
      final user = await _buildUserFromFirebase(cred.user!, role: UserRole.buyer);
      await _persistLocal(user);
      return user;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthFailure(_mapFirebaseError(e));
    }
  }

  Future<AppUser> _buildUserFromFirebase(
    fb.User fbUser, {
    required UserRole role,
    String? nameOverride,
  }) async {
    // Persist the chosen role so it survives session restores.
    await _prefs.setString(_kUserRole, role.name);
    return AppUser(
      id: fbUser.uid,
      name: nameOverride ?? fbUser.displayName ?? fbUser.email!.split('@').first,
      email: fbUser.email ?? '',
      role: role,
      rating: 5.0,
      verified: fbUser.emailVerified,
    );
  }

  // ── Demo paths ─────────────────────────────────────────────────────────────

  Future<AppUser> _loginDemo(String email, {required UserRole role}) async {
    final user = AppUser(
      id: 'demo-${email.hashCode}',
      name: _demoName(role),
      email: email,
      role: role,
      rating: 4.8,
      verified: true,
    );
    await _secure.writeTokens(access: 'demo-token');
    await _persistLocal(user);
    return user;
  }

  Future<AppUser> _registerDemo({
    required String name,
    required String email,
    required UserRole role,
  }) async {
    final user = AppUser(
      id: 'demo-reg-${email.hashCode}',
      name: name,
      email: email,
      role: role,
      rating: 5.0,
      verified: false,
    );
    await _persistLocal(user);
    return user;
  }

  Future<AppUser> _googleSignInDemo() async {
    const user = AppUser(
      id: 'demo-google',
      name: 'Google Demo Buyer',
      email: 'buyer.demo@smartagro.ng',
      role: UserRole.buyer,
      rating: 4.7,
      verified: true,
    );
    await _persistLocal(user);
    return user;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _persistLocal(AppUser user) async {
    await _prefs.setString(_kUserJson, jsonEncode(user.toJson()));
  }

  String _demoName(UserRole role) => switch (role) {
        UserRole.farmer => 'Demo Farmer',
        UserRole.buyer => 'Demo Buyer',
        UserRole.transporter => 'Demo Transporter',
        UserRole.admin => 'Demo Admin',
      };

  /// Whether Firebase Auth is live (vs demo mode).
  bool get isLiveMode => _firebaseReady;

  String _mapFirebaseError(fb.FirebaseAuthException e) {
    if (kDebugMode) {
      debugPrint('[Auth] FirebaseAuthException — code: "${e.code}", message: "${e.message}"');
    }
    return switch (e.code) {
      'user-not-found' => 'No account found for this email.',
      'wrong-password' => 'Incorrect password.',
      'invalid-credential' => 'Incorrect email or password.',
      'email-already-in-use' => 'An account with this email already exists.',
      'weak-password' => 'Password must be at least 6 characters.',
      'invalid-email' => 'Enter a valid email address.',
      'user-disabled' => 'This account has been disabled.',
      'too-many-requests' => 'Too many attempts. Try again later.',
      'network-request-failed' => 'Network error. Check your connection.',
      // Windows Firebase C++ SDK wraps server errors as INTERNAL_ERROR / UNKNOWN.
      'internal-error' => _parseInternalError(e.message),
      'unknown-error' => _parseInternalError(e.message),
      _ => e.message ?? 'Authentication failed.',
    };
  }

  String _parseInternalError(String? message) {
    final msg = (message ?? '').toUpperCase();
    if (msg.contains('INVALID_LOGIN_CREDENTIALS') ||
        msg.contains('INVALID_PASSWORD') ||
        msg.contains('EMAIL_NOT_FOUND')) {
      return 'Incorrect email or password.';
    }
    if (msg.contains('USER_NOT_FOUND')) return 'No account found for this email.';
    if (msg.contains('TOO_MANY_ATTEMPTS_TRY_LATER') ||
        msg.contains('TOO_MANY_REQUESTS')) {
      return 'Too many attempts. Try again later.';
    }
    if (msg.contains('USER_DISABLED')) return 'This account has been disabled.';
    return 'Authentication failed. Please try again.';
  }
}
