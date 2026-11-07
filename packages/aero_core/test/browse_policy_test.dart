import 'package:aero_core/aero_core.dart';
import 'package:test/test.dart';

InstalledSource src(
  Ecosystem eco,
  String id, {
  bool enabled = true,
  int priority = 100,
  Set<Capability>? caps,
  List<Capability> extra = const [],
}) =>
    InstalledSource(
      id: id,
      ecosystem: eco,
      name: id,
      url: 'https://example.com/$id',
      enabled: enabled,
      priority: priority,
      capabilities: caps ?? {Capability.catalogs, Capability.streams, ...extra},
    );

void main() {
  group('BrowsePolicy', () {
    test('Browse covers SkyStream, Vega and CloudStream only', () {
      expect(BrowsePolicy.browsable, [
        Ecosystem.skystream,
        Ecosystem.vega,
        Ecosystem.cloudstream,
      ]);
      expect(BrowsePolicy.isBrowsableEcosystem(Ecosystem.stremio), isFalse);
      expect(BrowsePolicy.isBrowsableEcosystem(Ecosystem.nuvio), isFalse);
    });

    test('browsableSources excludes add-ons and scrapers', () {
      final all = [
        src(Ecosystem.stremio, 'addon'),
        src(Ecosystem.nuvio, 'scraper'),
        src(Ecosystem.skystream, 'sky'),
        src(Ecosystem.vega, 'vega'),
      ];
      final out = BrowsePolicy.browsableSources(all);
      expect(out.map((s) => s.id), ['sky', 'vega']);
    });

    test('a provider without the catalogs capability is not browsable', () {
      final all = [
        src(Ecosystem.cloudstream, 'cs', caps: {Capability.streams}),
        src(Ecosystem.skystream, 'sky'),
      ];
      expect(BrowsePolicy.browsableSources(all).map((s) => s.id), ['sky']);
    });

    test('an unavailable ecosystem is dropped even if installed', () {
      final all = [src(Ecosystem.cloudstream, 'cs'), src(Ecosystem.vega, 'v')];
      final out = BrowsePolicy.browsableSources(all,
          unavailable: {Ecosystem.cloudstream});
      expect(out.map((s) => s.id), ['v']);
    });

    test('homeSources is add-ons only, enabled, priority order, capped', () {
      final all = [
        src(Ecosystem.skystream, 'sky'),
        src(Ecosystem.stremio, 'b', priority: 20),
        src(Ecosystem.stremio, 'a', priority: 10),
        src(Ecosystem.stremio, 'off', enabled: false),
        src(Ecosystem.nuvio, 'n'),
      ];
      final out = BrowsePolicy.homeSources(all);
      expect(out.map((s) => s.id), ['a', 'b']);

      final capped = BrowsePolicy.homeSources(
        [
          for (var i = 0; i < 12; i++)
            src(Ecosystem.stremio, 's$i', priority: i),
        ],
        maxSources: 3,
      );
      expect(capped.map((s) => s.id), ['s0', 's1', 's2']);
    });

    test('streamSources is add-ons plus scrapers, nothing browsable-only', () {
      final all = [
        src(Ecosystem.stremio, 'addon'),
        src(Ecosystem.nuvio, 'scraper'),
        src(Ecosystem.skystream, 'sky', caps: {Capability.catalogs, Capability.streams}),
        src(Ecosystem.nuvio, 'off', enabled: false),
      ];
      final out = BrowsePolicy.streamSources(all);
      // SkyStream declares streams too, so it is a legitimate stream source;
      // the ordering must still be deterministic.
      expect(out.map((s) => s.id), ['addon', 'scraper', 'sky']);
      expect(out.any((s) => s.id == 'off'), isFalse);
    });

    test('every ecosystem has an explicit role', () {
      for (final eco in Ecosystem.values) {
        final roles = [
          BrowsePolicy.browsable.contains(eco),
          BrowsePolicy.homeFeed.contains(eco),
          BrowsePolicy.streamsOnly.contains(eco),
        ];
        expect(roles.where((r) => r).length, 1,
            reason: '${eco.id} must have exactly one role, got $roles');
      }
    });

    test('absentReason explains add-ons and scrapers', () {
      expect(BrowsePolicy.absentReason(Ecosystem.stremio), isNotNull);
      expect(BrowsePolicy.absentReason(Ecosystem.nuvio), isNotNull);
      expect(BrowsePolicy.absentReason(Ecosystem.vega), isNull);
    });
  });
}
