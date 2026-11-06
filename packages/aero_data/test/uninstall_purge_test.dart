import 'package:aero_core/aero_core.dart';
import 'package:aero_data/aero_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AeroDatabase db;
  late SourceRepository sources;
  late CacheRepository cache;
  late PluginLogRepository logs;
  late MatchRepository matches;
  late HealthRepository health;

  const eco = Ecosystem.vega;

  Future<void> install(String id, {String? repoId}) => sources.save(
        InstalledSource(
          id: id,
          ecosystem: eco,
          name: id,
          url: 'https://example.test/$id',
          repoId: repoId,
        ),
      );

  /// Fills every store that belongs to `id`.
  Future<void> populate(String id) async {
    await cache.put(CacheKeys.manifest(eco.id, id), {'m': 1},
        ttl: const Duration(days: 1));
    await cache.put(CacheKeys.catalog(eco.id, id, 'movie', 'top', const {}),
        {'c': 1}, ttl: const Duration(days: 1));
    await cache.put(CacheKeys.meta(eco.id, id, 'movie', 'tt1'), {'d': 1},
        ttl: const Duration(days: 1));
    await cache.put('${eco.id}:streams:$id:tt1', {'s': 1},
        ttl: const Duration(days: 1));
    await logs.append('${eco.id}:$id', LogLevel.error, 't', 'boom');
    await matches.pin('${eco.id}:$id', 'movie:tt1',
        const TitleCandidate(title: 'Dune', link: '/dune'));
    await health.record('${eco.id}:$id', ok: false, error: 'down');
  }

  Future<void> expectGone(String id) async {
    expect(await cache.get(CacheKeys.manifest(eco.id, id)), isNull,
        reason: 'manifest');
    expect(
        await cache
            .get(CacheKeys.catalog(eco.id, id, 'movie', 'top', const {})),
        isNull,
        reason: 'catalog');
    expect(await cache.get(CacheKeys.meta(eco.id, id, 'movie', 'tt1')), isNull,
        reason: 'meta');
    expect(await cache.get('${eco.id}:streams:$id:tt1'), isNull,
        reason: 'streams');
    expect(await logs.forSource('${eco.id}:$id'), isEmpty, reason: 'logs');
    expect(await matches.lookup('${eco.id}:$id', 'movie:tt1'), isNull,
        reason: 'match decisions');
    expect(await health.get('${eco.id}:$id'), isNull, reason: 'health');
    expect((await sources.loadByEcosystem(eco)).map((s) => s.id),
        isNot(contains(id)),
        reason: 'source row');
  }

  setUp(() async {
    db = AeroDatabase.memory();
    await db.select(db.profiles).get();
    sources = SourceRepository(db);
    cache = CacheRepository(db);
    logs = PluginLogRepository(db);
    matches = MatchRepository(db);
    health = HealthRepository(db);
  });
  tearDown(() async => db.close());

  test('uninstall removes the source and everything it owned', () async {
    await install('gone');
    await populate('gone');
    await sources.delete(eco, 'gone');
    await expectGone('gone');
  });

  test('uninstall leaves another source completely untouched', () async {
    await install('gone');
    await install('kept');
    await populate('gone');
    await populate('kept');

    await sources.delete(eco, 'gone');

    expect(await cache.get(CacheKeys.manifest(eco.id, 'kept')), isNotNull);
    expect(await logs.forSource('${eco.id}:kept'), hasLength(1));
    expect(await matches.lookup('${eco.id}:kept', 'movie:tt1'), isNotNull);
    expect(await health.get('${eco.id}:kept'), isNotNull);
    expect((await sources.loadByEcosystem(eco)).map((s) => s.id), ['kept']);
  });

  test('a source id containing a colon does not over-delete', () async {
    // Stremio ids are derived from URLs and routinely contain separators.
    await install('a:b');
    await install('a:b:c');
    await populate('a:b');
    await populate('a:b:c');

    await sources.delete(eco, 'a:b');

    expect(await cache.get(CacheKeys.manifest(eco.id, 'a:b')), isNull);
    expect(await cache.get(CacheKeys.manifest(eco.id, 'a:b:c')), isNotNull,
        reason: 'the longer id must survive');
    expect(await logs.forSource('${eco.id}:a:b:c'), hasLength(1));
  });

  test('a LIKE wildcard inside an id is escaped, not interpreted', () async {
    await install('we%ird');
    await install('weXird');
    await populate('we%ird');
    await populate('weXird');

    await sources.delete(eco, 'we%ird');

    expect(await cache.get(CacheKeys.manifest(eco.id, 'we%ird')), isNull);
    expect(await cache.get(CacheKeys.manifest(eco.id, 'weXird')), isNotNull,
        reason: '% in an id must not match another source');
  });

  test('the same id in another ecosystem is not collateral damage', () async {
    await install('shared');
    await sources.save(InstalledSource(
        id: 'shared',
        ecosystem: Ecosystem.nuvio,
        name: 'shared',
        url: 'https://example.test/n'));
    await populate('shared');
    await cache.put(CacheKeys.manifest(Ecosystem.nuvio.id, 'shared'), {'n': 1},
        ttl: const Duration(days: 1));
    await logs.append('${Ecosystem.nuvio.id}:shared', LogLevel.info, 't', 'n');

    await sources.delete(eco, 'shared');

    expect(
        await cache.get(CacheKeys.manifest(Ecosystem.nuvio.id, 'shared')),
        isNotNull);
    expect(await logs.forSource('${Ecosystem.nuvio.id}:shared'), hasLength(1));
  });

  test('removing a repository purges its orphaned sources too', () async {
    await sources.saveRepository(Repository(
      id: 'repo1',
      ecosystem: eco,
      name: 'Repo',
      url: 'https://example.test/repo.json',
    ));
    await install('orphan', repoId: 'repo1');
    await populate('orphan');
    await install('standalone');
    await populate('standalone');

    await sources.deleteRepository(eco, 'repo1');

    await expectGone('orphan');
    expect(await cache.get(CacheKeys.manifest(eco.id, 'standalone')), isNotNull);
    expect(await logs.forSource('${eco.id}:standalone'), hasLength(1));
  });

  test('deleting an unknown source is a harmless no-op', () async {
    await install('kept');
    await populate('kept');
    await sources.delete(eco, 'never-existed');
    expect(await cache.get(CacheKeys.manifest(eco.id, 'kept')), isNotNull);
  });
}
