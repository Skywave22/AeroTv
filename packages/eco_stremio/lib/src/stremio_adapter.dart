import 'dart:async';
import 'dart:convert';

import 'package:aero_core/aero_core.dart';

import 'stremio_api.dart';
import 'stremio_manifest.dart';
import 'stremio_parsers.dart';

/// Persistence hook so this package stays pure Dart (no Flutter/Drift import).
abstract class StremioStore {
  Future<List<InstalledSource>> load();
  Future<void> save(InstalledSource source);
  Future<void> delete(String id);
}

/// In-memory store, useful for tests and previews.
class MemoryStremioStore implements StremioStore {
  final Map<String, InstalledSource> _items = {};

  @override
  Future<List<InstalledSource>> load() async => _items.values.toList();

  @override
  Future<void> save(InstalledSource source) async => _items[source.id] = source;

  @override
  Future<void> delete(String id) async => _items.remove(id);
}

/// Stremio adapter. Ships with **zero** add-ons: the user installs everything.
class StremioAdapter implements EcosystemAdapter {
  StremioAdapter({required this.store, StremioApi? api, JsonCache? cache})
      : api = api ?? StremioApi(),
        cache = cache ?? MemoryJsonCache();

  @override
  String? get unavailableReason => null;

  final StremioStore store;
  final StremioApi api;

  /// Persistent cache (Drift-backed in the app). Survives restarts.
  final JsonCache cache;

  final Map<String, StremioManifest> _manifests = {};
  final Set<String> _revalidating = {};

  @override
  Ecosystem get ecosystem => Ecosystem.stremio;

  @override
  bool get isAvailable => true;

  @override
  Set<Capability> get capabilities =>
      {Capability.catalogs, Capability.search, Capability.meta, Capability.streams, Capability.subtitles};

  @override
  Future<List<InstalledSource>> installedSources() => store.load();

