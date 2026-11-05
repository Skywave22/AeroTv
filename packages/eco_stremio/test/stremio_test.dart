import 'package:aero_core/aero_core.dart';
import 'package:eco_stremio/eco_stremio.dart';
import 'package:test/test.dart';

/// Realistic manifest shaped like a real add-on: mixed string/object
/// resources, searchable catalog with genre options, IMDb-only streams.
const manifestJson = {
  'id': 'org.example.aero',
  'version': '1.2.3',
  'name': 'Example Add-on',
  'description': 'Test fixture',
  'logo': 'https://example.com/logo.png',
  'types': ['movie', 'series'],
  'idPrefixes': ['tt'],
  'resources': [
    'catalog',
    {'name': 'meta', 'types': ['movie', 'series'], 'idPrefixes': ['tt']},
    {'name': 'stream', 'types': ['movie', 'series'], 'idPrefixes': ['tt']},
    {'name': 'subtitles', 'types': ['movie'], 'idPrefixes': ['tt']},
  ],
  'catalogs': [
    {
      'type': 'movie',
      'id': 'top',
      'name': 'Popular',
      'extra': [
        {'name': 'search', 'isRequired': false},
        {'name': 'genre', 'options': ['Action', 'Drama']},
        {'name': 'skip'},
      ],
    },
    {'type': 'series', 'id': 'series-top', 'name': 'Popular Series'},
  ],
  'behaviorHints': {'configurable': true},
};

