import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/services/secure_token_store.dart';
import '../../domain/entities/app_user.dart';
import 'firestore_providers.dart';
import 'initialization_provider.dart';

final secureTokenStoreProvider = Provider<SecureTokenStore>((ref) {
  return SecureTokenStore();
});

/// Synchronous access to [SharedPreferences] after [initializationProvider] succeeds.
final loadedSharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  final async = ref.watch(sharedPreferencesProvider);
  return async.when(
    data: (v) => v,
    loading: () => throw StateError('SharedPreferences not ready'),
    error: (e, _) => throw StateError('SharedPreferences failed: $e'),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    secure: ref.watch(secureTokenStoreProvider),
    prefs: ref.watch(loadedSharedPreferencesProvider),
    firestore: ref.watch(firestoreServiceProvider),
  );
});

/// Global session user — drives route guards, profile UI, and role checks.
final authSessionProvider =
    StateNotifierProvider<AuthSessionNotifier, AppUser?>((ref) {
  return AuthSessionNotifier(ref);
});

class AuthSessionNotifier extends StateNotifier<AppUser?> {
  AuthSessionNotifier(this._ref) : super(null) {
    _init();
  }

  final Ref _ref;
  StreamSubscription<fb.User?>? _firebaseSub;

  void _init() {
    // Restore any previously persisted session first (instant on cold start).
    final repo = _ref.read(authRepositoryProvider);
    state = repo.currentSessionUser;

    // If Firebase is ready, let its auth stream drive session state.
    // This means signing in/out on another device will update this device too.
    _tryListenFirebase();
  }

  void _tryListenFirebase() {
    try {
      if (Firebase.apps.isEmpty) return;
      _firebaseSub =
          fb.FirebaseAuth.instance.authStateChanges().listen((fbUser) async {
        if (fbUser == null) {
          // Firebase signed out — clear local session.
          state = null;
        } else {
          // Firebase signed in — refresh the local snapshot.
          final repo = _ref.read(authRepositoryProvider);
          final persisted = repo.currentSessionUser;
          if (persisted != null && persisted.id == fbUser.uid) {
            state = persisted;
          }
          // If IDs don't match (e.g. different device) the next explicit
          // login will call setUser() and persist the correct user.
        }
      });
    } catch (_) {
      // Firebase not available — demo mode, no stream needed.
    }
  }

  @override
  void dispose() {
    _firebaseSub?.cancel();
    super.dispose();
  }

  void setUser(AppUser user) => state = user;

  Future<void> logout() async {
    await _ref.read(authRepositoryProvider).logout();
    state = null;
  }
}
