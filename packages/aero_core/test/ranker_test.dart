import 'package:aero_core/aero_core.dart';
import 'package:test/test.dart';

StreamLink mk({
  Quality q = Quality.fullHd,
  Ecosystem eco = Ecosystem.stremio,
  String source = 'a',
  int? size,
  String? lang,
  String? codec,
  bool hdr = false,
  bool debrid = false,
  StreamKind kind = StreamKind.direct,
  String url = 'https://cdn/x.mkv',
}) =>
    StreamLink(
      url: url,
      sourceId: source,
      sourceName: source.toUpperCase(),
      ecosystem: eco,
      quality: q,
      sizeBytes: size,
      language: lang,
      codec: codec,
      isHdr: hdr,
      debrid: debrid,
      kind: kind,
    );

void main() {
  group('StreamRanker.passes', () {
    const ranker = StreamRanker(RankingRules());

    test('rejects unplayable kinds', () {
      expect(ranker.passes(mk(kind: StreamKind.torrent)), isFalse);
      expect(ranker.passes(mk(kind: StreamKind.youtube)), isFalse);
      expect(ranker.passes(mk(kind: StreamKind.external)), isFalse);
      expect(ranker.passes(mk(kind: StreamKind.hls)), isTrue);
      expect(ranker.passes(mk(kind: StreamKind.dash)), isTrue);
    });

    test('respects max size', () {
      const r = StreamRanker(RankingRules(maxSizeBytes: 1000));
      expect(r.passes(mk(size: 999)), isTrue);
      expect(r.passes(mk(size: 1001)), isFalse);
      expect(r.passes(mk()), isTrue, reason: 'unknown size is allowed');
    });

    test('respects blocked providers', () {
      const r = StreamRanker(RankingRules(blockedProviders: ['stremio:a']));
      expect(r.passes(mk()), isFalse);
      expect(r.passes(mk(source: 'b')), isTrue);
    });

    test('can cap quality ceiling', () {
      const r = StreamRanker(
        RankingRules(preferredQuality: Quality.hd, allowHigherThanPreferred: false),
      );
      expect(r.passes(mk(q: Quality.uhd)), isFalse);
      expect(r.passes(mk(q: Quality.hd)), isTrue);
      expect(r.passes(mk(q: Quality.unknown)), isTrue);
    });
  });

  group('StreamRanker.rank', () {
    test('prefers the preferred quality', () {
      const r = StreamRanker(RankingRules(preferredQuality: Quality.fullHd));
      final ranked = r.rank([mk(q: Quality.sd), mk(q: Quality.fullHd), mk(q: Quality.uhd)]);
      expect(ranked.first.link.quality, Quality.fullHd);
      expect(ranked.last.link.quality, Quality.sd);
    });

    test('provider order beats ecosystem order', () {
      const r = StreamRanker(
        RankingRules(providerOrder: ['vega:z', 'stremio:a']),
      );
      final ranked = r.rank([mk(source: 'a'), mk(eco: Ecosystem.vega, source: 'z')]);
      expect(ranked.first.link.sourceKey, 'vega:z');
    });

    test('language preference is a tiebreak, not an override of quality', () {
      const r = StreamRanker(RankingRules(preferredLanguages: ['en']));
      final ranked = r.rank([
        mk(q: Quality.fullHd, lang: 'de'),
        mk(q: Quality.fullHd, lang: 'en'),
      ]);
      expect(ranked.first.link.language, 'en');
    });

    test('debrid and adaptive streams get a bump', () {
      const r = StreamRanker(RankingRules());
      final ranked = r.rank([mk(), mk(debrid: true)]);
      expect(ranked.first.link.debrid, isTrue);
    });

    test('AV1 is penalised for low-end hardware', () {
      const r = StreamRanker(RankingRules());
      final ranked = r.rank([mk(codec: 'x264'), mk(codec: 'av1')]);
      expect(ranked.first.link.codec, 'x264');
    });

    test('HDR only wins when requested', () {
      const off = StreamRanker(RankingRules(preferHdr: false));
      expect(off.rank([mk(hdr: true), mk()]).first.link.isHdr, isFalse);
      const on = StreamRanker(RankingRules(preferHdr: true));
      expect(on.rank([mk(hdr: true), mk()]).first.link.isHdr, isTrue);
    });

    test('deterministic ordering for identical links', () {
      const r = StreamRanker(RankingRules());
      final a = r.rank([mk(source: 'b'), mk(source: 'a')]);
      final b = r.rank([mk(source: 'a'), mk(source: 'b')]);
      expect(a.map((e) => e.link.sourceName), b.map((e) => e.link.sourceName));
    });
  });

  group('auto-play guard rail', () {
    test('returns null when nothing is playable', () {
      const r = StreamRanker(RankingRules(autoPlayEnabled: true));
      expect(r.bestForAutoPlay([mk(kind: StreamKind.torrent)]), isNull);
    });

    test('returns null below the minimum score', () {
      const r = StreamRanker(RankingRules(minScoreForAutoPlay: 500));
      expect(r.bestForAutoPlay([mk()]), isNull);
    });

    test('returns the best link when it clears the bar', () {
      const r = StreamRanker(RankingRules(autoPlayEnabled: true));
      final best = r.bestForAutoPlay([mk(q: Quality.sd), mk(q: Quality.fullHd)]);
      expect(best, isNotNull);
      expect(best!.link.quality, Quality.fullHd);
    });
  });
}
