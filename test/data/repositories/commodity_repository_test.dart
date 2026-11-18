import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartagro_connect/data/datasources/asset_bundle_datasource.dart';
import 'package:smartagro_connect/data/repositories/commodity_repository.dart';

class MockAssets extends Mock implements AssetBundleDataSource {}

void main() {
  late MockAssets assets;
  late CommodityRepository repo;

  setUp(() {
    assets = MockAssets();
    repo = CommodityRepository(assets: assets);
    when(() => assets.loadJson(any())).thenAnswer((_) async => {
          'items': [
            {
              'id': 'maize',
              'name': 'Maize',
              'unit': 'bag (100 kg)',
              'priceNgn': 28000,
              'changePct': 2.3,
              'category': 'Grains',
            },
          ],
        });
  });

  test('demo mode shows the bundled sample prices', () async {
    final list = await repo.fetchCommodities();
    expect(list.single.name, 'Maize');
    expect(list.single.priceNgn, 28000);
    verify(() => assets.loadJson('assets/mock/commodities.json')).called(1);
  });
}
