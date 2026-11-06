import 'package:aero_core/aero_core.dart';
import 'package:test/test.dart';

/// A scriptable adapter: each behaviour is a field so a test can describe
/// exactly the ecosystem shape it cares about.
class FakeAdapter implements EcosystemAdapter {
  FakeAdapter({
    this.healthError,
    this.rows = const [],
    this.browseItems = const [],
    this.searchItems = const [],
    this.links = const [],
    this.catalogsThrow,
    this.streamsThrow,
  });

  final String? healthError;
  final List<CatalogRow> rows;
  final List<MediaItem> browseItems;
  final List<MediaItem> searchItems;
  final List<StreamLink> links;
  final Object? catalogsThrow;
  final Object? streamsThrow;

  final calls = <String>[];

  @override
  Ecosystem get ecosystem => Ecosystem.vega;

  @override
  Set<Capability> get capabilities => const {
        Capability.catalogs,
        Capability.search,
        Capability.meta,
        Capability.streams,
      };

  @override
  bool get isAvailable => true;

  @override
  String? get unavailableReason => null;

  @override
  Future<Result<Duration>> healthCheck(String id) async {
    calls.add('health');
    return healthError != null
        ? Err(healthError!)
        : const Ok(Duration(milliseconds: 42));
  }

  @override
  Future<List<CatalogRow>> catalogs(String id) async {
    calls.add('catalogs');
    if (catalogsThrow != null) throw catalogsThrow!;
    return rows;
  }

  @override
  Future<Page<MediaItem>> browse(String id, String cid, CatalogQuery q) async {
    calls.add('browse:$cid');
    return Page(items: browseItems);
  }

  @override
  Future<Page<MediaItem>> search(String id, String q) async {
    calls.add('search:$q');
    return Page(items: searchItems);
  }

  @override
  Stream<StreamLink> streams(String id, PlayRequest req) async* {
    calls.add('streams:${req.ref.id}');
    if (streamsThrow != null) throw streamsThrow!;
    for (final l in links) {
      yield l;
    }
  }

  @override
  Future<List<InstalledSource>> installedSources() async => const [];
  @override
  Future<Result<InstalledSource>> install(SourceRef ref) async => const Err('x');
  @override
  Future<void> uninstall(String id) async {}
  @override
  Future<Result<InstalledSource>> checkUpdate(String id) async => const Err('x');
  @override
  Future<Result<MediaDetails>> details(String id, MediaRef ref) async =>
      const Err('x');
  @override
  Future<List<SubtitleTrack>> subtitles(String id, PlayRequest req) async =>
      const [];
  @override
  Future<void> dispose() async {}
}

InstalledSource sourceWith(Set<Capability> caps) => InstalledSource(
      id: 'demo',
      ecosystem: Ecosystem.vega,
      name: 'Demo',
      url: 'https://example.test',
      capabilities: caps,
    );

MediaItem item(String id, String title) => MediaItem(
      ref: MediaRef(id: id, type: MediaType.movie, title: title),
      title: title,
    );

const row = CatalogRow(
    sourceId: 'demo', catalogId: 'top', title: 'Top', type: MediaType.movie);

StreamLink link(String url) => StreamLink(
      url: url,
      sourceId: 'demo',
      sourceName: 'Demo',
      ecosystem: Ecosystem.vega,
    );

