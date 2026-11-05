import 'dart:async';

import '../models/media.dart';
import '../util/aero_log.dart';
import 'id_map.dart';

/// Supplies external-ID lookups. Implemented in `aero_data` against TMDB with
/// a Drift-backed cache; the core only depends on this narrow interface.
abstract class IdLookup {
  /// Look up by any known id. Implementations should cache aggressively.
  Future<IdMap?> lookup({String? imdbId, String? tmdbId, MediaType? type});

  /// Title+year fallback when no id is known.
  Future<IdMap?> findByTitle(String title, {int? year, MediaType? type});
}

/// Translates a [MediaRef] into the identifiers each ecosystem expects.
///
/// Stremio wants IMDb, TMDB-style scrapers want TMDB, and some plugins only
/// accept a title. Rather than guessing, we resolve once and cache.
class MetadataResolver {
  MetadataResolver({this.lookup, this.cacheTtl = const Duration(days: 7)});

  final IdLookup? lookup;
  final Duration cacheTtl;

  final Map<String, ({IdMap map, DateTime at})> _cache = {};

  /// In-flight deduplication so a home screen with 40 cards doesn't fire
  /// 40 identical network calls.
  final Map<String, Future<IdMap>> _inFlight = {};

  IdMap? cached(String key) {
    final hit = _cache[key];
    if (hit == null) return null;
    if (DateTime.now().difference(hit.at) > cacheTtl) {
      _cache.remove(key);
      return null;
    }
    return hit.map;
  }

  /// Enrich a ref with whatever external IDs we can find. Never throws: on
  /// failure it returns the original ref so playback can still be attempted.
  Future<MediaRef> enrich(MediaRef ref) async {
    // Already has both ids → nothing to do.
    if (ref.hasImdb && ref.tmdbId != null) return ref;

    final inline = IdMap(
      imdbId: extractImdbId(ref.imdbId ?? ref.id),
      tmdbId: ref.tmdbId,
      title: ref.title,
      year: ref.year,
      type: ref.type.wire,
    );

    if (lookup == null) {
      return ref.copyWith(imdbId: inline.imdbId);
    }

    final key = ref.cacheKey;
    final hit = cached(key);
    if (hit != null) return _apply(ref, hit);

    try {
      final map = await _inFlight.putIfAbsent(key, () async {
        try {
          var found = await lookup!.lookup(
            imdbId: inline.imdbId,
            tmdbId: inline.tmdbId,
            type: ref.type,
          );
          if ((found == null || found.isEmpty) && ref.title != null) {
            found = await lookup!.findByTitle(
              ref.title!,
              year: ref.year,
              type: ref.type,
            );
          }
          final merged = inline.merge(found ?? const IdMap());
          _cache[key] = (map: merged, at: DateTime.now());
          return merged;
        } finally {
          unawaited(Future<void>.microtask(() => _inFlight.remove(key)));
        }
      });
      return _apply(ref, map);
    } catch (e) {
      AeroLog.instance.w('metadata', 'ID enrichment failed for ${ref.id}: $e');
      return ref.copyWith(imdbId: inline.imdbId);
    }
  }

  MediaRef _apply(MediaRef ref, IdMap map) => ref.copyWith(
        imdbId: map.imdbId ?? ref.imdbId,
        tmdbId: map.tmdbId ?? ref.tmdbId,
        title: ref.title ?? map.title,
        year: ref.year ?? map.year,
      );

  /// The id a given ecosystem should be queried with. Falls back to the native
  /// id, which adapters can then use for a title search.
  String idFor(MediaRef ref, {required bool wantsImdb, required bool wantsTmdb}) {
    if (wantsImdb && ref.hasImdb) return ref.imdbId!;
    if (wantsTmdb && ref.tmdbId != null) return ref.tmdbId!;
    return ref.id;
  }

  void clear() {
    _cache.clear();
    _inFlight.clear();
  }
}
