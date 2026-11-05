/// SkyStream's native plugin contract, mirrored from upstream.
///
/// Verified against `akashdh11/skystream@master`
/// (`lib/core/extensions/base_provider.dart`, `assets/plugins/plugin.js`) and
/// `akashdh11/skystream-tools@main/DEVELOPER.md` on 2026-11-05.
///
/// This is intentionally *not* the unified Aero model. Keeping SkyStream's own
/// shapes here means a plugin behaves exactly as it does in SkyStream, and the
/// translation to `MediaItem`/`StreamLink` happens in one auditable place.
library;

import 'package:aero_core/aero_core.dart';

/// Upstream `ProviderType`.
enum SkyProviderType {
  movie,
  series,
  anime,
  livestream,
  other;

  static SkyProviderType fromWire(String? s) {
    switch (s?.toLowerCase().trim()) {
      case 'movie':
        return SkyProviderType.movie;
      case 'series':
      case 'tv':
        return SkyProviderType.series;
      case 'anime':
        return SkyProviderType.anime;
      case 'livestream':
      case 'live':
        return SkyProviderType.livestream;
      default:
        return SkyProviderType.other;
    }
  }

  String get wire => name;

  MediaType get toMediaType => switch (this) {
        SkyProviderType.series || SkyProviderType.anime => MediaType.series,
        SkyProviderType.livestream => MediaType.channel,
        SkyProviderType.movie => MediaType.movie,
        SkyProviderType.other => MediaType.other,
      };
}

/// Upstream `Actor`.
class SkyActor {
  const SkyActor({required this.name, this.role, this.image});
  final String name;
  final String? role;
  final String? image;

  factory SkyActor.fromJson(Map<String, dynamic> j) => SkyActor(
        name: (j['name'] ?? '').toString(),
        role: j['role']?.toString(),
        image: j['image']?.toString(),
      );
}

/// Upstream `Trailer`.
class SkyTrailer {
  const SkyTrailer({required this.url, this.name});
  final String url;
  final String? name;

  factory SkyTrailer.fromJson(Map<String, dynamic> j) => SkyTrailer(
        url: (j['url'] ?? '').toString(),
        name: j['name']?.toString(),
      );
}

/// Upstream `NextAiring`. Accepts either `airDate` or `unixTime`.
class SkyNextAiring {
  const SkyNextAiring({this.episode, this.season, this.airDate});
  final int? episode;
  final int? season;
  final DateTime? airDate;

  factory SkyNextAiring.fromJson(Map<String, dynamic> j) {
    DateTime? when;
    final unix = j['unixTime'];
    if (unix is num) {
      when = DateTime.fromMillisecondsSinceEpoch(unix.toInt() * 1000);
    } else if (j['airDate'] != null) {
      when = DateTime.tryParse(j['airDate'].toString());
    }
    return SkyNextAiring(
      episode: (j['episode'] as num?)?.toInt(),
      season: (j['season'] as num?)?.toInt(),
      airDate: when,
    );
  }
}

/// Upstream `StreamResult`.
class SkyStreamResult {
  const SkyStreamResult({
    required this.url,
    this.source = 'Auto',
    this.quality,
    this.headers = const {},
    this.subtitles = const [],
    this.drmKid,
    this.licenseUrl,
  });

  final String url;

  /// Display name in the source list. Upstream defaults to `"Auto"`.
  final String source;

  /// Raw quality: SkyStream allows a number *or* a string, and `0`/`"Auto"`
  /// means an HLS master with several renditions.
  final Object? quality;

  final Map<String, String> headers;
  final List<SkySubtitle> subtitles;
  final String? drmKid;
  final String? licenseUrl;

  bool get isDrmProtected =>
      (drmKid != null && drmKid!.isNotEmpty) ||
      (licenseUrl != null && licenseUrl!.isNotEmpty);

  factory SkyStreamResult.fromJson(Map<String, dynamic> j) => SkyStreamResult(
        url: (j['url'] ?? j['link'] ?? '').toString(),
        source: (j['source'] ?? j['server'] ?? 'Auto').toString(),
        quality: j['quality'],
        headers: _headers(j['headers']),
        subtitles: (j['subtitles'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => SkySubtitle.fromJson(Map<String, dynamic>.from(e)))
            .where((s) => s.url.isNotEmpty)
            .toList(),
        drmKid: j['drmKid']?.toString(),
        licenseUrl: j['licenseUrl']?.toString(),
      );

  static Map<String, String> _headers(Object? raw) {
    final out = <String, String>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v != null) out[k.toString()] = v.toString();
      });
    }
    return out;
  }
}

