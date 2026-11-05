import 'package:aero_core/aero_core.dart';
import 'package:eco_js_runtime/testing.dart';
import 'package:eco_skystream/eco_skystream.dart';
import 'package:test/test.dart';

void main() {
  SkyStreamAdapter adapter(Map<String, String> routes) => SkyStreamAdapter(
        store: MemoryPluginStore(),
        dio: fakeDio(routes),
      );

  group('SkyStream repo.json', () {
    test('is advertised as a repository ecosystem', () {
      // Held as the base type, exactly as the Extensions manager holds it.
      final EcosystemAdapter a = adapter({});
      expect(a is RepositorySource, isTrue);
    });

    test('lists plugins and resolves relative filenames against the index', () async {
      const url = 'https://repo.example/plugins/repo.json';
      final a = adapter({
        url: jsonText({
          'name': 'Example repo',
          'plugins': [
            {
              'name': 'Alpha',
              'version': 3,
              'filename': 'alpha/plugin.js',
              'sha256': 'abc123',
              'languages': ['en'],
            },
            {
              'name': 'Beta',
              'version': 1,
              'url': 'https://cdn.example/beta.js',
            },
          ],
        }),
      });

      final res = await a.fetchRepository(url);
      expect(res.isOk, isTrue, reason: res.errorOrNull);
      final refs = res.valueOrNull!;
      expect(refs, hasLength(2));

      // Relative filename resolves against the index URL, not the host root.
      expect(refs[0].url, 'https://repo.example/plugins/alpha/plugin.js');
      expect(refs[0].name, 'Alpha');
      // plugin.json versions are ints upstream; they must survive as text.
      expect(refs[0].version, '3');
      expect(refs[0].expectedSha256, 'abc123');
      expect(refs[0].ecosystem, Ecosystem.skystream);

      // Absolute URLs are used verbatim.
      expect(refs[1].url, 'https://cdn.example/beta.js');
      // The raw entry is preserved so install() can reuse inlined metadata.
      expect(refs[0].extra['languages'], ['en']);
    });

    test('rejects an array index', () async {
      const url = 'https://repo.example/repo.json';
      final res = await adapter({url: jsonText([])}).fetchRepository(url);
      expect(res.isErr, isTrue);
      expect(res.errorOrNull, contains('object'));
    });

    test('reports an empty repository rather than installing nothing quietly', () async {
      const url = 'https://repo.example/repo.json';
      final res = await adapter({url: jsonText({'plugins': []})})
          .fetchRepository(url);
      expect(res.isErr, isTrue);
      expect(res.errorOrNull, contains('no plugins'));
    });

    test('skips entries with no code URL', () async {
      const url = 'https://repo.example/repo.json';
      final res = await adapter({
        url: jsonText({
          'plugins': [
            {'name': 'Broken'},
            {'name': 'Good', 'filename': 'good.js'},
          ],
        }),
      }).fetchRepository(url);
      expect(res.valueOrNull, hasLength(1));
      expect(res.valueOrNull!.single.name, 'Good');
    });

    test('a malformed URL fails validation before any request', () async {
      final res = await adapter({}).fetchRepository('not a url');
      expect(res.isErr, isTrue);
      expect(res.errorOrNull, contains('valid'));
    });
  });
}
