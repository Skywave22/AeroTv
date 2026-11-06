/// Cache abstraction the adapters can use without depending on a database.
library;

/// A cached value plus whether it has passed its TTL.
class CacheRead {
  const CacheRead(this.value, {required this.isStale});
  final Map<String, dynamic> value;
  final bool isStale;
  bool get isFresh => !isStale;
}

abstract interface class JsonCache {
  /// Reads [key], returning expired entries too (marked [CacheRead.isStale]).
  Future<CacheRead?> read(String key);
  Future<void> write(String key, Map<String, dynamic> value, {required Duration ttl});
  Future<void> delete(String key);
}

/// TTL policy from the Phase 1 plan (§4.5).
abstract final class CacheTtl {
  static const manifest = Duration(hours: 24);
  static const catalog = Duration(minutes: 15);
  static const meta = Duration(hours: 6);
  static const streams = Duration(minutes: 2);
  static const catalogMaxStale = Duration(hours: 24);
}

/// In-process cache. Used for stream links (never persisted) and in tests.
class MemoryJsonCache implements JsonCache {
  MemoryJsonCache({this.maxEntries = 256});
  final int maxEntries;
  final Map<String, _Entry> _entries = {};

  @override
  Future<CacheRead?> read(String key) async {
    final e = _entries[key];
    if (e == null) return null;
    final stale = DateTime.now().isAfter(e.expiresAt);
    _entries.remove(key);
    _entries[key] = e;
    return CacheRead(e.value, isStale: stale);
  }

  @override
  Future<void> write(String key, Map<String, dynamic> value, {required Duration ttl}) async {
    _entries.remove(key);
    _entries[key] = _Entry(value, DateTime.now().add(ttl));
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  @override
  Future<void> delete(String key) async => _entries.remove(key);

  void clear() => _entries.clear();
  int get length => _entries.length;
}

class _Entry {
  const _Entry(this.value, this.expiresAt);
  final Map<String, dynamic> value;
  final DateTime expiresAt;
}

/// Stable cache keys, centralised so a typo cannot silently split the cache.
abstract final class CacheKeys {
  static String manifest(String ecosystem, String sourceId) =>
      '$ecosystem:manifest:$sourceId';

  static String catalog(String ecosystem, String sourceId, String type,
      String catalogId, Map<String, String> extra) {
    final e = (extra.keys.toList()..sort()).map((k) => '$k=${extra[k]}').join('&');
    return '$ecosystem:catalog:$sourceId:$type:$catalogId:$e';
  }

  static String meta(String ecosystem, String sourceId, String type, String id) =>
      '$ecosystem:meta:$sourceId:$type:$id';
}
