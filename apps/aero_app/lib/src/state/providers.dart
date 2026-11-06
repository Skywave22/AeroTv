import 'dart:async';

import 'package:aero_core/aero_core.dart';
import 'package:aero_data/aero_data.dart';
import 'package:eco_cloudstream/eco_cloudstream.dart';
import 'package:eco_js_runtime/eco_js_runtime.dart';
import 'package:eco_nuvio/eco_nuvio.dart';
import 'package:eco_skystream/eco_skystream.dart';
import 'package:eco_stremio/eco_stremio.dart';
import 'package:eco_vega/eco_vega.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// --------------------------------------------------------------- database

final databaseProvider = Provider<AeroDatabase>((ref) {
  throw UnimplementedError('Overridden after bootstrap');
});

final sourceRepoProvider = Provider<SourceRepository>(
  (ref) => SourceRepository(ref.watch(databaseProvider)),
);

final settingsRepoProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);

final libraryRepoProvider = Provider<LibraryRepository>(
  (ref) => LibraryRepository(ref.watch(databaseProvider)),
);

final historyRepoProvider = Provider<HistoryRepository>(
  (ref) => HistoryRepository(ref.watch(databaseProvider)),
);

final healthRepoProvider = Provider<HealthRepository>(
  (ref) => HealthRepository(ref.watch(databaseProvider)),
);

final cacheRepoProvider = Provider<CacheRepository>(
  (ref) => CacheRepository(ref.watch(databaseProvider)),
);

/// Resolves a repository URL or shortcode, with the SSRF guard applied to the
/// address it resolves to.
final repoLinkServiceProvider = Provider<RepoLinkService>((ref) => RepoLinkService());

final pluginLogRepoProvider = Provider<PluginLogRepository>(
  (ref) => PluginLogRepository(ref.watch(databaseProvider)),
);

final matchRepoProvider = Provider<MatchRepository>(
  (ref) => MatchRepository(ref.watch(databaseProvider)),
);

/// Per-source circuit breaker. In-memory and session-scoped by design, so a
/// restart never inherits a stale "this host is down" verdict.
final circuitBreakerProvider = Provider<CircuitBreaker>((ref) => CircuitBreaker());

final backupServiceProvider = Provider<BackupService>((ref) => BackupService(
      db: ref.watch(databaseProvider),
      sources: ref.watch(sourceRepoProvider),
      settings: ref.watch(settingsRepoProvider),
      library: ref.watch(libraryRepoProvider),
    ));

/// ------------------------------------------------------------------ device

/// True on Android TV / Fire TV. Detected natively at bootstrap.
final isTvProvider = StateProvider<bool>((ref) => false);

/// ---------------------------------------------------------------- adapters

/// Bridges [SourceRepository] into the pure-Dart Stremio store interface.
class _StremioStoreBridge implements StremioStore {
  _StremioStoreBridge(this.repo);
  final SourceRepository repo;

  @override
  Future<List<InstalledSource>> load() => repo.loadByEcosystem(Ecosystem.stremio);
  @override
  Future<void> save(InstalledSource source) => repo.save(source);
  @override
  Future<void> delete(String id) => repo.delete(Ecosystem.stremio, id);
}

/// Bridges [SourceRepository] into the JS plugin store interface. Plugin code
/// is cached in the media cache table with a long TTL.
class _JsStoreBridge implements JsPluginStore {
  _JsStoreBridge(this.repo, this.cache);
  final SourceRepository repo;
  final CacheRepository cache;

  String _codeKey(Ecosystem e, String id) => 'jscode:${e.id}:$id';

  @override
  Future<List<InstalledSource>> load(Ecosystem ecosystem) =>
      repo.loadByEcosystem(ecosystem);
  @override
  Future<void> save(InstalledSource source) => repo.save(source);
  @override
  Future<void> delete(Ecosystem ecosystem, String id) => repo.delete(ecosystem, id);

  @override
  Future<String?> loadCode(Ecosystem ecosystem, String id) async {
    final row = await cache.get(_codeKey(ecosystem, id));
    return row?['code'] as String?;
  }

  @override
  Future<void> saveCode(Ecosystem ecosystem, String id, String code) async {
    if (code.isEmpty) {
      await cache.delete(_codeKey(ecosystem, id));
      return;
    }
    await cache.put(
      _codeKey(ecosystem, id),
      {'code': code},
      // Plugin code is effectively permanent until updated.
      ttl: const Duration(days: 3650),
    );
  }
}

