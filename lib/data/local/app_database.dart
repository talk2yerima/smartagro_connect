import 'dart:convert';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Local SQLite cache for offline-first marketplace reads.
class AppDatabase {
  Database? _db;

  Future<void> open() async {
    if (_db != null) return;
    final isDesktop = defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS;
    if (isDesktop) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'smartagro.db');
    _db = await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE commodity_cache (
  id TEXT PRIMARY KEY,
  payload TEXT NOT NULL,
  updated_at INTEGER NOT NULL
);''');
        await db.execute(
            'CREATE INDEX idx_commodity_updated ON commodity_cache(updated_at DESC);');
        await db.execute('''
CREATE TABLE product_cache (
  id TEXT PRIMARY KEY,
  payload TEXT NOT NULL,
  updated_at INTEGER NOT NULL
);''');
        await db.execute(
            'CREATE INDEX idx_product_updated ON product_cache(updated_at DESC);');
        await db.execute('''
CREATE TABLE meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);''');
        await _createWriteQueueTable(db);
        await _createWriteQueueIndexes(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createWriteQueueTable(db);
        }
        if (oldVersion < 3) {
          await _createWriteQueueIndexes(db);
          // Best-effort index creation — tables may already exist on upgrade path
          try {
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_commodity_updated ON commodity_cache(updated_at DESC);');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_product_updated ON product_cache(updated_at DESC);');
          } catch (_) {}
        }
      },
    );
  }

  Future<void> upsertCommodities(List<Map<String, dynamic>> rows) async {
    final db = _db!;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final r in rows) {
      batch.insert(
        'commodity_cache',
        {
          'id': r['id'],
          'payload': jsonEncode(r),
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> readCommodities({
    int? limit,
    int offset = 0,
  }) async {
    final db = _db!;
    final maps = await db.query(
      'commodity_cache',
      orderBy: 'updated_at DESC',
      limit: limit,
      offset: offset > 0 ? offset : null,
    );
    return maps
        .map((m) => jsonDecode(m['payload'] as String) as Map<String, dynamic>)
        .toList();
  }

  Future<void> upsertProducts(List<Map<String, dynamic>> rows) async {
    final db = _db!;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final r in rows) {
      batch.insert(
        'product_cache',
        {
          'id': r['id'],
          'payload': jsonEncode(r),
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> readProducts({
    int? limit,
    int offset = 0,
  }) async {
    final db = _db!;
    final maps = await db.query(
      'product_cache',
      orderBy: 'updated_at DESC',
      limit: limit,
      offset: offset > 0 ? offset : null,
    );
    return maps
        .map((m) => jsonDecode(m['payload'] as String) as Map<String, dynamic>)
        .toList();
  }

  // ── Write queue ─────────────────────────────────────────────────────────────

  static Future<void> _createWriteQueueTable(Database db) async {
    await db.execute('''
CREATE TABLE write_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  operation TEXT NOT NULL,
  payload TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  retry_count INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending'
);''');
  }

  static Future<void> _createWriteQueueIndexes(Database db) async {
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_wq_status_created ON write_queue(status, created_at ASC);');
  }

  Future<void> enqueueWrite({
    required String operation,
    required String payload,
  }) async {
    await _db!.insert('write_queue', {
      'operation': operation,
      'payload': payload,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'retry_count': 0,
      'status': 'pending',
    });
  }

  Future<List<Map<String, dynamic>>> pendingWrites() async {
    return _db!.query(
      'write_queue',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at ASC',
    );
  }

  Future<void> markWriteSynced(int id) async {
    await _db!.delete('write_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> incrementWriteRetry(int id, {required bool markFailed}) async {
    final entry = await _db!
        .query('write_queue', where: 'id = ?', whereArgs: [id]);
    if (entry.isEmpty) return;
    final retries = (entry.first['retry_count'] as int) + 1;
    await _db!.update(
      'write_queue',
      {
        'retry_count': retries,
        'status': markFailed ? 'failed' : 'pending',
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
