import 'package:aero_core/aero_core.dart';
import 'package:test/test.dart';

void main() {
  group('Ecosystem', () {
    test('round-trips ids', () {
      for (final e in Ecosystem.values) {
        expect(Ecosystem.fromId(e.id), e);
      }
    });
    test('classifies runtimes', () {
      expect(Ecosystem.vega.isJsBased, isTrue);
      expect(Ecosystem.nuvio.isJsBased, isTrue);
      expect(Ecosystem.skystream.isJsBased, isTrue);
      expect(Ecosystem.stremio.isJsBased, isFalse);
      expect(Ecosystem.cloudstream.requiresNativeHost, isTrue);
    });
    test('unknown id throws, tryFromId returns null', () {
      expect(() => Ecosystem.fromId('nope'), throwsArgumentError);
      expect(Ecosystem.tryFromId('nope'), isNull);
      expect(Ecosystem.tryFromId(null), isNull);
    });
  });

  group('Quality.parse', () {
    test('detects common labels', () {
      expect(Quality.parse('1080p WEB-DL'), Quality.fullHd);
      expect(Quality.parse('4K HDR'), Quality.uhd);
      expect(Quality.parse('2160p'), Quality.uhd);
      expect(Quality.parse('720p BluRay'), Quality.hd);
      expect(Quality.parse('480p'), Quality.sd);
      expect(Quality.parse('1440p'), Quality.qhd);
      expect(Quality.parse('HD'), Quality.hd);
      expect(Quality.parse('something else'), Quality.unknown);
      expect(Quality.parse(null), Quality.unknown);
      expect(Quality.parse(''), Quality.unknown);
    });
    test('is ordered', () {
      expect(Quality.uhd > Quality.fullHd, isTrue);
      expect(Quality.sd.compareTo(Quality.hd), lessThan(0));
    });
  });

  group('PlayRequest', () {
    test('builds stremio episode ids', () {
      const req = PlayRequest(
        ref: MediaRef(id: 'tt0944947', type: MediaType.series, imdbId: 'tt0944947'),
        season: 1,
        episode: 2,
      );
      expect(req.stremioVideoId, 'tt0944947:1:2');
      expect(req.isEpisode, isTrue);
    });
    test('movie id has no suffix', () {
      const req = PlayRequest(
        ref: MediaRef(id: 'tt0111161', type: MediaType.movie, imdbId: 'tt0111161'),
      );
      expect(req.stremioVideoId, 'tt0111161');
      expect(req.isEpisode, isFalse);
    });
  });

  group('id helpers', () {
    test('extractImdbId handles composites and urls', () {
      expect(extractImdbId('tt0944947:1:2'), 'tt0944947');
      expect(extractImdbId('https://imdb.com/title/tt0111161/'), 'tt0111161');
      expect(extractImdbId('12345'), isNull);
      expect(extractImdbId(null), isNull);
    });
    test('splitStremioId', () {
      final r = splitStremioId('tt0944947:2:5');
      expect(r.base, 'tt0944947');
      expect(r.season, 2);
      expect(r.episode, 5);
      final m = splitStremioId('tt0111161');
      expect(m.season, isNull);
    });
    test('title normalisation and matching', () {
      expect(normaliseTitle('The Matrix (1999)'), 'matrix');
      expect(titleYearMatches('The Matrix', 1999, 'Matrix', 1999), isTrue);
      expect(titleYearMatches('Matrix', 1999, 'Matrix', 2000), isTrue);
      expect(titleYearMatches('Matrix', 1999, 'Matrix', 2003), isFalse);
      expect(titleYearMatches('Matrix', 1999, 'Inception', 2010), isFalse);
    });
  });

  group('JSON round-trips', () {
    test('StreamLink survives round-trip', () {
      const link = StreamLink(
        url: 'https://cdn.example/v.mkv',
        sourceId: 'a',
        sourceName: 'Addon A',
        ecosystem: Ecosystem.stremio,
        kind: StreamKind.direct,
        quality: Quality.fullHd,
        sizeBytes: 1610612736,
        headers: {'Referer': 'https://example.com'},
        language: 'en',
        debrid: true,
      );
      final back = StreamLink.fromJson(link.toJson());
      expect(back.url, link.url);
      expect(back.quality, Quality.fullHd);
      expect(back.headers['Referer'], 'https://example.com');
      expect(back.debrid, isTrue);
      expect(back.sizeLabel, '1.5 GB');
      expect(back.sourceKey, 'stremio:a');
    });

    test('InstalledSource survives round-trip', () {
      const s = InstalledSource(
        id: 'org.test',
        ecosystem: Ecosystem.stremio,
        name: 'Test',
        url: 'https://x/manifest.json',
        capabilities: {Capability.streams, Capability.catalogs},
        types: [MediaType.movie],
        idPrefixes: ['tt'],
        priority: 5,
      );
      final back = InstalledSource.fromJson(s.toJson());
      expect(back.id, s.id);
      expect(back.capabilities, s.capabilities);
      expect(back.types, [MediaType.movie]);
      expect(back.priority, 5);
      expect(back.acceptsId('tt123'), isTrue);
      expect(back.acceptsId('tmdb123'), isFalse);
      expect(back.supports(MediaType.movie), isTrue);
      expect(back.supports(MediaType.series), isFalse);
    });

    test('MediaDetails keeps episodes', () {
      const d = MediaDetails(
        item: MediaItem(
          ref: MediaRef(id: 'tt1', type: MediaType.series),
          title: 'Show',
        ),
        seasons: [1, 2],
        episodes: [
          EpisodeRef(id: 'tt1:1:1', season: 1, episode: 1),
          EpisodeRef(id: 'tt1:2:1', season: 2, episode: 1),
        ],
      );
      final back = MediaDetails.fromJson(d.toJson());
      expect(back.episodes.length, 2);
      expect(back.episodesOfSeason(2).single.label, 'S02E01');
    });

    test('RankingRules round-trip', () {
      const r = RankingRules(preferredQuality: Quality.uhd, maxSizeBytes: 123);
      final back = RankingRules.fromJson(r.toJson());
      expect(back.preferredQuality, Quality.uhd);
      expect(back.maxSizeBytes, 123);
      expect(back.ecosystemOrder.length, 5);
    });
  });

  group('StreamLink helpers', () {
    test('playability by kind', () {
      const base = StreamLink(
        url: 'x',
        sourceId: 's',
        sourceName: 'S',
        ecosystem: Ecosystem.vega,
      );
      expect(base.isPlayable, isTrue);
      expect(base.copyWith(kind: StreamKind.torrent).isPlayable, isFalse);
      expect(base.copyWith(kind: StreamKind.hls).isPlayable, isTrue);
    });
    test('size formatting', () {
      const l = StreamLink(
        url: 'x',
        sourceId: 's',
        sourceName: 'S',
        ecosystem: Ecosystem.vega,
        sizeBytes: 734003200,
      );
      expect(l.sizeLabel, '700 MB');
    });
    test('subtitle format inference', () {
      const s = SubtitleTrack(id: '1', url: 'https://x/a.vtt', lang: 'en');
      expect(s.resolvedFormat, 'vtt');
      const t = SubtitleTrack(id: '2', url: 'https://x/a', lang: 'fr');
      expect(t.resolvedFormat, 'srt');
    });
  });
}
