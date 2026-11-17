import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';
import 'core/utils/app_logger.dart';
import 'firebase_options.dart';

void main() {
  // runZonedGuarded ensures that errors thrown anywhere in the async boot
  // sequence AND in the widget tree are funnelled into Crashlytics (when
  // Firebase is configured) or printed to the console (demo mode).
  runZonedGuarded(_boot, _onZoneError);
}

Future<void> _boot() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fonts ship inside the app (assets/fonts). Never fetch them at runtime:
  // that cost mobile data and made text jump when the font arrived.
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(_fontLicenses);
  await _tryInitFirebase();
  _setupCrashlytics();

  runApp(
    const ProviderScope(
      overrides: [],
      child: SmartAgroConnectApp(),
    ),
  );
}

/// The bundled fonts are under the SIL Open Font License, which asks that
/// the licence travels with them; it shows in Settings → licences.
Stream<LicenseEntry> _fontLicenses() async* {
  for (final (family, file) in [
    ('Poppins', 'assets/fonts/OFL-Poppins.txt'),
    ('Inter', 'assets/fonts/OFL-Inter.txt'),
  ]) {
    final text = await rootBundle.loadString(file);
    yield LicenseEntryWithLineBreaks([family], text);
  }
}

// ── Zone-level uncaught error handler ─────────────────────────────────────────

void _onZoneError(Object error, StackTrace stack) {
  if (_firebaseConfigured() && _crashlyticsSupported()) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  } else {
    log.e('[SmartAgro] Unhandled zone error', error: error, stackTrace: stack);
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
    log.w('[SmartAgro] Firebase not initialised — running in demo mode. '
        'Run `flutterfire configure` to activate real auth.');
  }
}