final adapterRegistryProvider = Provider<AdapterRegistry>((ref) {
  final registry = AdapterRegistry();
  final sources = ref.watch(sourceRepoProvider);
  final cache = ref.watch(cacheRepoProvider);

  registry.register(
    StremioAdapter(store: _StremioStoreBridge(sources), cache: cache),
  );

  final jsStore = _JsStoreBridge(sources, cache);
  // JS ecosystems are registered but ship no plugins; the user adds their own.
  registry.register(VegaAdapter(store: jsStore));
  registry.register(NuvioAdapter(store: jsStore));
  registry.register(SkyStreamAdapter(store: jsStore));
  registry.register(CloudStreamAdapter());

  ref.onDispose(() => unawaited(registry.disposeAll()));
  return registry;
});

final metadataResolverProvider = Provider<MetadataResolver>((ref) {
  final settings = ref.watch(settingsRepoProvider);
  final key = settings.tmdbApiKey;
  return MetadataResolver(
    lookup: key.isEmpty
        ? null
        : TmdbIdLookup(db: ref.watch(databaseProvider), apiKey: key),
  );
});

/// ----------------------------------------------------------------- resolver

final rankingRulesProvider = StateProvider<RankingRules>((ref) {
  return ref.watch(settingsRepoProvider).ranking;
});

final streamResolverProvider = Provider<StreamResolver>((ref) {
  final health = ref.watch(healthRepoProvider);
  return StreamResolver(
    registry: ref.watch(adapterRegistryProvider),
    rules: ref.watch(rankingRulesProvider),
    perSourceTimeout: const Duration(seconds: 12),
    overallTimeout: const Duration(seconds: 25),
    onHealth: (key, {required bool ok, int? latencyMs, String? error}) {
      unawaited(health.record(key, ok: ok, latencyMs: latencyMs, error: error));
    },
  );
});

/// ---------------------------------------------------------------- settings

final playerSettingsProvider = StateProvider<PlayerSettings>(
  (ref) => ref.watch(settingsRepoProvider).player,
);

final uiSettingsProvider = StateProvider<UiSettings>(
  (ref) => ref.watch(settingsRepoProvider).ui,
);

/// ---------------------------------------------------------------- sources

/// All installed sources; invalidate after install/uninstall/toggle.
final installedSourcesProvider = FutureProvider<List<InstalledSource>>((ref) async {
  return ref.watch(sourceRepoProvider).loadAll();
});

final sourcesByEcosystemProvider =
    FutureProvider.family<List<InstalledSource>, Ecosystem>((ref, eco) async {
  final all = await ref.watch(installedSourcesProvider.future);
  return all.where((s) => s.ecosystem == eco).toList();
});

final enabledSourceCountProvider = Provider<int>((ref) {
  final sources = ref.watch(installedSourcesProvider).valueOrNull ?? const [];
  return sources.where((s) => s.enabled).length;
});

/// ------------------------------------------------------------------- home

/// A home row ready to render.
class HomeRow {
  const HomeRow({
    required this.key,
    required this.title,
    required this.sourceId,
    required this.ecosystem,
    required this.catalogId,
    required this.items,
    this.subtitle,
  });

  final String key;
  final String title;
  final String sourceId;
  final Ecosystem ecosystem;
  final String catalogId;
  final List<MediaItem> items;
  final String? subtitle;
}

/// Aggregates catalogs from every enabled source, in priority order.
///
/// Rows load in parallel with a per-row timeout so one slow add-on doesn't
/// stall Home. Empty rows are dropped.
final homeRowsProvider = FutureProvider<List<HomeRow>>((ref) async {
  final registry = ref.watch(adapterRegistryProvider);
  final sources = await ref.watch(installedSourcesProvider.future);
  final enabled = sources.where((s) => s.enabled).toList()
    ..sort((a, b) => a.priority.compareTo(b.priority));
  if (enabled.isEmpty) return const [];

  final rows = <HomeRow>[];
  final futures = <Future<void>>[];

  for (final s in enabled.take(8)) {
    final adapter = registry.forEcosystem(s.ecosystem);
    if (adapter == null || !adapter.isAvailable) continue;
    futures.add(() async {
      try {
        final catalogs = await adapter
            .catalogs(s.id)
            .timeout(const Duration(seconds: 12));
        // Only catalogs needing no user input can be passive Home rows.
        for (final c in catalogs.where((c) => c.isHomeEligible).take(3)) {
          try {
            final page = await adapter
                .browse(s.id, c.catalogId, const CatalogQuery())
                .timeout(const Duration(seconds: 12));
            if (page.items.isEmpty) continue;
            rows.add(HomeRow(
              key: '${s.key}:${c.catalogId}',
              title: c.title,
              subtitle: s.name,
              sourceId: s.id,
              ecosystem: s.ecosystem,
              catalogId: c.catalogId,
              items: page.items,
            ));
          } catch (_) {
            // Skip an individual failing catalog.
          }
        }
      } catch (_) {
        // Skip a failing add-on entirely.
      }
    }());
  }

  await Future.wait(futures);

  // Preserve provider priority in the final ordering.
  final order = {for (var i = 0; i < enabled.length; i++) enabled[i].key: i};
  rows.sort((a, b) {
    final ai = order['${a.ecosystem.id}:${a.sourceId}'] ?? 999;
    final bi = order['${b.ecosystem.id}:${b.sourceId}'] ?? 999;
    return ai.compareTo(bi);
  });
  return rows;
});

