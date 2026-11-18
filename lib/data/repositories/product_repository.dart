import '../../core/errors/failures.dart';
import '../../domain/entities/product_listing.dart';
import '../datasources/asset_bundle_datasource.dart';
import '../local/app_database.dart';
import '../mappers/market_mappers.dart';
import '../services/firestore_service.dart';

/// Product listings.
///
/// With Firebase (the real app), Firestore is the source of truth and the
/// SQLite copy is only an offline cache. Without Firebase (demo mode), the
/// SQLite copy is the store, seeded from the bundled sample listings.
/// (A REST API at api.smartagro.ng used to sit in between; that server never
/// existed, so writes only queued up and never arrived.)
class ProductRepository {
  ProductRepository({
    required AssetBundleDataSource assets,
    required AppDatabase db,
    required FirestoreService firestore,
  })  : _assets = assets,
        _db = db,
        _firestore = firestore;

  final AssetBundleDataSource _assets;
  final AppDatabase _db;
  final FirestoreService _firestore;

  static const _asset = 'assets/mock/products.json';

  // ── Write operations ──────────────────────────────────────────────────────

  Future<void> addListing(Map<String, dynamic> data) async {
    if (_firestore.isAvailable) {
      final id = await _firestore.addProduct(data);
      if (id == null) {
        throw const ServerFailure(
            'Could not save your listing. Please try again.');
      }
      await _db.upsertProducts([
        {...data, 'id': id}
      ]);
      return;
    }
    // Demo mode: keep it on this phone.
    await _db.upsertProducts([
      {
        ...data,
        'id': data['id'] ?? 'demo-${DateTime.now().millisecondsSinceEpoch}'
      }
    ]);
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
    'state',
    'city',
  ];

  Future<void> updateListing(String id, Map<String, dynamic> data) async {
    if (_firestore.isAvailable) {
      final fields = {
        for (final key in editableFields)
          if (data.containsKey(key)) key: data[key],
      };
      await _firestore.updateProduct(id, fields);
    }
    await _db.upsertProducts([
      {...data, 'id': id}
    ]);
  }

  Future<void> deleteListing(String id) async {
    if (_firestore.isAvailable) {
      await _firestore.deleteProduct(id);
    }
    await _db.deleteProduct(id);
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

    // Demo mode: this phone's copy, seeded once from the sample listings.
    final cached = await _db.readProducts();
    if (cached.isNotEmpty) return cached.map(productFromMap).toList();
    final fixture = await _assets.loadJson(_asset);
    final items = (fixture['items'] as List).cast<Map<String, dynamic>>();
    await _db.upsertProducts(items);
    return items.map(productFromMap).toList();
  }
}
