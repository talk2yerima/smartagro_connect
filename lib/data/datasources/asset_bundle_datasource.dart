import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Loads bundled JSON fixtures used as mock API responses.
class AssetBundleDataSource {
  Future<Map<String, dynamic>> loadJson(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}
