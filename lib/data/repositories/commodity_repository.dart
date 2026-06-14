import '../../core/errors/failures.dart';
import '../../domain/entities/commodity.dart';
import '../datasources/asset_bundle_datasource.dart';
import '../datasources/remote_api_datasource.dart';
import '../local/app_database.dart';
import '../mappers/market_mappers.dart';

/// Commodity repository: remote first, SQLite cache, bundled mock fallback.
class CommodityRepository {
  CommodityRepository({
    required RemoteApiDataSource remote,
    required AssetBundleDataSource assets,
    required AppDatabase db,
  })  : _remote = remote,
        _assets = assets,
        _db = db;

  final RemoteApiDataSource _remote;
  final AssetBundleDataSource _assets;
  final AppDatabase _db;

  static const _asset = 'assets/mock/commodities.json';

  Future<List<Commodity>> fetchCommodities() async {
    try {
      final rows = await _remote.fetchCommodities();
      await _db.upsertCommodities(rows);
      return rows.map(commodityFromMap).toList();
    } on Failure catch (_) {
      final cached = await _db.readCommodities();
      if (cached.isNotEmpty) {
        return cached.map(commodityFromMap).toList();
      }
      final fixture = await _assets.loadJson(_asset);
      final items = (fixture['items'] as List).cast<Map<String, dynamic>>();
      await _db.upsertCommodities(items);
      return items.map(commodityFromMap).toList();
    } catch (_) {
      final cached = await _db.readCommodities();
      if (cached.isNotEmpty) {
        return cached.map(commodityFromMap).toList();
      }
      final fixture = await _assets.loadJson(_asset);
      final items = (fixture['items'] as List).cast<Map<String, dynamic>>();
      return items.map(commodityFromMap).toList();
    }
  }
}
