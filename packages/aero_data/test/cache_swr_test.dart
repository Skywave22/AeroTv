import 'package:aero_core/aero_core.dart';
import 'package:aero_data/aero_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AeroDatabase db;
  late CacheRepository cache;

  setUp(() async {
    db = AeroDatabase.memory();
    await db.select(db.profiles).get();
    cache = CacheRepository(db);
  });
  tearDown(() async => db.close());

  group('CacheRepository as a JsonCache', () {
    test('satisfies the adapter-facing interface', () {
      expect(cache, isA<JsonCache>());
    });

    test('a fresh write reads back fresh through both APIs', () async {
      await cache.write('k', {'v': 1}, ttl: const Duration(minutes: 5));
      expect((await cache.read('k'))!.isFresh, isTrue);
      expect((await cache.get('k'))!['v'], 1);
    });

    test('an expired entry is kept and marked stale, not deleted', () async {
      await cache.put('k', {'v': 1}, ttl: const Duration(milliseconds: -1));
      final hit = await cache.read('k');
      expect(hit, isNotNull);
      expect(hit!.isStale, isTrue);
      expect(hit.value['v'], 1);
      expect(await cache.get('k'), isNull);
      expect(await cache.read('k'), isNotNull);
    });

    test('a corrupt row is dropped instead of failing forever', () async {
      await db.into(db.mediaCache).insertOnConflictUpdate(
            MediaCacheCompanion.insert(
              key: 'bad', json: 'not json at all',
              expiresAt: DateTime.now().add(const Duration(hours: 1)),
            ),
          );
      expect(await cache.read('bad'), isNull);
      expect(await cache.read('bad'), isNull);
    });

    test('rewriting a key refreshes value and expiry', () async {
      await cache.put('k', {'v': 1}, ttl: const Duration(milliseconds: -1));
      expect((await cache.read('k'))!.isStale, isTrue);
      await cache.write('k', {'v': 2}, ttl: const Duration(minutes: 5));
      final hit = await cache.read('k');
      expect(hit!.isFresh, isTrue);
      expect(hit.value['v'], 2);
    });

    test('prune removes expired rows', () async {
      await cache.put('old', {'v': 1}, ttl: const Duration(milliseconds: -1));
      await cache.put('new', {'v': 2}, ttl: const Duration(minutes: 5));
      await cache.prune();
      expect(await cache.read('old'), isNull);
      expect(await cache.read('new'), isNotNull);
    });

    test('values are truly persisted in the table', () async {
      await cache.write('persisted', {'v': 42}, ttl: const Duration(hours: 1));
      final rows = await db.select(db.mediaCache).get();
      expect(rows.map((r) => r.key), contains('persisted'));
    });
  });
}
