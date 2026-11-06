import 'package:aero_core/aero_core.dart';
import 'package:test/test.dart';

InstalledSource src(String id, Ecosystem eco,
        {bool enabled = true,
        int priority = 100,
        Set<Capability> caps = const {Capability.catalogs}}) =>
    InstalledSource(
      id: id,
      ecosystem: eco,
      name: id,
      url: 'https://example.test/$id',
      enabled: enabled,
      priority: priority,
      capabilities: caps,
    );

void main() {
  group('sections', () {
    test('SkyStream comes first, then Vega, then CloudStream', () {
      final sections = ProviderDirectory.build(const []);
      expect(sections.take(3).map((s) => s.ecosystem),
          [Ecosystem.skystream, Ecosystem.vega, Ecosystem.cloudstream]);
    });

    test('every ecosystem gets a section, even with nothing installed', () {
      final sections = ProviderDirectory.build(const []);
      expect(sections.map((s) => s.ecosystem).toSet(), Ecosystem.values.toSet());
      expect(sections.every((s) => s.isEmpty), isTrue);
    });

    test('includeEmpty hides empty sections but keeps the beta one', () {
      final sections =
          ProviderDirectory.build(const [], includeEmpty: false);
      expect(sections.map((s) => s.ecosystem), [Ecosystem.cloudstream],
          reason: 'a beta section is the announcement, so it stays');
    });

    test('sources land in their own ecosystem section', () {
      final sections = ProviderDirectory.build([
        src('sky1', Ecosystem.skystream),
        src('vega1', Ecosystem.vega),
        src('addon1', Ecosystem.stremio),
        src('scraper1', Ecosystem.nuvio, caps: {Capability.streams}),
      ]);
      final by = {for (final s in sections) s.ecosystem: s};
      expect(by[Ecosystem.skystream]!.sources.map((s) => s.id), ['sky1']);
      expect(by[Ecosystem.vega]!.sources.map((s) => s.id), ['vega1']);
      expect(by[Ecosystem.stremio]!.sources.map((s) => s.id), ['addon1']);
      expect(by[Ecosystem.nuvio]!.sources.map((s) => s.id), ['scraper1']);
      expect(by[Ecosystem.cloudstream]!.isEmpty, isTrue);
    });

    test('enabled providers sort above disabled ones, then by priority', () {
      final sections = ProviderDirectory.build([
        src('off', Ecosystem.vega, enabled: false, priority: 1),
        src('b', Ecosystem.vega, priority: 20),
        src('a', Ecosystem.vega, priority: 10),
      ]);
      final vega =
          sections.firstWhere((s) => s.ecosystem == Ecosystem.vega);
      expect(vega.sources.map((s) => s.id), ['a', 'b', 'off']);
    });
  });

  group('gating', () {
    test('CloudStream is beta: shown, not openable', () {
      final sections = ProviderDirectory.build([
        src('cs', Ecosystem.cloudstream),
      ]);
      final cs =
          sections.firstWhere((s) => s.ecosystem == Ecosystem.cloudstream);
      expect(cs.isBeta, isTrue);
      expect(cs.isOpenable, isFalse);
      expect(cs.note, 'Beta soon');
      expect(cs.sources, hasLength(1),
          reason: 'an installed entry is still listed, just not openable');
    });

    test('canOpen refuses a beta source', () {
      expect(ProviderDirectory.canOpen(src('cs', Ecosystem.cloudstream)),
          isFalse);
    });

    test('Nuvio is streams-only and explains itself', () {
      final sections = ProviderDirectory.build([
        src('n', Ecosystem.nuvio, caps: {Capability.streams}),
      ]);
      final nuvio =
          sections.firstWhere((s) => s.ecosystem == Ecosystem.nuvio);
      expect(nuvio.isStreamsOnly, isTrue);
      expect(nuvio.isOpenable, isFalse);
      expect(nuvio.note, contains('Streams only'));
      expect(nuvio.note, contains('TMDB'));
    });

    test('SkyStream and Vega are openable', () {
      for (final eco in [Ecosystem.skystream, Ecosystem.vega]) {
        final sections = ProviderDirectory.build([src('x', eco)]);
        final sec = sections.firstWhere((s) => s.ecosystem == eco);
        expect(sec.isOpenable, isTrue, reason: eco.name);
        expect(sec.isBeta, isFalse);
        expect(sec.isStreamsOnly, isFalse);
        expect(ProviderDirectory.canOpen(src('x', eco)), isTrue);
      }
    });

    test('an unavailable adapter closes the section and says why', () {
      final sections = ProviderDirectory.build(
        [src('v', Ecosystem.vega)],
        unavailable: {Ecosystem.vega: 'Not supported on this platform'},
      );
      final vega =
          sections.firstWhere((s) => s.ecosystem == Ecosystem.vega);
      expect(vega.isOpenable, isFalse);
      expect(vega.note, 'Not supported on this platform');
      expect(
          ProviderDirectory.canOpen(src('v', Ecosystem.vega),
              unavailable: {Ecosystem.vega: 'no'}),
          isFalse);
    });

    test('a source without catalogues cannot be opened', () {
      expect(
          ProviderDirectory.canOpen(
              src('v', Ecosystem.vega, caps: {Capability.streams})),
          isFalse);
    });

    test('beta wins over an unavailable reason, so the label stays honest', () {
      final sections = ProviderDirectory.build(
        [src('cs', Ecosystem.cloudstream)],
        unavailable: {Ecosystem.cloudstream: 'Android only'},
      );
      final cs =
          sections.firstWhere((s) => s.ecosystem == Ecosystem.cloudstream);
      expect(cs.note, 'Beta soon');
      expect(cs.unavailableReason, isNull);
    });
  });

  group('copy', () {
    test('each section uses its ecosystem\'s own noun', () {
      final sections = ProviderDirectory.build(const []);
      final sky =
          sections.firstWhere((s) => s.ecosystem == Ecosystem.skystream);
      expect(sky.title, 'SkyStream');
      expect(sky.noun, 'Plugins');
      final stremio =
          sections.firstWhere((s) => s.ecosystem == Ecosystem.stremio);
      expect(stremio.noun, 'Add-ons');
    });

    test('the add-on section points out its content is already on Home', () {
      final sections = ProviderDirectory.build(const []);
      final stremio =
          sections.firstWhere((s) => s.ecosystem == Ecosystem.stremio);
      expect(stremio.note, contains('Home'));
      expect(stremio.isOpenable, isTrue);
    });
  });
}
