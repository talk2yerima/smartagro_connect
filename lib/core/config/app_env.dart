/// Compile-time environment for API + feature flags.
abstract final class AppEnv {
  /// Override with `--dart-define=API_BASE=https://api.yourdomain.com`
  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://api.smartagro.connect',
  );

  static const bool enableFirebaseMessaging =
      bool.fromEnvironment('ENABLE_FCM', defaultValue: true);
}
