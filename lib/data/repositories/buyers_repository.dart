import '../../domain/entities/nearby_buyer.dart';
import '../datasources/asset_bundle_datasource.dart';
import '../mappers/market_mappers.dart';

class BuyersRepository {
  BuyersRepository(this._assets);
  final AssetBundleDataSource _assets;

  static const _asset = 'assets/mock/buyers_nearby.json';

  Future<List<NearbyBuyer>> fetchBuyers() async {
    final fixture = await _assets.loadJson(_asset);
    final items = (fixture['items'] as List).cast<Map<String, dynamic>>();
    return items.map(buyerFromMap).toList();
  }
}
