import 'package:aero_core/aero_core.dart';
import 'package:eco_js_runtime/testing.dart';
import 'package:eco_nuvio/eco_nuvio.dart';
import 'package:test/test.dart';

void main() {
  NuvioAdapter adapter(Map<String, String> routes) => NuvioAdapter(
        store: MemoryPluginStore(),
        dio: fakeDio(routes),
      );

  group('Nuvio manifest.json (object)', () {
    test('is advertised as a repository ecosystem', () {
      // Held as the base type, exactly as the Extensions manager holds it.
      final EcosystemAdapter a = adapter({});
      expect(a is RepositorySource, isTrue);
    });

    test('lists scrapers and resolves code URLs relative to the manifest', () async {
      const url = 'https://repo.example/plugins/manifest.json';
      final res = await adapter({
        url: jsonText({
          'name': 'Example scrapers',
          'version': '1.0.0',
          'author': 'someone',
          'scrapers': [
            {
              'id': 'alpha',
              'name': 'Alpha',
              'version': '2.1.0',
              'filename': 'alpha.js',
              'supportedTypes': ['movie', 'tv'],
              'enabled': true,
            },
            {
              'id': 'beta',
              'name': 'Beta',
              'version': '1.0.0',
              'filename': '/shared/beta.js',
            },
            {
              'id': 'cdn',
              'name': 'CDN',
              'version': '1.0.0',
              'filename': 'https://cdn.example/c.js',
            },
          ],
        }),
      }).fetchRepository(url);

      expect(res.isOk, isTrue, reason: res.errorOrNull);
      final refs = res.valueOrNull!;
      expect(refs, hasLength(3));

      // Base is the manifest URL minus /manifest.json; a leading slash on the
      // filename is trimmed rather than treated as host-root.
      expect(refs[0].url, 'https://repo.example/plugins/alpha.js');
      expect(refs[1].url, 'https://repo.example/plugins/shared/beta.js');
      // Absolute URLs are used verbatim.
      expect(refs[2].url, 'https://cdn.example/c.js');

      expect(refs[0].repoId, url);
      expect(refs[0].name, 'Alpha');
      expect(refs[0].version, '2.1.0');
      expect(refs[0].extra['id'], 'alpha');
      expect(refs[0].ecosystem, Ecosystem.nuvio);
    });

    test('defaults supportedTypes, enabled and hasSettings', () async {
      const url = 'https://repo.example/manifest.json';
      final res = await adapter({
        url: jsonText({
          'name': 'r',
          'version': '1',
          'scrapers': [
            {'id': 's', 'name': 'S', 'version': '1', 'filename': 's.js'},
          ],
        }),
      }).fetchRepository(url);
      final extra = res.valueOrNull!.single.extra;
      expect(extra['supportedTypes'], ['movie', 'tv']);
      expect(extra['hasSettings'], false);
    });

    test('skips disabled scrapers', () async {
      const url = 'https://repo.example/manifest.json';
      final res = await adapter({
        url: jsonText({
          'name': 'r',
          'version': '1',
          'scrapers': [
            {'id': 'off', 'name': 'Off', 'version': '1', 'filename': 'off.js', 'enabled': false},
            {'id': 'on', 'name': 'On', 'version': '1', 'filename': 'on.js'},
          ],
        }),
      }).fetchRepository(url);
      expect(res.valueOrNull, hasLength(1));
      expect(res.valueOrNull!.single.extra['id'], 'on');
    });

    test('rejects a manifest missing name or version', () async {
      const url = 'https://repo.example/manifest.json';
      for (final bad in [
        {'version': '1', 'scrapers': [
          {'id': 's', 'name': 'S', 'version': '1', 'filename': 's.js'}
        ]},
        {'name': 'r', 'scrapers': [
          {'id': 's', 'name': 'S', 'version': '1', 'filename': 's.js'}
        ]},
      ]) {
        final res = await adapter({url: jsonText(bad)}).fetchRepository(url);
        expect(res.isErr, isTrue, reason: 'should reject $bad');
      }
    });

    test('rejects an array manifest, which is the Vega format', () async {
      const url = 'https://repo.example/manifest.json';
      final res = await adapter({url: jsonText([])}).fetchRepository(url);
      expect(res.isErr, isTrue);
      expect(res.errorOrNull, contains('object'));
    });

    test('reports a repository whose scrapers are all disabled', () async {
      const url = 'https://repo.example/manifest.json';
      final res = await adapter({
        url: jsonText({
          'name': 'r',
          'version': '1',
          'scrapers': [
            {'id': 'off', 'name': 'Off', 'version': '1', 'filename': 'o.js', 'enabled': false},
          ],
        }),
      }).fetchRepository(url);
      expect(res.isErr, isTrue);
      expect(res.errorOrNull, contains('disabled'));
    });

    test('scrapers are streams-only, so Browse must exclude them', () async {
      final a = adapter({});
      expect(a.capabilities, contains(Capability.streams));
      expect(a.capabilities.contains(Capability.catalogs), isFalse);
    });
  });
}
