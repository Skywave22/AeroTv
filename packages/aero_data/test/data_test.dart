import 'package:aero_core/aero_core.dart';
import 'package:aero_data/aero_data.dart';
import 'package:flutter_test/flutter_test.dart';

MediaItem item(String id, {String title = 'Title', MediaType type = MediaType.movie}) =>
    MediaItem(
      ref: MediaRef(id: id, type: type, imdbId: id.startsWith('tt') ? id : null),
      title: title,
      poster: 'https://p/$id.jpg',
    );

void main() {
  late AeroDatabase db;
  late SourceRepository sources;
  late SettingsRepository settings;
  late LibraryRepository library;
  late HistoryRepository history;
  late HealthRepository health;
  late CacheRepository cache;

  setUp(() async {
    db = AeroDatabase.memory();
    // Trigger onCreate so the default profile exists.
    await db.select(db.profiles).get();
    sources = SourceRepository(db);
    settings = SettingsRepository(db);
    await settings.load();
    library = LibraryRepository(db);
    history = HistoryRepository(db);
    health = HealthRepository(db);
    cache = CacheRepository(db);
  });

  tearDown(() async => db.close());

  group('SourceRepository', () {
    test('saves and reloads a source with all manifest metadata', () async {
      const s = InstalledSource(
        id: 'org.x',
        ecosystem: Ecosystem.stremio,
        name: 'X',
        url: 'https://x/manifest.json',
        version: '2.0.0',
        capabilities: {Capability.streams, Capability.catalogs},
        types: [MediaType.movie, MediaType.series],
        idPrefixes: ['tt'],
        catalogs: [CatalogDescriptor(id: 'top', type: MediaType.movie, name: 'Top')],
        config: {'debrid': 'rd'},
        priority: 20,
      );
      await sources.save(s);
      final loaded = await sources.loadByEcosystem(Ecosystem.stremio);
      expect(loaded.length, 1);
      final got = loaded.first;
      expect(got.name, 'X');
      expect(got.version, '2.0.0');
      expect(got.capabilities, s.capabilities);
      expect(got.types, s.types);
      expect(got.idPrefixes, ['tt']);
      expect(got.catalogs.single.name, 'Top');
      expect(got.config['debrid'], 'rd');
      expect(got.priority, 20);
    });

    test('same id in different ecosystems coexists', () async {
      for (final e in [Ecosystem.stremio, Ecosystem.vega]) {
        await sources.save(InstalledSource(
          id: 'shared', ecosystem: e, name: e.displayName, url: 'https://x',
        ));
      }
      expect((await sources.loadAll()).length, 2);
      expect((await sources.loadByEcosystem(Ecosystem.vega)).single.name, 'Vega');
    });

    test('upsert does not duplicate', () async {
      const s = InstalledSource(
          id: 'a', ecosystem: Ecosystem.stremio, name: 'One', url: 'https://x');
      await sources.save(s);
      await sources.save(s.copyWith(name: 'Two', version: '9.9.9'));
      final all = await sources.loadAll();
      expect(all.length, 1);
      expect(all.single.name, 'Two');
      expect(all.single.version, '9.9.9');
    });

    test('enable/disable and reorder', () async {
      for (final id in ['a', 'b', 'c']) {
        await sources.save(InstalledSource(
          id: id, ecosystem: Ecosystem.stremio, name: id, url: 'https://x',
          priority: id.codeUnitAt(0),
        ));
      }
      await sources.setEnabled(Ecosystem.stremio, 'b', false);
      await sources.reorder(['stremio:c', 'stremio:a', 'stremio:b']);
      final all = await sources.loadAll();
      expect(all.map((s) => s.id), ['c', 'a', 'b']);
      expect(all.first.priority, 10);
      expect(all.where((s) => s.id == 'b').single.enabled, isFalse);
    });

    test('delete removes only the targeted ecosystem entry', () async {
      for (final e in [Ecosystem.stremio, Ecosystem.nuvio]) {
        await sources.save(InstalledSource(
            id: 'dup', ecosystem: e, name: 'n', url: 'https://x'));
      }
      await sources.delete(Ecosystem.stremio, 'dup');
      final left = await sources.loadAll();
      expect(left.single.ecosystem, Ecosystem.nuvio);
    });

    test('deleting a repo removes its sources', () async {
      await sources.saveRepository(const Repository(
        id: 'r1', ecosystem: Ecosystem.vega, url: 'https://repo', name: 'Repo',
      ));
      await sources.save(const InstalledSource(
        id: 'p1', ecosystem: Ecosystem.vega, name: 'P', url: 'https://p', repoId: 'r1',
      ));
      await sources.deleteRepository(Ecosystem.vega, 'r1');
      expect(await sources.loadRepositories(), isEmpty);
      expect(await sources.loadAll(), isEmpty);
    });
  });

  group('LibraryRepository', () {
    test('add, contains, toggle, remove', () async {
      final m = item('tt0111161', title: 'Shawshank');
      await library.add(m, LibraryLists.watchlist);
      expect(await library.contains(m.ref.cacheKey, LibraryLists.watchlist), isTrue);
      expect((await library.list(LibraryLists.watchlist)).single.title, 'Shawshank');

      await library.toggle(m, LibraryLists.watchlist);
      expect(await library.contains(m.ref.cacheKey, LibraryLists.watchlist), isFalse);

      await library.toggle(m, LibraryLists.favorites);
      expect((await library.list(LibraryLists.favorites)).length, 1);
      expect(await library.list(LibraryLists.watchlist), isEmpty);
    });

    test('watch stream emits on change', () async {
      final stream = library.watch(LibraryLists.watchlist);
      final future = stream.skip(1).first;
      await library.add(item('tt1'), LibraryLists.watchlist);
      expect((await future).length, 1);
    });
  });

  group('HistoryRepository', () {
    test('records and reads a resume point', () async {
      await history.record(
        item: item('tt0111161'),
        positionMs: 120000,
        durationMs: 600000,
      );
      final r = await history.resumePoint('imdb:tt0111161');
      expect(r, isNotNull);
      expect(r!.positionMs, 120000);
      expect(r.progress, closeTo(0.2, 0.001));
      expect(r.isResumable, isTrue);
      expect(r.isFinished, isFalse);
    });

    test('continue watching excludes finished and barely-started items', () async {
      await history.record(
          item: item('tt1'), positionMs: 500000, durationMs: 600000); // 83% - keep
      await history.record(
          item: item('tt2'), positionMs: 590000, durationMs: 600000); // 98% - finished
      await history.record(
          item: item('tt3'), positionMs: 5000, durationMs: 600000); // too early
      final cw = await history.continueWatching();
      expect(cw.map((e) => e.item.id), ['tt1']);
    });

    test('one card per series, most recent episode wins', () async {
      final show = item('tt0944947', type: MediaType.series, title: 'GoT');
      await history.record(
          item: show, positionMs: 100000, durationMs: 3000000, season: 1, episode: 1);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await history.record(
          item: show, positionMs: 100000, durationMs: 3000000, season: 1, episode: 2);
      final cw = await history.continueWatching();
      expect(cw.length, 1);
      expect(cw.single.episode, 2);
      expect(cw.single.episodeLabel, 'S01E02');
    });

    test('same-second writes still order correctly (regression)', () async {
      // Drift used to store DateTime as Unix *seconds*, so these two writes
      // tied and ORDER BY updated_at DESC returned E01. No artificial delay
      // here on purpose — that is the whole point of the regression.
      final show = item('tt9999999', type: MediaType.series, title: 'Fast');
      await history.record(
          item: show, positionMs: 100000, durationMs: 3000000, season: 2, episode: 1);
      await history.record(
          item: show, positionMs: 100000, durationMs: 3000000, season: 2, episode: 2);
      await history.record(
          item: show, positionMs: 100000, durationMs: 3000000, season: 2, episode: 3);
      final cw = await history.continueWatching();
      expect(cw.single.episode, 3);
      expect(cw.single.episodeLabel, 'S02E03');
    });

    test('clear wipes history', () async {
      await history.record(item: item('tt1'), positionMs: 90000, durationMs: 600000);
      await history.clear();
      expect(await history.all(), isEmpty);
    });
  });

  group('HealthRepository', () {
    test('accumulates counters and computes latency average', () async {
      await health.record('stremio:a', ok: true, latencyMs: 100);
      await health.record('stremio:a', ok: true, latencyMs: 200);
      final h = await health.get('stremio:a');
      expect(h!.successCount, 2);
      expect(h.failCount, 0);
      expect(h.avgLatencyMs, greaterThan(100));
      expect(h.successRate, 1.0);
      expect(h.isFlaky, isFalse);
    });

    test('flags a repeatedly failing provider as flaky', () async {
      for (var i = 0; i < 6; i++) {
        await health.record('vega:bad', ok: false, error: 'timeout');
      }
      final h = await health.get('vega:bad');
      expect(h!.isFlaky, isTrue);
      expect(await health.flakyKeys(), contains('vega:bad'));
      expect(h.lastError, 'timeout');
    });

    test('reset clears counters', () async {
      await health.record('x:y', ok: false);
      await health.reset('x:y');
      expect(await health.get('x:y'), isNull);
    });
  });

  group('CacheRepository', () {
    test('put/get round-trip', () async {
      await cache.put('k', {'a': 1}, ttl: const Duration(minutes: 5));
      expect((await cache.get('k'))!['a'], 1);
    });

    test('expired entries are not returned', () async {
      await cache.put('k', {'a': 1}, ttl: const Duration(milliseconds: -1));
      expect(await cache.get('k'), isNull);
    });

    test('remember computes once then serves cache', () async {
      var calls = 0;
      Future<Map<String, dynamic>> compute() async {
        calls++;
        return {'n': calls};
      }
      final a = await cache.remember('k', ttl: const Duration(minutes: 1), compute: compute);
      final b = await cache.remember('k', ttl: const Duration(minutes: 1), compute: compute);
      expect(a['n'], 1);
      expect(b['n'], 1);
      expect(calls, 1);
    });
  });

  group('SettingsRepository', () {
    test('defaults are sane', () {
      expect(settings.player.resumePlayback, isTrue);
      expect(settings.player.defaultSubtitleLang, 'en');
      expect(settings.ui.enableBlur, isTrue);
      expect(settings.ranking.preferredQuality, Quality.fullHd);
      expect(settings.telemetryOptIn, isFalse, reason: 'must be opt-in');
      expect(settings.hasOnboarded, isFalse);
    });

    test('persists and reloads from disk', () async {
      await settings.setPlayer(settings.player.copyWith(subtitleSize: 1.4));
      await settings.setRanking(settings.ranking.copyWith(preferredQuality: Quality.uhd));
      await settings.setTmdbApiKey('secret');
      await settings.setOnboarded();

      final fresh = SettingsRepository(db);
      await fresh.load();
      expect(fresh.player.subtitleSize, 1.4);
      expect(fresh.ranking.preferredQuality, Quality.uhd);
      expect(fresh.tmdbApiKey, 'secret');
      expect(fresh.hasOnboarded, isTrue);
    });
  });

  group('BackupService', () {
    late BackupService backup;
    setUp(() {
      backup = BackupService(
          db: db, sources: sources, settings: settings, library: library);
    });

    test('exports then restores into a fresh database', () async {
      await sources.save(const InstalledSource(
        id: 'org.x', ecosystem: Ecosystem.stremio, name: 'X', url: 'https://x/manifest.json',
        capabilities: {Capability.streams},
      ));
      await library.add(item('tt0111161', title: 'Shawshank'), LibraryLists.watchlist);
      await settings.setPlayer(settings.player.copyWith(subtitleSize: 1.3));

      final text = await backup.export();

      final db2 = AeroDatabase.memory();
      await db2.select(db2.profiles).get();
      final sources2 = SourceRepository(db2);
      final settings2 = SettingsRepository(db2);
      await settings2.load();
      final backup2 = BackupService(
        db: db2,
        sources: sources2,
        settings: settings2,
        library: LibraryRepository(db2),
      );
      final summary = await backup2.import(text);

      expect(summary, contains('1 source'));
      expect((await sources2.loadAll()).single.id, 'org.x');
      expect((await sources2.loadAll()).single.capabilities, {Capability.streams});
      expect(settings2.player.subtitleSize, 1.3);
      expect((await LibraryRepository(db2).list(LibraryLists.watchlist)).single.title,
          'Shawshank');
      await db2.close();
    });

    test('rejects invalid input with helpful errors', () async {
      expect(() => backup.import('not json'), throwsA(isA<AeroException>()));
      expect(() => backup.import('[]'), throwsA(isA<AeroException>()));
      expect(() => backup.import('{}'), throwsA(isA<AeroException>()));
      expect(
        () => backup.import('{"aeroBackupVersion": 99}'),
        throwsA(isA<AeroException>()),
      );
    });

    test('skips entries with unknown ecosystems', () async {
      const text = '{"aeroBackupVersion":1,"sources":'
          '[{"id":"a","ecosystem":"bogus","name":"n","url":"https://x"}]}';
      final summary = await backup.import(text);
      expect(summary, contains('0 source'));
      expect(await sources.loadAll(), isEmpty);
    });
  });

  group('TmdbIdLookup', () {
    test('is inert without an API key', () async {
      final lookup = TmdbIdLookup(db: db, apiKey: '');
      expect(lookup.isConfigured, isFalse);
      expect(await lookup.lookup(imdbId: 'tt0111161'), isNull);
      expect(await lookup.findByTitle('Matrix'), isNull);
    });
  });
}
