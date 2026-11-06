import 'package:aero_core/aero_core.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;

import '../db/database.dart';
import 'cache_repository.dart';

/// Caches title-match decisions per source, and stores user corrections.
///
/// Scraping a catalogue to find one title is the slowest part of resolving a
/// stream. Once a source has been matched to a media item the decision is
/// reused, so the second play of the same film skips the search entirely.
///
/// Two kinds of entry:
///  * **auto** — what [TitleMatcher] chose. Expires, so a renamed or newly
///    added entry on the source can be picked up later.
///  * **pinned** — the user pressed "Wrong match?" and picked a different
///    result. Never expires and always wins over an auto match.
///
/// Stored in the existing cache table under a `match:` key prefix, so it needs
/// no schema change and is removed with the rest of a source's data on
/// uninstall.
class MatchRepository {
  MatchRepository(this.db, {CacheRepository? cache})
      : _cache = cache ?? CacheRepository(db);

  final AeroDatabase db;
  final CacheRepository _cache;

  /// Auto matches are re-derived weekly.
  static const autoTtl = Duration(days: 7);

  /// Pinned matches effectively never expire (10 years).
  static const pinnedTtl = Duration(days: 3650);

  static const _prefix = 'match:';

  static String keyFor(String sourceKey, String mediaKey) =>
      '$_prefix$sourceKey|$mediaKey';

  /// The remembered decision, or null. A pinned entry is returned even when
  /// its (nominal) expiry has passed, because a user choice must not silently
  /// revert to a guess.
  Future<TitleMatch?> lookup(String sourceKey, String mediaKey) async {
    final hit = await _cache.read(keyFor(sourceKey, mediaKey));
    if (hit == null) return null;
    final json = hit.value;
    final pinned = json['pinned'] == true;
    if (hit.isStale && !pinned) return null;
    try {
      final c = json['candidate'] as Map<String, dynamic>;
      return TitleMatch(
        TitleCandidate(
          title: c['title'] as String,
          link: c['link'] as String,
          year: c['year'] as int?,
          type: c['type'] as String?,
          poster: c['poster'] as String?,
        ),
        (json['score'] as num).toDouble(),
        pinned: pinned,
      );
    } catch (_) {
      // A malformed row is a cache miss, never an error.
      await forget(sourceKey, mediaKey);
      return null;
    }
  }

  /// Remembers an automatic decision. Never overwrites a user's pin.
  Future<void> remember(
      String sourceKey, String mediaKey, TitleMatch match) async {
    final existing = await lookup(sourceKey, mediaKey);
    if (existing != null && existing.pinned) return;
    await _write(sourceKey, mediaKey, match, pinned: false);
  }

  /// The user picked [candidate] from the "Wrong match?" list.
  Future<void> pin(
      String sourceKey, String mediaKey, TitleCandidate candidate) =>
      _write(sourceKey, mediaKey, TitleMatch(candidate, 1, pinned: true),
          pinned: true);

  /// Drops a pin so the matcher chooses again on the next play.
  Future<void> unpin(String sourceKey, String mediaKey) async {
    final existing = await lookup(sourceKey, mediaKey);
    if (existing != null && !existing.pinned) return;
    await forget(sourceKey, mediaKey);
  }

  Future<void> forget(String sourceKey, String mediaKey) =>
      _cache.delete(keyFor(sourceKey, mediaKey));

  /// Removes every decision for a source. Called on uninstall and on
  /// "Clear cache" for a single plugin.
  Future<int> forgetSource(String sourceKey) =>
      (db.delete(db.mediaCache)
            ..where((t) => t.key.like('$_prefix$sourceKey|%')))
          .go();

  Future<void> _write(
      String sourceKey, String mediaKey, TitleMatch match,
      {required bool pinned}) async {
    final c = match.candidate;
    await _cache.put(
      keyFor(sourceKey, mediaKey),
      {
        'pinned': pinned,
        'score': match.score,
        'candidate': {
          'title': c.title,
          'link': c.link,
          'year': c.year,
          'type': c.type,
          'poster': c.poster,
        },
      },
      ttl: pinned ? pinnedTtl : autoTtl,
    );
  }
}
