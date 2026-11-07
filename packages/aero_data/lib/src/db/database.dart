import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  Repositories,
  InstalledSources,
  MediaCache,
  WatchHistory,
  LibraryEntries,
  Profiles,
  ProviderHealthTable,
  AppSettings,
  IdMappings,
  PluginLogs,
])
class AeroDatabase extends _$AeroDatabase {
  AeroDatabase(super.executor);

  /// Opens the on-device database file.
  static Future<AeroDatabase> open() async {
    final dir = await getApplicationSupportDirectory();
    await Directory(dir.path).create(recursive: true);
    final file = File(p.join(dir.path, 'aero.sqlite'));
    return AeroDatabase(NativeDatabase.createInBackground(file));
  }

  /// In-memory database for tests.
  factory AeroDatabase.memory() => AeroDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // Seed the default profile so the app always has one.
          await into(profiles).insert(
            ProfilesCompanion.insert(id: 'default', name: 'Default'),
            mode: InsertMode.insertOrIgnore,
          );
        },
        onUpgrade: (m, from, to) async {
          // v1 -> v2: DateTime columns moved from Unix *seconds* to ISO-8601
          // text so sub-second ordering is possible. See build.yaml for why
          // this matters (Continue Watching picked the wrong episode when two
          // episodes were recorded within the same second).
          //
          // SQLite is dynamically typed, so the existing INTEGER values are
          // still readable in place; we rewrite them as text. The `typeof`
          // guard makes this idempotent and safe to re-run.
          //
          // 'localtime' is deliberate: Drift writes `DateTime.toIso8601String()`
          // of a *local* DateTime (no offset suffix), so converted rows must
          // use the same representation or ordering would mix two formats.
          if (from < 2) {
            const dateColumns = <String, String>{
              'repositories': 'last_sync',
              'installed_sources': 'installed_at',
              'media_cache': 'expires_at',
              'watch_history': 'updated_at',
              'library_entries': 'added_at',
              'provider_health_table': 'last_checked',
              'id_mappings': 'fetched_at',
            };
            for (final e in dateColumns.entries) {
              // Guard on existence: a partially-created or hand-repaired
              // database must not make the whole upgrade throw.
              final exists = await customSelect(
                "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
                variables: [Variable.withString(e.key)],
              ).get();
              if (exists.isEmpty) continue;
              await customStatement(
                "UPDATE ${e.key} SET ${e.value} = "
                "strftime('%Y-%m-%dT%H:%M:%f', ${e.value}, 'unixepoch', 'localtime') "
                "WHERE typeof(${e.value}) = 'integer'",
              );
            }
          }
          // v2 -> v3: per-plugin diagnostic log. Additive only, so existing
          // installs keep their library, history and cached catalogues.
          if (from < 3) {
            await m.createTable(pluginLogs);
          }
          // Future migrations go here, guarded by `from`.
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          // WAL is markedly faster on the slow eMMC used in TV boxes.
          await customStatement('PRAGMA journal_mode = WAL');
        },
      );

  /// Long-lived rows (plugin code is written with a ten-year TTL) keep a
  /// forward `expiresAt`, so expiry alone never reclaims them. Anything that far
  /// out survives this age cap: it is stale by construction.
  static const cacheAgeCap = Duration(days: 45);

  /// Removes expired cache rows, plus long-lived rows old enough that they can
  /// only be abandoned plugin code or a mis-set TTL.
  ///
  /// Called on startup so the on-device database does not grow without bound.
  Future<int> pruneCache() async {
    final now = DateTime.now();
    final expired = await (delete(mediaCache)
          ..where((t) => t.expiresAt.isSmallerThanValue(now)))
        .go();
    // A row whose expiry is more than [cacheAgeCap] in the future was written
    // with the "effectively permanent" TTL; those are the ones that leak.
    final farFuture = now.add(cacheAgeCap);
    final ancient = await (delete(mediaCache)
          ..where((t) => t.expiresAt.isBiggerThanValue(farFuture)))
        .go();
    return expired + ancient;
  }
}
