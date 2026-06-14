import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight token store backed by SharedPreferences.
///
/// For production Android/iOS builds, replace this with flutter_secure_storage
/// (Android Keystore / iOS Keychain).  flutter_secure_storage is excluded from
/// the Windows dev build because it requires the VS ATL C++ component.
/// To enable: uncomment flutter_secure_storage in pubspec.yaml, install
/// "C++ ATL for latest v143 build tools" via Visual Studio Installer, then
/// swap this implementation for the FlutterSecureStorage version.
class SecureTokenStore {
  SecureTokenStore();

  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';

  Future<void> writeTokens({required String access, String? refresh}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccess, access);
    if (refresh != null) await prefs.setString(_kRefresh, refresh);
  }

  Future<String?> readAccess() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kAccess);
  }

  Future<String?> readRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kRefresh);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccess);
    await prefs.remove(_kRefresh);
  }
}
