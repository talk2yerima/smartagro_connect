import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_env.dart';
import '../../core/network/dio_client.dart';
import '../../data/datasources/asset_bundle_datasource.dart';
import '../../data/datasources/remote_api_datasource.dart';
import '../../data/repositories/buyers_repository.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/commodity_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../domain/entities/chat_models.dart';
import 'auth_providers.dart';
import 'firestore_providers.dart';
import 'initialization_provider.dart';

final dioClientProvider = Provider<DioClient>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return DioClient(
    baseUrl: AppEnv.apiBase,
    // Provides a fresh token on every request (Firebase refreshes automatically).
    getToken: () => authRepo.getIdToken(),
    // Force-refreshes the token on 401 before retrying.
    refreshToken: () => authRepo.getIdToken(forceRefresh: true),
    // On persistent 401, sign the user out.
    onUnauthorized: () => ref.read(authSessionProvider.notifier).logout(),
  );
});

final remoteApiDataSourceProvider = Provider<RemoteApiDataSource>((ref) {
  return RemoteApiDataSource(ref.watch(dioClientProvider));
});

final assetBundleDataSourceProvider = Provider<AssetBundleDataSource>((ref) {
  return AssetBundleDataSource();
});

final commodityRepositoryProvider = Provider<CommodityRepository>((ref) {
  return CommodityRepository(
    remote: ref.watch(remoteApiDataSourceProvider),
    assets: ref.watch(assetBundleDataSourceProvider),
    db: ref.watch(appDatabaseProvider),
  );
});

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(
    remote: ref.watch(remoteApiDataSourceProvider),
    assets: ref.watch(assetBundleDataSourceProvider),
    db: ref.watch(appDatabaseProvider),
    firestore: ref.watch(firestoreServiceProvider),
  );
});

final buyersRepositoryProvider = Provider<BuyersRepository>((ref) {
  return BuyersRepository(ref.watch(assetBundleDataSourceProvider));
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(assetBundleDataSourceProvider));
});

final commoditiesProvider = FutureProvider((ref) {
  return ref.watch(commodityRepositoryProvider).fetchCommodities();
});

final productsProvider = FutureProvider((ref) {
  return ref.watch(productRepositoryProvider).fetchProducts();
});

final buyersNearbyProvider = FutureProvider((ref) {
  return ref.watch(buyersRepositoryProvider).fetchBuyers();
});

final chatThreadsProvider = FutureProvider((ref) {
  return ref.watch(chatRepositoryProvider).threads();
});

final chatMessagesProvider =
    FutureProvider.family<List<ChatMessage>, String>((ref, threadId) {
  return ref.watch(chatRepositoryProvider).messages(threadId);
});
