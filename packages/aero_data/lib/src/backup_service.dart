import 'dart:convert';

import 'package:aero_core/aero_core.dart';

import 'db/database.dart';
import 'repos/library_repository.dart';
import 'repos/source_repository.dart';
import 'settings/settings_repository.dart';

/// Portable JSON backup of configuration — **never** credentials or content.
///
/// Restoring is additive-by-default and validates the ecosystem ids so a
/// malformed file can't corrupt the database.
class BackupService {
  BackupService({
    required this.db,
    required this.sources,
    required this.settings,
    required this.library,
  });

  final AeroDatabase db;
  final SourceRepository sources;
  final SettingsRepository settings;
  final LibraryRepository library;

  static const backupVersion = 1;

  Future<String> export() async {
    final repos = await sources.loadRepositories();
    final installed = await sources.loadAll();
    final watchlist = await library.list(LibraryLists.watchlist);
    final favorites = await library.list(LibraryLists.favorites);

    final payload = {
      'aeroBackupVersion': backupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'repositories': repos.map((r) => r.toJson()).toList(),
      'sources': installed.map((s) => s.toJson()).toList(),
      'settings': settings.exportAll(),
      'library': {
        LibraryLists.watchlist: watchlist.map((i) => i.toJson()).toList(),
        LibraryLists.favorites: favorites.map((i) => i.toJson()).toList(),
      },
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Returns a human-readable summary, or throws [AeroException] if invalid.
  Future<String> import(String jsonText, {bool replace = false}) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(jsonText);
    } catch (_) {
      throw const AeroException('That file is not valid JSON.');
    }
    if (decoded is! Map) {
      throw const AeroException('Backup must be a JSON object.');
    }
    final map = Map<String, dynamic>.from(decoded);
    final version = (map['aeroBackupVersion'] as num?)?.toInt();
    if (version == null) {
      throw const AeroException('Not an Aero TV backup (missing version).');
    }
    if (version > backupVersion) {
      throw AeroException(
        'This backup is from a newer version ($version). Update Aero TV first.',
      );
    }

    var repoCount = 0, sourceCount = 0, itemCount = 0;

    await db.transaction(() async {
      if (replace) {
        await db.delete(db.installedSources).go();
        await db.delete(db.repositories).go();
      }

      for (final r in (map['repositories'] as List? ?? const [])) {
        if (r is! Map) continue;
        final m = Map<String, dynamic>.from(r);
        if (Ecosystem.tryFromId(m['ecosystem'] as String?) == null) continue;
        await sources.saveRepository(Repository.fromJson(m));
        repoCount++;
      }

      for (final s in (map['sources'] as List? ?? const [])) {
        if (s is! Map) continue;
        final m = Map<String, dynamic>.from(s);
        if (Ecosystem.tryFromId(m['ecosystem'] as String?) == null) continue;
        await sources.save(InstalledSource.fromJson(m));
        sourceCount++;
      }

      final rawSettings = map['settings'];
      if (rawSettings is Map) {
        await settings.importAll(Map<String, dynamic>.from(rawSettings));
      }

      final lib = map['library'];
      if (lib is Map) {
        for (final listName in [LibraryLists.watchlist, LibraryLists.favorites]) {
          for (final i in (lib[listName] as List? ?? const [])) {
            if (i is! Map) continue;
            try {
              await library.add(
                MediaItem.fromJson(Map<String, dynamic>.from(i)),
                listName,
              );
              itemCount++;
            } catch (_) {
              // Skip a malformed entry rather than aborting the restore.
            }
          }
        }
      }
    });

    // Re-read settings so the in-memory cache reflects the restore.
    await settings.load();

    return 'Restored $sourceCount source(s), $repoCount repo(s), '
        '$itemCount library item(s).';
  }
}