  Future<InstalledSource?> _source(String id) async {
    final all = await store.load();
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<StremioManifest> _manifestFor(InstalledSource s) async {
    final hot = _manifests[s.id];
    if (hot != null) return hot;

    final key = CacheKeys.manifest(ecosystem.id, s.id);
    final hit = await cache.read(key);
    if (hit != null && hit.isFresh) {
      try {
        final m = StremioManifest.fromJson(hit.value);
        _manifests[s.id] = m;
        return m;
      } catch (_) {
        await cache.delete(key);
      }
    }
    try {
      final m = await api.fetchManifest(s.url);
      _manifests[s.id] = m;
      await cache.write(key, m.toJson(), ttl: CacheTtl.manifest);
      return m;
    } catch (e) {
      // Offline: a stale manifest still lets the user browse cached catalogs.
      if (hit != null) {
        final m = StremioManifest.fromJson(hit.value);
        _manifests[s.id] = m;
        return m;
      }
      rethrow;
    }
  }

  /// Background catalog refresh, de-duplicated so stale reads cannot stampede.
  void _revalidateCatalog({
    required String key,
    required String url,
    required String sourceName,
  }) {
    if (!_revalidating.add(key)) return;
    unawaited(() async {
      try {
        final json = await api.getJson(url, sourceName: sourceName);
        await cache.write(key, json, ttl: CacheTtl.catalog);
      } catch (_) {
        // Keep serving stale; the next read retries.
      } finally {
        _revalidating.remove(key);
      }
    }());
  }

  @override
  Future<Result<InstalledSource>> install(SourceRef ref) async {
    try {
      final url = StremioApi.normaliseManifestUrl(ref.url);
      final manifest = await api.fetchManifest(url);

      if (manifest.requiresConfiguration) {
        return const Err(
          'This add-on requires configuration. Open its configure page, then '
          'install using the generated URL.',
        );
      }

      final existing = await store.load();
      final nextPriority = existing.isEmpty
          ? 10
          : existing.map((e) => e.priority).reduce((a, b) => a > b ? a : b) + 10;

      final source = InstalledSource(
        id: manifest.id,
        ecosystem: Ecosystem.stremio,
        name: manifest.name,
        url: url,
        version: manifest.version,
        description: manifest.description,
        logo: manifest.logo,
        priority: nextPriority,
        repoId: ref.repoId,
        capabilities: manifest.capabilities,
        types: manifest.types,
        idPrefixes: manifest.idPrefixes,
        catalogs: manifest.catalogs,
        installedAt: DateTime.now(),
        adult: manifest.isAdult,
      );
      await store.save(source);
      _manifests[manifest.id] = manifest;
      AeroLog.instance.i('stremio', 'Installed ${manifest.name} v${manifest.version}');
      return Ok(source);
    } on AeroException catch (e) {
      return Err(e.message);
    } catch (e) {
      return Err(_friendly(e));
    }
  }

  @override
  Future<void> uninstall(String sourceId) async {
    await store.delete(sourceId);
    _manifests.remove(sourceId);
  }

  @override
  Future<Result<InstalledSource>> checkUpdate(String sourceId) async {
    final s = await _source(sourceId);
    if (s == null) return const Err('Add-on not installed');
    try {
      final m = await api.fetchManifest(s.url);
      _manifests[sourceId] = m;
      final updated = s.copyWith(
        version: m.version,
        name: m.name,
        capabilities: m.capabilities,
        catalogs: m.catalogs,
      );
      await store.save(updated);
      return Ok(updated);
    } catch (e) {
      return Err(_friendly(e));
    }
  }

  @override
  Future<Result<Duration>> healthCheck(String sourceId) async {
    final s = await _source(sourceId);
    if (s == null) return const Err('Add-on not installed');
    final sw = Stopwatch()..start();
    try {
      await api.fetchManifest(s.url);
      sw.stop();
      return Ok(sw.elapsed);
    } catch (e) {
      return Err(_friendly(e));
    }
  }

  @override
  Future<List<CatalogRow>> catalogs(String sourceId) async {
    final s = await _source(sourceId);
    if (s == null) return const [];
    try {
      final m = await _manifestFor(s);
      return m.catalogs
          .map((c) => CatalogRow(
                sourceId: sourceId,
                catalogId: c.id,
                title: c.displayTitle,
                type: c.type,
                genres: c.genres,
                searchable: c.searchable,
                requiredExtras: c.requiredExtras,
              ))
          .toList();
    } catch (e) {
      AeroLog.instance.w('stremio', 'catalogs($sourceId) failed: $e');
      return const [];
    }
  }

  @override
  Future<Page<MediaItem>> browse(
    String sourceId,
    String catalogId,
    CatalogQuery q,
  ) async {
    final s = await _source(sourceId);
    if (s == null) return Page.empty();
    try {
      final m = await _manifestFor(s);
      CatalogDescriptor? desc;
      for (final c in m.catalogs) {
        if (c.id == catalogId) {
          desc = c;
          break;
        }
      }
      final type = desc?.type.wire ?? 'movie';
      final extra = q.toExtraMap();
      final url = StremioApi.catalogUrl(s.url, type, catalogId, extra);
      final key = CacheKeys.catalog(ecosystem.id, sourceId, type, catalogId, extra);

      final hit = await cache.read(key);
      Map<String, dynamic> json;
      if (hit != null && hit.isFresh) {
        json = hit.value;
      } else if (hit != null) {
        json = hit.value;
        _revalidateCatalog(key: key, url: url, sourceName: s.name);
      } else {
        json = await api.getJson(url, sourceName: s.name);
        await cache.write(key, json, ttl: CacheTtl.catalog);
      }
      final metas = (json['metas'] as List? ?? const []);
      final items = metas
          .whereType<Map>()
          .map((e) => StremioParsers.metaPreview(Map<String, dynamic>.from(e)))
          .whereType<MediaItem>()
          .toList();
      final pageSize = desc?.pageSize ?? 100;
      return Page(
        items: items,
        hasMore: items.length >= pageSize,
        nextSkip: q.skip + items.length,
      );
    } catch (e) {
      AeroLog.instance.w('stremio', 'browse($sourceId/$catalogId) failed: $e');
      return Page.empty();
    }
  }

  @override
  Future<Page<MediaItem>> search(String sourceId, String query) async {
    if (query.trim().isEmpty) return Page.empty();
    final s = await _source(sourceId);
    if (s == null) return Page.empty();
    try {
      final m = await _manifestFor(s);
      final searchable = m.catalogs.where((c) => c.searchable).toList();
      if (searchable.isEmpty) return Page.empty();

      // Query each searchable catalog in parallel, then merge and de-dup.
      final results = await Future.wait(searchable.map((c) async {
        final url = StremioApi.catalogUrl(
          s.url,
          c.type.wire,
          c.id,
          {'search': query.trim()},
        );
        try {
          final json = await api.getJson(url, sourceName: s.name);
          return (json['metas'] as List? ?? const [])
              .whereType<Map>()
              .map((e) => StremioParsers.metaPreview(Map<String, dynamic>.from(e)))
              .whereType<MediaItem>()
              .toList();
        } catch (_) {
          return const <MediaItem>[];
        }
      }));

      final seen = <String>{};
      final merged = <MediaItem>[];
      for (final list in results) {
        for (final item in list) {
          if (seen.add(item.ref.cacheKey)) merged.add(item);
        }
      }
      return Page(items: merged);
    } catch (e) {
      AeroLog.instance.w('stremio', 'search($sourceId) failed: $e');
      return Page.empty();
    }
  }

  @override
  Future<Result<MediaDetails>> details(String sourceId, MediaRef ref) async {
    final s = await _source(sourceId);
    if (s == null) return const Err('Add-on not installed');
    try {
      final m = await _manifestFor(s);
      final id = ref.imdbId ?? ref.id;
      if (!m.serves('meta', ref.type, mediaId: id)) {
        return const Err('This add-on does not provide metadata for this title');
      }
      final url = StremioApi.resourceUrl(s.url, 'meta', ref.type.wire, id);
      final key = CacheKeys.meta(ecosystem.id, sourceId, ref.type.wire, id);
      final hit = await cache.read(key);
      Map<String, dynamic> json;
      if (hit != null && hit.isFresh) {
        json = hit.value;
      } else {
        try {
          json = await api.getJson(url, sourceName: s.name);
          await cache.write(key, json, ttl: CacheTtl.meta);
        } catch (e) {
          if (hit != null) {
            json = hit.value;
          } else {
            rethrow;
          }
        }
      }
      final meta = json['meta'];
      if (meta is! Map) return const Err('No metadata returned');
      final details = StremioParsers.metaDetail(Map<String, dynamic>.from(meta));
      if (details == null) return const Err('Malformed metadata');
      return Ok(details);
    } catch (e) {
      return Err(_friendly(e));
    }
  }

  @override
  Stream<StreamLink> streams(String sourceId, PlayRequest req) async* {
    final s = await _source(sourceId);
    if (s == null) return;
    StremioManifest m;
    try {
      m = await _manifestFor(s);
    } catch (e) {
      AeroLog.instance.w('stremio', 'streams: manifest failed for $sourceId: $e');
      return;
    }

    final videoId = req.stremioVideoId;
    // For series, the resource is declared against `series` but the id is the
    // composite episode id; check the base id for prefix matching.
    final baseId = req.ref.imdbId ?? req.ref.id;
    if (!m.serves('stream', req.ref.type, mediaId: baseId)) return;

    final url = StremioApi.resourceUrl(s.url, 'stream', req.ref.type.wire, videoId);
    try {
      final json = await api.getJson(url, sourceName: s.name);
      final list = (json['streams'] as List? ?? const []);
      for (final raw in list) {
        if (raw is! Map) continue;
        final link = StremioParsers.stream(
          Map<String, dynamic>.from(raw),
          sourceId: sourceId,
          sourceName: s.name,
        );
        if (link == null) continue;
        // Emit immediately so the sheet fills progressively.
        yield link;
      }
    } catch (e) {
      AeroLog.instance.w('stremio', 'streams($sourceId) failed: $e');
      // Swallow: the resolver reports this source as empty/failed.
    }
  }

  @override
  Future<List<SubtitleTrack>> subtitles(String sourceId, PlayRequest req) async {
    final s = await _source(sourceId);
    if (s == null) return const [];
    try {
      final m = await _manifestFor(s);
      final baseId = req.ref.imdbId ?? req.ref.id;
      if (!m.serves('subtitles', req.ref.type, mediaId: baseId)) return const [];
      final url =
          StremioApi.resourceUrl(s.url, 'subtitles', req.ref.type.wire, req.stremioVideoId);
      final json = await api.getJson(url, sourceName: s.name);
      return (json['subtitles'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => SubtitleTrack.fromJson(Map<String, dynamic>.from(e)))
          .where((t) => t.url.isNotEmpty)
          .toList();
    } catch (e) {
      AeroLog.instance.w('stremio', 'subtitles($sourceId) failed: $e');
      return const [];
    }
  }

  /// Serialises installed add-ons for backup/export.
  Future<String> exportConfig() async {
    final all = await store.load();
    return const JsonEncoder.withIndent('  ')
        .convert({'stremio': all.map((s) => s.toJson()).toList()});
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('SocketException') || s.contains('Failed host lookup')) {
      return 'Could not reach the add-on. Check the URL and your connection.';
    }
    if (s.contains('TimeoutException') || s.contains('timeout')) {
      return 'The add-on took too long to respond.';
    }
    if (s.contains('HandshakeException') || s.contains('CERTIFICATE')) {
      return 'TLS certificate error. The add-on host may be misconfigured.';
    }
    return s.length > 180 ? '${s.substring(0, 180)}…' : s;
  }

  @override
  Future<void> dispose() async {
    _manifests.clear();
    api.close();
  }
}