void main() {
  const all = {
    Capability.catalogs,
    Capability.search,
    Capability.meta,
    Capability.streams,
  };

  group('capability gating', () {
    test('a stream-only plugin skips home, browse and search', () async {
      final a = FakeAdapter();
      final r = await AdapterDiagnostics.run(a, sourceWith({Capability.streams}));
      final byName = {for (final s in r.steps) s.name: s};
      expect(byName['Reachable']!.status, DiagnosticStatus.pass);
      expect(byName['Catalogues']!.status, DiagnosticStatus.skipped);
      expect(byName['Browse']!.status, DiagnosticStatus.skipped);
      expect(byName['Search']!.status, DiagnosticStatus.skipped);
      expect(byName['Streams']!.status, DiagnosticStatus.skipped,
          reason: 'no title to resolve, which is not a stream failure');
      expect(r.ok, isTrue);
      expect(a.calls, ['health']);
    });

    test('a full plugin runs every step in order', () async {
      final a = FakeAdapter(
        rows: const [row],
        browseItems: [item('m1', 'Dune')],
        links: [link('https://cdn.test/a.mp4')],
      );
      final r = await AdapterDiagnostics.run(a, sourceWith(all));
      expect(r.steps.map((s) => s.name),
          ['Reachable', 'Catalogues', 'Browse', 'Search', 'Streams']);
      expect(a.calls,
          ['health', 'catalogs', 'browse:top', 'search:star', 'streams:m1']);
      expect(r.ok, isTrue);
    });

    test('a search hit is preferred over a catalogue poster for streams',
        () async {
      final a = FakeAdapter(
        rows: const [row],
        browseItems: [item('browse1', 'From Browse')],
        searchItems: [item('search1', 'From Search')],
        links: [link('https://cdn.test/a.mp4')],
      );
      await AdapterDiagnostics.run(a, sourceWith(all));
      expect(a.calls.last, 'streams:search1');
    });

    test('the catalogue item is used when search finds nothing', () async {
      final a = FakeAdapter(
        rows: const [row],
        browseItems: [item('browse1', 'From Browse')],
        links: [link('https://cdn.test/a.mp4')],
      );
      final r = await AdapterDiagnostics.run(a, sourceWith(all));
      expect(a.calls.last, 'streams:browse1');
      final search = r.steps.firstWhere((s) => s.name == 'Search');
      expect(search.status, DiagnosticStatus.warn);
    });
  });

  group('empty upstream does not cascade into false failures', () {
    test('no catalogues means Browse is skipped, not crashed', () async {
      final a = FakeAdapter(rows: const []);
      final r = await AdapterDiagnostics.run(a, sourceWith(all));
      final byName = {for (final s in r.steps) s.name: s};
      expect(byName['Catalogues']!.status, DiagnosticStatus.warn);
      expect(byName['Browse']!.status, DiagnosticStatus.skipped);
      expect(byName['Browse']!.detail, 'no catalogue to browse');
      expect(byName['Streams']!.status, DiagnosticStatus.skipped);
      expect(r.ok, isTrue, reason: 'an empty catalogue is not a broken plugin');
      expect(a.calls.contains('browse:top'), isFalse);
    });

    test('an empty browse and search leaves Streams skipped', () async {
      final a = FakeAdapter(rows: const [row]);
      final r = await AdapterDiagnostics.run(a, sourceWith(all));
      expect(r.steps.last.status, DiagnosticStatus.skipped);
      expect(r.steps.last.detail, 'no title available to resolve');
      expect(r.ok, isTrue);
    });
  });

  group('real failures are reported', () {
    test('an unreachable source fails at Reachable', () async {
      final a = FakeAdapter(healthError: 'SocketException: no route to host');
      final r = await AdapterDiagnostics.run(a, sourceWith(all));
      expect(r.ok, isFalse);
      expect(r.firstFailure!.name, 'Reachable');
      expect(r.failKind, FailKind.network);
    });

    test('catalogues that throw are a failure, not an empty result', () async {
      final a = FakeAdapter(catalogsThrow: Exception('HTTP 503'));
      final r = await AdapterDiagnostics.run(a, sourceWith(all));
      final cat = r.steps.firstWhere((s) => s.name == 'Catalogues');
      expect(cat.status, DiagnosticStatus.fail);
      expect(cat.failKind, FailKind.http5xx);
    });

    test('working search but broken streams points at Streams', () async {
      final a = FakeAdapter(
        rows: const [row],
        browseItems: [item('m1', 'Dune')],
        streamsThrow: Exception('type \'String\' is not a subtype'),
      );
      final r = await AdapterDiagnostics.run(a, sourceWith(all));
      expect(r.ok, isFalse);
      expect(r.firstFailure!.name, 'Streams');
      expect(r.failKind, FailKind.badShape);
      expect(r.summary, contains('Streams failed'));
    });

    test('later steps still run by default so the whole picture is visible',
        () async {
      final a = FakeAdapter(healthError: 'down', rows: const [row]);
      await AdapterDiagnostics.run(a, sourceWith(all));
      expect(a.calls, contains('catalogs'),
          reason: 'a failed ping should not hide a working catalogue');
    });
  });

  group('report identity', () {
    test('the report is keyed by ecosystem and source', () async {
      final r = await AdapterDiagnostics.run(FakeAdapter(), sourceWith(all));
      expect(r.sourceKey, 'vega:demo');
      expect(r.toText(), contains('vega:demo'));
    });

    test('the round-trip time is surfaced', () async {
      final r = await AdapterDiagnostics.run(FakeAdapter(), sourceWith(all));
      expect(r.steps.first.detail, contains('42 ms'));
    });
  });
}