final continueWatchingProvider = StreamProvider<List<HistoryEntry>>((ref) {
  return ref.watch(historyRepoProvider).watchContinueWatching();
});

final watchlistProvider = StreamProvider<List<MediaItem>>((ref) {
  return ref.watch(libraryRepoProvider).watch(LibraryLists.watchlist);
});

final favoritesProvider = StreamProvider<List<MediaItem>>((ref) {
  return ref.watch(libraryRepoProvider).watch(LibraryLists.favorites);
});

/// ------------------------------------------------------------------ search

final searchQueryProvider = StateProvider<String>((ref) => '');
final searchEcosystemFilterProvider = StateProvider<Set<Ecosystem>>((ref) => {});

final searchResultsProvider = FutureProvider<List<MediaItem>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.length < 2) return const [];
  final filter = ref.watch(searchEcosystemFilterProvider);
  final registry = ref.watch(adapterRegistryProvider);
  final sources = await ref.watch(installedSourcesProvider.future);

  final targets = sources
      .where((s) => s.enabled)
      .where((s) => filter.isEmpty || filter.contains(s.ecosystem))
      .where((s) => s.can(Capability.search))
      .toList();

  final results = await Future.wait(targets.map((s) async {
    final adapter = registry.forEcosystem(s.ecosystem);
    if (adapter == null || !adapter.isAvailable) return const <MediaItem>[];
    try {
      final page =
          await adapter.search(s.id, query).timeout(const Duration(seconds: 12));
      return page.items;
    } catch (_) {
      return const <MediaItem>[];
    }
  }));

  // Merge, de-duping by external id so the same film from two add-ons is one card.
  final seen = <String>{};
  final merged = <MediaItem>[];
  for (final list in results) {
    for (final item in list) {
      if (seen.add(item.ref.cacheKey)) merged.add(item);
    }
  }
  return merged;
});

/// ----------------------------------------------------------------- details

/// Identifies a details request across ecosystems.
@immutable
class DetailsArgs {
  const DetailsArgs({required this.ref, this.preferredSourceId, this.preferredEcosystem});

  final MediaRef ref;
  final String? preferredSourceId;
  final Ecosystem? preferredEcosystem;

  @override
  bool operator ==(Object other) =>
      other is DetailsArgs &&
      other.ref == ref &&
      other.preferredSourceId == preferredSourceId;

  @override
  int get hashCode => Object.hash(ref, preferredSourceId);
}

/// Fetches details from the best available metadata source.
final detailsProvider =
    FutureProvider.family<MediaDetails?, DetailsArgs>((ref, args) async {
  final registry = ref.watch(adapterRegistryProvider);
  final resolver = ref.watch(metadataResolverProvider);
  final enriched = await resolver.enrich(args.ref);
  final sources = await ref.watch(installedSourcesProvider.future);

  final candidates = sources.where((s) => s.enabled && s.can(Capability.meta)).toList()
    ..sort((a, b) {
      // Prefer the add-on the user came from.
      if (a.id == args.preferredSourceId) return -1;
      if (b.id == args.preferredSourceId) return 1;
      return a.priority.compareTo(b.priority);
    });

  for (final s in candidates) {
    final adapter = registry.forEcosystem(s.ecosystem);
    if (adapter == null || !adapter.isAvailable) continue;
    try {
      final res = await adapter
          .details(s.id, enriched)
          .timeout(const Duration(seconds: 12));
      if (res.isOk) return res.valueOrNull;
    } catch (_) {
      continue;
    }
  }

  // No add-on could supply metadata: still return a shell so Play works.
  return MediaDetails(
    item: MediaItem(
      ref: enriched,
      title: enriched.title ?? enriched.id,
      year: enriched.year,
    ),
  );
});

