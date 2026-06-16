import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Shared image cache: 7-day TTL, 200 MB disk cap.
/// Pass to every CachedNetworkImage so all screens share one persistent cache.
class AppImageCacheManager {
  AppImageCacheManager._();

  static final CacheManager instance = CacheManager(
    Config(
      'smartagro_image_cache',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 300,
      repo: JsonCacheInfoRepository(databaseName: 'smartagro_image_cache'),
      fileService: HttpFileService(),
    ),
  );
}
