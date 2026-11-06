import 'dart:convert';
import 'dart:io';

import 'package:aero_core/aero_core.dart';
import 'package:eco_stremio/eco_stremio.dart';
import 'package:test/test.dart';

/// Contract tests against recorded add-on responses in `fixtures/`.
void main() {
  Map<String, dynamic> fixture(String name) =>
      jsonDecode(File('test/fixtures/$name').readAsStringSync()) as Map<String, dynamic>;
  String fixtureText(String name) => File('test/fixtures/$name').readAsStringSync();

  group('Manifest: string resources (Cinemeta shape)', () {
    late StremioManifest m;
    setUp(() => m = StremioManifest.fromJson(fixture('manifest_string_resources.json')));

    test('parses identity and bare-string resources', () {
      expect(m.id, 'com.linvo.cinemeta');
      expect(m.version, '3.1.0');
      expect(m.resources.map((r) => r.name), containsAll(['catalog', 'meta']));
    });

    test('a string resource inherits manifest types and prefixes', () {
      expect(m.serves('meta', MediaType.movie, mediaId: 'tt0111161'), isTrue);
      expect(m.serves('meta', MediaType.series, mediaId: 'tt0903747'), isTrue);
      expect(m.serves('stream', MediaType.movie, mediaId: 'tt0111161'), isFalse);
      expect(m.serves('meta', MediaType.movie, mediaId: 'kitsu:123'), isFalse);
    });

    test('all catalogs are home-eligible; search declared where present', () {
      expect(m.catalogs, hasLength(3));
      expect(m.catalogs.every((c) => c.isHomeEligible), isTrue);
      expect(m.catalogs.first.searchable, isTrue);
      expect(m.catalogs.first.genres, containsAll(['Action', 'Drama']));
      expect(m.catalogs[2].searchable, isFalse);
    });

    test('round-trips without losing catalog detail', () {
      final back = StremioManifest.fromJson(m.toJson());
      expect(back.catalogs, hasLength(3));
      expect(back.catalogs.first.searchable, isTrue);
      expect(back.catalogs.first.genres, containsAll(['Action', 'Drama']));
    });
  });

  group('Manifest: object resources with per-resource scopes', () {
    late StremioManifest m;
    setUp(() => m = StremioManifest.fromJson(fixture('manifest_object_resources.json')));

    test('honours per-resource types', () {
      expect(m.serves('catalog', MediaType.movie, mediaId: 'tt1'), isTrue);
      expect(m.serves('catalog', MediaType.series, mediaId: 'tt1'), isFalse);
      expect(m.serves('stream', MediaType.movie, mediaId: 'tt1'), isTrue);
      expect(m.serves('stream', MediaType.series, mediaId: 'tt1'), isFalse);
      expect(m.serves('subtitles', MediaType.series, mediaId: 'tt1'), isTrue);
    });

    test('required extras exclude search and genre catalogs from Home', () {
      expect(m.catalogs.where((c) => c.isHomeEligible).map((c) => c.id), ['trending']);
      expect(m.catalogs.firstWhere((c) => c.id == 'search-only').requiredExtras, ['search']);
      expect(m.catalogs.firstWhere((c) => c.id == 'genre-only').requiredExtras, ['genre']);
    });
  });

  test('configurationRequired is detected', () {
    final m = StremioManifest.fromJson(fixture('manifest_configuration_required.json'));
    expect(m.behaviorHints['configurationRequired'], true);
    expect(m.catalogs, isEmpty);
  });

  group('Catalog page', () {
    test('maps previews and keeps IMDb ids', () {
      final metas = (fixture('catalog_page.json')['metas'] as List).cast<Map<String, dynamic>>();
      final items = metas.map(StremioParsers.metaPreview).whereType<MediaItem>().toList();
      expect(items, hasLength(3));
      expect(items.first.title, 'The Shawshank Redemption');
      expect(items.first.ref.imdbId, 'tt0111161');
    });

    test('duplicate ids collapse when deduped by cache key', () {
      final metas = (fixture('catalog_page.json')['metas'] as List).cast<Map<String, dynamic>>();
      final seen = <String>{};
      final unique = metas
          .map(StremioParsers.metaPreview)
          .whereType<MediaItem>()
          .where((i) => seen.add(i.ref.cacheKey))
          .toList();
      expect(unique, hasLength(2));
    });

    test('an empty metas list is valid', () {
      expect(fixture('catalog_empty.json')['metas'], isEmpty);
    });
  });

  group('Series metadata', () {
    late MediaDetails d;
    setUp(() {
      d = StremioParsers.metaDetail(
          fixture('meta_series.json')['meta'] as Map<String, dynamic>)!;
    });

    test('parses episodes with season and number', () {
      expect(d.item.title, 'Breaking Bad');
      expect(d.episodes, hasLength(3));
      expect(d.episodes.first.season, 1);
      expect(d.episodes.first.episode, 1);
      expect(d.episodes.first.title, 'Pilot');
      expect(d.episodes.last.season, 2);
    });

    test('derives the season list', () => expect(d.seasons, [1, 2]));

    test('parses release dates and overviews', () {
      expect(d.episodes.first.released!.year, 2008);
      expect(d.episodes.first.overview, contains('diagnosed'));
    });

    test('carries cast, directors and runtime', () {
      expect(d.cast, contains('Bryan Cranston'));
      expect(d.directors, contains('Vince Gilligan'));
      expect(d.item.runtime, '49 min');
    });
  });

  group('Streams with behaviorHints', () {
    late List<StreamLink> links;
    setUp(() {
      links = (fixture('streams_behavior_hints.json')['streams'] as List)
          .cast<Map<String, dynamic>>()
          .map((s) => StremioParsers.stream(s, sourceId: 's1', sourceName: 'Example'))
          .whereType<StreamLink>()
          .toList();
    });

    test('maps all three playable streams', () {
      expect(links, hasLength(3));
      expect(links.every((l) => l.ecosystem == Ecosystem.stremio), isTrue);
    });

    test('reads videoSize from the hint and quality from text', () {
      expect(links.first.sizeBytes, 4509715660);
      expect(links.first.quality.height, 1080);
    });

    test('carries bingeGroup', () => expect(links.first.bingeGroup, 'example-1080'));

    test('extracts proxyHeaders.request', () {
      expect(links[1].headers['Referer'], 'https://referer.example/');
      expect(links[1].headers['User-Agent'], 'Custom/1.0');
    });

    test('detects HLS from the URL', () => expect(links[2].kind, StreamKind.hls));

    test('carries inline subtitles with language', () {
      expect(links.first.subtitles, hasLength(2));
      expect(links.first.subtitles.first.lang, 'eng');
    });
  });

  test('infoHash, ytId and externalUrl yield nothing playable', () {
    final raw = (fixture('streams_unplayable.json')['streams'] as List).cast<Map<String, dynamic>>();
    final playable = raw
        .map((s) => StremioParsers.stream(s, sourceId: 's1', sourceName: 'X'))
        .whereType<StreamLink>()
        .where((l) => l.isPlayable)
        .toList();
    expect(playable, isEmpty);
  });

  test('an HTML error page is not mistaken for JSON', () {
    final html = fixtureText('error_html_page.txt');
    expect(html.trim().startsWith('<'), isTrue);
    expect(() => jsonDecode(html), throwsFormatException);
  });
}