/// `{url, label, lang}` inside a StreamResult.
class SkySubtitle {
  const SkySubtitle({required this.url, this.label, this.lang});
  final String url;
  final String? label;
  final String? lang;

  factory SkySubtitle.fromJson(Map<String, dynamic> j) => SkySubtitle(
        url: (j['url'] ?? '').toString(),
        label: (j['label'] ?? j['title'])?.toString(),
        lang: (j['lang'] ?? j['language'])?.toString(),
      );
}

/// Upstream `Episode`.
class SkyEpisode {
  const SkyEpisode({
    required this.name,
    required this.url,
    required this.season,
    required this.episode,
    this.description,
    this.posterUrl,
    this.rating,
    this.runtime,
    this.airDate,
    this.dubStatus,
    this.headers = const {},
    this.streams = const [],
  });

  final String name;
  final String url;
  final int season;
  final int episode;
  final String? description;
  final String? posterUrl;
  final double? rating;
  final int? runtime;
  final String? airDate;

  /// `none`, `dubbed` or `subbed`.
  final String? dubStatus;

  final Map<String, String> headers;

  /// "Instant load" — when present the app can skip `loadStreams`.
  final List<SkyStreamResult> streams;

  factory SkyEpisode.fromJson(Map<String, dynamic> j) => SkyEpisode(
        name: (j['name'] ?? j['title'] ?? '').toString(),
        url: (j['url'] ?? '').toString(),
        season: (j['season'] as num?)?.toInt() ?? 1,
        episode: (j['episode'] as num?)?.toInt() ?? 0,
        description: j['description']?.toString(),
        posterUrl: (j['posterUrl'] ?? j['image'])?.toString(),
        rating: (j['rating'] as num?)?.toDouble(),
        runtime: (j['runtime'] as num?)?.toInt(),
        airDate: j['airDate']?.toString(),
        dubStatus: j['dubStatus']?.toString(),
        headers: SkyStreamResult._headers(j['headers']),
        streams: (j['streams'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => SkyStreamResult.fromJson(Map<String, dynamic>.from(e)))
            .where((s) => s.url.isNotEmpty)
            .toList(),
      );
}

/// Upstream `MultimediaItem`.
class SkyMediaItem {
  const SkyMediaItem({
    required this.title,
    required this.url,
    required this.posterUrl,
    required this.type,
    this.bannerUrl,
    this.logoUrl,
    this.description,
    this.year,
    this.score,
    this.duration,
    this.status,
    this.contentRating,
    this.playbackPolicy,
    this.isAdult = false,
    this.tags = const [],
    this.cast = const [],
    this.trailers = const [],
    this.nextAiring,
    this.recommendations = const [],
    this.syncData = const {},
    this.headers = const {},
    this.episodes = const [],
    this.streams = const [],
  });

  final String title;
  final String url;
  final String posterUrl;
  final SkyProviderType type;
  final String? bannerUrl;
  final String? logoUrl;
  final String? description;
  final int? year;
  final double? score;

  /// Minutes.
  final int? duration;

  /// `ongoing`, `completed`, `upcoming`.
  final String? status;
  final String? contentRating;

  /// `none`, `VPN Recommended`, `torrent`, `externalPlayerOnly`,
  /// `internalPlayerOnly`.
  final String? playbackPolicy;

  final bool isAdult;
  final List<String> tags;
  final List<SkyActor> cast;
  final List<SkyTrailer> trailers;
  final SkyNextAiring? nextAiring;
  final List<SkyMediaItem> recommendations;

  /// External ids for metadata sync, e.g. `{"mal": "123", "tmdb": "456"}`.
  final Map<String, String> syncData;

  final Map<String, String> headers;
  final List<SkyEpisode> episodes;

  /// "Instant load" streams attached straight to the item.
  final List<SkyStreamResult> streams;

  bool get requiresExternalPlayer =>
      playbackPolicy?.toLowerCase().contains('external') ?? false;

  bool get isTorrentOnly => playbackPolicy?.toLowerCase() == 'torrent';

