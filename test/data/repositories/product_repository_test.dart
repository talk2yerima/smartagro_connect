import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartagro_connect/data/datasources/asset_bundle_datasource.dart';
import 'package:smartagro_connect/data/local/app_database.dart';
import 'package:smartagro_connect/data/repositories/product_repository.dart';
import 'package:smartagro_connect/data/services/firestore_service.dart';

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
  late MockAssets assets;
  late MockDb db;
  late MockFirestoreService firestore;
  late ProductRepository repo;

  setUp(() {
    assets = MockAssets();
    db = MockDb();
    firestore = MockFirestoreService();
    repo = ProductRepository(assets: assets, db: db, firestore: firestore);
    when(() => db.upsertProducts(any())).thenAnswer((_) async {});
    // Demo mode (no Firebase) unless a group says otherwise.
    when(() => firestore.isAvailable).thenReturn(false);
  });

  group('demo mode (no Firebase)', () {
    test('first run seeds this phone from the sample listings', () async {
      when(() => db.readProducts()).thenAnswer((_) async => []);
      when(() => assets.loadJson(any()))
          .thenAnswer((_) async => Map<String, dynamic>.from(_assetFixture));

      final result = await repo.fetchProducts();

      expect(result.map((p) => p.id), ['p1', 'p2']);
      verify(() => assets.loadJson('assets/mock/products.json')).called(1);
      verify(() => db.upsertProducts(any())).called(1);
    });

    test("later runs use this phone's copy, including demo edits", () async {
      when(() => db.readProducts()).thenAnswer((_) async => [_rows.first]);

      final result = await repo.fetchProducts();

      expect(result.single.id, 'p1');
      verifyNever(() => assets.loadJson(any()));
    });

    test('demo edits and deletes stay on this phone', () async {
      when(() => db.deleteProduct(any())).thenAnswer((_) async {});

      await repo.updateListing('p1', Map<String, dynamic>.from(_rows.first));
      await repo.deleteListing('p1');

      verify(() => db.upsertProducts(any())).called(1);
      verify(() => db.deleteProduct('p1')).called(1);
      verifyNever(() => firestore.updateProduct(any(), any()));
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
        'state',
        'city',
      });
      expect(sent.containsKey('sellerId'), isFalse);
      expect(sent.containsKey('verified'), isFalse);
    });

    test('deletes go to Firestore and the offline copy', () async {
      when(() => firestore.deleteProduct(any())).thenAnswer((_) async {});

      await repo.deleteListing('p1');

      verify(() => firestore.deleteProduct('p1')).called(1);
      verify(() => db.deleteProduct('p1')).called(1);
    });
  });
}
