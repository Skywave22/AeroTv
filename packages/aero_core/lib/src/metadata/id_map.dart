/// A cached bundle of external IDs for one title.
class IdMap {
  const IdMap({this.imdbId, this.tmdbId, this.tvdbId, this.title, this.year, this.type});

  final String? imdbId;
  final String? tmdbId;
  final String? tvdbId;
  final String? title;
  final int? year;
  final String? type;

  bool get isEmpty => imdbId == null && tmdbId == null && tvdbId == null;

  Map<String, dynamic> toJson() => {
        if (imdbId != null) 'imdbId': imdbId,
        if (tmdbId != null) 'tmdbId': tmdbId,
        if (tvdbId != null) 'tvdbId': tvdbId,
        if (title != null) 'title': title,
        if (year != null) 'year': year,
        if (type != null) 'type': type,
      };

  factory IdMap.fromJson(Map<String, dynamic> j) => IdMap(
        imdbId: j['imdbId'] as String?,
        tmdbId: j['tmdbId']?.toString(),
        tvdbId: j['tvdbId']?.toString(),
        title: j['title'] as String?,
        year: (j['year'] as num?)?.toInt(),
        type: j['type'] as String?,
      );

  IdMap merge(IdMap other) => IdMap(
        imdbId: imdbId ?? other.imdbId,
        tmdbId: tmdbId ?? other.tmdbId,
        tvdbId: tvdbId ?? other.tvdbId,
        title: title ?? other.title,
        year: year ?? other.year,
        type: type ?? other.type,
      );
}

/// Extracts an IMDb id from arbitrary text/ids. Handles bare `tt1234567`,
/// URLs, and Stremio composite episode ids (`tt1234567:1:2`).
String? extractImdbId(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final m = RegExp(r'(tt\d{7,10})').firstMatch(raw);
  return m?.group(1);
}

/// Splits a Stremio video id into (base, season, episode).
({String base, int? season, int? episode}) splitStremioId(String id) {
  final parts = id.split(':');
  if (parts.length >= 3) {
    return (
      base: parts[0],
      season: int.tryParse(parts[1]),
      episode: int.tryParse(parts[2]),
    );
  }
  return (base: id, season: null, episode: null);
}

/// Normalises a title for fuzzy fallback matching: lowercase, strip punctuation
/// and articles, collapse whitespace.
String normaliseTitle(String title) {
  var t = title.toLowerCase();
  t = t.replaceAll(RegExp(r'\((\d{4})\)'), ' ');
  t = t.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
  t = t.replaceAll(RegExp(r'\b(the|a|an)\b'), ' ');
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Loose equality used when no ID match exists and we fall back to title+year.
bool titleYearMatches(String aTitle, int? aYear, String bTitle, int? bYear) {
  if (normaliseTitle(aTitle) != normaliseTitle(bTitle)) return false;
  if (aYear == null || bYear == null) return true;
  // Providers often list a series' premiere year vs an episode's air year.
  return (aYear - bYear).abs() <= 1;
}
