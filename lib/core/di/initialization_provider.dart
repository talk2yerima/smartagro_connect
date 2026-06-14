import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/local/app_database.dart';
import '../../data/services/connectivity_watcher.dart';
import '../services/push_messaging_service.dart';
import 'queue_provider.dart';

/// Boot-time dependencies and global toggles (theme, onboarding, session).
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  return ThemeModeController(ref);
});

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._ref) : super(ThemeMode.system) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final prefs = await _ref.read(sharedPreferencesProvider.future);
    final raw = prefs.getString(_kThemeKey);
    state = switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await _ref.read(sharedPreferencesProvider.future);
    await prefs.setString(
      _kThemeKey,
      switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      },
    );
  }

  static const _kThemeKey = 'theme_mode';
}

final onboardingCompletedProvider = FutureProvider<bool>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return prefs.getBool('onboarding_completed') ?? false;
});

Future<void> setOnboardingCompleted(WidgetRef ref, {required bool value}) async {
  final prefs = await ref.read(sharedPreferencesProvider.future);
  await prefs.setBool('onboarding_completed', value);
  ref.invalidate(onboardingCompletedProvider);
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

// secureTokenStoreProvider lives in auth_providers.dart (needs loadedSharedPreferencesProvider)

final connectivityWatcherProvider = Provider<ConnectivityWatcher>((ref) {
  final w = ConnectivityWatcher();
  ref.onDispose(w.dispose);
  return w;
});

/// Ensures async singletons are ready before [MaterialApp.router] mounts.
final initializationProvider = FutureProvider<void>((ref) async {
  await ref.watch(sharedPreferencesProvider.future);
  await ref.read(appDatabaseProvider).open();
  // Start offline write-queue flusher after DB is open.
  ref.read(queueSyncServiceProvider).start();
  // Register for push notifications (no-op when Firebase is not configured).
  await PushMessagingService.instance.register();
});
