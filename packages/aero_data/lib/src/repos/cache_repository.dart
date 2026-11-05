import 'dart:convert';


import '../db/database.dart';

/// TTL JSON cache for catalogs, metadata and resolved streams.
class CacheRepository {
  CacheRepository(this.db);

  final AeroDatabase db;

  Future<Map<String, dynamic>?> get(String key) async {
    final rows = await (db.select(db.mediaCache)
          ..where((t) => t.key.equals(key))
          ..limit(1))
        .get();
    if (rows.isEmpty) return null;
    final row = rows.first;
    if (row.expiresAt.isBefore(DateTime.now())) {
      await delete(key);
      return null;
    }
    try {
      return Map<String, dynamic>.from(jsonDecode(row.json) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> put(String key, Map<String, dynamic> value, {required Duration ttl}) async {
    await db.into(db.mediaCache).insertOnConflictUpdate(
          MediaCacheCompanion.insert(
            key: key,
            json: jsonEncode(value),
            expiresAt: DateTime.now().add(ttl),
          ),
        );
  }

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
