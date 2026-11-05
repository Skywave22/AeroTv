import 'dart:convert';

import 'package:aero_core/aero_core.dart';
import 'package:dio/dio.dart';
import 'package:eco_js_runtime/eco_js_runtime.dart';

import 'js_skystream_provider.dart';
import 'skystream_provider.dart';

/// SkyStream ecosystem adapter.
///
/// Contract verified 2026-11-05 against `akashdh11/skystream@master` and
/// `skystream-tools/DEVELOPER.md`. Plugins are callback-style JS with a
/// `plugin.json` manifest; repositories are `repo.json` indexes.
class SkyStreamAdapter implements EcosystemAdapter {
  SkyStreamAdapter({
    required JsPluginStore store,
    JsSandboxPolicy policy = const JsSandboxPolicy(),
    Dio? dio,
  }) : _mgr = JsSourceManager(
          ecosystem: Ecosystem.skystream,
          store: store,
          policy: policy,
          dio: dio,
        );

  final JsSourceManager _mgr;
  final Map<String, Map<String, dynamic>> _manifests = {};

  JsSourceManager get manager => _mgr;

  @override
  Ecosystem get ecosystem => Ecosystem.skystream;

  @override
  bool get isAvailable => true;

  @override
  String? get unavailableReason => null;

  @override
  Set<Capability> get capabilities => {
        Capability.catalogs,
        Capability.search,
        Capability.meta,
        Capability.streams,
      };

  @override
  Future<List<InstalledSource>> installedSources() => _mgr.installed();

  // ------------------------------------------------------------- manifest

  /// Extracts `plugin.json` from a repository entry or a sidecar URL.
  ///
  /// SkyStream ships the manifest separately from the JS, so we accept it
  /// inline (repo index) or fetch `<plugin dir>/plugin.json`.
  Future<Map<String, dynamic>> _manifestFor(String codeUrl,
      {Map<String, dynamic>? inline}) async {
    if (inline != null && inline.isNotEmpty) return inline;
    final dir = codeUrl.substring(0, codeUrl.lastIndexOf('/') + 1);
    final res = await _mgr.fetchJson('${dir}plugin.json');
    if (res.isOk && res.valueOrNull is Map) {
      return Map<String, dynamic>.from(res.valueOrNull! as Map);
    }
    // Fall back to a minimal manifest so a bare plugin.js still installs.
    final name = Uri.parse(codeUrl).pathSegments.isNotEmpty
        ? Uri.parse(codeUrl).pathSegments.last.replaceAll('.js', '')
        : 'plugin';
    return {
      'packageName': name,
      'name': name,
      'version': 1,
      'baseUrl': dir,
    };
  }

  @override
  Future<Result<InstalledSource>> install(SourceRef ref) async {
    try {
      final codeRes = await _mgr.fetchCode(ref.url, expectedSha256: ref.expectedSha256);
      if (codeRes.isErr) return Err(codeRes.errorOrNull!);
      final code = codeRes.valueOrNull!;

      final manifest = await _manifestFor(ref.url, inline: ref.extra);
      final id = (manifest['packageName'] ?? ref.name ?? 'sky_plugin').toString();
      final name = (manifest['name'] ?? ref.name ?? id).toString();

      final source = InstalledSource(
        id: id,
        ecosystem: ecosystem,
        name: name,
        url: ref.url,
        version: (manifest['version'] ?? 1).toString(),
        description: manifest['description']?.toString(),
        logo: manifest['logo']?.toString(),
        priority: await _mgr.nextPriority(),
        repoId: ref.repoId,
        capabilities: capabilities,
        types: const [MediaType.movie, MediaType.series],
        installedAt: DateTime.now(),
        sha256: JsPluginBundle.hashOf(code),
      );

      _manifests[id] = manifest;
      _mgr.setPrelude(id, JsSkyStreamProvider.preludeFor(manifest));
      await _mgr.persist(source, code);
      // Persist the manifest alongside the code so it survives a restart.
      await _mgr.store.saveCode(ecosystem, '$id.manifest', jsonEncode(manifest));
      return Ok(source);
    } catch (e) {
      return Err(JsSourceManager.friendlyError(e));
    }
  }

  Future<Map<String, dynamic>> _loadManifest(InstalledSource s) async {
    final cached = _manifests[s.id];
    if (cached != null) return cached;
    final raw = await _mgr.store.loadCode(ecosystem, '${s.id}.manifest');
    if (raw != null && raw.isNotEmpty) {
      try {
        final m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        _manifests[s.id] = m;
        _mgr.setPrelude(s.id, JsSkyStreamProvider.preludeFor(m));
        return m;
      } catch (_) {/* fall through */}
    }
    final m = {'packageName': s.id, 'name': s.name, 'version': 1, 'baseUrl': s.url};
    _manifests[s.id] = m;
    _mgr.setPrelude(s.id, JsSkyStreamProvider.preludeFor(m));
    return m;
  }

  /// Returns the native SkyStream provider for a plugin, so the Browse tab can
  /// use `getHome()` categories exactly as SkyStream does.
  Future<SkyStreamProvider?> providerFor(String sourceId) async {
    final s = await _mgr.source(sourceId);
    if (s == null) return null;
    final manifest = await _loadManifest(s);
    final host = await _mgr.hostFor(s);
    if (host == null) return null;
    return JsSkyStreamProvider(host: host, manifest: manifest);
  }

  @override
  Future<void> uninstall(String sourceId) async {
    _manifests.remove(sourceId);
    await _mgr.store.saveCode(ecosystem, '$sourceId.manifest', '');
    await _mgr.uninstall(sourceId);
  }

