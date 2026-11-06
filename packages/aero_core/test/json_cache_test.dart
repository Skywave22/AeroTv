import 'package:aero_core/aero_core.dart';
import 'package:test/test.dart';

void main() {
  group('MemoryJsonCache', () {
    test('returns null for a missing key', () async {
      expect(await MemoryJsonCache().read('nope'), isNull);
    });

    test('a fresh write reads back fresh', () async {
      final c = MemoryJsonCache();
      await c.write('k', {'v': 1}, ttl: const Duration(minutes: 5));
      final hit = await c.read('k');
      expect(hit!.value['v'], 1);
      expect(hit.isFresh, isTrue);
      expect(hit.isStale, isFalse);
    });

    test('an expired entry is still readable, marked stale', () async {
      final c = MemoryJsonCache();
      await c.write('k', {'v': 1}, ttl: const Duration(milliseconds: -1));
      final hit = await c.read('k');
      expect(hit, isNotNull);
      expect(hit!.isStale, isTrue);
      expect(hit.value['v'], 1);
    });

    test('delete removes the entry entirely', () async {
      final c = MemoryJsonCache();
      await c.write('k', {'v': 1}, ttl: const Duration(minutes: 5));
      await c.delete('k');
      expect(await c.read('k'), isNull);
    });

    test('evicts least-recently-used beyond maxEntries', () async {
      final c = MemoryJsonCache(maxEntries: 2);
      await c.write('a', {'v': 1}, ttl: const Duration(minutes: 5));
      await c.write('b', {'v': 2}, ttl: const Duration(minutes: 5));
      await c.read('a');
      await c.write('c', {'v': 3}, ttl: const Duration(minutes: 5));
      expect(c.length, 2);
      expect(await c.read('b'), isNull);
      expect(await c.read('a'), isNotNull);
      expect(await c.read('c'), isNotNull);
    });

    test('rewriting a key does not grow the cache', () async {
      final c = MemoryJsonCache(maxEntries: 2);
      await c.write('a', {'v': 1}, ttl: const Duration(minutes: 5));
      await c.write('a', {'v': 2}, ttl: const Duration(minutes: 5));
      expect(c.length, 1);
      expect((await c.read('a'))!.value['v'], 2);
    });
  });

  group('CacheKeys', () {
    test('are stable regardless of extra ordering', () {
      expect(
        CacheKeys.catalog('stremio', 's', 'movie', 'top', {'genre': 'Action', 'skip': '100'}),
        CacheKeys.catalog('stremio', 's', 'movie', 'top', {'skip': '100', 'genre': 'Action'}),
      );
    });

    test('distinguish sources, types and catalogs', () {
      String k(String s, String t, String i) => CacheKeys.catalog('stremio', s, t, i, const {});
      expect(k('s1', 'movie', 'top'), isNot(k('s2', 'movie', 'top')));
      expect(k('s1', 'movie', 'top'), isNot(k('s1', 'series', 'top')));
      expect(k('s1', 'movie', 'top'), isNot(k('s1', 'movie', 'popular')));
    });

    test('distinguish ecosystems', () {
      expect(CacheKeys.manifest('stremio', 'abc'), isNot(CacheKeys.manifest('vega', 'abc')));
    });

    test('meta keys include the id', () {
      expect(CacheKeys.meta('stremio', 's', 'movie', 'tt1'),
          isNot(CacheKeys.meta('stremio', 's', 'movie', 'tt2')));
    });
  });

  group('CacheTtl policy', () {
    test('matches the documented Phase 1 policy', () {
      expect(CacheTtl.manifest, const Duration(hours: 24));
      expect(CacheTtl.catalog, const Duration(minutes: 15));
      expect(CacheTtl.meta, const Duration(hours: 6));
      expect(CacheTtl.streams, const Duration(minutes: 2));
    });

    test('streams expire long before catalogs', () {
      expect(CacheTtl.streams < CacheTtl.catalog, isTrue);
      expect(CacheTtl.catalog < CacheTtl.meta, isTrue);
      expect(CacheTtl.meta < CacheTtl.manifest, isTrue);
    });
  });
}
