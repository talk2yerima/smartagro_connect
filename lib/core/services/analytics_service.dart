import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Thin wrapper around FirebaseAnalytics.
///
/// All methods silently no-op in demo / dev mode so the app works without a
/// real Firebase project.  Once `flutterfire configure` is run, every call
/// transparently reaches Firebase Analytics.
class AnalyticsService {
  // ── Firebase availability ──────────────────────────────────────────────────

  bool get _ready {
    // firebase_analytics only supports Android, iOS, macOS, and web.
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) return false;
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

  FirebaseAnalytics get _fa => FirebaseAnalytics.instance;

  // ── Navigator observer (attach to GoRouter) ────────────────────────────────

  /// Returns a [NavigatorObserver] that logs screen views automatically.
  /// Falls back to a no-op observer in demo mode.
  NavigatorObserver get observer => _ready
      ? FirebaseAnalyticsObserver(analytics: _fa)
      : _NoOpObserver();

  // ── Event helpers ──────────────────────────────────────────────────────────

  Future<void> logLogin({String method = 'email'}) async {
    if (!_ready) return;
    await _fa.logLogin(loginMethod: method);
  }

  Future<void> logSignUp({String method = 'email'}) async {
    if (!_ready) return;
    await _fa.logSignUp(signUpMethod: method);
  }

  Future<void> logScreenView(String screenName) async {
    if (!_ready) return;
    await _fa.logScreenView(screenName: screenName);
  }

  Future<void> logProductView({
    required String productId,
    required String productName,
    required double priceNgn,
  }) async {
    if (!_ready) return;
    await _fa.logViewItem(
      currency: 'NGN',
      value: priceNgn,
      items: [
        AnalyticsEventItem(
          itemId: productId,
          itemName: productName,
          itemCategory: 'product',
          price: priceNgn,
        ),
      ],
    );
  }

  Future<void> logAddListing({required String category}) async {
    if (!_ready) return;
    await _fa.logEvent(
      name: 'add_listing',
      parameters: {'category': category},
    );
  }

  Future<void> logSearch({required String query}) async {
    if (!_ready) return;
    await _fa.logSearch(searchTerm: query);
  }

  Future<void> logCommodityView({required String commodityName}) async {
    if (!_ready) return;
    await _fa.logEvent(
      name: 'commodity_view',
      parameters: {'commodity_name': commodityName},
    );
  }
}

// ── No-op fallback ─────────────────────────────────────────────────────────────

class _NoOpObserver extends NavigatorObserver {}
