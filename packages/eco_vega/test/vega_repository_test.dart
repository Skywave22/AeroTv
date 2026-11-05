import 'package:aero_core/aero_core.dart';
import 'package:eco_js_runtime/testing.dart';
import 'package:eco_vega/eco_vega.dart';
import 'package:test/test.dart';

void main() {
  VegaAdapter adapter(Map<String, String> routes) => VegaAdapter(
        store: MemoryPluginStore(),
        dio: fakeDio(routes),
      );

  group('Vega manifest.json (array)', () {
    test('is advertised as a repository ecosystem', () {
      // Held as the base type, exactly as the Extensions manager holds it.
      final EcosystemAdapter a = adapter({});
      expect(a is RepositorySource, isTrue);
    });

    test('reads the array and keeps the source URL plus the entry', () async {
      const url = 'https://repo.example/manifest.json';
      final res = await adapter({
        url: jsonText([
          {
            'value': 'provider-a',
            'display_name': 'Provider A',
            'version': '1.2.0',
            'icon': 'https://repo.example/a.png',
            'disabled': false,
            'type': 'movie',
            'hasSettings': true,
          },
          {'value': 'provider-b', 'display_name': 'Provider B'},
        ]),
      }).fetchRepository(url);

      expect(res.isOk, isTrue, reason: res.errorOrNull);
      final refs = res.valueOrNull!;
      expect(refs, hasLength(2));

      // Vega providers share the repository's source URL; the provider id
      // travels in `extra`, which is what install() uses to build file paths.
      expect(refs[0].url, 'https://repo.example');
      expect(refs[0].extra['value'], 'provider-a');
      expect(refs[0].name, 'Provider A');
      expect(refs[0].version, '1.2.0');
      expect(refs[0].extra['hasSettings'], true);
      expect(refs[0].ecosystem, Ecosystem.vega);
    });

    test('appends manifest.json when given a bare repository URL', () async {
      const index = 'https://repo.example/manifest.json';
      final res = await adapter({
        index: jsonText([
          {'value': 'x', 'display_name': 'X'},
        ]),
      }).fetchRepository('https://repo.example/');
      expect(res.isOk, isTrue, reason: res.errorOrNull);
      expect(res.valueOrNull!.single.url, 'https://repo.example');
    });

    test('skips disabled providers', () async {
      const url = 'https://repo.example/manifest.json';
      final res = await adapter({
        url: jsonText([
          {'value': 'off', 'disabled': true},
          {'value': 'on', 'disabled': false},
        ]),
      }).fetchRepository(url);
      expect(res.valueOrNull, hasLength(1));
      expect(res.valueOrNull!.single.extra['value'], 'on');
    });

    test('rejects entries whose path escapes the repository', () async {
      const url = 'https://repo.example/manifest.json';
      final res = await adapter({
        url: jsonText([
          {'value': 'evil', 'path': '../../etc'},
          {'value': 'abs', 'path': '/etc/passwd'},
          {'value': 'win', 'path': r'dist\..\secrets'},
          {'value': 'ok', 'path': 'custom/dist'},
        ]),
      }).fetchRepository(url);
      expect(res.isOk, isTrue, reason: res.errorOrNull);
      expect(res.valueOrNull, hasLength(1));
      expect(res.valueOrNull!.single.extra['value'], 'ok');
    });

    test('rejects an object manifest, which is the Nuvio format', () async {
      const url = 'https://repo.example/manifest.json';
      final res = await adapter({url: jsonText({'scrapers': []})})
          .fetchRepository(url);
      expect(res.isErr, isTrue);
      expect(res.errorOrNull, contains('array'));
    });

    test('reports a repository with nothing enabled', () async {
      const url = 'https://repo.example/manifest.json';
      final res = await adapter({
        url: jsonText([
          {'value': 'off', 'disabled': true},
        ]),
      }).fetchRepository(url);
      expect(res.isErr, isTrue);
      expect(res.errorOrNull, contains('no enabled providers'));
    });
  });
}
