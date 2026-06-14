import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartagro_connect/core/errors/failures.dart';
import 'package:smartagro_connect/data/datasources/asset_bundle_datasource.dart';
import 'package:smartagro_connect/data/datasources/remote_api_datasource.dart';
import 'package:smartagro_connect/data/local/app_database.dart';
import 'package:smartagro_connect/data/repositories/commodity_repository.dart';

class MockRemote extends Mock implements RemoteApiDataSource {}
class MockAssets extends Mock implements AssetBundleDataSource {}
class MockDb extends Mock implements AppDatabase {}

// Minimal fixture rows used across tests.
const _rows = [
  {
    'id': 'c1', 'name': 'Maize', 'unit': 'kg',
    'priceNgn': 350, 'changePct': 2.5, 'category': 'Grains',
  },
  {
    'id': 'c2', 'name': 'Soybean', 'unit': 'kg',
    'priceNgn': 620, 'changePct': -1.2, 'category': 'Legumes',
  },
];

const _assetFixture = {'items': _rows};

void main() {
  late MockRemote remote;
  late MockAssets assets;
  late MockDb db;
  late CommodityRepository repo;

  setUp(() {
    remote = MockRemote();
    assets = MockAssets();
    db = MockDb();
    repo = CommodityRepository(remote: remote, assets: assets, db: db);
    // DB write stubs (fire-and-forget).
    when(() => db.upsertCommodities(any())).thenAnswer((_) async {});
  });

  group('fetchCommodities — remote success', () {
    setUp(() {
      when(() => remote.fetchCommodities()).thenAnswer((_) async => List.from(_rows));
    });

    test('returns mapped commodities from remote', () async {
      final result = await repo.fetchCommodities();
      expect(result.length, 2);
      expect(result.first.id, 'c1');
      expect(result.last.id, 'c2');
    });

    test('upserts rows to local DB', () async {
      await repo.fetchCommodities();
      verify(() => db.upsertCommodities(any())).called(1);
    });

    test('does not touch asset bundle', () async {
      await repo.fetchCommodities();
      verifyNever(() => assets.loadJson(any()));
    });
  });

  group('fetchCommodities — remote fails, cache hit', () {
    setUp(() {
      when(() => remote.fetchCommodities())
          .thenThrow(const NetworkFailure('Offline'));
      when(() => db.readCommodities())
          .thenAnswer((_) async => List.from(_rows));
    });

    test('returns cached commodities', () async {
      final result = await repo.fetchCommodities();
      expect(result.length, 2);
      expect(result.first.id, 'c1');
    });

    test('does not touch asset bundle', () async {
      await repo.fetchCommodities();
      verifyNever(() => assets.loadJson(any()));
    });
  });

  group('fetchCommodities — remote fails, cache empty, asset fallback', () {
    setUp(() {
      when(() => remote.fetchCommodities())
          .thenThrow(const NetworkFailure('Offline'));
      when(() => db.readCommodities()).thenAnswer((_) async => []);
      when(() => assets.loadJson(any()))
          .thenAnswer((_) async => Map<String, dynamic>.from(_assetFixture));
    });

    test('returns asset fixture commodities', () async {
      final result = await repo.fetchCommodities();
      expect(result.length, 2);
      expect(result.map((c) => c.id), containsAll(['c1', 'c2']));
    });

    test('upserts asset rows to DB', () async {
      await repo.fetchCommodities();
      verify(() => db.upsertCommodities(any())).called(1);
    });

    test('loads from correct asset path', () async {
      await repo.fetchCommodities();
      verify(() => assets.loadJson('assets/mock/commodities.json')).called(1);
    });
  });

  group('fetchCommodities — generic error, cache empty, asset fallback', () {
    setUp(() {
      when(() => remote.fetchCommodities()).thenThrow(Exception('Unexpected'));
      when(() => db.readCommodities()).thenAnswer((_) async => []);
      when(() => assets.loadJson(any()))
          .thenAnswer((_) async => Map<String, dynamic>.from(_assetFixture));
    });

    test('returns asset fixture commodities on generic error', () async {
      final result = await repo.fetchCommodities();
      expect(result.length, 2);
    });
  });
}
