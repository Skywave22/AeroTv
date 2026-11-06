import 'package:aero_core/aero_core.dart';
import 'package:dio/dio.dart';

import '../db/database.dart';
import 'cache_repository.dart';

/// TMDB-backed Home rows.
///
/// This is how Nuvio builds its own home: the plugin contract there is
/// `getStreams` only, so catalogues and metadata come from TMDB and the
/// installed scrapers supply the links at play time. Aero does the same, so a
/// user with add-ons and Nuvio scrapers gets a populated Home without any
/// JavaScript ecosystem having to expose a catalogue API it does not have.
///
/// The user supplies their own API key in Settings. Without one this returns
/// nothing and Home falls back to add-on catalogues alone — Aero ships no key.
class TmdbCatalogRepository {
  TmdbCatalogRepository({
    required this.db,
    required this.apiKey,
    Dio? dio,
    CacheRepository? cache,
    this.ttl = const Duration(hours: 6),
    this.language = 'en-US',
  })  : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://api.themoviedb.org/3',
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
            )),
        _cache = cache ?? CacheRepository(db);

  final AeroDatabase db;
  final String apiKey;
  final Dio _dio;
  final CacheRepository _cache;
  final Duration ttl;
  final String language;

  static const imageBase = 'https://image.tmdb.org/t/p';

  bool get isConfigured => apiKey.trim().isNotEmpty;

  /// The rows Home shows, in order. Trending first because it mixes films and
  /// series and is the most useful single row on a cold start.
  static const List<({String id, String path, String title, MediaType type})>
      feeds = [
    (
      id: 'trending',
      path: '/trending/all/week',
      title: 'Trending this week',
      type: MediaType.other,
    ),
    (
      id: 'popular-movie',
      path: '/movie/popular',
      title: 'Popular movies',
      type: MediaType.movie,
    ),
    (
      id: 'popular-tv',
      path: '/tv/popular',
      title: 'Popular series',
      type: MediaType.series,
    ),
    (
      id: 'top-movie',
      path: '/movie/top_rated',
      title: 'Top rated movies',
      type: MediaType.movie,
    ),
    (
      id: 'top-tv',
      path: '/tv/top_rated',
      title: 'Top rated series',
      type: MediaType.series,
    ),
  ];

  /// Fetches the feeds in parallel. A feed that fails is dropped, never fatal:
  /// Home must render from whatever answered.
  Future<List<CatalogRow>> rows({int maxFeeds = 4, int perFeed = 20}) async {
    if (!isConfigured) return const [];
    final chosen = feeds.take(maxFeeds).toList();
    final out = List<CatalogRow?>.filled(chosen.length, null);
    await Future.wait([
      for (var i = 0; i < chosen.length; i++)
        () async {
          try {
            out[i] = await _feed(chosen[i], perFeed: perFeed);
          } catch (e) {
            AeroLog.instance
                .w('tmdb', 'catalog ${chosen[i].id} failed: $e');
          }
        }(),
    ]);
    return out.whereType<CatalogRow>().where((r) => r.items.isNotEmpty).toList();
  }

  Future<CatalogRow> _feed(
    ({String id, String path, String title, MediaType type}) feed, {
    required int perFeed,
  }) async {
    final key = 'tmdb:catalog:${feed.id}:$language';
    final hit = await _cache.read(key);
    if (hit != null && hit.isFresh) {
      final items = _decodeItems(hit.value);
      if (items.isNotEmpty) {
        return CatalogRow(
          sourceId: 'tmdb',
          catalogId: feed.id,
          title: feed.title,
          type: feed.type,
          items: items,
        );
      }
    }

    final res = await _dio.get<dynamic>(
      feed.path,
      queryParameters: {'api_key': apiKey, 'language': language},
    );
    final data = res.data;
    final json = data is Map<String, dynamic>
        ? data
        : data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
    final results = (json['results'] as List?) ?? const [];
    final items = <MediaItem>[];
    for (final raw in results.take(perFeed)) {
      if (raw is! Map) continue;
      final item = parseItem(Map<String, dynamic>.from(raw), feed.type);
      if (item != null) items.add(item);
    }

    if (items.isNotEmpty) {
      await _cache.put(key, {
        'items': [for (final i in items) i.toJson()],
      }, ttl: ttl);
    }
    return CatalogRow(
      sourceId: 'tmdb',
      catalogId: feed.id,
      title: feed.title,
      type: feed.type,
      items: items,
    );
  }

  List<MediaItem> _decodeItems(Map<String, dynamic> json) {
    final list = (json['items'] as List?) ?? const [];
    final out = <MediaItem>[];
    for (final raw in list) {
      if (raw is! Map) continue;
      try {
        out.add(MediaItem.fromJson(Map<String, dynamic>.from(raw)));
      } catch (_) {
        // One malformed card must not empty the row.
      }
    }
    return out;
  }

  /// Maps one TMDB entry. Public so the shape is testable on its own.
  ///
  /// [feedType] is [MediaType.other] for the mixed trending feed, where each
  /// entry carries its own `media_type`.
  static MediaItem? parseItem(Map<String, dynamic> j, MediaType feedType) {
    final id = j['id'];
    if (id == null) return null;

    final type = feedType == MediaType.other
        ? MediaType.fromWire(j['media_type'] as String?)
        : feedType;
    // Trending includes people; they are not playable and have no title.
    if (type != MediaType.movie && type != MediaType.series) return null;

    final title = (j['title'] ?? j['name']) as String?;
    if (title == null || title.trim().isEmpty) return null;

    final date = (j['release_date'] ?? j['first_air_date']) as String?;
    final year = (date != null && date.length >= 4)
        ? int.tryParse(date.substring(0, 4))
        : null;

    final tmdbId = '$id';
    final poster = j['poster_path'] as String?;
    final backdrop = j['backdrop_path'] as String?;
    final rating = (j['vote_average'] as num?)?.toDouble();

    return MediaItem(
      // IMDb is unknown here. MetadataResolver.enrich fills it from
      // /external_ids at play time, which is what the scrapers need.
      ref: MediaRef(
        id: 'tmdb:$tmdbId',
        type: type,
        tmdbId: tmdbId,
        title: title,
        year: year,
      ),
      title: title,
      poster: poster == null || poster.isEmpty ? null : '$imageBase/w500$poster',
      background:
          backdrop == null || backdrop.isEmpty ? null : '$imageBase/w1280$backdrop',
      description: (j['overview'] as String?)?.trim().isEmpty ?? true
          ? null
          : j['overview'] as String,
      year: year,
      imdbRating: rating == null || rating <= 0 ? null : rating,
    );
  }
}
