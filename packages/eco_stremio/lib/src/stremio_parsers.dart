import 'package:aero_core/aero_core.dart';

/// Parsers that turn Stremio JSON into unified models.
///
/// These are intentionally tolerant: real-world add-ons omit fields, use
/// `title` where the spec now says `description`, and return numbers as
/// strings. Nothing here should throw on malformed input.
class StremioParsers {
  const StremioParsers._();

  /// `meta` preview object → [MediaItem].
  static MediaItem? metaPreview(Map<String, dynamic> j) {
    final id = j['id']?.toString();
    if (id == null || id.isEmpty) return null;
    final type = MediaType.fromWire(j['type'] as String?);
    final imdb = extractImdbId(id) ?? extractImdbId(j['imdb_id']?.toString());
    return MediaItem(
      ref: MediaRef(
        id: id,
        type: type,
        imdbId: imdb,
        tmdbId: j['tmdb_id']?.toString(),
        title: j['name']?.toString(),
        year: _year(j['releaseInfo'] ?? j['year']),
      ),
      title: (j['name'] ?? j['title'] ?? 'Untitled').toString(),
      poster: _str(j['poster']),
      background: _str(j['background']),
      logo: _str(j['logo']),
      description: _str(j['description']),
      year: _year(j['releaseInfo'] ?? j['year']),
      genres: _strList(j['genres'] ?? j['genre']),
      imdbRating: _double(j['imdbRating']),
      runtime: _str(j['runtime']),
    );
  }

  /// Full `meta` object → [MediaDetails], including season/episode parsing.
  static MediaDetails? metaDetail(Map<String, dynamic> j) {
    final item = metaPreview(j);
    if (item == null) return null;

    final episodes = <EpisodeRef>[];
    final seasonSet = <int>{};
    for (final v in (j['videos'] as List? ?? const [])) {
      if (v is! Map) continue;
      final m = Map<String, dynamic>.from(v);
      final season = _int(m['season']);
      final episode = _int(m['episode']);
      // Skip specials (season 0) unless that's all we have.
      if (season == null || episode == null) continue;
      final vid = m['id']?.toString() ?? '${item.id}:$season:$episode';
      episodes.add(EpisodeRef(
        id: vid,
        season: season,
        episode: episode,
        title: _str(m['title']) ?? _str(m['name']),
        overview: _str(m['overview']),
        thumbnail: _str(m['thumbnail']),
        released: DateTime.tryParse(m['released']?.toString() ?? ''),
      ));
      seasonSet.add(season);
    }
    episodes.sort((a, b) {
      final s = a.season.compareTo(b.season);
      return s != 0 ? s : a.episode.compareTo(b.episode);
    });

    final trailers = <String>[];
    for (final t in (j['trailers'] as List? ?? const [])) {
      if (t is Map) {
        final src = t['ytId'] ?? t['source'];
        if (src != null) trailers.add(src.toString());
      } else if (t is String) {
        trailers.add(t);
      }
    }
    // `trailerStreams` is the newer shape.
    for (final t in (j['trailerStreams'] as List? ?? const [])) {
      if (t is Map && t['ytId'] != null) trailers.add(t['ytId'].toString());
    }

    return MediaDetails(
      item: item,
      cast: _strList(j['cast']),
      directors: _strList(j['director']),
      seasons: seasonSet.toList()..sort(),
      episodes: episodes,
      trailers: trailers,
      countries: _strList(j['country']),
      language: _str(j['language']),
      certification: _str(j['certification']),
    );
  }