  @override
  Future<Result<InstalledSource>> checkUpdate(String sourceId) async {
    final s = await _mgr.source(sourceId);
    if (s == null) return const Err('Plugin not installed');
    await _mgr.evict(sourceId);
    _manifests.remove(sourceId);
    return install(SourceRef(
      ecosystem: ecosystem,
      url: s.url,
      repoId: s.repoId,
      name: s.name,
    ));
  }

  @override
  Future<Result<Duration>> healthCheck(String sourceId) async {
    final s = await _mgr.source(sourceId);
    if (s != null) await _loadManifest(s);
    return _mgr.healthCheck(sourceId);
  }

  // -------------------------------------------------------------- content

  @override
  Future<List<CatalogRow>> catalogs(String sourceId) async {
    final p = await providerFor(sourceId);
    if (p == null) return const [];
    final home = await p.getHome();
    final layout = applySkyDashboardRule(home);
    final rows = <CatalogRow>[];
    if (layout.hero.isNotEmpty) {
      rows.add(CatalogRow(
        sourceId: sourceId,
        catalogId: kSkyTrendingCategory,
        title: kSkyTrendingCategory,
        type: MediaType.movie,
        items: layout.hero.map((e) => e.toMediaItem()).toList(),
      ));
    }
    layout.rows.forEach((title, items) {
      rows.add(CatalogRow(
        sourceId: sourceId,
        catalogId: title,
        title: title,
        type: items.first.type.toMediaType,
        items: items.map((e) => e.toMediaItem()).toList(),
      ));
    });
    return rows;
  }

  @override
  Future<Page<MediaItem>> browse(
      String sourceId, String catalogId, CatalogQuery q) async {
    final p = await providerFor(sourceId);
    if (p == null) return Page.empty();
    final home = await p.getHome();
    // SkyStream has no paged browse: getHome returns whole categories.
    final items = (home[catalogId] ?? const <SkyMediaItem>[])
        .map((e) => e.toMediaItem())
        .toList();
    return Page(items: items, hasMore: false);
  }

  @override
  Future<Page<MediaItem>> search(String sourceId, String query) async {
    final p = await providerFor(sourceId);
    if (p == null) return Page.empty();
    final items = await p.search(query);
    return Page(items: items.map((e) => e.toMediaItem()).toList());
  }

  @override
  Future<Result<MediaDetails>> details(String sourceId, MediaRef ref) async {
    final p = await providerFor(sourceId);
    if (p == null) return const Err('Plugin not installed');
    try {
      final item = await p.load(ref.id);
      final episodes = item.episodes
          .map((e) => EpisodeRef(
                id: e.url,
                season: e.season,
                episode: e.episode,
                title: e.name,
                thumbnail: e.posterUrl,
                overview: e.description,
              ))
          .toList();
      return Ok(MediaDetails(
        item: item.toMediaItem(),
        episodes: episodes,
        seasons: episodes.map((e) => e.season).toSet().toList()..sort(),
        cast: item.cast.map((a) => a.name).toList(),
        trailers: item.trailers.map((t) => t.url).toList(),
      ));
    } catch (e) {
      return Err(JsSourceManager.friendlyError(e));
    }
  }

  @override
  Stream<StreamLink> streams(String sourceId, PlayRequest req) async* {
    final p = await providerFor(sourceId);
    if (p == null) return;
    final s = await _mgr.source(sourceId);
    final target = req.episodeId ?? req.ref.id;

    List<SkyStreamResult> results;
    try {
      results = await p.loadStreams(target);
    } catch (e) {
      AeroLog.instance.w('skystream', 'loadStreams failed: $e');
      return;
    }

    for (final r in results) {
      yield StreamLink(
        url: r.url,
        sourceId: sourceId,
        sourceName: s?.name ?? 'SkyStream',
        ecosystem: ecosystem,
        kind: kindForUrl(r.url),
        quality: parseQualityLabel(r.quality),
        title: r.source,
        headers: r.headers,
        // DRM-protected links cannot play in libmpv without a licence flow.
        notWebReady: r.isDrmProtected,
      );
    }
  }

  @override
  Future<List<SubtitleTrack>> subtitles(String sourceId, PlayRequest req) async {
    final p = await providerFor(sourceId);
    if (p == null) return const [];
    try {
      final results = await p.loadStreams(req.episodeId ?? req.ref.id);
      final out = <SubtitleTrack>[];
      for (final r in results) {
        for (final sub in r.subtitles) {
          out.add(SubtitleTrack(
            id: sub.url,
            url: sub.url,
            lang: sub.lang ?? 'und',
            label: sub.label ?? sub.lang ?? 'Subtitle',
          ));
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// Reads a SkyStream `repo.json` index.
  Future<Result<List<SourceRef>>> fetchRepository(String url) async {
    final res = await _mgr.fetchJson(url);
    if (res.isErr) return Err(res.errorOrNull!);
    final data = res.valueOrNull;
    if (data is! Map) return const Err('SkyStream repo.json must be an object');
    final plugins = (data['plugins'] as List? ?? const []);
    final base = Uri.parse(url);
    final out = <SourceRef>[];
    for (final e in plugins) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final raw = (m['url'] ?? m['jsUrl'] ?? m['filename'])?.toString();
      if (raw == null || raw.isEmpty) continue;
      final codeUrl = raw.startsWith('http') ? raw : base.resolve(raw).toString();
      out.add(SourceRef(
        ecosystem: ecosystem,
        url: codeUrl,
        name: m['name']?.toString(),
        version: m['version']?.toString(),
        expectedSha256: m['sha256']?.toString(),
        extra: m,
      ));
    }
    if (out.isEmpty) return const Err('This repository lists no plugins');
    return Ok(out);
  }

  @override
  Future<void> dispose() async {
    _manifests.clear();
    await _mgr.dispose();
  }
}
