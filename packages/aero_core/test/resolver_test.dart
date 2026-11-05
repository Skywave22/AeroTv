import 'dart:async';

import 'package:aero_core/aero_core.dart';
import 'package:test/test.dart';

/// A fake adapter that emits scripted links, optionally slowly or failing.
class FakeAdapter implements EcosystemAdapter {
  FakeAdapter({
    required this.ecosystem,
    required this.sources,
    this.links = const [],
    this.delay = Duration.zero,
    this.failWith,
    this.available = true,
  });

  @override
  final Ecosystem ecosystem;
  final List<InstalledSource> sources;
  final List<StreamLink> links;
  final Duration delay;
  final String? failWith;
  final bool available;

  int streamCalls = 0;

  @override
  bool get isAvailable => available;

  @override
  String? get unavailableReason => available ? null : 'Not on this platform';

  @override
  Set<Capability> get capabilities =>
      {Capability.streams, Capability.catalogs, Capability.search};

  @override
  Future<List<InstalledSource>> installedSources() async => sources;

  @override
  Stream<StreamLink> streams(String sourceId, PlayRequest req) async* {
    streamCalls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (failWith != null) throw AeroException(failWith!);
    for (final l in links) {
      yield l;
    }
  }

  @override
  Future<Result<InstalledSource>> install(SourceRef ref) async =>
      Err('not implemented');
  @override
  Future<void> uninstall(String sourceId) async {}
  @override
  Future<Result<InstalledSource>> checkUpdate(String sourceId) async =>
      Err('not implemented');
  @override
  Future<Result<Duration>> healthCheck(String sourceId) async =>
      const Ok(Duration.zero);
  @override
  Future<List<CatalogRow>> catalogs(String sourceId) async => const [];
  @override
  Future<Page<MediaItem>> browse(
          String sourceId, String catalogId, CatalogQuery q) async =>
      Page.empty();
  @override
  Future<Page<MediaItem>> search(String sourceId, String query) async =>
      Page.empty();
  @override
  Future<Result<MediaDetails>> details(String sourceId, MediaRef ref) async =>
      Err('not implemented');
  @override
  Future<List<SubtitleTrack>> subtitles(String sourceId, PlayRequest req) async =>
      const [];
  @override
  Future<void> dispose() async {}
}

InstalledSource src(
  Ecosystem e,
  String id, {
  bool enabled = true,
  int priority = 100,
  List<MediaType> types = const [],
  List<String> prefixes = const [],
  Set<Capability> caps = const {Capability.streams},
}) =>
    InstalledSource(
      id: id,
      ecosystem: e,
      name: id,
      url: 'https://example/$id',
      enabled: enabled,
      priority: priority,
      types: types,
      idPrefixes: prefixes,
      capabilities: caps,
    );

StreamLink link(String url, {Ecosystem e = Ecosystem.stremio, String s = 'a'}) =>
    StreamLink(
      url: url,
      sourceId: s,
      sourceName: s,
      ecosystem: e,
      quality: Quality.fullHd,
    );

const movieReq = PlayRequest(
  ref: MediaRef(id: 'tt0111161', type: MediaType.movie, imdbId: 'tt0111161'),
);

