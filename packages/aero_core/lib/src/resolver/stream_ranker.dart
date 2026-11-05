import '../models/stream_link.dart';
import 'ranking_rules.dart';

/// A link plus the score that ranked it, so the UI can explain the choice.
class RankedStream {
  const RankedStream({required this.link, required this.score, this.reasons = const []});

  final StreamLink link;
  final int score;
  final List<String> reasons;
}

/// Scores and sorts resolved links. Pure and deterministic → unit-testable.
class StreamRanker {
  const StreamRanker(this.rules);

  final RankingRules rules;

  /// Hard filters: unplayable kinds, blocked providers, over-size, over-quality.
  bool passes(StreamLink s) {
    if (!s.isPlayable) return false;
    if (rules.blockedProviders.contains(s.sourceKey)) return false;
    final max = rules.maxSizeBytes;
    if (max != null && s.sizeBytes != null && s.sizeBytes! > max) return false;
    if (!rules.allowHigherThanPreferred &&
        s.quality != Quality.unknown &&
        s.quality.height > rules.preferredQuality.height) {
      return false;
    }
    return true;
  }

  /// Higher is better. Weights are tuned so quality dominates, then provider
  /// preference, then language, then codec/HDR niceties, then latency.
  int score(StreamLink s) {
    final reasons = <String>[];
    var total = 0;

    // --- Quality: closest to preferred wins; unknown is penalised. ---
    if (s.quality == Quality.unknown) {
      if (rules.penaliseUnknownQuality) {
        total -= 15;
        reasons.add('unknown quality −15');
      }
    } else {
      final diff = (s.quality.height - rules.preferredQuality.height).abs();
      // Exact match = 100. Being *below* the preferred quality is worse than
      // being above it, so the penalty is asymmetric: 25/bucket down, 12 up.
      final steps = _bucketDistance(s.quality, rules.preferredQuality);
      final perStep = s.quality.height < rules.preferredQuality.height ? 25 : 12;
      final q = (100 - steps * perStep).clamp(0, 100);
      total += q;
      if (steps == 0) {
        reasons.add('preferred ${s.quality.label} +$q');
      } else {
        reasons.add('${s.quality.label} (Δ$diff) +$q');
      }
    }

    // --- Explicit provider order beats ecosystem order. ---
    final pIdx = rules.providerOrder.indexOf(s.sourceKey);
    if (pIdx >= 0) {
      final bonus = (30 - pIdx * 5).clamp(5, 30);
      total += bonus;
      reasons.add('provider #${pIdx + 1} +$bonus');
    } else {
      final eIdx = rules.ecosystemOrder.indexOf(s.ecosystem);
      if (eIdx >= 0) {
        final bonus = (20 - eIdx * 4).clamp(0, 20);
        total += bonus;
        if (bonus > 0) reasons.add('${s.ecosystem.displayName} +$bonus');
      }
    }

    // --- Language / audio preference. ---
    final lang = s.language?.toLowerCase();
    if (lang != null && lang.isNotEmpty) {
      final lIdx = rules.preferredLanguages
          .indexWhere((p) => lang == p.toLowerCase() || lang.startsWith(p.toLowerCase()));
      if (lIdx >= 0) {
        final bonus = (18 - lIdx * 4).clamp(4, 18);
        total += bonus;
        reasons.add('language $lang +$bonus');
      }
    }

    // --- Codec: prefer widely hardware-decoded formats on TV boxes. ---
    final codec = s.codec?.toLowerCase() ??
        _codecFromText(s.qualityHint.toLowerCase());
    if (codec != null) {
      if (rules.preferredCodecs.any((c) => codec.contains(c.toLowerCase()))) {
        total += 8;
        reasons.add('codec $codec +8');
      } else if (codec.contains('av1')) {
        // AV1 still software-decodes on many low-end boxes.
        total -= 6;
        reasons.add('AV1 −6');
      }
    }

    // --- HDR only when the user asked for it. ---
    if (s.isHdr) {
      total += rules.preferHdr ? 10 : -4;
      reasons.add(rules.preferHdr ? 'HDR +10' : 'HDR −4');
    }

    // --- Debrid-resolved links are more reliable than raw hosters. ---
    if (s.debrid) {
      total += 12;
      reasons.add('debrid +12');
    }

    // --- Smaller is slightly better at equal quality (faster start). ---
    final size = s.sizeBytes;
    if (size != null && size > 0) {
      final gb = size / (1024 * 1024 * 1024);
      if (gb > 8) {
        total -= 8;
        reasons.add('very large −8');
      } else if (gb < 3 && s.quality.height >= 1080) {
        total += 4;
        reasons.add('compact +4');
      }
    }

    // --- Latency tiebreak. ---
    final lat = s.latencyMs;
    if (lat != null) {
      if (lat < 400) {
        total += 5;
      } else if (lat > 2500) {
        total -= 5;
      }
    }

    // --- HLS/DASH adapt better on flaky networks than huge MP4s. ---
    if (s.kind == StreamKind.hls || s.kind == StreamKind.dash) {
      total += 3;
      reasons.add('adaptive +3');
    }

    return total;
  }

  /// Number of quality buckets between two qualities.
  int _bucketDistance(Quality a, Quality b) {
    const order = [Quality.sd, Quality.hd, Quality.fullHd, Quality.qhd, Quality.uhd];
    final ai = order.indexOf(a);
    final bi = order.indexOf(b);
    if (ai < 0 || bi < 0) return 3;
    return (ai - bi).abs();
  }

  String? _codecFromText(String t) {
    for (final c in ['av1', 'x265', 'h265', 'hevc', 'x264', 'h264', 'avc', 'vp9']) {
      if (t.contains(c)) return c;
    }
    return null;
  }

  /// Filters, scores and sorts descending. Stable for equal scores so the
  /// user's provider order is respected.
  List<RankedStream> rank(Iterable<StreamLink> links) {
    final out = <RankedStream>[];
    for (final s in links) {
      if (!passes(s)) continue;
      out.add(RankedStream(link: s, score: score(s), reasons: _explain(s)));
    }
    out.sort((a, b) {
      final c = b.score.compareTo(a.score);
      if (c != 0) return c;
      final ai = rules.providerOrder.indexOf(a.link.sourceKey);
      final bi = rules.providerOrder.indexOf(b.link.sourceKey);
      if (ai != bi) {
        if (ai < 0) return 1;
        if (bi < 0) return -1;
        return ai.compareTo(bi);
      }
      return a.link.sourceName.compareTo(b.link.sourceName);
    });
    return out;
  }

  List<String> _explain(StreamLink s) {
    // Re-run scoring but capture reasons via a lightweight second pass.
    final probe = <String>[];
    if (s.quality != Quality.unknown) probe.add(s.quality.label);
    if (s.language != null) probe.add(s.language!);
    if (s.sizeLabel != null) probe.add(s.sizeLabel!);
    if (s.debrid) probe.add('debrid');
    return probe;
  }

  /// Best link for auto-play, or null when nothing clears the guard rail.
  RankedStream? bestForAutoPlay(Iterable<StreamLink> links) {
    final ranked = rank(links);
    if (ranked.isEmpty) return null;
    final top = ranked.first;
    if (top.score < rules.minScoreForAutoPlay) return null;
    return top;
  }
}
