import 'dart:convert';

import 'package:aero_core/aero_core.dart';
import 'package:dio/dio.dart';
import 'package:eco_js_runtime/eco_js_runtime.dart';

import 'vega_provider.dart';

/// Runs a Vega provider's six modules in one sandbox.
///
/// Upstream ships `posts.js`, `meta.js`, `stream.js`, `catalog.js` and the
/// optional `episodes.js` / `settings.js`. They are ES modules whose exported
/// functions all take a single object; we strip the `export` keyword and
/// concatenate so each function becomes a global the host can call.
class JsVegaProvider implements VegaProvider {
  JsVegaProvider({
    required this.host,
    required this.value,
    required this.displayName,
    required this.version,
    required this.hasEpisodeModule,
  });

  final JsPluginHost host;

  @override
  final String value;
  @override
  final String displayName;
  @override
  final String version;
  @override
  final bool hasEpisodeModule;

  /// Wraps the modules and injects `providerContext`.
  ///
  /// `axios` and `cheerio` are supplied by the host shim; `signal` is a real
  /// AbortController so a plugin that honours cancellation behaves.
  static String buildSource(Map<String, String> modules, String providerValue) {
    final buf = StringBuffer()
      ..writeln('var __vegaProviderValue = ${jsonEncode(providerValue)};')
      ..writeln('''
var providerContext = {
  axios: (typeof axios !== 'undefined') ? axios : undefined,
  cheerio: (typeof cheerio !== 'undefined') ? cheerio : undefined,
  Crypto: (typeof crypto !== 'undefined') ? crypto : undefined,
  commonHeaders: {},
  getBaseUrl: function (v) { return Promise.resolve(__vegaBaseUrl || ''); },
  kvStore: {
    get: function (k) { return Promise.resolve(__vegaKv[k]); },
    set: function (k, v) { __vegaKv[k] = v; return Promise.resolve(); },
    delete: function (k) { var had = k in __vegaKv; delete __vegaKv[k]; return Promise.resolve(had); },
    keys: function () { return Promise.resolve(Object.keys(__vegaKv)); },
    clear: function () { __vegaKv = {}; return Promise.resolve(); }
  },
  openWebView: function () { return Promise.reject(new Error('openWebView is not available in Aero')); },
  getCookies: function () { return Promise.resolve({}); }
};
var __vegaKv = {};
var __vegaBaseUrl = '';
globalThis.providerContext = providerContext;
if (typeof module === 'undefined') { var module = { exports: {} }; }
''');
    // Order matters: catalog first so posts can reference it.
    for (final name in ['catalog', 'posts', 'meta', 'episodes', 'stream', 'settings']) {
      final code = modules[name];
      if (code == null || code.isEmpty) continue;
      buf.writeln('// ---- $name.js ----');
      buf.writeln(stripEsExports(code));
    }
    return buf.toString();
  }

  /// Removes ES module syntax so the concatenation evaluates as a script.
  ///
  /// Handles `export function`, `export const/let/var`, `export default` and
  /// `export { a, b }`. `import` lines are dropped because the host already
  /// provides axios/cheerio/crypto as globals.
  static String stripEsExports(String code) {
    var out = code;
    // Drop import statements (single and multi-line).
    out = out.replaceAll(
        RegExp(r'^\s*import\s+[^;]*?;?\s*$', multiLine: true), '');
    out = out.replaceAll(RegExp(r'\bexport\s+default\s+'), 'var __vegaDefault = ');
    out = out.replaceAll(RegExp(r'\bexport\s+(?=(async\s+)?function\b)'), '');
    out = out.replaceAll(RegExp(r'\bexport\s+(?=(const|let|var|class)\b)'), '');
    out = out.replaceAll(RegExp(r'^\s*export\s*\{[^}]*\}\s*;?\s*$', multiLine: true), '');
    return out;
  }

  Map<String, Object?> _ctx(Map<String, Object?> extra) => {
        'providerValue': value,
        'providerContext': null, // replaced in JS by the global
        ...extra,
      };

  /// Vega passes `providerContext` by reference; we splice the global in JS
  /// rather than serialising it, so axios/cheerio stay live objects.
  Future<Result<Object?>> _call(String fn, Map<String, Object?> args) async {
    final payload = jsonEncode(_ctx(args)..remove('providerContext'));
    final res = await host.call('__vegaInvoke', [fn, payload]);
    return res;
  }

