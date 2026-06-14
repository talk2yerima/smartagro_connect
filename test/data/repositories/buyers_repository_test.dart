import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartagro_connect/data/datasources/asset_bundle_datasource.dart';
import 'package:smartagro_connect/data/repositories/buyers_repository.dart';

class MockAssets extends Mock implements AssetBundleDataSource {}

const _rows = [
  {
    'id': 'b1', 'name': 'Ade Traders', 'type': 'Wholesaler',
    'state': 'Lagos', 'distanceKm': 8, 'rating': 4.3, 'verified': true,
  },
  {
    'id': 'b2', 'name': 'Kola Mill', 'type': 'Processor',
    'state': 'Ogun', 'distanceKm': 22, 'rating': 3.9, 'verified': false,
  },
];

void main() {
  late MockAssets assets;
  late BuyersRepository repo;

  setUp(() {
    assets = MockAssets();
    repo = BuyersRepository(assets);
    when(() => assets.loadJson('assets/mock/buyers_nearby.json'))
        .thenAnswer((_) async => {'items': List.from(_rows)});
  });

  group('fetchBuyers', () {
    test('returns mapped buyers from asset fixture', () async {
      final result = await repo.fetchBuyers();
      expect(result.length, 2);
    });

    test('maps id, name, type, state correctly', () async {
      final result = await repo.fetchBuyers();
      expect(result.first.id, 'b1');
      expect(result.first.name, 'Ade Traders');
      expect(result.first.type, 'Wholesaler');
      expect(result.first.state, 'Lagos');
    });

    test('maps distanceKm and rating', () async {
      final result = await repo.fetchBuyers();
      expect(result.first.distanceKm, 8);
      expect(result.first.rating, 4.3);
    });

    test('maps verified flag', () async {
      final result = await repo.fetchBuyers();
      expect(result.first.verified, isTrue);
      expect(result.last.verified, isFalse);
    });

    test('loads from correct asset path', () async {
      await repo.fetchBuyers();
      verify(() => assets.loadJson('assets/mock/buyers_nearby.json')).called(1);
    });

    test('returns empty list when fixture has no items', () async {
      when(() => assets.loadJson(any()))
          .thenAnswer((_) async => {'items': <dynamic>[]});
      final result = await repo.fetchBuyers();
      expect(result, isEmpty);
    });
  });
}
