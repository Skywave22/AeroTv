import 'dart:async';

import 'package:aero_core/aero_core.dart';
import 'package:test/test.dart';

InstalledSource src(
  String id,
  Ecosystem eco, {
  bool enabled = true,
  int priority = 100,
  Set<Capability> caps = const {Capability.catalogs, Capability.streams},
}) =>
    InstalledSource(
      id: id,
      ecosystem: eco,
      name: id,
      url: 'https://example.test/$id',
      enabled: enabled,
      priority: priority,
      capabilities: caps,
    );

CatalogRow row(String catalogId, String title,
        {List<String> requiredExtras = const [], List<MediaItem> items = const []}) =>
    CatalogRow(
      sourceId: 's',
      catalogId: catalogId,
      title: title,
      type: MediaType.movie,
      requiredExtras: requiredExtras,
      items: items,
    );

MediaItem item(String id) => MediaItem(
      ref: MediaRef(id: id, type: MediaType.movie),
      title: id,
    );

void main() {
  group('eligibility', () {
    test('only merging ecosystems contribute to Home', () {
      final out = HomeComposer.eligibleSources([
        src('addon', Ecosystem.stremio),
        src('sky', Ecosystem.skystream),
        src('vega', Ecosystem.vega),
        src('cs', Ecosystem.cloudstream),
        src('nuvio', Ecosystem.nuvio),
      ]);
      expect(out.map((s) => s.id), ['addon'],
          reason: 'standalone providers are browsed, not flattened into Home');
    });

    test('the rule is a property, not a name check', () {
      expect(Ecosystem.stremio.mergesIntoHome, isTrue);
      for (final e in [Ecosystem.vega, Ecosystem.skystream, Ecosystem.cloudstream]) {
        expect(e.mergesIntoHome, isFalse);
        expect(e.isStandaloneProvider, isTrue);
      }
      expect(Ecosystem.nuvio.mergesIntoHome, isFalse);
      expect(Ecosystem.nuvio.isStandaloneProvider, isFalse,
          reason: 'Nuvio has no catalogues to browse either');
    });

    test('disabled sources are excluded', () {
      expect(
          HomeComposer.eligibleSources([src('off', Ecosystem.stremio, enabled: false)]),
          isEmpty);
    });

    test('a source without the catalogs capability is excluded', () {
      expect(
          HomeComposer.eligibleSources(
              [src('x', Ecosystem.stremio, caps: {Capability.streams})]),
          isEmpty);
    });

    test('an unavailable adapter is excluded', () {
      expect(
          HomeComposer.eligibleSources([src('a', Ecosystem.stremio)],
              unavailable: {Ecosystem.stremio}),
          isEmpty);
    });

    test('priority order is respected and capped', () {
      final out = HomeComposer.eligibleSources([
        src('c', Ecosystem.stremio, priority: 30),
        src('a', Ecosystem.stremio, priority: 10),
        src('b', Ecosystem.stremio, priority: 20),
      ], maxSources: 2);
      expect(out.map((s) => s.id), ['a', 'b']);
    });
  });

  group('composition', () {
    test('metadata rows come first and are marked as metadata', () async {
      final out = await HomeComposer.build(
        sources: [src('addon', Ecosystem.stremio)],
        metadataRows: [row('trending', 'Trending this week', items: [item('m1')])],
        catalogs: (_) async => [row('top', 'Top')],
        browse: (_, _) async => Page(items: [item('a1')]),
      );
      expect(out.first.title, 'Trending this week');
      expect(out.first.isMetadata, isTrue);
      expect(out.first.ecosystem, isNull);
      expect(out.first.subtitle, 'TMDB');
      expect(out.last.title, 'Top');
      expect(out.last.isMetadata, isFalse);
    });

    test('an empty metadata row is dropped', () async {
      final out = await HomeComposer.build(
        sources: const [],
        metadataRows: [row('empty', 'Nothing')],
        catalogs: (_) async => const [],
        browse: (_, _) async => Page.empty(),
      );
      expect(out, isEmpty);
    });

    test('Home works with metadata alone, no add-ons installed', () async {
      final out = await HomeComposer.build(
        sources: const [],
        metadataRows: [row('trending', 'Trending', items: [item('m1')])],
        catalogs: (_) async => const [],
        browse: (_, _) async => Page.empty(),
      );
      expect(out.length, 1);
    });

    test('Home works with add-ons alone, no TMDB key', () async {
      final out = await HomeComposer.build(
        sources: [src('addon', Ecosystem.stremio)],
        metadataRows: const [],
        catalogs: (_) async => [row('top', 'Top')],
        browse: (_, _) async => Page(items: [item('a1')]),
      );
      expect(out.length, 1);
      expect(out.single.ecosystem, Ecosystem.stremio);
    });

    test('one source\'s rows stay together and in catalogue order', () async {
      final out = await HomeComposer.build(
        sources: [
          src('a', Ecosystem.stremio, priority: 1),
          src('b', Ecosystem.stremio, priority: 2),
        ],
        metadataRows: const [],
        catalogs: (s) async => [
          row('${s.id}-1', '${s.id} first'),
          row('${s.id}-2', '${s.id} second'),
        ],
        browse: (s, c) async {
          // Make the second source finish first, so a naive implementation
          // would interleave.
          if (s.id == 'a') {
            await Future<void>.delayed(const Duration(milliseconds: 30));
          }
          return Page(items: [item(c)]);
        },
      );
      expect(out.map((r) => r.title),
          ['a first', 'a second', 'b first', 'b second']);
    });

    test('catalogues needing user input are not passive Home rows', () async {
      final out = await HomeComposer.build(
        sources: [src('a', Ecosystem.stremio)],
        metadataRows: const [],
        catalogs: (_) async => [
          row('search', 'Search', requiredExtras: ['search']),
          row('top', 'Top'),
        ],
        browse: (_, _) async => Page(items: [item('x')]),
      );
      expect(out.map((r) => r.title), ['Top']);
    });

    test('maxRowsPerSource caps a chatty add-on', () async {
      final out = await HomeComposer.build(
        sources: [src('a', Ecosystem.stremio)],
        metadataRows: const [],
        catalogs: (_) async => List.generate(10, (i) => row('c$i', 'C$i')),
        browse: (_, _) async => Page(items: [item('x')]),
        maxRowsPerSource: 2,
      );
      expect(out.length, 2);
    });
  });

  group('failure isolation', () {
    test('a source that throws is dropped, the others still render', () async {
      final out = await HomeComposer.build(
        sources: [
          src('bad', Ecosystem.stremio, priority: 1),
          src('good', Ecosystem.stremio, priority: 2),
        ],
        metadataRows: const [],
        catalogs: (s) async {
          if (s.id == 'bad') throw Exception('down');
          return [row('top', 'Good row')];
        },
        browse: (_, _) async => Page(items: [item('x')]),
      );
      expect(out.map((r) => r.title), ['Good row']);
    });

    test('a hanging source times out without stalling Home', () async {
      final out = await HomeComposer.build(
        sources: [
          src('slow', Ecosystem.stremio, priority: 1),
          src('fast', Ecosystem.stremio, priority: 2),
        ],
        metadataRows: const [],
        catalogs: (s) => s.id == 'slow'
            ? Completer<List<CatalogRow>>().future
            : Future.value([row('top', 'Fast row')]),
        browse: (_, _) async => Page(items: [item('x')]),
        timeout: const Duration(milliseconds: 60),
      );
      expect(out.map((r) => r.title), ['Fast row']);
    });

    test('one failing catalogue does not sink its source', () async {
      final out = await HomeComposer.build(
        sources: [src('a', Ecosystem.stremio)],
        metadataRows: const [],
        catalogs: (_) async => [row('bad', 'Bad'), row('ok', 'Ok')],
        browse: (_, c) async {
          if (c == 'bad') throw Exception('nope');
          return Page(items: [item('x')]);
        },
      );
      expect(out.map((r) => r.title), ['Ok']);
    });

    test('an empty catalogue is dropped', () async {
      final out = await HomeComposer.build(
        sources: [src('a', Ecosystem.stremio)],
        metadataRows: const [],
        catalogs: (_) async => [row('empty', 'Empty'), row('ok', 'Ok')],
        browse: (_, c) async =>
            c == 'empty' ? Page.empty() : Page(items: [item('x')]),
      );
      expect(out.map((r) => r.title), ['Ok']);
    });

    test('nothing installed and no key yields an empty feed, not an error',
        () async {
      final out = await HomeComposer.build(
        sources: const [],
        metadataRows: const [],
        catalogs: (_) async => const [],
        browse: (_, _) async => Page.empty(),
      );
      expect(out, isEmpty);
    });
  });
}
