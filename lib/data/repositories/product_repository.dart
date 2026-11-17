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
        await _db.upsertProducts([
          {...data, 'id': id}
        ]);
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

  /// Fields a seller may change on an existing listing. The Firestore rules
  /// reject any edit that touches `sellerId` or `verified`, so those (and
  /// other fixed fields) are never sent.
  static const editableFields = [
    'title',
    'priceNgn',
    'quantityKg',
    'availability',
    'description',
    'imageUrl',
  ];

  Future<void> updateListing(String id, Map<String, dynamic> data) async {
    if (_firestore.isAvailable) {
      final fields = {
        for (final key in editableFields)
          if (data.containsKey(key)) key: data[key],
      };
      await _firestore.updateProduct(id, fields);
      await _db.upsertProducts([
        {...data, 'id': id}
      ]);
      return;
    }
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
    if (_firestore.isAvailable) {
      await _firestore.deleteProduct(id);
      await _db.deleteProduct(id);
      return;
    }
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
    // Real users only ever see real listings: an empty marketplace shows its
    // empty state, never the bundled sample products.
    if (_firestore.isAvailable) {
      try {
        final rows = await _firestore.fetchProducts();
        await _db.replaceProducts(rows);
        return rows.map(productFromMap).toList();
      } catch (_) {
        // Offline with nothing in Firestore's own cache: last saved copy.
        final cached = await _db.readProducts();
        return cached.map(productFromMap).toList();
      }
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