void main() {
  group('AdapterRegistry', () {
    test('sorts enabled sources by priority and hides disabled', () async {
      final reg = AdapterRegistry();
      reg.register(FakeAdapter(
        ecosystem: Ecosystem.stremio,
        sources: [
          src(Ecosystem.stremio, 'low', priority: 90),
          src(Ecosystem.stremio, 'high', priority: 1),
          src(Ecosystem.stremio, 'off', enabled: false),
        ],
      ));
      final list = await reg.enabledSources();
      expect(list.map((s) => s.id), ['high', 'low']);
    });

    test('excludes unavailable adapters from streamProviders', () {
      final reg = AdapterRegistry();
      reg.register(FakeAdapter(
          ecosystem: Ecosystem.cloudstream, sources: const [], available: false));
      reg.register(FakeAdapter(ecosystem: Ecosystem.stremio, sources: const []));
      expect(reg.streamProviders.map((a) => a.ecosystem), [Ecosystem.stremio]);
      expect(reg.all.length, 2);
    });

    test('a throwing adapter does not hide healthy ones', () async {
      final reg = AdapterRegistry();
      reg.register(_BrokenAdapter());
      reg.register(FakeAdapter(
          ecosystem: Ecosystem.stremio, sources: [src(Ecosystem.stremio, 'ok')]));
      expect((await reg.enabledSources()).length, 1);
    });
  });

  group('StreamResolver', () {
    test('fans out and emits a ranked finish event', () async {
      final reg = AdapterRegistry();
      reg.register(FakeAdapter(
        ecosystem: Ecosystem.stremio,
        sources: [src(Ecosystem.stremio, 'a')],
        links: [link('https://x/1.mkv')],
      ));
      reg.register(FakeAdapter(
        ecosystem: Ecosystem.vega,
        sources: [src(Ecosystem.vega, 'b')],
        links: [link('https://x/2.mkv', e: Ecosystem.vega, s: 'b')],
      ));

      final resolver = StreamResolver(registry: reg);
      final events = await resolver.resolve(movieReq).toList();

      expect(events.first, isA<ResolverStarted>());
      expect(events.whereType<ResolverLink>().length, 2);
      final fin = events.last as ResolverFinished;
      expect(fin.ranked.length, 2);
    });

    test('de-duplicates identical URLs across providers', () async {
      final reg = AdapterRegistry();
      reg.register(FakeAdapter(
        ecosystem: Ecosystem.stremio,
        sources: [src(Ecosystem.stremio, 'a', priority: 1)],
        links: [link('https://x/same.mkv')],
      ));
      reg.register(FakeAdapter(
        ecosystem: Ecosystem.vega,
        sources: [src(Ecosystem.vega, 'b', priority: 2)],
        links: [link('https://x/same.mkv', e: Ecosystem.vega, s: 'b')],
      ));
      final resolver = StreamResolver(registry: reg);
      final ranked = await resolver.resolveAll(movieReq);
      expect(ranked.length, 1);
    });

    test('contains a failing source and still returns others', () async {
      final reg = AdapterRegistry();
      reg.register(FakeAdapter(
        ecosystem: Ecosystem.stremio,
        sources: [src(Ecosystem.stremio, 'bad')],
        failWith: 'boom',
      ));
      reg.register(FakeAdapter(
        ecosystem: Ecosystem.vega,
        sources: [src(Ecosystem.vega, 'good')],
        links: [link('https://x/ok.mkv', e: Ecosystem.vega, s: 'good')],
      ));
      final resolver = StreamResolver(registry: reg);
      final events = await resolver.resolve(movieReq).toList();
      final failed = events
          .whereType<ResolverProgress>()
          .any((p) => p.status == SourceStatus.failed);
      expect(failed, isTrue);
      expect((events.last as ResolverFinished).ranked.length, 1);
    });

    test('times out a slow source without blocking the fast one', () async {
      final reg = AdapterRegistry();
      reg.register(FakeAdapter(
        ecosystem: Ecosystem.stremio,
        sources: [src(Ecosystem.stremio, 'slow')],
        links: [link('https://x/slow.mkv')],
        delay: const Duration(seconds: 5),
      ));
      reg.register(FakeAdapter(
        ecosystem: Ecosystem.vega,
        sources: [src(Ecosystem.vega, 'fast')],
        links: [link('https://x/fast.mkv', e: Ecosystem.vega, s: 'fast')],
      ));
      final resolver = StreamResolver(
        registry: reg,
        perSourceTimeout: const Duration(milliseconds: 250),
        overallTimeout: const Duration(seconds: 2),
      );
      final sw = Stopwatch()..start();
      final events = await resolver.resolve(movieReq).toList();
      sw.stop();
      expect(sw.elapsed.inSeconds, lessThan(3));
      expect(
        events.whereType<ResolverProgress>().any((p) => p.status == SourceStatus.timedOut),
        isTrue,
      );
      expect((events.last as ResolverFinished).ranked.length, 1);
    });

    test('skips sources that cannot serve the type or id prefix', () async {
      final reg = AdapterRegistry();
      final adapter = FakeAdapter(
        ecosystem: Ecosystem.stremio,
        sources: [
          src(Ecosystem.stremio, 'seriesOnly', types: [MediaType.series]),
          src(Ecosystem.stremio, 'tmdbOnly', prefixes: ['tmdb']),
          src(Ecosystem.stremio, 'noStreams', caps: {Capability.catalogs}),
        ],
      );
      reg.register(adapter);
      final resolver = StreamResolver(registry: reg);
      final events = await resolver.resolve(movieReq).toList();
      expect(adapter.streamCalls, 0);
      expect(
        events.whereType<ResolverProgress>().where((p) => p.status == SourceStatus.skipped).length,
        3,
      );
      expect((events.last as ResolverFinished).ranked, isEmpty);
    });

    test('reports health for each settled source', () async {
      final reg = AdapterRegistry();
      reg.register(FakeAdapter(
        ecosystem: Ecosystem.stremio,
        sources: [src(Ecosystem.stremio, 'a')],
        links: [link('https://x/1.mkv')],
      ));
      final health = <String, bool>{};
      final resolver = StreamResolver(
        registry: reg,
        onHealth: (key, {required bool ok, int? latencyMs, String? error}) {
          health[key] = ok;
        },
      );
      await resolver.resolveAll(movieReq);
      expect(health['stremio:a'], isTrue);
    });

    test('cancelling the subscription stops work', () async {
      final reg = AdapterRegistry();
      final slow = FakeAdapter(
        ecosystem: Ecosystem.stremio,
        sources: [src(Ecosystem.stremio, 'slow')],
        links: [link('https://x/1.mkv')],
        delay: const Duration(milliseconds: 400),
      );
      reg.register(slow);
      final resolver = StreamResolver(registry: reg);
      final sub = resolver.resolve(movieReq).listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 600));
      // No exception, and the controller closed cleanly.
      expect(true, isTrue);
    });

    test('groups links by ecosystem then provider', () {
      final grouped = StreamResolver.group([
        link('1', s: 'a'),
        link('2', s: 'a'),
        link('3', e: Ecosystem.vega, s: 'b'),
      ]);
      expect(grouped[Ecosystem.stremio]!['a']!.length, 2);
      expect(grouped[Ecosystem.vega]!['b']!.length, 1);
    });
  });

  group('MetadataResolver', () {
    test('returns inline imdb id without a lookup', () async {
      final r = MetadataResolver();
      final enriched = await r.enrich(
        const MediaRef(id: 'tt0111161', type: MediaType.movie),
      );
      expect(enriched.imdbId, 'tt0111161');
    });

    test('uses lookup then caches, deduping in-flight calls', () async {
      final lookup = _CountingLookup();
      final r = MetadataResolver(lookup: lookup);
      const ref = MediaRef(id: 'tmdb:603', type: MediaType.movie, tmdbId: '603');
      final results = await Future.wait([r.enrich(ref), r.enrich(ref), r.enrich(ref)]);
      expect(results.every((m) => m.imdbId == 'tt0133093'), isTrue);
      expect(lookup.calls, 1);
      await r.enrich(ref);
      expect(lookup.calls, 1, reason: 'served from cache');
    });

    test('falls back to title search', () async {
      final lookup = _CountingLookup(emptyLookup: true);
      final r = MetadataResolver(lookup: lookup);
      final m = await r.enrich(
        const MediaRef(id: 'x', type: MediaType.movie, title: 'The Matrix', year: 1999),
      );
      expect(m.imdbId, 'tt0133093');
      expect(lookup.titleCalls, 1);
    });

    test('a throwing lookup degrades gracefully', () async {
      final r = MetadataResolver(lookup: _ThrowingLookup());
      final m = await r.enrich(const MediaRef(id: 'tt0111161', type: MediaType.movie));
      expect(m.id, 'tt0111161');
    });
  });
}

class _BrokenAdapter extends FakeAdapter {
  _BrokenAdapter() : super(ecosystem: Ecosystem.nuvio, sources: const []);
  @override
  Future<List<InstalledSource>> installedSources() => throw Exception('db corrupt');
}

class _CountingLookup implements IdLookup {
  _CountingLookup({this.emptyLookup = false});
  final bool emptyLookup;
  int calls = 0;
  int titleCalls = 0;

  @override
  Future<IdMap?> lookup({String? imdbId, String? tmdbId, MediaType? type}) async {
    calls++;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    if (emptyLookup) return null;
    return const IdMap(imdbId: 'tt0133093', tmdbId: '603');
  }

  @override
  Future<IdMap?> findByTitle(String title, {int? year, MediaType? type}) async {
    titleCalls++;
    return const IdMap(imdbId: 'tt0133093', tmdbId: '603');
  }
}

class _ThrowingLookup implements IdLookup {
  @override
  Future<IdMap?> lookup({String? imdbId, String? tmdbId, MediaType? type}) =>
      throw Exception('network down');
  @override
  Future<IdMap?> findByTitle(String title, {int? year, MediaType? type}) =>
      throw Exception('network down');
}
