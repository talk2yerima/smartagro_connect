import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';

void main() {
  // runZonedGuarded ensures that errors thrown anywhere in the async boot
  // sequence AND in the widget tree are funnelled into Crashlytics (when
  // Firebase is configured) or printed to the console (demo mode).
  runZonedGuarded(_boot, _onZoneError);
}

Future<void> _boot() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _tryInitFirebase();
  _setupCrashlytics();

  runApp(
    const ProviderScope(
      overrides: [],
      child: SmartAgroConnectApp(),
    ),
  );
}

// ── Zone-level uncaught error handler ─────────────────────────────────────────

void _onZoneError(Object error, StackTrace stack) {
  if (_firebaseConfigured() && _crashlyticsSupported()) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  } else {
    debugPrint('[SmartAgro] Unhandled zone error: $error\n$stack');
  }
}

// ── Crashlytics wiring ────────────────────────────────────────────────────────

void _setupCrashlytics() {
  if (!_firebaseConfigured() || !_crashlyticsSupported()) return;

  FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
}

// Crashlytics only supports Android, iOS, and macOS — not Windows/Linux desktop or web.
bool _crashlyticsSupported() {
  if (kIsWeb) return false;
  return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
}

// ── Firebase helpers ──────────────────────────────────────────────────────────

bool _firebaseConfigured() {
  try {
    if (Firebase.apps.isEmpty) return false;
    final key = Firebase.app().options.apiKey;
    return key.isNotEmpty &&
        !key.startsWith('YOUR_') &&
        !key.startsWith('REPLACE_');
  } catch (_) {
    return false;
  }
}

Future<void> _tryInitFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Firebase not configured or platform unsupported (e.g. Windows dev).
    // The app continues in demo mode — auth stubs remain active.
    debugPrint(
      '[SmartAgro] Firebase not initialised — running in demo mode. '
      'Run `flutterfire configure` to activate real auth.',
    );
  }
}
