import 'dart:async';
import 'dart:convert';

import 'package:aero_core/aero_core.dart';
import 'package:dio/dio.dart';

import 'js_host.dart';
import 'js_plugin_bundle.dart';
import 'js_sandbox_policy.dart';

/// Persistence hook, implemented by `aero_data`.
abstract class JsPluginStore {
  Future<List<InstalledSource>> load(Ecosystem ecosystem);
  Future<void> save(InstalledSource source);
  Future<void> delete(Ecosystem ecosystem, String id);

  /// Cached bundle code so plugins work offline and start instantly.
  Future<String?> loadCode(Ecosystem ecosystem, String id);
  Future<void> saveCode(Ecosystem ecosystem, String id, String code);
}

/// Describes how one JS ecosystem names its manifest fields and functions.
///
/// **These mappings are provisional.** Phase 0 of the roadmap is a spec
/// discovery sprint; each adapter overrides this with verified names once the
/// upstream repo has been read. Keeping them in one object means a format
/// change is a one-line fix, not a rewrite.
class JsDialect {
  const JsDialect({
    required this.manifestFileName,
    required this.repoPluginsKey,
    required this.fnHome,
    required this.fnSearch,
    required this.fnDetail,
    required this.fnStreams,
    this.fnSubtitles,
    this.fieldId = 'id',
    this.fieldName = 'name',
    this.fieldVersion = 'version',
    this.fieldUrl = 'url',
    this.fieldItems = 'items',
    this.itemTitle = 'title',
    this.itemPoster = 'poster',
    this.itemUrl = 'url',
    this.itemId = 'id',
    this.streamUrl = 'url',
    this.streamQuality = 'quality',
    this.streamHeaders = 'headers',
  });

  /// e.g. `manifest.json`, `repo.json`, `plugins.json`.
  final String manifestFileName;

  /// Key in a repository index that lists plugins.
  final String repoPluginsKey;

  final String fnHome;
  final String fnSearch;
  final String fnDetail;
  final String fnStreams;
  final String? fnSubtitles;

  final String fieldId;
  final String fieldName;
  final String fieldVersion;
  final String fieldUrl;
  final String fieldItems;

  final String itemTitle;
  final String itemPoster;
  final String itemUrl;
  final String itemId;

  final String streamUrl;
  final String streamQuality;
  final String streamHeaders;
}

