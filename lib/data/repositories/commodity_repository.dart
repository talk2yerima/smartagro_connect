import '../../domain/entities/commodity.dart';
import '../datasources/asset_bundle_datasource.dart';
import '../mappers/market_mappers.dart';

/// Commodity prices for demo mode (no Firebase configured).
///
/// With Firebase, prices stream live from Firestore (commoditiesProvider)
/// and admins edit them in the app. Without it, the bundled sample prices
/// are shown. (A REST API at api.smartagro.ng used to be tried first; that
/// server never existed, so it only added a slow failed request.)
class CommodityRepository {
  CommodityRepository({required AssetBundleDataSource assets})
      : _assets = assets;

  final AssetBundleDataSource _assets;

  static const _asset = 'assets/mock/commodities.json';

  Future<List<Commodity>> fetchCommodities() async {
    final fixture = await _assets.loadJson(_asset);
    final items = (fixture['items'] as List).cast<Map<String, dynamic>>();
    return items.map(commodityFromMap).toList();
  }
}
