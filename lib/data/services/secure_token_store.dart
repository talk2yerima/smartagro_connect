import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Secure token store backed by the OS keystore on mobile/macOS and
/// SharedPreferences on Windows/Linux/web (where no keystore is available).
class SecureTokenStore {
  SecureTokenStore();

  // FlutterSecureStorage is supported on Android, iOS, and macOS.
  // Windows requires the VS ATL C++ component (atlstr.h), which is not
  // universally available on dev machines, so we fall back gracefully.
  static bool get _useSecure =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';

  // ── Auth tokens ──────────────────────────────────────────────────────────────

  Future<void> writeTokens({required String access, String? refresh}) async {
    if (_useSecure) {
      await _secure.write(key: _kAccess, value: access);
      if (refresh != null) await _secure.write(key: _kRefresh, value: refresh);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAccess, access);
      if (refresh != null) await prefs.setString(_kRefresh, refresh);
    }
  }

  Future<String?> readAccess() async {
    if (_useSecure) return _secure.read(key: _kAccess);
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kAccess);
  }

  Future<String?> readRefresh() async {
    if (_useSecure) return _secure.read(key: _kRefresh);
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kRefresh);
  }

  Future<void> clear() async {
    if (_useSecure) {
      await _secure.delete(key: _kAccess);
      await _secure.delete(key: _kRefresh);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kAccess);
      await prefs.remove(_kRefresh);
    }
  }

  // ── Generic secure key-value ─────────────────────────────────────────────────

  Future<void> writeValue(String key, String value) async {
    if (_useSecure) {
      await _secure.write(key: key, value: value);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    }
  }

  Future<String?> readValue(String key) async {
    if (_useSecure) return _secure.read(key: key);
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> removeValue(String key) async {
    if (_useSecure) {
      await _secure.delete(key: key);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    }
  }
}
