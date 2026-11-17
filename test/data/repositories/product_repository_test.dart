import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartagro_connect/core/errors/failures.dart';
import 'package:smartagro_connect/data/datasources/asset_bundle_datasource.dart';
import 'package:smartagro_connect/data/datasources/remote_api_datasource.dart';
import 'package:smartagro_connect/data/local/app_database.dart';
import 'package:smartagro_connect/data/repositories/product_repository.dart';
import 'package:smartagro_connect/data/services/firestore_service.dart';
import 'package:smartagro_connect/domain/entities/product_listing.dart';

class MockRemote extends Mock implements RemoteApiDataSource {}

class MockAssets extends Mock implements AssetBundleDataSource {}

class MockDb extends Mock implements AppDatabase {}

class MockFirestoreService extends Mock implements FirestoreService {}

const _rows = [
  {
    'id': 'p1',
    'title': 'Tomatoes',
    'description': 'Fresh',
    'priceNgn': 1200,
    'quantityKg': 500,
    'state': 'Lagos',
    'city': 'Ikeja',
    'sellerId': 's1',
    'sellerName': 'Emeka',
    'sellerRating': 4.5,
    'verified': true,
    'availability': 'in_stock',
    'imageUrl': 'https://img.test/t.jpg',
    'lat': 6.52,
    'lng': 3.38,
  },
  {
    'id': 'p2',
    'title': 'Yam',
    'description': 'Grade B',
    'priceNgn': 800,
    'quantityKg': 200,
    'state': 'Oyo',
    'city': 'Ibadan',
    'sellerId': 's2',
    'sellerName': 'Bola',
    'sellerRating': 4.1,
    'verified': false,
    'availability': 'limited',
    'imageUrl': 'https://img.test/y.jpg',
    'lat': 7.38,
    'lng': 3.90,
  },
];

const _assetFixture = {'items': _rows};

void main() {
  late MockRemote remote;
  late MockAssets assets;
  late MockDb db;
  late MockFirestoreService firestore;
  late ProductRepository repo;

  setUp(() {
    remote = MockRemote();
    assets = MockAssets();
    db = MockDb();
    firestore = MockFirestoreService();
    repo = ProductRepository(
        remote: remote, assets: assets, db: db, firestore: firestore);
    when(() => db.upsertProducts(any())).thenAnswer((_) async {});
    // These tests cover the REST → cache → fixture path (no Firebase).
    when(() => firestore.isAvailable).thenReturn(false);
  });

  group('fetchProducts — remote success', () {
    setUp(() {
      when(() => remote.fetchProducts())
          .thenAnswer((_) async => List.from(_rows));
    });

    test('returns mapped products', () async {
      final result = await repo.fetchProducts();
      expect(result.length, 2);
      expect(result.first.id, 'p1');
      expect(result.first.availability, ProductAvailability.inStock);
      expect(result.last.availability, ProductAvailability.limited);
    });

    test('upserts to DB', () async {
      await repo.fetchProducts();
      verify(() => db.upsertProducts(any())).called(1);
    });
  });

  group('fetchProducts — remote fails, cache hit', () {
    setUp(() {
      when(() => remote.fetchProducts()).thenThrow(const ServerFailure('500'));
      when(() => db.readProducts()).thenAnswer((_) async => List.from(_rows));
    });

    test('returns cached products', () async {
      final result = await repo.fetchProducts();
      expect(result.length, 2);
    });

    test('does not call asset bundle', () async {
      await repo.fetchProducts();
      verifyNever(() => assets.loadJson(any()));
    });
  });

  group('fetchProducts — remote fails, empty cache, asset fallback', () {
    setUp(() {
      when(() => remote.fetchProducts())
          .thenThrow(const NetworkFailure('No internet'));
      when(() => db.readProducts()).thenAnswer((_) async => []);
      when(() => assets.loadJson(any()))
          .thenAnswer((_) async => Map<String, dynamic>.from(_assetFixture));
    });

    test('returns products from asset fixture', () async {
      final result = await repo.fetchProducts();
      expect(result.length, 2);
      expect(result.first.id, 'p1');
    });

    test('loads correct asset path', () async {
      await repo.fetchProducts();
      verify(() => assets.loadJson('assets/mock/products.json')).called(1);
    });

    test('upserts asset rows to DB', () async {
      await repo.fetchProducts();
      verify(() => db.upsertProducts(any())).called(1);
    });
  });
  // ── Firebase configured: Firestore is the source of truth ──────────────
  group('with Firestore', () {
    setUp(() {
      when(() => firestore.isAvailable).thenReturn(true);
      when(() => db.replaceProducts(any())).thenAnswer((_) async {});
      when(() => db.deleteProduct(any())).thenAnswer((_) async {});
      when(() => db.readProducts()).thenAnswer((_) async => List.from(_rows));
    });

    test('an empty marketplace stays empty (no sample products)', () async {
      when(() => firestore.fetchProducts()).thenAnswer((_) async => []);

      final result = await repo.fetchProducts();

      expect(result, isEmpty);
      verifyNever(() => assets.loadJson(any()));
      verify(() => db.replaceProducts([])).called(1);
    });

    test('real listings replace the whole offline cache', () async {
      when(() => firestore.fetchProducts())
          .thenAnswer((_) async => List.from(_rows));

      final result = await repo.fetchProducts();

      expect(result.map((p) => p.id), ['p1', 'p2']);
      verify(() => db.replaceProducts(any())).called(1);
    });

    test('offline falls back to the saved copy, not sample data', () async {
      when(() => firestore.fetchProducts()).thenThrow(Exception('offline'));

      final result = await repo.fetchProducts();

      expect(result.length, 2);
      verifyNever(() => assets.loadJson(any()));
    });

    test('edits go to Firestore with only seller-editable fields', () async {
      when(() => firestore.updateProduct(any(), any()))
          .thenAnswer((_) async {});

      await repo.updateListing('p1', Map<String, dynamic>.from(_rows.first));

      final sent = verify(() => firestore.updateProduct('p1', captureAny()))
          .captured
          .single as Map<String, dynamic>;
      expect(sent.keys.toSet(), {
        'title',
        'priceNgn',
        'quantityKg',
        'availability',
        'description',
        'imageUrl',
      });
      expect(sent.containsKey('sellerId'), isFalse);
      expect(sent.containsKey('verified'), isFalse);
      verifyNever(() => remote.updateProduct(any(), any()));
    });

    test('deletes go to Firestore and leave the offline cache', () async {
      when(() => firestore.deleteProduct(any())).thenAnswer((_) async {});

      await repo.deleteListing('p1');

      verify(() => firestore.deleteProduct('p1')).called(1);
      verify(() => db.deleteProduct('p1')).called(1);
      verifyNever(() => remote.deleteProduct(any()));
    });
  });
}