  factory SkyMediaItem.fromJson(Map<String, dynamic> j) => SkyMediaItem(
        title: (j['title'] ?? j['name'] ?? '').toString(),
        url: (j['url'] ?? j['link'] ?? '').toString(),
        posterUrl: (j['posterUrl'] ?? j['image'] ?? j['poster'] ?? '').toString(),
        type: SkyProviderType.fromWire(j['type']?.toString()),
        bannerUrl: (j['bannerUrl'] ?? j['background'])?.toString(),
        logoUrl: j['logoUrl']?.toString(),
        description: (j['description'] ?? j['synopsis'])?.toString(),
        year: (j['year'] as num?)?.toInt(),
        score: (j['score'] as num?)?.toDouble(),
        duration: (j['duration'] as num?)?.toInt(),
        status: j['status']?.toString(),
        contentRating: j['contentRating']?.toString(),
        playbackPolicy: j['playbackPolicy']?.toString(),
        isAdult: j['isAdult'] == true,
        tags: (j['tags'] as List? ?? const []).map((e) => e.toString()).toList(),
        cast: (j['cast'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => SkyActor.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        trailers: (j['trailers'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => SkyTrailer.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        nextAiring: j['nextAiring'] is Map
            ? SkyNextAiring.fromJson(Map<String, dynamic>.from(j['nextAiring'] as Map))
            : null,
        recommendations: (j['recommendations'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => SkyMediaItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        syncData: _syncData(j['syncData']),
        headers: SkyStreamResult._headers(j['headers']),
        episodes: (j['episodes'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => SkyEpisode.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        streams: (j['streams'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => SkyStreamResult.fromJson(Map<String, dynamic>.from(e)))
            .where((s) => s.url.isNotEmpty)
            .toList(),
      );

  static Map<String, String> _syncData(Object? raw) {
    final out = <String, String>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v != null) out[k.toString()] = v.toString();
      });
    }
    return out;
  }

  /// Converts to Aero's unified item. The source URL is the stable id, exactly
  /// as SkyStream itself treats it.
  MediaItem toMediaItem() {
    final imdb = extractImdbId(syncData['imdb'] ?? url);
    return MediaItem(
      ref: MediaRef(
        id: url,
        type: type.toMediaType == MediaType.other
            ? MediaType.movie
            : type.toMediaType,
        imdbId: imdb,
        tmdbId: syncData['tmdb'],
        title: title,
        year: year,
      ),
      title: title,
      poster: posterUrl.isEmpty ? null : posterUrl,
      background: bannerUrl,
      logo: logoUrl,
      description: description,
      year: year,
      imdbRating: score,
      genres: tags,
      runtime: duration == null ? null : '$duration min',
    );
  }
}

/// The four functions every SkyStream plugin implements.
///
/// Upstream signature is callback-based: `fn(args…, cb)` where `cb` receives
/// `{success, data, errorCode, message}`. Implementations here expose ordinary
/// Dart futures and unwrap that envelope.
abstract class SkyStreamProvider {
  String get packageName;
  String get name;
  String get baseUrl;
  int get version;
  List<String> get languages;
  Set<SkyProviderType> get supportedTypes;
  bool get hasSearch;

  /// Category name → items. `"Trending"` is reserved for the hero carousel.
  Future<Map<String, List<SkyMediaItem>>> getHome();

  Future<List<SkyMediaItem>> search(String query, {int page = 1});

  Future<SkyMediaItem> load(String url);

  Future<List<SkyStreamResult>> loadStreams(String url);

  Future<void> dispose();
}

/// Reserved category that SkyStream promotes to the hero carousel.
const String kSkyTrendingCategory = 'Trending';

/// Applies SkyStream's dashboard rule to a raw `getHome` result.
///
/// * `"Trending"` becomes the carousel and is removed from the rows.
/// * If absent, the **first** category is used instead.
/// * Everything else stays a row, in the plugin's own order.
({List<SkyMediaItem> hero, Map<String, List<SkyMediaItem>> rows})
    applySkyDashboardRule(Map<String, List<SkyMediaItem>> home) {
  if (home.isEmpty) {
    return (hero: const <SkyMediaItem>[], rows: const {});
  }
  final entries = home.entries.toList();
  String heroKey;
  final trendingIndex = entries.indexWhere(
      (e) => e.key.trim().toLowerCase() == kSkyTrendingCategory.toLowerCase());
  heroKey = trendingIndex >= 0 ? entries[trendingIndex].key : entries.first.key;

  final hero = home[heroKey] ?? const <SkyMediaItem>[];
  final rows = <String, List<SkyMediaItem>>{};
  for (final e in entries) {
    if (e.key == heroKey) continue; // avoid duplicating the carousel below
    if (e.value.isEmpty) continue;
    rows[e.key] = e.value;
  }
  return (hero: hero, rows: rows);
}
