/// Normalisation and scoring for matching a known title (from an IMDb-keyed
/// add-on) against a plugin's own search results.
///
/// Match-based ecosystems (Vega-style) have no IMDb id: they need a provider
/// link found by searching their own catalogue. A wrong match plays the wrong
/// film, so scoring is conservative and the caller can override it.
library;

/// A candidate returned by a plugin's search.
class TitleCandidate {
  const TitleCandidate({
    required this.title,
    required this.link,
    this.year,
    this.type,
    this.poster,
  });

  final String title;
  final String link;
  final int? year;
  final String? type;

  /// Optional artwork, shown in the "Wrong match?" picker.
  final String? poster;
}

/// How a candidate scored against the request.
class TitleMatch {
  const TitleMatch(this.candidate, this.score, {this.pinned = false});
  final TitleCandidate candidate;
  final double score;

  /// True when the user chose this candidate themselves. A pinned match is
  /// trusted unconditionally and is never replaced by a better-scoring guess.
  final bool pinned;

  /// A pinned match is always usable; an auto match must clear the threshold.
  bool get isUsable => pinned || score >= TitleMatcher.acceptThreshold;
}

abstract final class TitleMatcher {
  /// Minimum score to accept automatically. Below this the caller should ask
  /// the user rather than silently play something else.
  static const double acceptThreshold = 0.75;

  /// Score at which we stop searching alternative query spellings.
  static const double confidentThreshold = 0.9;