  /// `stream` object → [StreamLink].
  ///
  /// Honors `behaviorHints.proxyHeaders` (request headers required for
  /// playback) and `notWebReady`. Torrent-only streams are returned with
  /// [StreamKind.torrent] so the UI can label them as unsupported unless a
  /// debrid add-on already produced a direct URL.
  static StreamLink? stream(
    Map<String, dynamic> j, {
    required String sourceId,
    required String sourceName,
  }) {
    final hints = Map<String, dynamic>.from(j['behaviorHints'] as Map? ?? const {});
    final url = _str(j['url']);
    final infoHash = _str(j['infoHash']);
    final ytId = _str(j['ytId']);
    final externalUrl = _str(j['externalUrl']);

    // Nothing playable and nothing to label → drop it.
    if (url == null && infoHash == null && ytId == null && externalUrl == null) {
      return null;
    }

    final headers = <String, String>{};
    final proxy = hints['proxyHeaders'];
    if (proxy is Map) {
      final req = proxy['request'];
      if (req is Map) {
        req.forEach((k, v) {
          if (v != null) headers[k.toString()] = v.toString();
        });
      }
    }

    final kind = url != null
        ? _kindFromUrl(url)
        : infoHash != null
            ? StreamKind.torrent
            : ytId != null
                ? StreamKind.youtube
                : StreamKind.external;

    // `description` is the current field; `title` is the deprecated one.
    final description = _str(j['description']) ?? _str(j['title']);
    final name = _str(j['name']);
    final hintText = [name, description, url].whereType<String>().join(' ');
    final lower = hintText.toLowerCase();

    final subtitles = <SubtitleTrack>[];
    for (final s in (j['subtitles'] as List? ?? const [])) {
      if (s is! Map) continue;
      final st = SubtitleTrack.fromJson(Map<String, dynamic>.from(s));
      if (st.url.isNotEmpty) subtitles.add(st);
    }

    return StreamLink(
      url: url ?? (ytId != null ? 'https://youtube.com/watch?v=$ytId' : externalUrl ?? ''),
      sourceId: sourceId,
      sourceName: sourceName,
      ecosystem: Ecosystem.stremio,
      kind: kind,
      quality: Quality.parse(hintText),
      title: name,
      description: description,
      sizeBytes: _int(hints['videoSize']) ?? _parseSize(hintText),
      language: _guessLanguage(hintText),
      headers: headers,
      subtitles: subtitles,
      bingeGroup: _str(hints['bingeGroup']),
      infoHash: infoHash,
      fileIdx: _int(j['fileIdx']),
      notWebReady: hints['notWebReady'] == true,
      isHdr: lower.contains('hdr') || lower.contains('dolby vision') || lower.contains('dv '),
      codec: _guessCodec(lower),
      // A direct URL that came from a torrent hash is a debrid-resolved link.
      debrid: url != null &&
          (lower.contains('debrid') ||
              lower.contains('real-debrid') ||
              lower.contains('realdebrid') ||
              lower.contains('premiumize') ||
              lower.contains('alldebrid') ||
              lower.contains('torbox')),
    );
  }

  static StreamKind _kindFromUrl(String url) {
    final u = url.toLowerCase();
    if (u.contains('.m3u8') || u.contains('format=m3u8') || u.contains('/hls')) {
      return StreamKind.hls;
    }
    if (u.contains('.mpd') || u.contains('format=mpd') || u.contains('/dash')) {
      return StreamKind.dash;
    }
    if (u.startsWith('magnet:')) return StreamKind.torrent;
    return StreamKind.direct;
  }

  static String? _guessCodec(String t) {
    for (final c in ['av1', 'x265', 'h265', 'hevc', 'x264', 'h264', 'avc', 'vp9']) {
      if (t.contains(c)) return c;
    }
    return null;
  }

  static String? _guessLanguage(String text) {
    final t = text.toLowerCase();
    const map = {
      'english': 'en', 'hindi': 'hi', 'urdu': 'ur', 'spanish': 'es',
      'french': 'fr', 'german': 'de', 'italian': 'it', 'portuguese': 'pt',
      'russian': 'ru', 'japanese': 'ja', 'korean': 'ko', 'chinese': 'zh',
      'arabic': 'ar', 'turkish': 'tr', 'tamil': 'ta', 'telugu': 'te',
      'malayalam': 'ml', 'punjabi': 'pa', 'bengali': 'bn',
    };
    for (final e in map.entries) {
      if (t.contains(e.key)) return e.value;
    }
    // Common scene tags: MULTI, DUAL, [EN], .en.
    final m = RegExp(r'\b(en|hi|ur|es|fr|de|it|pt|ru|ja|ko|zh|ar|tr|ta|te|ml)\b')
        .firstMatch(t);
    return m?.group(1);
  }

  /// Parses "1.4 GB" / "700MB" out of provider text.
  static int? _parseSize(String text) {
    final m = RegExp(r'([\d.,]+)\s*(GB|MB|KB|GiB|MiB|TB)\b', caseSensitive: false)
        .firstMatch(text);
    if (m == null) return null;
    final v = double.tryParse(m.group(1)!.replaceAll(',', ''));
    if (v == null) return null;
    const mul = {
      'KB': 1024, 'MB': 1024 * 1024, 'GB': 1024 * 1024 * 1024,
      'MIB': 1024 * 1024, 'GIB': 1024 * 1024 * 1024, 'TB': 1024 * 1024 * 1024 * 1024,
    };
    final factor = mul[m.group(2)!.toUpperCase()];
    if (factor == null) return null;
    return (v * factor).round();
  }

  static String? _str(Object? v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty || s == 'null' ? null : s;
  }

  static List<String> _strList(Object? v) {
    if (v is List) return v.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    if (v is String && v.isNotEmpty) {
      return v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    return const [];
  }

  static int? _int(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  static double? _double(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim());
    return null;
  }

  /// `releaseInfo` can be "2010", "2010-2019", or "2010–".
  static int? _year(Object? v) {
    if (v == null) return null;
    final m = RegExp(r'(\d{4})').firstMatch(v.toString());
    return m == null ? null : int.tryParse(m.group(1)!);
  }
}
