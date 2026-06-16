import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/queue_sync_service.dart';
import 'initialization_provider.dart';
import 'repositories_provider.dart';

final pendingSyncCountProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final rows = await db.pendingWriteCount();
  if (rows.isEmpty) return 0;
  return (rows.first['cnt'] as int?) ?? 0;
});

final queueSyncServiceProvider = Provider<QueueSyncService>((ref) {
  final service = QueueSyncService(
    db: ref.watch(appDatabaseProvider),
    remote: ref.watch(remoteApiDataSourceProvider),
    connectivity: ref.watch(connectivityWatcherProvider),
    onQueueChanged: () => ref.invalidate(pendingSyncCountProvider),
  );
  ref.onDispose(service.stop);
  return service;
});