  static const Map<String, String> _diacritics = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
    'ñ': 'n', 'ç': 'c', 'ý': 'y', 'ÿ': 'y', 'ß': 'ss', 'æ': 'ae', 'œ': 'oe',
  };

  /// Lowercase, fold diacritics, drop bracketed year/quality tags, drop season
  /// suffixes and a leading article, and collapse whitespace.
  static String normalise(String input) {
    var s = input.toLowerCase();

    // Fold diacritics one code unit at a time.
    final buf = StringBuffer();
    for (final ch in s.split('')) {
      buf.write(_diacritics[ch] ?? ch);
    }
    s = buf.toString();

    // (2019), [1080p], {extra}
    s = s.replaceAll(RegExp(r'[\(\[\{][^\)\]\}]*[\)\]\}]'), ' ');
    // Trailing bare year: "Movie 2019"
    s = s.replaceAll(RegExp(r'\b(19|20)\d{2}\b'), ' ');
    // Season / episode markers.
    s = s.replaceAll(
        RegExp(r'\b(s\d{1,2}\s*e\d{1,3}|season\s*\d+|episode\s*\d+|s\d{1,2})\b'),
        ' ');
    // Apostrophes join words rather than split them: "Ocean's" -> "oceans",
    // not "ocean s". Scrapers drop them inconsistently.
    s = s.replaceAll(RegExp(r"['\u2019`]"), '');
    // Everything that is not a letter, digit or space.
    s = s.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Leading article, only when something follows it.
    final words = s.split(' ');
    if (words.length > 1 && const {'the', 'a', 'an'}.contains(words.first)) {
      s = words.sublist(1).join(' ');
    }
    return s;
  }

  /// Levenshtein distance, iterative with two rows.
  static int _editDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    var curr = List<int>.filled(b.length + 1, 0);
    for (var i = 1; i <= a.length; i++) {
      curr[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        var m = prev[j] + 1;
        final del = curr[j - 1] + 1;
        if (del < m) m = del;
        final sub = prev[j - 1] + cost;
        if (sub < m) m = sub;
        curr[j] = m;
      }
      final t = prev;
      prev = curr;
      curr = t;
    }
    return prev[b.length];
  }

  static double _ratio(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 1;
    final longest = a.length > b.length ? a.length : b.length;
    if (longest == 0) return 1;
    return 1 - _editDistance(a, b) / longest;
  }

  /// Token-set similarity: rewards the same words in a different order, which
  /// is common between an add-on title and a scraper's title.
  static double _tokenSetRatio(String a, String b) {
    final sa = a.split(' ').where((w) => w.isNotEmpty).toSet();
    final sb = b.split(' ').where((w) => w.isNotEmpty).toSet();
    if (sa.isEmpty || sb.isEmpty) return 0;
    final inter = sa.intersection(sb).length;
    final union = sa.union(sb).length;
    final jaccard = inter / union;
    // Also compare the sorted intersection against each full set, so a
    // subtitle ("Movie: Something") is not punished too harshly.
    final common = (sa.intersection(sb).toList()..sort()).join(' ');
    final ra = _ratio(common, (sa.toList()..sort()).join(' '));
    final rb = _ratio(common, (sb.toList()..sort()).join(' '));
    return (jaccard + ra + rb) / 3;
  }

  /// Pure string similarity in 0..1, on normalised inputs.
  static double similarity(String a, String b) {
    final na = normalise(a);
    final nb = normalise(b);
    if (na.isEmpty || nb.isEmpty) return 0;
    if (na == nb) return 1;
    final lev = _ratio(na, nb);
    final tok = _tokenSetRatio(na, nb);
    // Weight the token set higher: word order and subtitles vary a lot.
    return 0.4 * lev + 0.6 * tok;
  }

  /// ±1 year is tolerated (festival vs release year); further off is penalised.
  static double yearBonus(int? candidateYear, int? wantedYear) {
    if (candidateYear == null || wantedYear == null) return 0;
    final d = (candidateYear - wantedYear).abs();
    if (d == 0) return 0.08;
    if (d == 1) return 0.03;
    if (d <= 2) return -0.05;
    return -0.25;
  }

  static double typeBonus(String? candidateType, String? wantedType) {
    if (candidateType == null || wantedType == null) return 0;
    return candidateType.toLowerCase() == wantedType.toLowerCase() ? 0.04 : -0.15;
  }

  /// Scores one candidate. Clamped to 0..1.
  static double score(
    TitleCandidate c, {
    required String title,
    int? year,
    String? type,
  }) {
    final s = similarity(c.title, title) +
        yearBonus(c.year, year) +
        typeBonus(c.type, type);
    return s.clamp(0.0, 1.0);
  }

  /// Picks the best candidate, or null when nothing clears [acceptThreshold].
  static TitleMatch? best(
    List<TitleCandidate> candidates, {
    required String title,
    int? year,
    String? type,
    double threshold = acceptThreshold,
  }) {
    TitleMatch? top;
    for (final c in candidates) {
      final s = score(c, title: title, year: year, type: type);
      if (top == null || s > top.score) top = TitleMatch(c, s);
    }
    if (top == null || top.score < threshold) return null;
    return top;
  }

  /// Ranks all candidates, best first — used by the "Wrong match?" picker.
  static List<TitleMatch> rank(
    List<TitleCandidate> candidates, {
    required String title,
    int? year,
    String? type,
  }) {
    final scored = candidates
        .map((c) => TitleMatch(c, score(c, title: title, year: year, type: type)))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return scored;
  }

  /// Parses a season/episode out of an episode title, covering the common
  /// spellings scrapers use: "S01E02", "1x02", "Episode 2", or a bare number.
  static (int, int)? parseEpisode(String title, {int defaultSeason = 1}) {
    final s = title.toLowerCase();
    var m = RegExp(r's(\d{1,2})\s*e(\d{1,3})').firstMatch(s);
    if (m != null) return (int.parse(m.group(1)!), int.parse(m.group(2)!));
    m = RegExp(r'(\d{1,2})x(\d{1,3})').firstMatch(s);
    if (m != null) return (int.parse(m.group(1)!), int.parse(m.group(2)!));
    m = RegExp(r'season\s*(\d{1,2}).{0,12}?episode\s*(\d{1,3})').firstMatch(s);
    if (m != null) return (int.parse(m.group(1)!), int.parse(m.group(2)!));
    m = RegExp(r'episode\s*(\d{1,3})').firstMatch(s);
    if (m != null) return (defaultSeason, int.parse(m.group(1)!));
    m = RegExp(r'^\s*(\d{1,3})\s*$').firstMatch(s);
    if (m != null) return (defaultSeason, int.parse(m.group(1)!));
    return null;
  }
}
