import 'dart:convert';

import 'package:aero_core/aero_core.dart';
import 'package:dio/dio.dart';

import '../db/database.dart';

/// TMDB-backed [IdLookup] with a Drift cache.
///
/// The user supplies their own TMDB API key in Settings; without one, the
/// resolver simply falls back to IMDb ids and title matching. Aero ships with
/// no built-in key.
class TmdbIdLookup implements IdLookup {
  TmdbIdLookup({
    required this.db,
    required this.apiKey,
    Dio? dio,
    this.cacheTtl = const Duration(days: 30),
  }) : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://api.themoviedb.org/3',
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
            ));

  final AeroDatabase db;
  final String apiKey;
  final Dio _dio;
  final Duration cacheTtl;

  bool get isConfigured => apiKey.trim().isNotEmpty;

  String _key({String? imdbId, String? tmdbId, MediaType? type}) =>
      'tmdb|${imdbId ?? '-'}|${tmdbId ?? '-'}|${type?.wire ?? '-'}';

  Future<IdMap?> _cached(String key) async {
    final rows = await (db.select(db.idMappings)
          ..where((t) => t.key.equals(key))
          ..limit(1))
        .get();
    if (rows.isEmpty) return null;
    final r = rows.first;
    if (DateTime.now().difference(r.fetchedAt) > cacheTtl) return null;
    try {
      return IdMap.fromJson(Map<String, dynamic>.from(jsonDecode(r.json) as Map));
    } catch (_) {
      return null;
    }
  }

  Future<void> _store(String key, IdMap map) async {
    await db.into(db.idMappings).insertOnConflictUpdate(
          IdMappingsCompanion.insert(
            key: key,
            json: jsonEncode(map.toJson()),
            fetchedAt: DateTime.now(),
          ),
        );
  }

  @override
  Future<IdMap?> lookup({String? imdbId, String? tmdbId, MediaType? type}) async {
    if (!isConfigured) return null;
    final key = _key(imdbId: imdbId, tmdbId: tmdbId, type: type);
    final hit = await _cached(key);
    if (hit != null) return hit;

    try {
      // /find resolves an IMDb id to a TMDB entry (and vice versa).
      if (imdbId != null && imdbId.isNotEmpty) {
        final res = await _dio.getUri(Uri.https(
          'api.themoviedb.org',
          '/3/find/$imdbId',
          {'api_key': apiKey, 'external_source': 'imdb_id'},
        ));
        final data = res.data;
        if (data is Map) {
          final isTv = type == MediaType.series;
          final list = (isTv ? data['tv_results'] : data['movie_results']) as List?;
          if (list != null && list.isNotEmpty) {
            final m = Map<String, dynamic>.from(list.first as Map);
            final map = IdMap(
              imdbId: imdbId,
              tmdbId: m['id']?.toString(),
              title: (m['title'] ?? m['name'])?.toString(),
              year: _year(m['release_date'] ?? m['first_air_date']),
              type: type?.wire,
            );
            await _store(key, map);
            return map;
          }
        }
      }

      // Reverse direction: TMDB → IMDb via /external_ids.
      if (tmdbId != null && tmdbId.isNotEmpty) {
        final kind = type == MediaType.series ? 'tv' : 'movie';
        final res = await _dio.getUri(Uri.https(
          'api.themoviedb.org',
          '/3/$kind/$tmdbId/external_ids',
          {'api_key': apiKey},
        ));
        final data = res.data;
        if (data is Map) {
          final map = IdMap(
            imdbId: data['imdb_id']?.toString(),
            tmdbId: tmdbId,
            tvdbId: data['tvdb_id']?.toString(),
            type: type?.wire,
          );
          await _store(key, map);
          return map;
        }
      }
    } catch (e) {
      AeroLog.instance.w('tmdb', 'lookup failed: $e');
    }
    return null;
  }

  @override
  Future<IdMap?> findByTitle(String title, {int? year, MediaType? type}) async {
    if (!isConfigured || title.trim().isEmpty) return null;
    final key = 'title|$title|$year|${type?.wire ?? '-'}';
    final hit = await _cached(key);
    if (hit != null) return hit;

    try {
      final kind = type == MediaType.series ? 'tv' : 'movie';
      final params = <String, String>{
        'api_key': apiKey,
        'query': title,
        if (year != null) (kind == 'tv' ? 'first_air_date_year' : 'year'): '$year',
      };
      final res = await _dio.getUri(
        Uri.https('api.themoviedb.org', '/3/search/$kind', params),
      );
      final data = res.data;
      if (data is Map) {
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          final m = Map<String, dynamic>.from(results.first as Map);
          final tmdbId = m['id']?.toString();
          // Chain into external_ids to get the IMDb id we actually need.
          final map = await lookup(tmdbId: tmdbId, type: type);
          final merged = (map ?? const IdMap()).merge(IdMap(
            tmdbId: tmdbId,
            title: (m['title'] ?? m['name'])?.toString(),
            year: _year(m['release_date'] ?? m['first_air_date']),
            type: type?.wire,
          ));
          await _store(key, merged);
          return merged;
        }
      }
    } catch (e) {
      AeroLog.instance.w('tmdb', 'title search failed: $e');
    }
    return null;
  }

  static int? _year(Object? v) {
    if (v == null) return null;
    final m = RegExp(r'(\d{4})').firstMatch(v.toString());
    return m == null ? null : int.tryParse(m.group(1)!);
  }
}
