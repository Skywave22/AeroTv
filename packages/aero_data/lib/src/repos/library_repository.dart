import 'dart:convert';

import 'package:aero_core/aero_core.dart';
import 'package:drift/drift.dart';

import '../db/database.dart';

/// Well-known list names.
class LibraryLists {
  static const watchlist = 'watchlist';
  static const favorites = 'favorites';
}

/// Watchlist / favorites, scoped to a profile.
class LibraryRepository {
  LibraryRepository(this.db, {this.profileId = 'default'});

  final AeroDatabase db;
  final String profileId;

  Future<List<MediaItem>> list(String listName) async {
    final rows = await (db.select(db.libraryEntries)
          ..where((t) => t.listName.equals(listName) & t.profileId.equals(profileId))
          ..orderBy([(t) => OrderingTerm.desc(t.addedAt)]))
        .get();
    return rows.map(_item).whereType<MediaItem>().toList();
  }

  Future<bool> contains(String mediaId, String listName) async {
    final rows = await (db.select(db.libraryEntries)
          ..where((t) =>
              t.mediaId.equals(mediaId) &
              t.listName.equals(listName) &
              t.profileId.equals(profileId))
          ..limit(1))
        .get();
    return rows.isNotEmpty;
  }

  Future<void> add(MediaItem item, String listName) async {
    await db.into(db.libraryEntries).insertOnConflictUpdate(
          LibraryEntriesCompanion.insert(
            mediaId: item.ref.cacheKey,
            profileId: Value(profileId),
            listName: listName,
            metaJson: Value(jsonEncode(item.toJson())),
            addedAt: DateTime.now(),
          ),
        );
  }

  Future<void> remove(String mediaId, String listName) async {
    await (db.delete(db.libraryEntries)
          ..where((t) =>
              t.mediaId.equals(mediaId) &
              t.listName.equals(listName) &
              t.profileId.equals(profileId)))
        .go();
  }

  Future<void> toggle(MediaItem item, String listName) async {
    if (await contains(item.ref.cacheKey, listName)) {
      await remove(item.ref.cacheKey, listName);
    } else {
      await add(item, listName);
    }
  }

  /// Reactive stream so the Library tab updates without manual refresh.
  Stream<List<MediaItem>> watch(String listName) {
    final q = db.select(db.libraryEntries)
      ..where((t) => t.listName.equals(listName) & t.profileId.equals(profileId))
      ..orderBy([(t) => OrderingTerm.desc(t.addedAt)]);
    return q.watch().map((rows) => rows.map(_item).whereType<MediaItem>().toList());
  }

  MediaItem? _item(LibraryEntryRow row) {
    try {
      return MediaItem.fromJson(Map<String, dynamic>.from(jsonDecode(row.metaJson) as Map));
    } catch (_) {
      return null;
    }
  }
}
