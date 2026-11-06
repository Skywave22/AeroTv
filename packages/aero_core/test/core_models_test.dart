import 'package:aero_core/aero_core.dart';
import 'package:test/test.dart';

/// Coverage for the small core value types everything else builds on.
void main() {
  group('Result', () {
    test('Ok carries a value and no error', () {
      const r = Ok<int>(7);
      expect(r.isOk, isTrue);
      expect(r.isErr, isFalse);
      expect(r.valueOrNull, 7);
      expect(r.errorOrNull, isNull);
      expect(r.orElse(0), 7);
    });

    test('Err carries a message and no value', () {
      const r = Err<int>('boom');
      expect(r.isOk, isFalse);
      expect(r.isErr, isTrue);
      expect(r.valueOrNull, isNull);
      expect(r.errorOrNull, 'boom');
      expect(r.orElse(0), 0);
      expect(r.toString(), contains('boom'));
    });

    test('when dispatches to the right branch', () {
      String d(Result<int> r) => r.when(ok: (v) => 'ok:$v', err: (e) => 'err:$e');
      expect(d(const Ok(1)), 'ok:1');
      expect(d(const Err('x')), 'err:x');
    });

    test('Err keeps an optional detail', () {
      expect(const Err<int>('failed', 'underlying').detail, 'underlying');
    });

    test('exception types render usefully', () {
      expect(const AeroException('bad').toString(), contains('bad'));
      expect(const AeroException('bad', 'cause').toString(), contains('cause'));
      expect(const UnsupportedPlatformException('tv only'), isA<AeroException>());
      expect(const SandboxException('over budget'), isA<AeroException>());
    });
  });

  group('PlayRequest', () {
    const movie = PlayRequest(
        ref: MediaRef(id: 'tt0111161', type: MediaType.movie, imdbId: 'tt0111161'));
    const episode = PlayRequest(
        ref: MediaRef(id: 'tt0903747', type: MediaType.series, imdbId: 'tt0903747'),
        season: 1, episode: 2);

    test('a movie is not an episode', () {
      expect(movie.isEpisode, isFalse);
      expect(movie.stremioVideoId, 'tt0111161');
    });

    test('an episode builds the colon-delimited video id', () {
      expect(episode.isEpisode, isTrue);
      expect(episode.stremioVideoId, 'tt0903747:1:2');
    });

    test('falls back to the native id without an IMDb id', () {
      const r = PlayRequest(
          ref: MediaRef(id: 'kitsu:123', type: MediaType.series), season: 1, episode: 1);
      expect(r.stremioVideoId, 'kitsu:123:1:1');
    });

    test('season alone does not make an episode', () {
      const r = PlayRequest(ref: MediaRef(id: 'tt1', type: MediaType.series), season: 3);
      expect(r.isEpisode, isFalse);
      expect(r.stremioVideoId, 'tt1');
    });

    test('cache keys separate episodes', () {
      const e2 = PlayRequest(
          ref: MediaRef(id: 'tt0903747', type: MediaType.series, imdbId: 'tt0903747'),
          season: 1, episode: 3);
      expect(episode.cacheKey, isNot(e2.cacheKey));
      expect(movie.cacheKey, isNot(episode.cacheKey));
    });

    test('round-trips through JSON', () {
      const r = PlayRequest(
          ref: MediaRef(id: 'tt1', type: MediaType.series, imdbId: 'tt1'),
          season: 2, episode: 5, episodeId: 'native-ep', bingeGroup: 'grp');
      final back = PlayRequest.fromJson(r.toJson());
      expect(back.stremioVideoId, r.stremioVideoId);
      expect(back.episodeId, 'native-ep');
      expect(back.bingeGroup, 'grp');
      expect(back.toString(), contains('tt1'));
    });
  });

  group('SubtitleTrack', () {
    test('infers format from the URL extension', () {
      for (final e in {
        'https://x/a.srt': 'srt', 'https://x/a.vtt': 'vtt', 'https://x/a.ass': 'ass',
        'https://x/a.ssa': 'ssa', 'https://x/a.ttml': 'ttml', 'https://x/a.sub': 'sub',
      }.entries) {
        expect(SubtitleTrack(id: '1', url: e.key, lang: 'eng').resolvedFormat, e.value);
      }
    });

    test('defaults to srt without a recognised extension', () {
      expect(const SubtitleTrack(id: '1', url: 'https://x/sub?id=9', lang: 'eng').resolvedFormat, 'srt');
    });

    test('an explicit format wins and is normalised', () {
      expect(const SubtitleTrack(id: '1', url: 'https://x/a.srt', lang: 'eng', format: '.VTT').resolvedFormat, 'vtt');
    });

    test('display label falls back to uppercased language', () {
      expect(const SubtitleTrack(id: '1', url: 'u', lang: 'eng', label: 'English (SDH)').displayLabel, 'English (SDH)');
      expect(const SubtitleTrack(id: '1', url: 'u', lang: 'spa').displayLabel, 'SPA');
    });

    test('round-trips and defaults missing language to und', () {
      const t = SubtitleTrack(id: 's', url: 'https://x/a.vtt', lang: 'eng', sourceKey: 'addon:1');
      final back = SubtitleTrack.fromJson(t.toJson());
      expect(back.url, t.url);
      expect(back.sourceKey, 'addon:1');
      expect(SubtitleTrack.fromJson({'url': 'u'}).lang, 'und');
      expect(SubtitleTrack.fromJson({'url': 'u'}).id, 'u');
    });
  });

  group('CatalogQuery', () {
    test('empty query produces no extras', () {
      expect(const CatalogQuery().toExtraMap(), isEmpty);
    });

    test('packs genre, search and skip', () {
      expect(const CatalogQuery(genre: 'Action', search: 'bat', skip: 100).toExtraMap(),
          {'genre': 'Action', 'search': 'bat', 'skip': '100'});
    });

    test('skip=0 is omitted so the first page URL stays canonical', () {
      expect(const CatalogQuery(skip: 0).toExtraMap().containsKey('skip'), isFalse);
    });

    test('blank genre and search are dropped', () {
      expect(const CatalogQuery(genre: '', search: '').toExtraMap(), isEmpty);
    });

    test('explicit extras merge and can override', () {
      const q = CatalogQuery(genre: 'Action', extra: {'genre': 'Drama', 'x': '1'});
      expect(q.toExtraMap()['genre'], 'Drama');
      expect(q.toExtraMap()['x'], '1');
    });

    test('nextPage advances skip and preserves filters', () {
      const q = CatalogQuery(genre: 'Action', search: 'bat');
      final next = q.nextPage(50);
      expect(next.skip, 50);
      expect(next.genre, 'Action');
      expect(next.search, 'bat');
      expect(next.nextPage(50).skip, 100);
    });
  });

  group('Page', () {
    test('empty page has no items and no cursor', () {
      final p = Page.empty<MediaItem>();
      expect(p.items, isEmpty);
      expect(p.hasMore, isFalse);
      expect(p.nextSkip, isNull);
    });

    test('carries a pagination cursor', () {
      const p = Page<int>(items: [1, 2], hasMore: true, nextSkip: 2);
      expect(p.hasMore, isTrue);
      expect(p.nextSkip, 2);
    });
  });

  group('InstalledSource', () {
    InstalledSource build({
      List<MediaType> types = const [],
      List<String> prefixes = const [],
      Set<Capability> caps = const {Capability.streams},
    }) =>
        InstalledSource(
          id: 'addon1', ecosystem: Ecosystem.stremio, name: 'Addon',
          url: 'https://x/manifest.json', version: '1.0.0',
          types: types, idPrefixes: prefixes, capabilities: caps,
        );

    test('key namespaces the id by ecosystem', () => expect(build().key, 'stremio:addon1'));

    test('no declared types means it supports everything', () {
      expect(build().supports(MediaType.movie), isTrue);
      expect(build().supports(MediaType.channel), isTrue);
    });

    test('declared types gate support', () {
      final s = build(types: [MediaType.movie]);
      expect(s.supports(MediaType.movie), isTrue);
      expect(s.supports(MediaType.series), isFalse);
    });

    test('id prefixes gate which ids are worth requesting', () {
      final s = build(prefixes: ['tt']);
      expect(s.acceptsId('tt0111161'), isTrue);
      expect(s.acceptsId('kitsu:1'), isFalse);
      expect(build().acceptsId('anything'), isTrue);
    });

    test('capability check drives the UI', () {
      expect(build().can(Capability.streams), isTrue);
      expect(build().can(Capability.catalogs), isFalse);
    });

    test('copyWith changes only what is asked', () {
      final s = build();
      final off = s.copyWith(enabled: false, priority: 5);
      expect(off.enabled, isFalse);
      expect(off.priority, 5);
      expect(off.id, s.id);
      expect(off.name, s.name);
    });

    test('round-trips through JSON', () {
      final s = build(types: [MediaType.movie], prefixes: ['tt']);
      final back = InstalledSource.fromJson(s.toJson());
      expect(back.key, s.key);
      expect(back.url, s.url);
      expect(back.supports(MediaType.movie), isTrue);
      expect(back.acceptsId('tt1'), isTrue);
    });
  });

  group('SourceRef', () {
    test('round-trips the fields install needs', () {
      const r = SourceRef(
          ecosystem: Ecosystem.vega, url: 'https://x/dist/a.js',
          repoId: 'https://x/manifest.json', name: 'A', version: '2', expectedSha256: 'abc');
      final j = r.toJson();
      expect(j['ecosystem'], 'vega');
      expect(j['repoId'], 'https://x/manifest.json');
      expect(j['expectedSha256'], 'abc');
    });

    test('extra carries the raw repository entry', () {
      const r = SourceRef(ecosystem: Ecosystem.vega, url: 'u', extra: {'value': 'provider-a'});
      expect(r.extra['value'], 'provider-a');
    });
  });
}
