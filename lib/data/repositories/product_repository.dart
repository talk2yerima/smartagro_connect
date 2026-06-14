import 'dart:convert';

import '../../core/errors/failures.dart';
import '../../domain/entities/product_listing.dart';
import '../datasources/asset_bundle_datasource.dart';
import '../datasources/remote_api_datasource.dart';
import '../local/app_database.dart';
import '../mappers/market_mappers.dart';
import '../services/firestore_service.dart';

class ProductRepository {
  ProductRepository({
    required RemoteApiDataSource remote,
    required AssetBundleDataSource assets,
    required AppDatabase db,
    required FirestoreService firestore,
  })  : _remote = remote,
        _assets = assets,
        _db = db,
        _firestore = firestore;

  final RemoteApiDataSource _remote;
  final AssetBundleDataSource _assets;
  final AppDatabase _db;
  final FirestoreService _firestore;

  static const _asset = 'assets/mock/products.json';

  // ── Write operations ──────────────────────────────────────────────────────

  Future<void> addListing(Map<String, dynamic> data) async {
    if (_firestore.isAvailable) {
      final id = await _firestore.addProduct(data);
      if (id != null) {
        await _db.upsertProducts([{...data, 'id': id}]);
        return;
      }
    }
    // Fallback: REST API → offline queue.
    try {
      await _remote.createProduct(data);
      await _db.upsertProducts([data]);
    } on Failure catch (_) {
      await _db.enqueueWrite(
        operation: 'create_listing',
        payload: jsonEncode(data),
      );
      await _db.upsertProducts([data]);
    }
  }

  Future<void> updateListing(String id, Map<String, dynamic> data) async {
    try {
      await _remote.updateProduct(id, data);
      await _db.upsertProducts([data]);
    } on Failure catch (_) {
      await _db.enqueueWrite(
        operation: 'update_listing',
        payload: jsonEncode({...data, 'id': id}),
      );
      await _db.upsertProducts([data]);
    }
  }

  Future<void> deleteListing(String id) async {
    try {
      await _remote.deleteProduct(id);
    } on Failure catch (_) {
      await _db.enqueueWrite(
        operation: 'delete_listing',
        payload: jsonEncode({'id': id}),
      );
    }
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  Future<List<ProductListing>> fetchProducts() async {
    // Firestore is the live source of truth when Firebase is configured.
    if (_firestore.isAvailable) {
      final firestoreRows = await _firestore.fetchProducts();
      // Always append mock data so the UI is never empty for new accounts.
      final fixture = await _assets.loadJson(_asset);
      final mockItems = (fixture['items'] as List).cast<Map<String, dynamic>>();
      final all = [...firestoreRows, ...mockItems];
      await _db.upsertProducts(all);
      return all.map(productFromMap).toList();
    }

    // No Firebase — REST → SQLite cache → bundled fixture.
    try {
      final rows = await _remote.fetchProducts();
      await _db.upsertProducts(rows);
      return rows.map(productFromMap).toList();
    } on Failure catch (_) {
      final cached = await _db.readProducts();
      if (cached.isNotEmpty) return cached.map(productFromMap).toList();
      final fixture = await _assets.loadJson(_asset);
      final items = (fixture['items'] as List).cast<Map<String, dynamic>>();
      await _db.upsertProducts(items);
      return items.map(productFromMap).toList();
    } catch (_) {
      final cached = await _db.readProducts();
      if (cached.isNotEmpty) return cached.map(productFromMap).toList();
      final fixture = await _assets.loadJson(_asset);
      final items = (fixture['items'] as List).cast<Map<String, dynamic>>();
      return items.map(productFromMap).toList();
    }
  }
}
