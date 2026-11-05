import 'dart:convert';

import 'package:aero_core/aero_core.dart';
import 'package:drift/drift.dart';

import '../db/database.dart';

/// A resume point plus the card needed to render Continue Watching.
class HistoryEntry {
  const HistoryEntry({
    required this.item,
    required this.positionMs,
    required this.durationMs,
    required this.updatedAt,
    this.season,
    this.episode,
  });

  final MediaItem item;
  final int positionMs;
  final int durationMs;
  final DateTime updatedAt;
  final int? season;
  final int? episode;

  double get progress =>
      durationMs <= 0 ? 0 : (positionMs / durationMs).clamp(0.0, 1.0);

  /// Considered finished past 92% — matches common streaming behaviour.
  bool get isFinished => progress > 0.92;

  /// Worth resuming only if the user is meaningfully into it.
  bool get isResumable => positionMs > 30000 && !isFinished;

  String get episodeLabel => season == null || episode == null
      ? ''
      : 'S${season.toString().padLeft(2, '0')}E${episode.toString().padLeft(2, '0')}';
}

class HistoryRepository {
  HistoryRepository(this.db, {this.profileId = 'default'});

  final AeroDatabase db;
  final String profileId;

  /// Upserts a resume point. Called every ~10s during playback and on exit.
  Future<void> record({
    required MediaItem item,
    required int positionMs,
    required int durationMs,
    int? season,
    int? episode,
  }) async {
    await db.into(db.watchHistory).insertOnConflictUpdate(
          WatchHistoryCompanion.insert(
            mediaId: item.ref.cacheKey,
            profileId: Value(profileId),
            season: Value(season),
            episode: Value(episode),
            positionMs: Value(positionMs),
            durationMs: Value(durationMs),
            updatedAt: DateTime.now(),
            metaJson: Value(jsonEncode(item.toJson())),
          ),
        );
  }

  Future<HistoryEntry?> resumePoint(String mediaId, {int? season, int? episode}) async {
    final q = db.select(db.watchHistory)
      ..where((t) => t.mediaId.equals(mediaId) & t.profileId.equals(profileId));
    if (season != null) q.where((t) => t.season.equals(season));
    if (episode != null) q.where((t) => t.episode.equals(episode));
    q.orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    q.limit(1);
    final rows = await q.get();
    if (rows.isEmpty) return null;
    return _entry(rows.first);
  }

  /// Continue Watching row: unfinished entries, most recent first.
  Future<List<HistoryEntry>> continueWatching({int limit = 20}) async {
    final rows = await (db.select(db.watchHistory)
          ..where((t) => t.profileId.equals(profileId))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(limit * 2))
        .get();
    final out = <HistoryEntry>[];
    final seen = <String>{};
    for (final r in rows) {
      final e = _entry(r);
      if (e == null || !e.isResumable) continue;
      // One card per title, showing the most recent episode.
      if (!seen.add(e.item.ref.cacheKey)) continue;
      out.add(e);
      if (out.length >= limit) break;
    }
    return out;
  }

  Stream<List<HistoryEntry>> watchContinueWatching({int limit = 20}) {
    final q = db.select(db.watchHistory)
      ..where((t) => t.profileId.equals(profileId))
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
      ..limit(limit * 2);
    return q.watch().map((rows) {
      final out = <HistoryEntry>[];
      final seen = <String>{};
      for (final r in rows) {
        final e = _entry(r);
        if (e == null || !e.isResumable) continue;
        if (!seen.add(e.item.ref.cacheKey)) continue;
        out.add(e);
        if (out.length >= limit) break;
      }
      return out;
    });
  }

  Future<List<HistoryEntry>> all({int limit = 200}) async {
    final rows = await (db.select(db.watchHistory)
          ..where((t) => t.profileId.equals(profileId))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(limit))
        .get();
    return rows.map(_entry).whereType<HistoryEntry>().toList();
  }

  Future<void> remove(String mediaId) async {
    await (db.delete(db.watchHistory)
          ..where((t) => t.mediaId.equals(mediaId) & t.profileId.equals(profileId)))
        .go();
  }

  Future<void> clear() async {
    await (db.delete(db.watchHistory)..where((t) => t.profileId.equals(profileId))).go();
  }

  HistoryEntry? _entry(WatchHistoryRow row) {
    try {
      final item =
          MediaItem.fromJson(Map<String, dynamic>.from(jsonDecode(row.metaJson) as Map));
      return HistoryEntry(
        item: item,
        positionMs: row.positionMs,
        durationMs: row.durationMs,
        updatedAt: row.updatedAt,
        season: row.season,
        episode: row.episode,
      );
    } catch (_) {
      return null;
    }
  }
}
