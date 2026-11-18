import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/asset_bundle_datasource.dart';
import '../../data/repositories/buyers_repository.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/commodity_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/entities/chat_models.dart';
import '../../domain/entities/commodity.dart';
import '../../domain/entities/nearby_buyer.dart';
import '../../domain/entities/price_alert.dart';
import '../../domain/entities/product_listing.dart';
import 'auth_providers.dart';
import 'firestore_providers.dart';
import 'initialization_provider.dart';

final assetBundleDataSourceProvider = Provider<AssetBundleDataSource>((ref) {
  return AssetBundleDataSource();
});

final commodityRepositoryProvider = Provider<CommodityRepository>((ref) {
  return CommodityRepository(assets: ref.watch(assetBundleDataSourceProvider));
});

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(
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

final commoditiesProvider = StreamProvider<List<Commodity>>((ref) {
  final firestore = ref.watch(firestoreServiceProvider);
  // Re-subscribe whenever the signed-in person changes. Signing out cuts
  // the listener (PERMISSION_DENIED) and it never came back after the next
  // sign-in, leaving prices empty until the app was restarted.
  final uid = ref.watch(authSessionProvider.select((u) => u?.id));
  if (firestore.isAvailable) {
    if (uid == null) return Stream.value(const <Commodity>[]);
    return firestore.commoditiesStream().map((items) => items
        .map((m) => Commodity(
              id: (m['id'] as String?) ?? '',
              name: (m['name'] as String?) ?? '',
              unit: (m['unit'] as String?) ?? '',
              priceNgn: (m['priceNgn'] as num?)?.toInt() ?? 0,
              changePct: (m['changePct'] as num?)?.toDouble() ?? 0.0,
              category: (m['category'] as String?) ?? '',
            ))
        .where((c) => c.name.isNotEmpty)
        .toList());
  }
  return Stream.fromFuture(
      ref.read(commodityRepositoryProvider).fetchCommodities());
});

final productsProvider = FutureProvider((ref) {
  // Reload for each signed-in person (see commoditiesProvider).
  ref.watch(authSessionProvider.select((u) => u?.id));
  return ref.watch(productRepositoryProvider).fetchProducts();
});

final buyersNearbyProvider = FutureProvider<List<NearbyBuyer>>((ref) async {
  final firestore = ref.watch(firestoreServiceProvider);
  // Reload for each signed-in person (see commoditiesProvider).
  final uid = ref.watch(authSessionProvider.select((u) => u?.id));
  if (firestore.isAvailable) {
    if (uid == null) return const <NearbyBuyer>[];
    final maps = await firestore.fetchBuyers();
    if (maps.isNotEmpty) {
      return maps
          .map((m) => NearbyBuyer(
                id: (m['id'] as String?) ?? '',
                name: (m['name'] as String?) ?? 'Unknown',
                type: (m['role'] as String?) ?? 'buyer',
                state: (m['state'] as String?) ?? '',
                distanceKm: 0,
                rating: (m['rating'] as num?)?.toDouble() ?? 4.0,
                verified: (m['verified'] as bool?) ?? false,
              ))
          .toList();
    }
  }
  return ref.read(buyersRepositoryProvider).fetchBuyers();
});

final chatThreadsProvider = StreamProvider<List<ChatThread>>((ref) {
  final user = ref.watch(authSessionProvider);
  final firestore = ref.watch(firestoreServiceProvider);
  if (user != null && firestore.isAvailable) {
    return firestore.chatThreadsStream(user.id);
  }
  return Stream.fromFuture(ref.watch(chatRepositoryProvider).threads());
});

final chatMessagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, threadId) {
  final user = ref.watch(authSessionProvider);
  final firestore = ref.watch(firestoreServiceProvider);
  if (user != null && firestore.isAvailable) {
    return firestore.chatMessagesStream(threadId, user.id).transform(
          StreamTransformer.fromHandlers(
            handleData: (data, sink) => sink.add(data),
            handleError: (_, __, sink) => sink.add([]),
            handleDone: (sink) => sink.close(),
          ),
        );
  }
  return Stream.fromFuture(
      ref.watch(chatRepositoryProvider).messages(threadId));
});

/// Products belonging to the currently signed-in farmer.
final myListingsProvider = FutureProvider<List<ProductListing>>((ref) async {
  final user = ref.watch(authSessionProvider);
  if (user == null) return [];
  final all = await ref.watch(productsProvider.future);
  return all.where((p) => p.sellerId == user.id).toList();
});

/// Real-time notifications for the signed-in user from Firestore.
/// Falls back to an empty list when Firebase is unavailable.
final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final user = ref.watch(authSessionProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).notificationsStream(user.id);
});

final userCreatedAtProvider = FutureProvider<DateTime?>((ref) {
  final user = ref.watch(authSessionProvider);
  if (user == null) return Future.value(null);
  return ref.read(firestoreServiceProvider).fetchUserCreatedAt(user.id);
});

final adminStatsProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.read(firestoreServiceProvider).fetchAdminStats();
});

final adminActivityProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.read(firestoreServiceProvider).fetchAdminActivity();
});

/// Whether the peer is currently typing in a thread.
/// Key format: "threadId|peerId" (UIDs are alphanumeric, safe to split on |).
final peerTypingProvider =
    StreamProvider.autoDispose.family<bool, String>((ref, key) {
  final parts = key.split('|');
  if (parts.length != 2) return Stream.value(false);
  return ref
      .watch(firestoreServiceProvider)
      .peerTypingStream(parts[0], parts[1]);
});

/// The signed-in person's price alerts for one commodity.
final priceAlertsProvider = StreamProvider.autoDispose
    .family<List<PriceAlert>, String>((ref, commodityId) {
  final uid = ref.watch(authSessionProvider.select((u) => u?.id));
  if (uid == null) return Stream.value(const []);
  return ref
      .watch(firestoreServiceProvider)
      .priceAlertsStream(uid, commodityId);
});
