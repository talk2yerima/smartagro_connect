import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/config/app_env.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/app_logger.dart';
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
///
/// Session user JSON is stored via [SecureTokenStore], which will use
/// flutter_secure_storage (Android Keystore / iOS Keychain) in production.
class AuthRepository {
  AuthRepository({
    required SecureTokenStore secure,
    required FirestoreService firestore,
  })  : _secure = secure,
        _firestore = firestore;

  final SecureTokenStore _secure;
  final FirestoreService _firestore;

  // In-memory cache for synchronous access via [currentSessionUser].
  AppUser? _cachedUser;

  static const _kUserJson = 'session_user_json';

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

  /// Synchronous in-memory snapshot. Call [initSession] once at startup
  /// to populate this from secure storage before reading it.
  AppUser? get currentSessionUser => _cachedUser;

  /// Reads the persisted user from secure storage and warms the in-memory
  /// cache. Call this before accessing [currentSessionUser] on cold start.
  Future<void> initSession() async {
    final raw = await _secure.readValue(_kUserJson);
    if (raw == null) return;
    try {
      _cachedUser = AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      _cachedUser = null;
    }
  }

  Future<AppUser> loginWithEmail({
    required String email,
    required String password,
    UserRole demoRole = UserRole.farmer,
  }) async {
    if (_firebaseReady) {
      return _loginFirebase(email, password, role: _selfServiceRole(demoRole));
    }
    _ensureDemoAllowed();
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
      return _registerFirebase(
        name: name,
        email: email,
        password: password,
        role: _selfServiceRole(role),
      );
    }
    _ensureDemoAllowed();
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
      log.d('[Auth] Password reset (demo): $email');
    }
  }

  Future<AppUser> googleSignIn() async {
    if (_firebaseReady) {
      return _googleSignInFirebase();
    }
    _ensureDemoAllowed();
    return _googleSignInDemo();
  }

  Future<AppUser> updateProfile({
    required String userId,
    required String name,
    String? phone,
    String? location,
    String? avatarUrl,
  }) async {
    final current = _cachedUser;
    if (current == null) throw const AuthFailure('Not signed in');
    await _firestore.updateUserProfile(
      userId,
      name: name,
      phone: phone?.isEmpty ?? true ? null : phone,
      location: location?.isEmpty ?? true ? null : location,
      avatarUrl: avatarUrl,
    );
    if (_firebaseReady) {
      try {
        await _auth.currentUser?.updateDisplayName(name);
      } catch (_) {}
    }
    final updated = current.copyWith(
      name: name,
      phone: phone?.isEmpty ?? true ? null : phone,
      location: location?.isEmpty ?? true ? null : location,
      avatarUrl: avatarUrl ?? current.avatarUrl,
    );
    await _persistLocal(updated);
    return updated;
  }

  Future<void> logout() async {
    if (_firebaseReady) {
      try {
        await GoogleSignIn().signOut();
        await _auth.signOut();
      } catch (_) {}
    }
    _cachedUser = null;
    await _secure.clear();
    await _secure.removeValue(_kUserJson);
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

      Map<String, dynamic>? profile;
      try {
        profile = await _firestore.fetchUserProfile(cred.user!.uid);
        if (profile == null) {
          // No Firestore profile yet — create one and refetch.
          await _firestore.saveUserProfile(
            cred.user!.uid,
            name: cred.user!.displayName ?? email.split('@').first,
            email: email,
            role: role,
          );
          profile = await _firestore.fetchUserProfile(cred.user!.uid);
        }
      } catch (e) {
        log.w('[Auth] fetchUserProfile failed, using Firebase-only fallback',
            error: e);
      }

      if (profile?['banned'] == true) {
        await _auth.signOut();
        throw const AuthFailure(
            'This account has been suspended. Contact support.');
      }

      final user = _buildUserFromFirebase(cred.user!,
          fallbackRole: role, profile: profile);
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
      final user = _buildUserFromFirebase(cred.user!,
          fallbackRole: role, nameOverride: name);
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
      Map<String, dynamic>? profile;
      try {
        profile = await _firestore.fetchUserProfile(cred.user!.uid);
      } catch (e) {
        log.w('[Auth] fetchUserProfile failed for Google sign-in', error: e);
      }

      if (profile?['banned'] == true) {
        await _auth.signOut();
        throw const AuthFailure(
            'This account has been suspended. Contact support.');
      }

      final user = _buildUserFromFirebase(
        cred.user!,
        fallbackRole: UserRole.buyer,
        profile: profile,
      );
      await _persistLocal(user);
      return user;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthFailure(_mapFirebaseError(e));
    }
  }

  AppUser _buildUserFromFirebase(
    fb.User fbUser, {
    required UserRole fallbackRole,
    Map<String, dynamic>? profile,
    String? nameOverride,
  }) {
    final roleName = profile?['role'] as String?;
    final role = roleName != null
        ? UserRole.values.firstWhere(
            (r) => r.name == roleName,
            orElse: () => fallbackRole,
          )
        : fallbackRole;

    return AppUser(
      id: fbUser.uid,
      name: nameOverride ??
          (profile?['name'] as String?) ??
          fbUser.displayName ??
          // Phone-only accounts have no email.
          fbUser.email?.split('@').first ??
          fbUser.phoneNumber ??
          'SmartAgro user',
      email: fbUser.email ?? '',
      role: role,
      phone: profile?['phone'] as String? ?? fbUser.phoneNumber,
      location: profile?['location'] as String?,
      avatarUrl: profile?['avatarUrl'] as String?,
      rating: (profile?['rating'] as num?)?.toDouble() ?? 5.0,
      // "Verified seller" is a trust badge granted by an admin (see
      // FirestoreService.setUserVerified) — not the same as a confirmed email.
      verified: (profile?['verified'] as bool?) ?? false,
    );
  }

  // ── Phone-number sign-in (Firebase SMS codes) ──────────────────────────────

  /// Sends a 6-digit SMS code to [e164Phone] (e.g. "+2348036582546").
  ///
  /// Android can sometimes confirm the number without the person typing
  /// the code (instant verification); the result then carries a ready
  /// [PhoneCodeRequest.instantCredential] and no SMS needs typing.
  Future<PhoneCodeRequest> sendPhoneCode(
    String e164Phone, {
    int? resendToken,
  }) {
    if (!_firebaseReady) {
      throw const AuthFailure('Phone sign-in needs an internet connection.');
    }
    final done = Completer<PhoneCodeRequest>();
    _auth.verifyPhoneNumber(
      phoneNumber: e164Phone,
      timeout: const Duration(seconds: 60),
      forceResendingToken: resendToken,
      verificationCompleted: (credential) {
        if (!done.isCompleted) {
          done.complete(PhoneCodeRequest(instantCredential: credential));
        }
      },
      verificationFailed: (e) {
        if (!done.isCompleted) {
          done.completeError(AuthFailure(_mapPhoneError(e)));
        }
      },
      codeSent: (verificationId, token) {
        if (!done.isCompleted) {
          done.complete(PhoneCodeRequest(
            verificationId: verificationId,
            resendToken: token,
          ));
        }
      },
      codeAutoRetrievalTimeout: (_) {},
    );
    return done.future;
  }

  /// Signs in with the SMS code (or an instant credential).
  ///
  /// Returns the signed-in user, or null when this phone number has no
  /// SmartAgro profile yet; then call [completePhoneProfile].
  Future<AppUser?> confirmPhoneCode({
    String? verificationId,
    String? smsCode,
    fb.PhoneAuthCredential? instantCredential,
  }) async {
    final credential = instantCredential ??
        fb.PhoneAuthProvider.credential(
          verificationId: verificationId ?? '',
          smsCode: smsCode ?? '',
        );
    try {
      final cred = await _auth.signInWithCredential(credential);
      final fbUser = cred.user!;
      final profile = await _firestore.fetchUserProfile(fbUser.uid);
      if (profile == null) return null; // new person: needs name + role
      if (profile['banned'] == true) {
        await _auth.signOut();
        throw const AuthFailure(
            'This account has been suspended. Contact support.');
      }
      final user = _buildUserFromFirebase(fbUser,
          fallbackRole: UserRole.farmer, profile: profile);
      await _persistLocal(user);
      return user;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthFailure(_mapPhoneError(e));
    }
  }

  /// Creates the profile for someone who just signed in by phone for the
  /// first time. The phone number is the one Firebase verified by SMS.
  Future<AppUser> completePhoneProfile({
    required String name,
    required UserRole role,
  }) async {
    final fbUser = _auth.currentUser;
    if (fbUser == null) {
      throw const AuthFailure('Your session expired. Request a new code.');
    }
    final safeRole = _selfServiceRole(role);
    await fbUser.updateDisplayName(name);
    await _firestore.saveUserProfile(
      fbUser.uid,
      name: name,
      email: '',
      role: safeRole,
    );
    final phone = fbUser.phoneNumber;
    if (phone != null) {
      await _firestore.updateUserProfile(fbUser.uid, phone: phone);
    }
    final user = _buildUserFromFirebase(fbUser,
        fallbackRole: safeRole,
        nameOverride: name,
        profile: {'role': safeRole.name, 'phone': phone});
    await _persistLocal(user);
    return user;
  }

  String _mapPhoneError(fb.FirebaseAuthException e) => switch (e.code) {
        'invalid-phone-number' =>
          'That phone number is not valid. Check it and try again.',
        'invalid-verification-code' =>
          "That code is not right. Check the SMS and try again.",
        'session-expired' ||
        'code-expired' =>
          'That code has expired. Tap "Send a new code".',
        'too-many-requests' ||
        'quota-exceeded' =>
          'Too many attempts. Wait a while, then try again.',
        'operation-not-allowed' =>
          'Phone sign-in is not switched on yet. Use email for now.',
        'missing-client-identifier' ||
        'app-not-authorized' =>
          'Phone sign-in is not set up for this app yet. Use email for now.',
        'network-request-failed' =>
          "You're offline or the connection is weak. Try again.",
        _ => 'Phone sign-in failed. Please try again.',
      };

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

  /// Users may pick farmer / buyer / transporter for themselves. Admin is
  /// only ever granted server-side, so a self-chosen admin role is downgraded.
  static UserRole _selfServiceRole(UserRole role) =>
      role == UserRole.admin ? UserRole.farmer : role;

  /// Production builds never fall back to the offline demo login, where any
  /// password is accepted.
  void _ensureDemoAllowed() {
    if (!AppEnv.allowDemoMode) {
      throw const AuthFailure(
        'Sign-in is temporarily unavailable. Check your connection and try again.',
      );
    }
  }

  Future<void> _persistLocal(AppUser user) async {
    _cachedUser = user;
    await _secure.writeValue(_kUserJson, jsonEncode(user.toJson()));
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
      log.w(
          '[Auth] FirebaseAuthException — code: "${e.code}", message: "${e.message}"');
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
    if (msg.contains('USER_NOT_FOUND')) {
      return 'No account found for this email.';
    }
    if (msg.contains('TOO_MANY_ATTEMPTS_TRY_LATER') ||
        msg.contains('TOO_MANY_REQUESTS')) {
      return 'Too many attempts. Try again later.';
    }
    if (msg.contains('USER_DISABLED')) return 'This account has been disabled.';
    return 'Authentication failed. Please try again.';
  }
}

/// What [AuthRepository.sendPhoneCode] produced: a code was sent
/// ([verificationId]), or Android confirmed the number on its own
/// ([instantCredential]).
class PhoneCodeRequest {
  const PhoneCodeRequest({
    this.verificationId,
    this.resendToken,
    this.instantCredential,
  });

  final String? verificationId;
  final int? resendToken;
  final fb.PhoneAuthCredential? instantCredential;
}
