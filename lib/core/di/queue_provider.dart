import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/queue_sync_service.dart';
import 'initialization_provider.dart';
import 'repositories_provider.dart';

final queueSyncServiceProvider = Provider<QueueSyncService>((ref) {
  final service = QueueSyncService(
    db: ref.watch(appDatabaseProvider),
    remote: ref.watch(remoteApiDataSourceProvider),
    connectivity: ref.watch(connectivityWatcherProvider),
  );
  ref.onDispose(service.stop);
  return service;
});
