import 'package:drift/drift.dart';

/// Plugin repositories (Vega / Nuvio / SkyStream / CloudStream).
///
/// The generated row class is named `PluginRepoRow` to avoid colliding with
/// the domain model `Repository` from aero_core.
@DataClassName('PluginRepoRow')
class Repositories extends Table {
  TextColumn get id => text()();
  TextColumn get ecosystem => text()();
  TextColumn get url => text()();
  TextColumn get name => text()();
  DateTimeColumn get lastSync => dateTime().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id, ecosystem};
}

/// Installed add-ons / providers / scrapers / plugins across all ecosystems.
@DataClassName('InstalledSourceRow')
class InstalledSources extends Table {
  TextColumn get id => text()();
  TextColumn get ecosystem => text()();
  TextColumn get repoId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get url => text()();
  TextColumn get version => text().withDefault(const Constant('0.0.0'))();
  TextColumn get description => text().nullable()();
  TextColumn get logo => text().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get priority => integer().withDefault(const Constant(100))();

  /// JSON blob: capabilities, types, idPrefixes, catalogs, per-plugin config.
  TextColumn get configJson => text().withDefault(const Constant('{}'))();
  TextColumn get sha256 => text().nullable()();
  BoolColumn get adult => boolean().withDefault(const Constant(false))();
  DateTimeColumn get installedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id, ecosystem};
}

/// Generic JSON cache with TTL (catalogs, metadata, resolved streams).
@DataClassName('MediaCacheRow')
class MediaCache extends Table {
  TextColumn get key => text()();
  TextColumn get json => text()();
  DateTimeColumn get expiresAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Resume points and watch history.
@DataClassName('WatchHistoryRow')
class WatchHistory extends Table {
  TextColumn get mediaId => text()();
  TextColumn get profileId => text().withDefault(const Constant('default'))();
  IntColumn get season => integer().nullable()();
  IntColumn get episode => integer().nullable()();
  IntColumn get positionMs => integer().withDefault(const Constant(0))();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();

  /// Denormalised card data so Continue Watching renders offline.
  TextColumn get metaJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {mediaId, profileId, season, episode};
}

/// Watchlist / favorites / custom lists.
@DataClassName('LibraryEntryRow')
class LibraryEntries extends Table {
  TextColumn get mediaId => text()();
  TextColumn get profileId => text().withDefault(const Constant('default'))();
  TextColumn get listName => text()();
  TextColumn get metaJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {mediaId, profileId, listName};
}

/// Local profiles with an optional PIN hash.
@DataClassName('ProfileRow')
class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get avatar => text().nullable()();
  TextColumn get pinHash => text().nullable()();
  BoolColumn get isKids => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Rolling provider reliability counters.
@DataClassName('ProviderHealthRow')
class ProviderHealthTable extends Table {
  TextColumn get sourceKey => text()();
  IntColumn get successCount => integer().withDefault(const Constant(0))();
  IntColumn get failCount => integer().withDefault(const Constant(0))();
  RealColumn get avgLatencyMs => real().withDefault(const Constant(0))();
  DateTimeColumn get lastChecked => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {sourceKey};
}

/// Non-secret app settings as key/value JSON.
@DataClassName('AppSettingRow')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get valueJson => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Cached external-ID mappings (IMDb ↔ TMDB).
@DataClassName('IdMappingRow')
class IdMappings extends Table {
  TextColumn get key => text()();
  TextColumn get json => text()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Per-plugin diagnostic log, persisted so a crash or a failed play can be
/// inspected after the fact. The in-memory AeroLog ring buffer is global and
/// loses everything on restart; this is scoped to one source and survives.
///
/// Rows are capped per source by [PluginLogRepository] and removed entirely on
/// uninstall, so a chatty plugin cannot grow the database without bound.
@DataClassName('PluginLogRow')
class PluginLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sourceKey => text()();
  DateTimeColumn get at => dateTime()();
  TextColumn get level => text()();
  TextColumn get tag => text()();
  TextColumn get message => text()();

  /// Redacted destination, when the entry describes a network call.
  TextColumn get uri => text().nullable()();
}
