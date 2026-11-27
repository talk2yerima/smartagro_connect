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
  final _restored = Completer<void>();

  /// Completes once the saved sign-in has been read from secure storage.
  /// Until then [state] is null even for a signed-in person, so anything
  /// that routes on sign-in at start-up (the splash) must await this.
  Future<void> get restored => _restored.future;

  Future<void> _init() async {
    try {
      // Warm the in-memory cache from secure storage, then expose the user.
      final repo = _ref.read(authRepositoryProvider);
      await repo.initSession();
      if (mounted) state = repo.currentSessionUser;
    } finally {
      if (!_restored.isCompleted) _restored.complete();
    }

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
            // Then pick up anything changed on the server since.
            try {
              final fresh = await repo.refreshSessionUser();
              if (mounted && fresh != null) state = fresh;
            } catch (_) {
              // Offline: keep the saved copy.
            }
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

  Future<void> updateProfile({
    required String name,
    String? phone,
    String? location,
    String? avatarUrl,
  }) async {
    final user = state;
    if (user == null) return;
    final updated = await _ref.read(authRepositoryProvider).updateProfile(
          userId: user.id,
          name: name,
          phone: phone,
          location: location,
          avatarUrl: avatarUrl,
        );
    state = updated;
  }

  Future<void> logout() async {
    await _ref.read(authRepositoryProvider).logout();
    state = null;
  }
}