/// Log stream for the debug panel.
final logStreamProvider = StreamProvider<LogEntry>((ref) {
  final controller = StreamController<LogEntry>.broadcast();
  final cancel = AeroLog.instance.listen(controller.add);
  ref.onDispose(() {
    cancel();
    unawaited(controller.close());
  });
  return controller.stream;
});

/// ----------------------------------------------------------------- browse
///
/// The Browse tab shows ONE plugin's own content at a time, the way SkyStream
/// and Vega present a provider: its own categories, its own hero, its own
/// ordering. It deliberately does not merge ecosystems — that is Home's job.

/// Installed plugins that can actually supply a home feed.
///
/// Nuvio is excluded by capability, not by a hardcoded name: its scrapers only
/// export `getStreams`, so offering to browse one would show an empty screen.
/// See docs/specs/VERIFIED_CONTRACTS.md.
final browsableSourcesProvider = FutureProvider<List<InstalledSource>>((ref) async {
  final registry = ref.watch(adapterRegistryProvider);
  final all = await ref.watch(installedSourcesProvider.future);
  final out = <InstalledSource>[];
  for (final s in all) {
    if (!s.enabled) continue;
    final adapter = registry.forEcosystem(s.ecosystem);
    if (adapter == null || !adapter.isAvailable) continue;
    if (!adapter.capabilities.contains(Capability.catalogs)) continue;
    out.add(s);
  }
  out.sort((a, b) => a.priority.compareTo(b.priority));
  return out;
});

/// Plugins that are installed but cannot be browsed, with the reason. Used to
/// explain the absence rather than silently hiding them.
final nonBrowsableSourcesProvider = FutureProvider<List<InstalledSource>>((ref) async {
  final registry = ref.watch(adapterRegistryProvider);
  final all = await ref.watch(installedSourcesProvider.future);
  return all.where((s) {
    if (!s.enabled) return false;
    final a = registry.forEcosystem(s.ecosystem);
    return a != null && !a.capabilities.contains(Capability.catalogs);
  }).toList();
});

/// Which plugin the Browse tab is showing. Null means "pick the first".
final browseSelectionProvider = StateProvider<String?>((ref) => null);

/// One plugin's home feed: a hero set plus its own category rows.
class PluginHome {
  const PluginHome({
    required this.source,
    required this.hero,
    required this.rows,
    this.error,
  });

  final InstalledSource source;
  final List<MediaItem> hero;
  final List<CatalogRow> rows;
  final String? error;

  bool get isEmpty => hero.isEmpty && rows.isEmpty;
}

/// Loads a single plugin's home. Applies SkyStream's dashboard rule uniformly:
/// a "Trending" category becomes the hero and is removed from the rows; if
/// absent the first non-empty category is promoted instead.
final pluginHomeProvider =
    FutureProvider.family<PluginHome, String>((ref, sourceId) async {
  final registry = ref.watch(adapterRegistryProvider);
  final sources = await ref.watch(installedSourcesProvider.future);
  InstalledSource? source;
  for (final s in sources) {
    if (s.id == sourceId) {
      source = s;
      break;
    }
  }
  if (source == null) {
    return PluginHome(
      source: InstalledSource(
        id: sourceId,
        ecosystem: Ecosystem.stremio,
        name: 'Unknown',
        url: '',
      ),
      hero: const [],
      rows: const [],
      error: 'This plugin is no longer installed.',
    );
  }

  final adapter = registry.forEcosystem(source.ecosystem);
  if (adapter == null || !adapter.isAvailable) {
    return PluginHome(
      source: source,
      hero: const [],
      rows: const [],
      error: adapter?.unavailableReason ?? 'This ecosystem is not available here.',
    );
  }

  try {
    final catalogs =
        await adapter.catalogs(sourceId).timeout(const Duration(seconds: 20));
    final filled = catalogs.where((c) => c.items.isNotEmpty).toList();
    if (filled.isEmpty) {
      return PluginHome(source: source, hero: const [], rows: const []);
    }
    final trendingIdx = filled
        .indexWhere((c) => c.title.trim().toLowerCase() == 'trending');
    final heroIdx = trendingIdx >= 0 ? trendingIdx : 0;
    final hero = filled[heroIdx].items;
    final rows = <CatalogRow>[];
    for (var i = 0; i < filled.length; i++) {
      if (i == heroIdx) continue;
      rows.add(filled[i]);
    }
    return PluginHome(source: source, hero: hero, rows: rows);
  } catch (e) {
    return PluginHome(
      source: source,
      hero: const [],
      rows: const [],
      error: e.toString().replaceFirst('Exception: ', ''),
    );
  }
});