/// Shared implementation for Vega / Nuvio / SkyStream.
///
/// Subclasses supply an [Ecosystem] and a [JsDialect]; everything else —
/// sandbox lifecycle, install/validate, hash pinning, mapping to unified
/// models, error containment — is handled here.
abstract class JsEcosystemAdapterBase implements EcosystemAdapter {
  JsEcosystemAdapterBase({
    required this.store,
    required this.dialect,
    this.policy = const JsSandboxPolicy(),
    Dio? dio,
  }) : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              validateStatus: (s) => s != null && s < 400,
            ));

  final JsPluginStore store;
  final JsDialect dialect;
  final JsSandboxPolicy policy;
  final Dio _dio;

  /// One live host per installed plugin, created lazily.
  final Map<String, JsPluginHost> _hosts = {};
  final Map<String, Future<JsPluginHost?>> _booting = {};

  @override
  bool get isAvailable => true;

  @override
  String? get unavailableReason => null;

  @override
  Set<Capability> get capabilities =>
      {Capability.catalogs, Capability.search, Capability.meta, Capability.streams};

  @override
  Future<List<InstalledSource>> installedSources() => store.load(ecosystem);

  Future<InstalledSource?> _source(String id) async {
    final all = await store.load(ecosystem);
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Boots (or reuses) the sandbox for a plugin.
  Future<JsPluginHost?> _hostFor(InstalledSource s) async {
    final existing = _hosts[s.id];
    if (existing != null && existing.isReady) return existing;

    return _booting.putIfAbsent(s.id, () async {
      try {
        final code = await store.loadCode(ecosystem, s.id);
        if (code == null || code.isEmpty) {
          AeroLog.instance.w(ecosystem.id, 'No cached code for ${s.name}');
          return null;
        }
        // Re-verify the pin at every boot, not just at install time.
        final actual = JsPluginBundle.hashOf(code);
        if (s.sha256 != null &&
            s.sha256!.isNotEmpty &&
            actual.toLowerCase() != s.sha256!.toLowerCase()) {
          AeroLog.instance.e(ecosystem.id,
              'Hash mismatch for ${s.name} — refusing to execute');
          return null;
        }
        final host = JsPluginHost(
          pluginId: s.id,
          pluginName: s.name,
          policy: policy,
        );
        final res = await host.initialise(JsPluginBundle(
          sourceUrl: s.url,
          code: code,
          manifest: const {},
          sha256: actual,
        ));
        if (res.isErr) {
          AeroLog.instance.e(ecosystem.id, 'Boot failed: ${res.errorOrNull}');
          await host.dispose();
          return null;
        }
        _hosts[s.id] = host;
        return host;
      } finally {
        unawaited(Future<void>.microtask(() => _booting.remove(s.id)));
      }
    });
  }

  @override
  Future<Result<InstalledSource>> install(SourceRef ref) async {
    try {
      final uri = Uri.tryParse(ref.url);
      if (uri == null || !uri.hasScheme || !uri.host.contains('.')) {
        return const Err('Enter a valid plugin or repository URL');
      }
      if (uri.scheme != 'https' && uri.scheme != 'http') {
        return const Err('Only http and https URLs are supported');
      }

      final res = await _dio.getUri(uri);
      final code = res.data?.toString() ?? '';
      if (code.trim().isEmpty) return const Err('The plugin file is empty');
      if (code.length > 8 * 1024 * 1024) {
        return const Err('Plugin is too large (over 8 MB)');
      }

      final hash = JsPluginBundle.hashOf(code);
      if (ref.expectedSha256 != null &&
          ref.expectedSha256!.isNotEmpty &&
          hash.toLowerCase() != ref.expectedSha256!.toLowerCase()) {
        return const Err(
          'Hash mismatch: the downloaded plugin does not match the pinned '
          'checksum. It may have been tampered with.',
        );
      }

      // Extract the manifest the plugin exports, inside a throwaway sandbox.
      final manifest = await _probeManifest(code, uri.toString());

      final existing = await store.load(ecosystem);
      final nextPriority = existing.isEmpty
          ? 10
          : existing.map((e) => e.priority).reduce((a, b) => a > b ? a : b) + 10;

      final id = (manifest[dialect.fieldId] ??
              ref.name ??
              uri.pathSegments.last.replaceAll(RegExp(r'\.js$'), ''))
          .toString();

      final source = InstalledSource(
        id: id,
        ecosystem: ecosystem,
        name: (manifest[dialect.fieldName] ?? ref.name ?? id).toString(),
        url: uri.toString(),
        version: (manifest[dialect.fieldVersion] ?? '0.0.0').toString(),
        description: manifest['description']?.toString(),
        logo: manifest['logo']?.toString(),
        priority: nextPriority,
        repoId: ref.repoId,
        capabilities: capabilities,
        types: const [MediaType.movie, MediaType.series],
        installedAt: DateTime.now(),
        sha256: hash,
      );

      await store.save(source);
      await store.saveCode(ecosystem, id, code);
      AeroLog.instance.i(ecosystem.id, 'Installed ${source.name} v${source.version}');
      return Ok(source);
    } catch (e) {
      return Err(_friendly(e));
    }
  }

  /// Evaluates the bundle in a scratch context and reads its exported
  /// manifest/metadata object. Never persists this host.
  Future<Map<String, dynamic>> _probeManifest(String code, String url) async {
    final host = JsPluginHost(
      pluginId: 'probe',
      pluginName: 'probe',
      policy: policy.copyWith(evalTimeout: const Duration(seconds: 8)),
    );
    try {
      final bundle = JsPluginBundle(
        sourceUrl: url,
        code: code,
        manifest: const {},
        sha256: JsPluginBundle.hashOf(code),
      );
      final init = await host.initialise(bundle);
      if (init.isErr) return const {};
      final res = await host.call('__aeroManifest');
      return await Future.value(res.when(
        ok: (v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{},
        err: (_) => <String, dynamic>{},
      ));
    } finally {
      await host.dispose();
    }
  }

  @override
  Future<void> uninstall(String sourceId) async {
    await _hosts.remove(sourceId)?.dispose();
    await store.delete(ecosystem, sourceId);
    await store.saveCode(ecosystem, sourceId, '');
  }

  @override
  Future<Result<InstalledSource>> checkUpdate(String sourceId) async {
    final s = await _source(sourceId);
    if (s == null) return const Err('Plugin not installed');
    // Re-install from the same URL; install() handles validation and pinning.
    final res = await install(SourceRef(
      ecosystem: ecosystem,
      url: s.url,
      repoId: s.repoId,
      name: s.name,
    ));
    if (res.isOk) {
      await _hosts.remove(sourceId)?.dispose();
    }
    return res;
  }

  @override
  Future<Result<Duration>> healthCheck(String sourceId) async {
    final s = await _source(sourceId);
    if (s == null) return const Err('Plugin not installed');
    final sw = Stopwatch()..start();
    final host = await _hostFor(s);
    sw.stop();
    if (host == null || !host.isReady) {
      return const Err('Plugin failed to start. Check the log for details.');
    }
    return Ok(sw.elapsed);
  }

  @override
  Future<List<CatalogRow>> catalogs(String sourceId) async {
    final s = await _source(sourceId);
    if (s == null) return const [];
    final host = await _hostFor(s);
    if (host == null) return const [];
    final res = await host.call(dialect.fnHome, [1]);
    return res.when(
      ok: (v) {
        final rows = _extractRows(v);
        return rows
            .map((r) => CatalogRow(
                  sourceId: sourceId,
                  catalogId: (r['id'] ?? r['title'] ?? 'home').toString(),
                  title: (r['title'] ?? r['name'] ?? 'Home').toString(),
                  type: MediaType.fromWire(r['type'] as String?),
                  items: _mapItems(r[dialect.fieldItems] ?? r['items']),
                ))
            .toList();
      },
      err: (e) {
        AeroLog.instance.w(ecosystem.id, 'catalogs failed: $e');
        return const [];
      },
    );
  }

  @override
  Future<Page<MediaItem>> browse(
    String sourceId,
    String catalogId,
    CatalogQuery q,
  ) async {
    final s = await _source(sourceId);
    if (s == null) return Page.empty();
    final host = await _hostFor(s);
    if (host == null) return Page.empty();
    final page = (q.skip ~/ 20) + 1;
    final res = await host.call(dialect.fnHome, [page, catalogId]);
    return res.when(
      ok: (v) {
        final items = _mapItems(_extractItems(v));
        return Page(items: items, hasMore: items.length >= 20);
      },
      err: (_) => Page.empty(),
    );
  }

  @override
  Future<Page<MediaItem>> search(String sourceId, String query) async {
    if (query.trim().isEmpty) return Page.empty();
    final s = await _source(sourceId);
    if (s == null) return Page.empty();
    final host = await _hostFor(s);
    if (host == null) return Page.empty();
    final res = await host.call(dialect.fnSearch, [query.trim(), 1]);
    return res.when(
      ok: (v) => Page(items: _mapItems(_extractItems(v))),
      err: (_) => Page.empty(),
    );
  }

  @override
  Future<Result<MediaDetails>> details(String sourceId, MediaRef ref) async {
    final s = await _source(sourceId);
    if (s == null) return const Err('Plugin not installed');
    final host = await _hostFor(s);
    if (host == null) return const Err('Plugin failed to start');
    final res = await host.call(dialect.fnDetail, [ref.id]);
    return res.when(
      ok: (v) {
        if (v is! Map) return const Err('Plugin returned no details');
        final m = Map<String, dynamic>.from(v);
        final item = _mapItem(m);
        if (item == null) return const Err('Malformed details from plugin');
        final episodes = <EpisodeRef>[];
        for (final e in (m['episodes'] as List? ?? const [])) {
          if (e is! Map) continue;
          final em = Map<String, dynamic>.from(e);
          episodes.add(EpisodeRef(
            id: (em['id'] ?? em['url'] ?? '').toString(),
            season: (em['season'] as num?)?.toInt() ?? 1,
            episode: (em['episode'] as num?)?.toInt() ?? 0,
            title: em['title']?.toString(),
            thumbnail: em['thumbnail']?.toString(),
          ));
        }
        return Ok(MediaDetails(
          item: item,
          episodes: episodes,
          seasons: episodes.map((e) => e.season).toSet().toList()..sort(),
          cast: (m['cast'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        ));
      },
      err: Err.new,
    );
  }

  @override
  Stream<StreamLink> streams(String sourceId, PlayRequest req) async* {
    final s = await _source(sourceId);
    if (s == null) return;
    final host = await _hostFor(s);
    if (host == null) return;
    final target = req.episodeId ?? req.ref.id;
    final res = await host.call(dialect.fnStreams, [
      target,
      {
        'title': req.ref.title,
        'year': req.ref.year,
        'imdbId': req.ref.imdbId,
        'tmdbId': req.ref.tmdbId,
        'season': req.season,
        'episode': req.episode,
        'type': req.ref.type.wire,
      }
    ]);
    if (res.isErr) {
      AeroLog.instance.w(ecosystem.id, 'streams failed: ${res.errorOrNull}');
      return;
    }
    final list = _extractItems(res.valueOrNull);
    for (final raw in list) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final url = (m[dialect.streamUrl] ?? m['url'] ?? m['link'])?.toString();
      if (url == null || url.isEmpty) continue;
      final headers = <String, String>{};
      final h = m[dialect.streamHeaders] ?? m['headers'];
      if (h is Map) {
        h.forEach((k, v) {
          if (v != null) headers[k.toString()] = v.toString();
        });
      }
      final label = (m[dialect.streamQuality] ?? m['quality'] ?? m['label'])?.toString();
      yield StreamLink(
        url: url,
        sourceId: sourceId,
        sourceName: s.name,
        ecosystem: ecosystem,
        kind: url.contains('.m3u8')
            ? StreamKind.hls
            : url.contains('.mpd')
                ? StreamKind.dash
                : StreamKind.direct,
        quality: Quality.parse(label ?? url),
        title: label,
        description: m['title']?.toString(),
        headers: headers,
        sizeBytes: (m['size'] as num?)?.toInt(),
        language: m['language']?.toString(),
      );
    }
  }

  @override
  Future<List<SubtitleTrack>> subtitles(String sourceId, PlayRequest req) async {
    final fn = dialect.fnSubtitles;
    if (fn == null) return const [];
    final s = await _source(sourceId);
    if (s == null) return const [];
    final host = await _hostFor(s);
    if (host == null) return const [];
    final res = await host.call(fn, [req.episodeId ?? req.ref.id]);
    return res.when(
      ok: (v) => _extractItems(v)
          .whereType<Map>()
          .map((e) => SubtitleTrack.fromJson(Map<String, dynamic>.from(e)))
          .where((t) => t.url.isNotEmpty)
          .toList(),
      err: (_) => const [],
    );
  }

  /// Pulls a repository index and returns installable entries.
  Future<Result<List<SourceRef>>> fetchRepository(String url, {String? repoName}) async {
    try {
      final uri = Uri.parse(url);
      final res = await _dio.getUri(uri);
      final data = res.data;
      final map = data is String ? jsonDecode(data) : data;
      if (map is! Map) return const Err('Repository index is not a JSON object');
      final m = Map<String, dynamic>.from(map);
      final list = (m[dialect.repoPluginsKey] ?? m['plugins'] ?? m['providers']) as List?;
      if (list == null) {
        return Err('Repository has no "${dialect.repoPluginsKey}" list');
      }
      final out = <SourceRef>[];
      for (final e in list) {
        if (e is! Map) continue;
        final em = Map<String, dynamic>.from(e);
        final pluginUrl = (em[dialect.fieldUrl] ?? em['url'])?.toString();
        if (pluginUrl == null || pluginUrl.isEmpty) continue;
        out.add(SourceRef(
          ecosystem: ecosystem,
          url: _resolveRelative(uri, pluginUrl),
          name: (em[dialect.fieldName] ?? em['name'])?.toString(),
          version: em[dialect.fieldVersion]?.toString(),
          expectedSha256: em['sha256']?.toString(),
        ));
      }
      return Ok(out);
    } catch (e) {
      return Err(_friendly(e));
    }
  }

  String _resolveRelative(Uri base, String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return base.resolve(path).toString();
  }

  // ------------------------------------------------------ shape helpers

  List<Map<String, dynamic>> _extractRows(Object? v) {
    if (v is List) {
      return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (v is Map) {
      final m = Map<String, dynamic>.from(v);
      final rows = m['rows'] ?? m['catalogs'] ?? m['sections'] ?? m[dialect.fieldItems];
      if (rows is List) {
        return rows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [m];
    }
    return const [];
  }

  List<Object?> _extractItems(Object? v) {
    if (v is List) return v;
    if (v is Map) {
      final m = Map<String, dynamic>.from(v);
      final items = m[dialect.fieldItems] ??
          m['results'] ??
          m['links'] ??
          m['streams'] ??
          m['data'];
      if (items is List) return items;
    }
    return const [];
  }

  List<MediaItem> _mapItems(List<Object?> raw) => raw
      .whereType<Map>()
      .map((e) => _mapItem(Map<String, dynamic>.from(e)))
      .whereType<MediaItem>()
      .toList();

  MediaItem? _mapItem(Map<String, dynamic> m) {
    final title = (m[dialect.itemTitle] ?? m['title'] ?? m['name'])?.toString();
    if (title == null || title.isEmpty) return null;
    final id = (m[dialect.itemId] ?? m['id'] ?? m[dialect.itemUrl] ?? m['url'] ?? title)
        .toString();
    final type = MediaType.fromWire(m['type'] as String?);
    return MediaItem(
      ref: MediaRef(
        id: id,
        type: type == MediaType.other ? MediaType.movie : type,
        imdbId: extractImdbId(m['imdbId']?.toString() ?? id),
        tmdbId: m['tmdbId']?.toString(),
        title: title,
        year: (m['year'] as num?)?.toInt(),
      ),
      title: title,
      poster: (m[dialect.itemPoster] ?? m['poster'] ?? m['image'])?.toString(),
      background: m['background']?.toString(),
      description: (m['description'] ?? m['overview'] ?? m['plot'])?.toString(),
      year: (m['year'] as num?)?.toInt(),
      genres: (m['genres'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('SocketException') || s.contains('Failed host lookup')) {
      return 'Could not reach that URL. Check your connection.';
    }
    if (s.contains('TimeoutException')) return 'The server took too long to respond.';
    if (s.contains('404')) return 'Not found (404). Check the URL.';
    return s.length > 180 ? '${s.substring(0, 180)}…' : s;
  }

  @override
  Future<void> dispose() async {
    for (final h in _hosts.values) {
      await h.dispose();
    }
    _hosts.clear();
    _dio.close(force: true);
  }
}
