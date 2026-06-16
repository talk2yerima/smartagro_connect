import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/utils/app_logger.dart';
import '../datasources/remote_api_datasource.dart';
import '../local/app_database.dart';
import 'connectivity_watcher.dart';

/// Maximum times an operation is retried before being marked failed.
const _maxRetries = 5;

/// Flushes the SQLite write queue to the remote API whenever connectivity
/// is available.  Call [start] once at app startup — it will replay any
/// pending offline writes immediately and auto-flush on future reconnects.
class QueueSyncService {
  QueueSyncService({
    required AppDatabase db,
    required RemoteApiDataSource remote,
    required ConnectivityWatcher connectivity,
    this.onQueueChanged,
  })  : _db = db,
        _remote = remote,
        _connectivity = connectivity;

  final AppDatabase _db;
  final RemoteApiDataSource _remote;
  final ConnectivityWatcher _connectivity;
  final VoidCallback? onQueueChanged;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  /// Starts the listener and performs an initial flush.
  void start() {
    _flush();
    _sub = _connectivity.stream.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) _flush();
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  /// Replays all `pending` queue entries against the remote API.
  Future<void> _flush() async {
    List<Map<String, dynamic>> entries;
    try {
      entries = await _db.pendingWrites();
    } catch (_) {
      return; // DB not yet ready — skip silently
    }
    if (entries.isEmpty) return;

    for (final entry in entries) {
      final id = entry['id'] as int;
      final operation = entry['operation'] as String;
      final payload =
          jsonDecode(entry['payload'] as String) as Map<String, dynamic>;
      final retries = entry['retry_count'] as int;

      try {
        await _dispatch(operation, payload);
        await _db.markWriteSynced(id);
        onQueueChanged?.call();
      } catch (e) {
        // 404 / 409 → server conflict; mark immediately without retrying.
        final isConflict = e is DioException &&
            (e.response?.statusCode == 404 ||
                e.response?.statusCode == 409);
        if (isConflict) {
          await _db.markWriteConflict(id);
          log.w('[QueueSync] conflict op=$operation id=$id — marked conflict.', error: e);
        } else {
          final exceeded = retries + 1 >= _maxRetries;
          await _db.incrementWriteRetry(id, markFailed: exceeded);
          if (exceeded) {
            log.w(
              '[QueueSync] op=$operation id=$id failed after $_maxRetries attempts — marked failed.',
              error: e,
            );
          }
        }
        onQueueChanged?.call();
      }
    }
  }

  Future<void> _dispatch(
    String operation,
    Map<String, dynamic> payload,
  ) async {
    switch (operation) {
      case 'create_listing':
        await _remote.createProduct(payload);
      case 'update_listing':
        final id = payload['id'] as String;
        await _remote.updateProduct(id, payload);
      case 'delete_listing':
        final id = payload['id'] as String;
        await _remote.deleteProduct(id);
      default:
        throw UnsupportedError('Unknown queue operation: $operation');
    }
  }
}
