import 'package:aero_core/aero_core.dart';
import 'package:eco_js_runtime/eco_js_runtime.dart' show parseQualityLabel;
import 'package:eco_skystream/eco_skystream.dart';
import 'package:test/test.dart';

void main() {
  group('SkyStream MultimediaItem', () {
    test('parses the upstream reference shape', () {
      final item = SkyMediaItem.fromJson({
        'title': 'Example',
        'url': 'https://site/movie/1',
        'posterUrl': 'https://site/p.jpg',
        'type': 'series',
        'year': 2024,
        'score': 8.5,
        'duration': 120,
        'status': 'ongoing',
        'tags': ['Action'],
        'syncData': {'tmdb': '456', 'imdb': 'tt1234567'},
        'episodes': [
          {'name': 'E1', 'url': 'https://site/w/1', 'season': 1, 'episode': 1},
          {'name': 'E2', 'url': 'https://site/w/2', 'season': 1, 'episode': 2},
        ],
      });
      expect(item.type, SkyProviderType.series);
      expect(item.score, 8.5);
      expect(item.duration, 120);
      expect(item.episodes, hasLength(2));
      expect(item.syncData['tmdb'], '456');

      final unified = item.toMediaItem();
      expect(unified.ref.id, 'https://site/movie/1');
      expect(unified.type, MediaType.series);
      expect(unified.ref.tmdbId, '456');
      expect(unified.ref.imdbId, 'tt1234567');
      expect(unified.imdbRating, 8.5);
    });

    test('anime and livestream map to sensible Aero types', () {
      expect(SkyProviderType.fromWire('anime').toMediaType, MediaType.series);
      expect(SkyProviderType.fromWire('livestream').toMediaType, MediaType.channel);
      expect(SkyProviderType.fromWire('movie').toMediaType, MediaType.movie);
      expect(SkyProviderType.fromWire('nonsense'), SkyProviderType.other);
    });

    test('playbackPolicy flags external-only and torrent', () {
      final ext = SkyMediaItem.fromJson({
        'title': 'x', 'url': 'u', 'posterUrl': 'p', 'type': 'movie',
        'playbackPolicy': 'externalPlayerOnly',
      });
      expect(ext.requiresExternalPlayer, isTrue);
      final tor = SkyMediaItem.fromJson({
        'title': 'x', 'url': 'u', 'posterUrl': 'p', 'type': 'movie',
        'playbackPolicy': 'torrent',
      });
      expect(tor.isTorrentOnly, isTrue);
    });
  });

  group('SkyStream StreamResult', () {
    test('source defaults to Auto, per upstream', () {
      final s = SkyStreamResult.fromJson({'url': 'https://x/v.m3u8'});
      expect(s.source, 'Auto');
    });

    test('quality accepts every upstream spelling', () {
      expect(parseQualityLabel(1080), Quality.fullHd);
      expect(parseQualityLabel('1080p'), Quality.fullHd);
      expect(parseQualityLabel('720'), Quality.hd);
      expect(parseQualityLabel('4K'), Quality.uhd);
      expect(parseQualityLabel('UHD'), Quality.uhd);
      expect(parseQualityLabel('2K'), Quality.qhd);
      expect(parseQualityLabel('1440p'), Quality.qhd);
      // 0 and "Auto" mean an HLS master, i.e. no single fixed quality.
      expect(parseQualityLabel(0), Quality.unknown);
      expect(parseQualityLabel('Auto'), Quality.unknown);
    });

    test('DRM fields are detected', () {
      final s = SkyStreamResult.fromJson({
        'url': 'https://x/v.mpd', 'drmKid': 'abc', 'licenseUrl': 'https://lic',
      });
      expect(s.isDrmProtected, isTrue);
    });

    test('subtitles parse {url,label,lang}', () {
      final s = SkyStreamResult.fromJson({
        'url': 'https://x/v.mp4',
        'subtitles': [{'url': 'https://x/en.vtt', 'label': 'English', 'lang': 'en'}],
      });
      expect(s.subtitles.single.lang, 'en');
      expect(s.subtitles.single.label, 'English');
    });
  });

  group('SkyStream dashboard rule', () {
    SkyMediaItem item(String t) => SkyMediaItem.fromJson(
        {'title': t, 'url': 'u/$t', 'posterUrl': 'p', 'type': 'movie'});

    test('"Trending" becomes the hero and is removed from the rows', () {
      final layout = applySkyDashboardRule({
        'Trending': [item('a')],
        'Movies': [item('b')],
        'Series': [item('c')],
      });
      expect(layout.hero.single.title, 'a');
      expect(layout.rows.keys, ['Movies', 'Series']);
      expect(layout.rows.containsKey('Trending'), isFalse);
    });

    test('without "Trending" the FIRST category is promoted', () {
      final layout = applySkyDashboardRule({
        'Latest': [item('a')],
        'Popular': [item('b')],
      });
      expect(layout.hero.single.title, 'a');
      expect(layout.rows.keys, ['Popular']);
    });

    test('match is case-insensitive', () {
      final layout = applySkyDashboardRule({
        'Movies': [item('b')],
        'trending': [item('a')],
      });
      expect(layout.hero.single.title, 'a');
      expect(layout.rows.keys, ['Movies']);
    });

    test('empty categories are dropped', () {
      final layout = applySkyDashboardRule({
        'Trending': [item('a')],
        'Empty': <SkyMediaItem>[],
      });
      expect(layout.rows, isEmpty);
    });

    test('empty home is safe', () {
      final layout = applySkyDashboardRule({});
      expect(layout.hero, isEmpty);
      expect(layout.rows, isEmpty);
    });
  });

  group('SkyStream callback bridge', () {
    test('prelude injects manifest and the helper constructors', () {
      final js = JsSkyStreamProvider.preludeFor(
          {'packageName': 'x', 'baseUrl': 'https://site'});
      expect(js, contains('var manifest ='));
      expect(js, contains('https://site'));
      for (final ctor in [
        'MultimediaItem', 'Episode', 'StreamResult',
        'Actor', 'Trailer', 'NextAiring',
      ]) {
        expect(js, contains('function $ctor('));
        expect(js, contains('globalThis.$ctor'));
      }
    });
  });
}