  static const String invokeHelper = '''
function __vegaInvoke(name, argsJson) {
  var fn = globalThis[name];
  if (typeof fn !== 'function') return Promise.reject(new Error('Vega function not found: ' + name));
  var args = JSON.parse(argsJson || '{}');
  args.providerContext = providerContext;
  if (args.signal === undefined && typeof AbortController !== 'undefined') {
    args.signal = new AbortController().signal;
  }
  return Promise.resolve(fn(args));
}
globalThis.__vegaInvoke = __vegaInvoke;
''';

  static List<Map<String, dynamic>> _maps(Object? v) => (v is List ? v : const [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  /// `catalog`/`genres` may be a plain array or a function upstream.
  Future<List<VegaCatalog>> _catalogList(String name) async {
    final res = await host.call('__vegaCatalog', [name]);
    if (res.isErr) return const [];
    return _maps(res.valueOrNull).map(VegaCatalog.fromJson).toList();
  }

  static const String catalogHelper = '''
function __vegaCatalog(name) {
  var c = globalThis[name];
  if (typeof c === 'function') {
    return Promise.resolve(c({ providerContext: providerContext })).then(function (v) { return v || []; });
  }
  if (c && c.catalog !== undefined) c = c.catalog;
  return Promise.resolve(Array.isArray(c) ? c : []);
}
globalThis.__vegaCatalog = __vegaCatalog;
''';

  @override
  Future<List<VegaCatalog>> catalog() => _catalogList('catalog');

  @override
  Future<List<VegaCatalog>> genres() => _catalogList('genres');

  @override
  Future<List<VegaPost>> getHomePosts({required String filter, int page = 1}) async {
    final res = await _call('GetHomePosts', {'filter': filter, 'page': page});
    if (res.isErr) {
      AeroLog.instance.w('vega', 'GetHomePosts failed: ${res.errorOrNull}');
      return const [];
    }
    return _maps(res.valueOrNull)
        .map(VegaPost.fromJson)
        .where((p) => p.title.isNotEmpty && p.link.isNotEmpty)
        .toList();
  }

  @override
  Future<List<VegaPost>> getSearchPosts({required String query, int page = 1}) async {
    if (query.trim().isEmpty) return const [];
    final res = await _call('GetSearchPosts', {'searchQuery': query.trim(), 'page': page});
    if (res.isErr) return const [];
    return _maps(res.valueOrNull)
        .map(VegaPost.fromJson)
        .where((p) => p.title.isNotEmpty && p.link.isNotEmpty)
        .toList();
  }

  @override
  Future<VegaInfo> getMetaData(String link) async {
    final res = await _call('GetMetaData', {'link': link, 'provider': value});
    if (res.isErr) throw AeroException(res.errorOrNull ?? 'Could not load details');
    final v = res.valueOrNull;
    if (v is! Map) throw const AeroException('Plugin returned no metadata');
    return VegaInfo.fromJson(Map<String, dynamic>.from(v));
  }

  @override
  Future<List<VegaEpisodeLink>> getEpisodeLinks(String url) async {
    if (!hasEpisodeModule) return const [];
    final res = await _call('GetEpisodeLinks', {'url': url});
    if (res.isErr) return const [];
    return _maps(res.valueOrNull)
        .map(VegaEpisodeLink.fromJson)
        .where((e) => e.link.isNotEmpty)
        .toList();
  }

  @override
  Future<List<VegaStream>> getStream({required String link, String type = 'movie'}) async {
    final res = await _call('GetStream', {'link': link, 'type': type, 'isDownload': false});
    if (res.isErr) {
      AeroLog.instance.w('vega', 'GetStream failed: ${res.errorOrNull}');
      return const [];
    }
    return _maps(res.valueOrNull)
        .map(VegaStream.fromJson)
        .where((s) => s.link.isNotEmpty)
        .toList();
  }

  @override
  Future<void> dispose() => host.dispose();
}

/// Vega ecosystem adapter.
class VegaAdapter implements EcosystemAdapter {
  VegaAdapter({
    required JsPluginStore store,
    JsSandboxPolicy policy = const JsSandboxPolicy(),
    Dio? dio,
  }) : _mgr = JsSourceManager(
          ecosystem: Ecosystem.vega,
          store: store,
          policy: policy,
          dio: dio,
        );

  final JsSourceManager _mgr;
  final Map<String, bool> _hasEpisodes = {};

  JsSourceManager get manager => _mgr;

  @override
  Ecosystem get ecosystem => Ecosystem.vega;

  @override
  bool get isAvailable => true;

  @override
  String? get unavailableReason => null;

  @override
  Set<Capability> get capabilities =>
      {Capability.catalogs, Capability.search, Capability.meta, Capability.streams};

  @override
  Future<List<InstalledSource>> installedSources() => _mgr.installed();

  /// Downloads all six modules and stores them as one JSON blob.
  @override
  Future<Result<InstalledSource>> install(SourceRef ref) async {
    try {
      // ref.url is the *source* URL; ref.extra carries the manifest entry.
      final entry = ref.extra;
      final value = (entry['value'] ?? ref.name ?? '').toString();
      if (value.isEmpty) {
        return const Err('This entry has no provider id. Add the repository, not a file.');
      }
      final filesUrl = vegaProviderFilesUrl(ref.url, value, entry['path']?.toString());
      if (filesUrl == null) {
        return const Err('The repository entry has an unsafe path and was rejected.');
      }

      final modules = <String, String>{};
      for (final name in [...kVegaRequiredModules, ...kVegaOptionalModules]) {
        final res = await _mgr.fetchCode('$filesUrl/$name.js');
        if (res.isOk) {
          modules[name] = res.valueOrNull!;
        } else if (kVegaRequiredModules.contains(name)) {
          return Err('Missing required module "$name.js": ${res.errorOrNull}');
        }
      }

      final blob = jsonEncode(modules);
      final id = value;
      final source = InstalledSource(
        id: id,
        ecosystem: ecosystem,
        name: (entry['display_name'] ?? value).toString(),
        url: ref.url,
        version: (entry['version'] ?? '0.0.0').toString(),
        logo: entry['icon']?.toString(),
        priority: await _mgr.nextPriority(),
        repoId: ref.repoId,
        capabilities: capabilities,
        types: const [MediaType.movie, MediaType.series],
        installedAt: DateTime.now(),
        sha256: JsPluginBundle.hashOf(blob),
        config: {'path': entry['path'] ?? '', 'value': value},
      );

      _hasEpisodes[id] = modules.containsKey('episodes');
      _mgr.setPrelude(id, _preludeFor(modules, value));
      await _mgr.persist(source, blob);
      return Ok(source);
    } catch (e) {
      return Err(JsSourceManager.friendlyError(e));
    }
  }

  String _preludeFor(Map<String, String> modules, String value) =>
      '${JsVegaProvider.buildSource(modules, value)}\n'
      '${JsVegaProvider.invokeHelper}\n'
      '${JsVegaProvider.catalogHelper}';

  Future<VegaProvider?> providerFor(String sourceId) async {
    final s = await _mgr.source(sourceId);
    if (s == null) return null;
    if (!_hasEpisodes.containsKey(sourceId)) {
      final raw = await _mgr.store.loadCode(ecosystem, sourceId);
      if (raw == null || raw.isEmpty) return null;
      try {
        final modules = Map<String, dynamic>.from(jsonDecode(raw) as Map)
            .map((k, v) => MapEntry(k, v.toString()));
        _hasEpisodes[sourceId] = modules.containsKey('episodes');
        _mgr.setPrelude(sourceId, _preludeFor(modules, sourceId));
      } catch (_) {
        return null;
      }
    }
    final host = await _mgr.hostFor(s);
    if (host == null) return null;
    return JsVegaProvider(
      host: host,
      value: sourceId,
      displayName: s.name,
      version: s.version,
      hasEpisodeModule: _hasEpisodes[sourceId] ?? false,
    );
  }

  @override
  Future<void> uninstall(String sourceId) async {
    _hasEpisodes.remove(sourceId);
    await _mgr.uninstall(sourceId);
  }

  @override
  Future<Result<InstalledSource>> checkUpdate(String sourceId) async {
    final s = await _mgr.source(sourceId);
    if (s == null) return const Err('Provider not installed');
    _hasEpisodes.remove(sourceId);
    await _mgr.evict(sourceId);
    return install(SourceRef(
      ecosystem: ecosystem,
      url: s.url,
      repoId: s.repoId,
      name: s.name,
      extra: {'value': sourceId, 'display_name': s.name, ...s.config},
    ));
  }

  @override
  Future<Result<Duration>> healthCheck(String sourceId) => _mgr.healthCheck(sourceId);

  @override
  Future<List<CatalogRow>> catalogs(String sourceId) async {
    final p = await providerFor(sourceId);
    if (p == null) return const [];
    final cats = await p.catalog();
    final rows = <CatalogRow>[];
    for (final c in cats) {
      final posts = await p.getHomePosts(filter: c.filter);
      if (posts.isEmpty) continue;
      rows.add(CatalogRow(
        sourceId: sourceId,
        catalogId: c.filter,
        title: c.title,
        type: MediaType.movie,
        items: posts.map((e) => e.toMediaItem()).toList(),
        hasMore: posts.length >= 20,
      ));
    }
    return rows;
  }

  @override
  Future<Page<MediaItem>> browse(String sourceId, String catalogId, CatalogQuery q) async {
    final p = await providerFor(sourceId);
    if (p == null) return Page.empty();
    final page = (q.skip ~/ 20) + 1;
    final posts = await p.getHomePosts(filter: catalogId, page: page);
    return Page(
      items: posts.map((e) => e.toMediaItem()).toList(),
      hasMore: posts.length >= 20,
    );
  }

  @override
  Future<Page<MediaItem>> search(String sourceId, String query) async {
    final p = await providerFor(sourceId);
    if (p == null) return Page.empty();
    final posts = await p.getSearchPosts(query: query);
    return Page(items: posts.map((e) => e.toMediaItem()).toList());
  }

  @override
  Future<Result<MediaDetails>> details(String sourceId, MediaRef ref) async {
    final p = await providerFor(sourceId);
    if (p == null) return const Err('Provider not installed');
    try {
      final info = await p.getMetaData(ref.id);
      final episodes = <EpisodeRef>[];
      for (final link in info.linkList) {
        if (link.episodesLink != null && link.episodesLink!.isNotEmpty) {
          final eps = await p.getEpisodeLinks(link.episodesLink!);
          for (var i = 0; i < eps.length; i++) {
            episodes.add(EpisodeRef(
              id: eps[i].link,
              season: 1,
              episode: i + 1,
              title: eps[i].title,
              thumbnail: eps[i].image,
              overview: eps[i].description,
            ));
          }
        } else {
          for (final d in link.directLinks) {
            episodes.add(EpisodeRef(
              id: d.link,
              season: 1,
              episode: episodes.length + 1,
              title: d.title,
              thumbnail: d.image,
            ));
          }
        }
      }
      return Ok(MediaDetails(
        item: info.toMediaItem(ref.id),
        episodes: info.mediaType == MediaType.series ? episodes : const [],
        seasons: episodes.map((e) => e.season).toSet().toList()..sort(),
        cast: info.cast,
        trailers: info.trailerUrl == null ? const [] : [info.trailerUrl!],
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
    final results = await p.getStream(
      link: req.episodeId ?? req.ref.id,
      type: req.ref.type == MediaType.series ? 'series' : 'movie',
    );
    for (final r in results) {
      yield StreamLink(
        url: r.link,
        sourceId: sourceId,
        sourceName: s?.name ?? 'Vega',
        ecosystem: ecosystem,
        kind: kindForUrl(r.link),
        quality: parseQualityLabel(r.quality ?? r.server),
        title: r.server,
        description: r.tag,
        headers: r.headers,
        subtitles: r.subtitles.map((e) => e.toSubtitle()).toList(),
      );
    }
  }

  @override
  Future<List<SubtitleTrack>> subtitles(String sourceId, PlayRequest req) async {
    final p = await providerFor(sourceId);
    if (p == null) return const [];
    final results = await p.getStream(link: req.episodeId ?? req.ref.id);
    return results.expand((r) => r.subtitles.map((e) => e.toSubtitle())).toList();
  }

  /// Reads a Vega `manifest.json` — a JSON **array** of provider entries.
  Future<Result<List<SourceRef>>> fetchRepository(String url) async {
    final manifestUrl = url.endsWith('.json') ? url : '${url.replaceAll(RegExp(r'/$'), '')}/manifest.json';
    final res = await _mgr.fetchJson(manifestUrl);
    if (res.isErr) return Err(res.errorOrNull!);
    final data = res.valueOrNull;
    if (data is! List) {
      return const Err('A Vega manifest.json must be a JSON array of providers');
    }
    final sourceUrl = manifestUrl.substring(0, manifestUrl.lastIndexOf('/'));
    final out = <SourceRef>[];
    for (final e in data) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      if (m['disabled'] == true) continue;
      final path = m['path']?.toString();
      if (path != null && !isSafeVegaPath(path)) continue; // traversal guard
      out.add(SourceRef(
        ecosystem: ecosystem,
        url: sourceUrl,
        name: m['display_name']?.toString() ?? m['value']?.toString(),
        version: m['version']?.toString(),
        extra: m,
      ));
    }
    if (out.isEmpty) return const Err('This repository lists no enabled providers');
    return Ok(out);
  }

  @override
  Future<void> dispose() async {
    _hasEpisodes.clear();
    await _mgr.dispose();
  }
}
