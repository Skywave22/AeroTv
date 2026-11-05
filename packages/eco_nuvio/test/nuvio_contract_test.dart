import 'package:aero_core/aero_core.dart';
import 'package:eco_js_runtime/eco_js_runtime.dart' show JsPluginStore;
import 'package:eco_nuvio/eco_nuvio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Nuvio manifest validation (mirrors PluginManifestParser)', () {
    Map<String, dynamic> base() => {
          'name': 'Repo',
          'version': '1.0.0',
          'scrapers': [
            {'id': 's1', 'name': 'S1', 'version': '1.0.0', 'filename': 's1.js'},
          ],
        };

    test('accepts a well-formed manifest', () {
      expect(NuvioManifest.validate(base()), isNull);
    });

    test('rejects blank name, blank version and empty scrapers', () {
      expect(NuvioManifest.validate({...base(), 'name': ' '}), isNotNull);
      expect(NuvioManifest.validate({...base(), 'version': ''}), isNotNull);
      expect(NuvioManifest.validate({...base(), 'scrapers': []}), isNotNull);
    });

    test('scraper defaults match upstream', () {
      final m = NuvioManifest.fromJson(base());
      final s = m.scrapers.single;
      expect(s.supportedTypes, ['movie', 'tv']);
      expect(s.enabled, isTrue);
      expect(s.hasSettings, isFalse);
    });

    test('supportsType normalises series/show to tv', () {
      final s = NuvioManifest.fromJson(base()).scrapers.single;
      expect(s.supportsType('series'), isTrue);
      expect(s.supportsType('show'), isTrue);
      expect(s.supportsType('tv'), isTrue);
      expect(s.supportsType('movie'), isTrue);
      expect(s.supportsType('anime'), isFalse);
    });
  });

  group('Nuvio scraper URL resolution (mirrors PluginRepository.kt)', () {
    test('relative filename resolves against the manifest folder', () {
      expect(
        nuvioScraperUrl('https://x.example/repo/manifest.json', 's1.js'),
        'https://x.example/repo/s1.js',
      );
    });

    test('query string on the manifest URL is dropped', () {
      expect(
        nuvioScraperUrl('https://x.example/repo/manifest.json?t=123', 's1.js'),
        'https://x.example/repo/s1.js',
      );
    });

    test('leading slashes on the filename are trimmed', () {
      expect(
        nuvioScraperUrl('https://x.example/repo/manifest.json', '/sub/s1.js'),
        'https://x.example/repo/sub/s1.js',
      );
    });

    test('absolute filename is used verbatim', () {
      expect(
        nuvioScraperUrl('https://x.example/repo/manifest.json', 'https://cdn/s1.js'),
        'https://cdn/s1.js',
      );
    });
  });

  group('Nuvio stream results', () {
    test('torrent fields produce a torrent StreamLink, not HTTP', () {
      final r = NuvioStreamResult.fromJson({
        'title': 'Movie 1080p',
        'url': 'magnet:?xt=urn:btih:abc',
        'quality': '1080p',
        'size': '2.1 GB',
        'infoHash': 'abc123',
        'seeders': 42,
        'peers': 7,
        'provider': 'TorrentGalaxy',
      });
      expect(r.isTorrent, isTrue);
      final link = r.toStreamLink(sourceId: 's1', sourceName: 'Scraper');
      expect(link.kind, StreamKind.torrent);
      expect(link.infoHash, 'abc123');
      expect(link.quality, Quality.fullHd);
      expect(link.description, contains('2.1 GB'));
      expect(link.description, contains('S:42'));
    });

    test('infoHash alone marks a torrent even with an http url', () {
      final r = NuvioStreamResult.fromJson(
          {'title': 't', 'url': 'https://x/f', 'infoHash': 'deadbeef'});
      expect(r.isTorrent, isTrue);
      expect(r.toStreamLink(sourceId: 's', sourceName: 'n').kind, StreamKind.torrent);
    });

    test('plain http result stays direct and keeps headers', () {
      final r = NuvioStreamResult.fromJson({
        'title': 'Direct', 'url': 'https://x/v.mp4', 'quality': '720p',
        'headers': {'Referer': 'https://x'},
      });
      expect(r.isTorrent, isFalse);
      final link = r.toStreamLink(sourceId: 's', sourceName: 'n');
      expect(link.kind, StreamKind.direct);
      expect(link.headers['Referer'], 'https://x');
      expect(link.quality, Quality.hd);
    });
  });

  group('Nuvio prelude', () {
    test('injects the three upstream globals and the call bridge', () {
      final js = nuvioPrelude(scraperId: 's1', tmdbApiKey: 'KEY');
      expect(js, contains('globalThis.SCRAPER_ID'));
      expect(js, contains('globalThis.SCRAPER_SETTINGS'));
      expect(js, contains('globalThis.TMDB_API_KEY'));
      expect(js, contains('"KEY"'));
      expect(js, contains('module.exports.getStreams'));
      expect(js, contains('globalThis.getStreams'));
      expect(js, contains('__nuvioOnSettings'));
    });

    test('a missing getStreams resolves to an empty list, as upstream does', () {
      final js = nuvioPrelude(scraperId: 's');
      expect(js, contains("if (typeof fn !== 'function') return Promise.resolve([]);"));
    });
  });

  group('Nuvio capability surface', () {
    test('scrapers are streams-only — no catalog, search or metadata', () {
      final adapter = NuvioAdapter(store: _NullStore());
      expect(adapter.capabilities, {Capability.streams});
      expect(adapter.capabilities.contains(Capability.catalogs), isFalse);
      expect(adapter.capabilities.contains(Capability.search), isFalse);
      expect(adapter.capabilities.contains(Capability.meta), isFalse);
    });

    test('details() explains why rather than returning empty', () async {
      final adapter = NuvioAdapter(store: _NullStore());
      final res = await adapter.details(
        'x',
        const MediaRef(id: '1', type: MediaType.movie, title: 'T'),
      );
      expect(res.isErr, isTrue);
      expect(res.errorOrNull, contains('TMDB'));
    });
  });
}

class _NullStore implements JsPluginStore {
  @override
  Future<List<InstalledSource>> load(Ecosystem ecosystem) async => const [];
  @override
  Future<void> save(InstalledSource source) async {}
  @override
  Future<void> delete(Ecosystem ecosystem, String id) async {}
  @override
  Future<String?> loadCode(Ecosystem ecosystem, String id) async => null;
  @override
  Future<void> saveCode(Ecosystem ecosystem, String id, String code) async {}
}
