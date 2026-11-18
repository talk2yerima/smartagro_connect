/// Compile-time environment for API base URL, feature flags, and log level.
///
/// Build with:
///   --dart-define=FLAVOR=dev|staging|prod
///   --dart-define=API_BASE=https://custom.api.com   (optional override)
///   --dart-define=ENABLE_FCM=false                  (optional)
///
/// [flavor] defaults to [Flavor.dev] when FLAVOR is omitted, so the
/// standard `flutter run` workflow needs no extra flags.
enum Flavor { dev, staging, prod }

abstract final class AppEnv {
  static const _flavorName =
      String.fromEnvironment('FLAVOR', defaultValue: 'dev');

  /// Active flavor resolved from the FLAVOR dart-define at compile time.
  static final Flavor flavor = switch (_flavorName) {
    'prod' => Flavor.prod,
    'staging' => Flavor.staging,
    _ => Flavor.dev,
  };

  static bool get isDev => flavor == Flavor.dev;
  static bool get isStaging => flavor == Flavor.staging;
  static bool get isProd => flavor == Flavor.prod;

  // ── Per-flavor API base URL ───────────────────────────────────────────────
  // Override at build time: --dart-define=API_BASE=https://api.yourdomain.com
  static const _apiOverride = String.fromEnvironment('API_BASE');

  static String get apiBase {
    if (_apiOverride.isNotEmpty) return _apiOverride;
    return switch (flavor) {
      Flavor.prod => 'https://api.smartagro.ng',
      Flavor.staging => 'https://staging-api.smartagro.ng',
      Flavor.dev => 'https://dev-api.smartagro.ng',
    };
  }

  // ── Display name ─────────────────────────────────────────────────────────
  static String get appName => switch (flavor) {
        Flavor.prod => 'SmartAgro Connect',
        Flavor.staging => 'SmartAgro (Staging)',
        Flavor.dev => 'SmartAgro (Dev)',
      };

  // ── Logging ───────────────────────────────────────────────────────────────
  static bool get verboseLogs => !isProd;

  // ── Feature flags ─────────────────────────────────────────────────────────
  static const bool enableFirebaseMessaging =
      bool.fromEnvironment('ENABLE_FCM', defaultValue: true);

  // ── Version ───────────────────────────────────────────────────────────────
  static const appVersion = '1.0.0';

  // ── Payments backend ──────────────────────────────────────────────────────
  // The Paystack SECRET key must never be compiled into the app — anyone can
  // extract it from an APK. It lives only in the Cloud Functions backend
  // (`functions/`, Firebase Secret Manager). The app calls that backend.
  static const firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'smartagro-connect',
  );
  static const _functionsOverride = String.fromEnvironment('FUNCTIONS_BASE');

  /// Base URL of the deployed Cloud Functions (region us-central1).
  /// Override with `--dart-define=FUNCTIONS_BASE=http://10.0.2.2:5001/PROJECT/us-central1`
  /// to use the local emulator.
  static String get functionsBase => _functionsOverride.isNotEmpty
      ? _functionsOverride
      : 'https://us-central1-$firebaseProjectId.cloudfunctions.net';

  // ── Public pages (Firebase Hosting, folder hosting/) ──────────────────────
  static String get privacyPolicyUrl =>
      'https://$firebaseProjectId.web.app/privacy';
  static String get termsUrl => 'https://$firebaseProjectId.web.app/terms';

  /// Demo mode (any password works, no Firebase) is a development aid only.
  /// Production builds refuse to fall back to it.
  static bool get allowDemoMode => !isProd;
}
