import 'dart:convert';

import 'package:aero_core/aero_core.dart';


import '../db/database.dart';

/// TTL JSON cache for catalogs, metadata and resolved streams.
class CacheRepository implements JsonCache {
  CacheRepository(this.db);

  final AeroDatabase db;

  /// Fresh-only read. Expired rows are kept so [read] can serve them
  /// stale-while-revalidate; [prune] removes them in bulk.
  Future<Map<String, dynamic>?> get(String key) async {
    final hit = await read(key);
    if (hit == null || hit.isStale) return null;
    return hit.value;
  }

  @override
  Future<CacheRead?> read(String key) async {
    final rows = await (db.select(db.mediaCache)
          ..where((t) => t.key.equals(key))
          ..limit(1))
        .get();
    if (rows.isEmpty) return null;
    final row = rows.first;
    try {
      return CacheRead(
        Map<String, dynamic>.from(jsonDecode(row.json) as Map),
        isStale: row.expiresAt.isBefore(DateTime.now()),
      );
    } catch (_) {
      await delete(key);
      return null;
    }
  }

  @override
  Future<void> write(String key, Map<String, dynamic> value,
          {required Duration ttl}) =>
      put(key, value, ttl: ttl);

  Future<void> put(String key, Map<String, dynamic> value, {required Duration ttl}) async {
    await db.into(db.mediaCache).insertOnConflictUpdate(
          MediaCacheCompanion.insert(
            key: key,
            json: jsonEncode(value),
            expiresAt: DateTime.now().add(ttl),
          ),
        );
  }

  @override
  Future<void> delete(String key) async {
    await (db.delete(db.mediaCache)..where((t) => t.key.equals(key))).go();
  }

  Future<void> clear() => db.delete(db.mediaCache).go();

  Future<int> prune() => db.pruneCache();

  /// Read-through helper: returns cached data or computes and stores it.
  Future<Map<String, dynamic>> remember(
    String key, {
    required Duration ttl,
    required Future<Map<String, dynamic>> Function() compute,
  }) async {
    final hit = await get(key);
    if (hit != null) return hit;
    final fresh = await compute();
    await put(key, fresh, ttl: ttl);
    return fresh;
  }
}
