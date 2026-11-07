import 'dart:convert';

import 'package:aero_core/aero_core.dart';
import 'package:dio/dio.dart';
import 'package:eco_js_runtime/eco_js_runtime.dart';

import 'nuvio_scraper.dart';

/// Runs a Nuvio scraper in the sandbox.
class JsNuvioScraper implements NuvioScraper {
  JsNuvioScraper({
    required this.host,
    required this.id,
    required this.name,
    required this.version,
  });

  final JsPluginHost host;

  @override
  final String id;
  @override
  final String name;
  @override
  final String version;

  @override
  Future<List<NuvioStreamResult>> getStreams({
    required String tmdbId,
    required String mediaType,
    int? season,
    int? episode,
  }) async {
    final args = jsonEncode({
      'tmdbId': tmdbId,
      'mediaType': normalizeNuvioType(mediaType),
      'season': season,
      'episode': episode,
    });
    final res = await host.call('__nuvioGetStreams', [args]);
    if (res.isErr) {
      AeroLog.instance.w('nuvio', 'getStreams failed: ${res.errorOrNull}');
      return const [];
    }
    final v = res.valueOrNull;
    if (v is! List) return const [];
    return v
        .whereType<Map>()
        .map((e) => NuvioStreamResult.fromJson(Map<String, dynamic>.from(e)))
        .where((r) => r.url.isNotEmpty || (r.infoHash?.isNotEmpty ?? false))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> onSettings() async {
    final res = await host.call('__nuvioOnSettings');
    if (res.isErr) return const [];
    final v = res.valueOrNull;
    if (v is! List) return const [];
    return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  Future<void> dispose() => host.dispose();
}

/// Nuvio ecosystem adapter — **streams only**.
///
/// Nuvio scrapers cannot browse, search or supply metadata; upstream takes all
/// of that from TMDB. Advertising anything else here would produce UI that
/// silently returns nothing, so the capability set is deliberately narrow.
class NuvioAdapter implements EcosystemAdapter, RepositorySource {
  NuvioAdapter({
    required JsPluginStore store,
    JsSandboxPolicy policy = const JsSandboxPolicy(),
    Dio? dio,
    this.tmdbApiKey = '',
  }) : _mgr = JsSourceManager(
          ecosystem: Ecosystem.nuvio,
          store: store,
          policy: policy,
          dio: dio,
        );

  final JsSourceManager _mgr;

  /// Injected as `TMDB_API_KEY`, exactly as upstream does.
  final String tmdbApiKey;

  JsSourceManager get manager => _mgr;

  @override
  Ecosystem get ecosystem => Ecosystem.nuvio;

  @override
  bool get isAvailable => true;

  @override
  String? get unavailableReason => null;

  /// The defining constraint of this ecosystem.
  @override
  Set<Capability> get capabilities => {Capability.streams};

  @override
  Future<List<InstalledSource>> installedSources() => _mgr.installed();

  @override
  Future<Result<InstalledSource>> install(SourceRef ref) async {
    try {
      final codeRes = await _mgr.fetchCode(ref.url, expectedSha256: ref.expectedSha256);
      if (codeRes.isErr) return Err(codeRes.errorOrNull!);
      final code = codeRes.valueOrNull!;

      final entry = ref.extra;
      final id = (entry['id'] ?? ref.name ?? Uri.parse(ref.url).pathSegments.last).toString();
      final source = InstalledSource(
        id: id,
        ecosystem: ecosystem,
        name: (entry['name'] ?? ref.name ?? id).toString(),
        url: ref.url,
        version: (entry['version'] ?? ref.version ?? '0.0.0').toString(),
        description: entry['description']?.toString(),
        logo: entry['logo']?.toString(),
        priority: await _mgr.nextPriority(),
        repoId: ref.repoId,
        capabilities: capabilities,
        types: [
          for (final t in (entry['supportedTypes'] as List? ?? const ['movie', 'tv']))
            normalizeNuvioType(t.toString()) == 'tv' ? MediaType.series : MediaType.movie,
        ],
        installedAt: DateTime.now(),
        sha256: JsPluginBundle.hashOf(code),
      );

      _mgr.setPrelude(
          id, nuvioPrelude(scraperId: id, tmdbApiKey: tmdbApiKey));
      await _mgr.persist(source, code);
      return Ok(source);
    } catch (e) {
      return Err(JsSourceManager.friendlyError(e));
    }
  }

  Future<NuvioScraper?> scraperFor(String sourceId) async {
    final s = await _mgr.source(sourceId);
    if (s == null) return null;
    _mgr.setPrelude(sourceId,
        nuvioPrelude(scraperId: sourceId, tmdbApiKey: tmdbApiKey));
    final host = await _mgr.hostFor(s);
    if (host == null) return null;
    return JsNuvioScraper(
      host: host,
      id: sourceId,
      name: s.name,
      version: s.version,
    );
  }

  @override
  Future<void> uninstall(String sourceId) => _mgr.uninstall(sourceId);

  @override
  Future<Result<InstalledSource>> checkUpdate(String sourceId) async {
    final s = await _mgr.source(sourceId);
    if (s == null) return const Err('Scraper not installed');
    await _mgr.evict(sourceId);
    return install(SourceRef(
      ecosystem: ecosystem,
      url: s.url,
      repoId: s.repoId,
      name: s.name,
      version: s.version,
      extra: {'id': sourceId, 'name': s.name, 'version': s.version},
    ));
  }

  @override
  Future<Result<Duration>> healthCheck(String sourceId) => _mgr.healthCheck(sourceId);

  // ---- Unsupported by this ecosystem. Explicit, not silently empty. -------

  @override
  Future<List<CatalogRow>> catalogs(String sourceId) async => const [];

  @override
  Future<Page<MediaItem>> browse(String sourceId, String catalogId, CatalogQuery q) async =>
      Page.empty();

  @override
  Future<Page<MediaItem>> search(String sourceId, String query) async => Page.empty();

  @override
  Future<Result<MediaDetails>> details(String sourceId, MediaRef ref) async =>
      const Err('Nuvio scrapers only provide streams. Metadata comes from TMDB.');

  // ---- Streams -----------------------------------------------------------

  @override
  Stream<StreamLink> streams(String sourceId, PlayRequest req) async* {
    final tmdbId = req.ref.tmdbId;
    if (tmdbId == null || tmdbId.isEmpty) {
      // Without a TMDB id this ecosystem simply cannot be queried. Say so
      // rather than returning an empty list the user cannot interpret.
      AeroLog.instance.w('nuvio',
          'Skipping ${req.ref.title}: no TMDB id. Nuvio scrapers are TMDB-keyed.');
      return;
    }
    final scraper = await scraperFor(sourceId);
    if (scraper == null) return;
    final s = await _mgr.source(sourceId);
    final results = await scraper.getStreams(
      tmdbId: tmdbId,
      mediaType: req.ref.type == MediaType.series ? 'tv' : 'movie',
      season: req.season,
      episode: req.episode,
    );
    for (final r in results) {
      yield r.toStreamLink(sourceId: sourceId, sourceName: s?.name ?? 'Nuvio');
    }
  }

  @override
  Future<List<SubtitleTrack>> subtitles(String sourceId, PlayRequest req) async {
    final out = <SubtitleTrack>[];
    await for (final link in streams(sourceId, req)) {
      out.addAll(link.subtitles);
    }
    return out;
  }

  /// Reads a Nuvio repository. The pasted URL **is** the manifest.json URL.
  @override
  Future<Result<List<SourceRef>>> fetchRepository(String url) async {
    final manifestUrl =
        url.endsWith('.json') ? url : '${url.replaceAll(RegExp(r'/$'), '')}/manifest.json';
    final res = await _mgr.fetchJson(manifestUrl);
    if (res.isErr) return Err(res.errorOrNull!);
    final data = res.valueOrNull;
    if (data is! Map) {
      return const Err('A Nuvio manifest.json must be an object with a "scrapers" list');
    }
    final j = Map<String, dynamic>.from(data);
    final invalid = NuvioManifest.validate(j);
    if (invalid != null) return Err(invalid);

    final manifest = NuvioManifest.fromJson(j);
    final out = <SourceRef>[];
    for (final s in manifest.scrapers) {
      if (!s.enabled) continue;
      if (s.filename.isEmpty) continue;
      out.add(SourceRef(
        ecosystem: ecosystem,
        url: nuvioScraperUrl(manifestUrl, s.filename),
        repoId: manifestUrl,
        name: s.name,
        version: s.version,
        extra: {
          'id': s.id,
          'name': s.name,
          'version': s.version,
          'description': s.description,
          'logo': s.logo,
          'supportedTypes': s.supportedTypes,
          'hasSettings': s.hasSettings,
        },
      ));
    }
    if (out.isEmpty) return const Err('Every scraper in this repository is disabled');
    return Ok(out);
  }

  @override
  Future<void> dispose() => _mgr.dispose();
}