void main() {
  group('URL construction', () {
    test('normalises user input', () {
      expect(StremioApi.normaliseManifestUrl('example.com'),
          'https://example.com/manifest.json');
      expect(StremioApi.normaliseManifestUrl('https://example.com/'),
          'https://example.com/manifest.json');
      expect(StremioApi.normaliseManifestUrl('https://example.com/manifest.json'),
          'https://example.com/manifest.json');
      expect(StremioApi.normaliseManifestUrl('stremio://example.com/manifest.json'),
          'https://example.com/manifest.json');
      expect(StremioApi.normaliseManifestUrl('  https://x.dev/abc/  '),
          'https://x.dev/abc/manifest.json');
    });

    test('preserves configuration path segments', () {
      const u = 'https://x.dev/eyJkZWJyaWQiOiIxMjMifQ/manifest.json';
      expect(StremioApi.baseUrlOf(u), 'https://x.dev/eyJkZWJyaWQiOiIxMjMifQ/');
      expect(StremioApi.catalogUrl(u, 'movie', 'top', {}),
          'https://x.dev/eyJkZWJyaWQiOiIxMjMifQ/catalog/movie/top.json');
    });

    test('empty url throws', () {
      expect(() => StremioApi.normaliseManifestUrl('   '), throwsA(isA<AeroException>()));
    });

    test('builds catalog urls with extras', () {
      const u = 'https://x.dev/manifest.json';
      expect(StremioApi.catalogUrl(u, 'movie', 'top', {}),
          'https://x.dev/catalog/movie/top.json');
      expect(
        StremioApi.catalogUrl(u, 'movie', 'top', {'genre': 'Action', 'skip': '100'}),
        'https://x.dev/catalog/movie/top/genre=Action&skip=100.json',
      );
      expect(StremioApi.catalogUrl(u, 'movie', 'top', {'search': 'the matrix'}),
          'https://x.dev/catalog/movie/top/search=the%20matrix.json');
    });

    test('keeps colons in episode ids', () {
      const u = 'https://x.dev/manifest.json';
      expect(StremioApi.resourceUrl(u, 'stream', 'series', 'tt0944947:1:2'),
          'https://x.dev/stream/series/tt0944947:1:2.json');
    });
  });

  group('manifest parsing', () {
    final m = StremioManifest.fromJson(manifestJson);

    test('reads identity and catalogs', () {
      expect(m.id, 'org.example.aero');
      expect(m.version, '1.2.3');
      expect(m.catalogs.length, 2);
      expect(m.catalogs.first.searchable, isTrue);
      expect(m.catalogs.first.genres, ['Action', 'Drama']);
      expect(m.catalogs.last.searchable, isFalse);
    });

    test('derives capabilities from resources', () {
      expect(m.capabilities, {
        Capability.catalogs,
        Capability.search,
        Capability.meta,
        Capability.streams,
        Capability.subtitles,
      });
    });

    test('handles string and object resources', () {
      expect(m.resources.first.name, 'catalog');
      expect(m.resources.first.types, isEmpty);
      expect(m.resources[1].types, [MediaType.movie, MediaType.series]);
    });

    test('serves() honours per-resource types and prefixes', () {
      expect(m.serves('stream', MediaType.movie, mediaId: 'tt0111161'), isTrue);
      expect(m.serves('stream', MediaType.movie, mediaId: 'tmdb603'), isFalse);
      expect(m.serves('subtitles', MediaType.movie, mediaId: 'tt0111161'), isTrue);
      // subtitles declared for movies only
      expect(m.serves('subtitles', MediaType.series, mediaId: 'tt0944947'), isFalse);
      expect(m.serves('addon_catalog', MediaType.movie), isFalse);
    });

    test('flags configurationRequired', () {
      final cfg = StremioManifest.fromJson({
        ...manifestJson,
        'behaviorHints': {'configurationRequired': true},
      });
      expect(cfg.requiresConfiguration, isTrue);
    });

    test('accepts singular `type` in a resource', () {
      final r = StremioResource.parse({'name': 'stream', 'type': 'movie'});
      expect(r!.types, [MediaType.movie]);
    });

    test('ignores malformed resource entries', () {
      expect(StremioResource.parse(42), isNull);
      expect(StremioResource.parse({'noName': true}), isNull);
    });
  });

  group('meta parsing', () {
    test('parses a movie preview', () {
      final item = StremioParsers.metaPreview({
        'id': 'tt0133093',
        'type': 'movie',
        'name': 'The Matrix',
        'poster': 'https://p/poster.jpg',
        'releaseInfo': '1999',
        'imdbRating': '8.7',
        'genres': ['Action', 'Sci-Fi'],
      })!;
      expect(item.title, 'The Matrix');
      expect(item.ref.imdbId, 'tt0133093');
      expect(item.year, 1999);
      expect(item.imdbRating, 8.7);
      expect(item.genres.length, 2);
    });

    test('handles year ranges and string numbers', () {
      final item = StremioParsers.metaPreview({
        'id': 'tt0944947',
        'type': 'series',
        'name': 'Game of Thrones',
        'releaseInfo': '2011-2019',
        'imdbRating': 9.2,
      })!;
      expect(item.year, 2011);
      expect(item.imdbRating, 9.2);
    });

    test('drops entries without an id', () {
      expect(StremioParsers.metaPreview({'name': 'x'}), isNull);
    });

    test('parses episodes and sorts them', () {
      final d = StremioParsers.metaDetail({
        'id': 'tt0944947',
        'type': 'series',
        'name': 'GoT',
        'videos': [
          {'id': 'tt0944947:2:1', 'season': 2, 'episode': 1, 'title': 'S2E1'},
          {'id': 'tt0944947:1:2', 'season': 1, 'episode': 2, 'title': 'S1E2'},
          {'id': 'tt0944947:1:1', 'season': 1, 'episode': 1, 'title': 'S1E1'},
          {'id': 'bad', 'title': 'no season'},
        ],
        'cast': ['A', 'B'],
        'director': 'X',
        'trailers': [
          {'ytId': 'abc123'},
        ],
      })!;
      expect(d.episodes.length, 3);
      expect(d.episodes.first.label, 'S01E01');
      expect(d.seasons, [1, 2]);
      expect(d.episodesOfSeason(1).length, 2);
      expect(d.directors, ['X']);
      expect(d.trailers, ['abc123']);
    });
  });

  group('stream parsing', () {
    StreamLink parse(Map<String, dynamic> j) => StremioParsers.stream(
          j,
          sourceId: 'org.example',
          sourceName: 'Example',
        )!;

    test('extracts proxyHeaders and notWebReady', () {
      final s = parse({
        'url': 'https://cdn/v.mkv',
        'name': '1080p',
        'description': 'WEB-DL x264',
        'behaviorHints': {
          'notWebReady': true,
          'bingeGroup': 'ex-1080',
          'proxyHeaders': {
            'request': {'Referer': 'https://ref.example', 'User-Agent': 'AeroTV'},
          },
        },
      });
      expect(s.headers['Referer'], 'https://ref.example');
      expect(s.headers['User-Agent'], 'AeroTV');
      expect(s.notWebReady, isTrue);
      expect(s.bingeGroup, 'ex-1080');
      expect(s.quality, Quality.fullHd);
      expect(s.isPlayable, isTrue);
    });

    test('falls back from description to deprecated title', () {
      final s = parse({'url': 'https://cdn/v.mkv', 'title': '720p HDR'});
      expect(s.description, '720p HDR');
      expect(s.quality, Quality.hd);
      expect(s.isHdr, isTrue);
    });

    test('detects HLS and DASH', () {
      expect(parse({'url': 'https://cdn/master.m3u8'}).kind, StreamKind.hls);
      expect(parse({'url': 'https://cdn/manifest.mpd'}).kind, StreamKind.dash);
      expect(parse({'url': 'https://cdn/v.mp4'}).kind, StreamKind.direct);
    });

    test('marks torrent-only streams unplayable', () {
      final s = parse({'infoHash': 'abc123def', 'name': '1080p'});
      expect(s.kind, StreamKind.torrent);
      expect(s.isTorrent, isTrue);
      expect(s.isPlayable, isFalse);
      expect(s.infoHash, 'abc123def');
    });

    test('parses size from text and from videoSize hint', () {
      expect(parse({'url': 'https://c/v', 'title': '1080p 1.5 GB'}).sizeBytes,
          1610612736);
      expect(parse({'url': 'https://c/v', 'title': '700MB'}).sizeBytes, 734003200);
      expect(
        parse({
          'url': 'https://c/v',
          'behaviorHints': {'videoSize': 12345},
        }).sizeBytes,
        12345,
      );
    });

    test('flags debrid-resolved links', () {
      final s = parse({'url': 'https://rd.download/x', 'name': 'RealDebrid 1080p'});
      expect(s.debrid, isTrue);
    });

    test('detects language and codec', () {
      final s = parse({'url': 'https://c/v', 'title': '1080p Hindi x265'});
      expect(s.language, 'hi');
      expect(s.codec, 'x265');
    });

    test('returns null when there is nothing to play', () {
      expect(
        StremioParsers.stream({'name': '1080p'},
            sourceId: 'x', sourceName: 'X'),
        isNull,
      );
    });

    test('carries inline subtitles', () {
      final s = parse({
        'url': 'https://c/v',
        'subtitles': [
          {'id': 's1', 'url': 'https://c/en.srt', 'lang': 'en'},
          {'id': 's2', 'url': '', 'lang': 'fr'},
        ],
      });
      expect(s.subtitles.length, 1);
      expect(s.subtitles.first.lang, 'en');
    });
  });

  group('adapter install/validation', () {
    test('rejects a configurationRequired add-on with a helpful message', () async {
      final adapter = StremioAdapter(store: MemoryStremioStore(), api: _FakeApi());
      final res = await adapter.install(
        const SourceRef(ecosystem: Ecosystem.stremio, url: 'https://needs-config'),
      );
      expect(res.isErr, isTrue);
      expect(res.errorOrNull, contains('configuration'));
    });

    test('installs, lists, health-checks and uninstalls', () async {
      final store = MemoryStremioStore();
      final adapter = StremioAdapter(store: store, api: _FakeApi());
      final res = await adapter.install(
        const SourceRef(ecosystem: Ecosystem.stremio, url: 'https://ok.example'),
      );
      expect(res.isOk, isTrue, reason: res.errorOrNull);
      final s = res.valueOrNull!;
      expect(s.id, 'org.example.aero');
      expect(s.capabilities.contains(Capability.streams), isTrue);
      expect((await adapter.installedSources()).length, 1);

      final health = await adapter.healthCheck(s.id);
      expect(health.isOk, isTrue);

      await adapter.uninstall(s.id);
      expect(await adapter.installedSources(), isEmpty);
    });

    test('assigns increasing priority to successive installs', () async {
      final adapter = StremioAdapter(store: MemoryStremioStore(), api: _FakeApi());
      final a = await adapter.install(
          const SourceRef(ecosystem: Ecosystem.stremio, url: 'https://ok.example'));
      final b = await adapter.install(
          const SourceRef(ecosystem: Ecosystem.stremio, url: 'https://ok2.example'));
      expect(b.valueOrNull!.priority, greaterThan(a.valueOrNull!.priority));
    });

    test('health check on a missing add-on errors cleanly', () async {
      final adapter = StremioAdapter(store: MemoryStremioStore(), api: _FakeApi());
      expect((await adapter.healthCheck('nope')).isErr, isTrue);
    });
  });
}

/// Serves fixtures without touching the network.
class _FakeApi extends StremioApi {
  @override
  Future<StremioManifest> fetchManifest(String manifestUrl) async {
    final url = StremioApi.normaliseManifestUrl(manifestUrl);
    if (url.contains('needs-config')) {
      return StremioManifest.fromJson({
        ...manifestJson,
        'behaviorHints': {'configurationRequired': true},
      });
    }
    if (url.contains('ok2')) {
      return StremioManifest.fromJson({...manifestJson, 'id': 'org.example.second'});
    }
    return StremioManifest.fromJson(manifestJson);
  }
}
