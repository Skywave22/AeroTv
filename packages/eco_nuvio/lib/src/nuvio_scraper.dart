/// Nuvio's native plugin contract, mirrored from upstream.
///
/// Verified against `NuvioMedia/NuvioMobile@cmp-rewrite`
/// (`PluginModels.kt`, `runtime/js/JsBindings.kt`, `PluginRepository.kt`) and
/// `NuvioMedia/NuvioTV@dev` (`core/plugin/PluginRuntime.kt`) on 2026-11-05.
/// Both apps run the identical QuickJS contract.
///
/// **Nuvio scrapers are source-only.** They export `getStreams` and nothing
/// else — no home, no search, no details. Nuvio takes all metadata from TMDB.
/// Aero therefore advertises `Capability.streams` only, and the Browse tab
/// will not offer Nuvio plugins.
library;

import 'package:aero_core/aero_core.dart';
import 'package:eco_js_runtime/eco_js_runtime.dart' show kindForUrl, parseQualityLabel;

/// Upstream `PluginManifest` — the repository's `manifest.json`.
class NuvioManifest {
  const NuvioManifest({
    required this.name,
    required this.version,
    required this.scrapers,
    this.description,
    this.author,
  });

  final String name;
  final String version;
  final String? description;
  final String? author;
  final List<NuvioScraperInfo> scrapers;

  /// Mirrors `PluginManifestParser.parse`: name and version must be non-blank
  /// and there must be at least one scraper.
  static String? validate(Map<String, dynamic> j) {
    if ((j['name'] ?? '').toString().trim().isEmpty) {
      return 'This manifest has no name';
    }
    if ((j['version'] ?? '').toString().trim().isEmpty) {
      return 'This manifest has no version';
    }
    final scrapers = j['scrapers'];
    if (scrapers is! List || scrapers.isEmpty) {
      return 'This repository lists no scrapers';
    }
    return null;
  }

  factory NuvioManifest.fromJson(Map<String, dynamic> j) => NuvioManifest(
        name: (j['name'] ?? '').toString(),
        version: (j['version'] ?? '').toString(),
        description: j['description']?.toString(),
        author: j['author']?.toString(),
        scrapers: (j['scrapers'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => NuvioScraperInfo.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// Upstream `PluginManifestScraper`.
class NuvioScraperInfo {
  const NuvioScraperInfo({
    required this.id,
    required this.name,
    required this.version,
    required this.filename,
    this.description,
    this.supportedTypes = const ['movie', 'tv'],
    this.enabled = true,
    this.hasSettings = false,
    this.logo,
    this.contentLanguage = const [],
    this.limited,
  });

  final String id;
  final String name;
  final String version;

  /// Relative to the manifest's folder, or an absolute URL.
  final String filename;
  final String? description;
  final List<String> supportedTypes;
  final bool enabled;
  final bool hasSettings;
  final String? logo;
  final List<String> contentLanguage;
  final bool? limited;

  bool supportsType(String type) {
    final t = normalizeNuvioType(type);
    return supportedTypes.map(normalizeNuvioType).contains(t);
  }

  factory NuvioScraperInfo.fromJson(Map<String, dynamic> j) => NuvioScraperInfo(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? j['id'] ?? '').toString(),
        version: (j['version'] ?? '0.0.0').toString(),
        filename: (j['filename'] ?? '').toString(),
        description: j['description']?.toString(),
        supportedTypes: (j['supportedTypes'] as List? ?? const ['movie', 'tv'])
            .map((e) => e.toString())
            .toList(),
        enabled: j['enabled'] != false,
        hasSettings: j['hasSettings'] == true,
        logo: j['logo']?.toString(),
        contentLanguage: (j['contentLanguage'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(),
        limited: j['limited'] as bool?,
      );
}

/// Upstream normalises `series`/`show` to `tv`.
String normalizeNuvioType(String type) {
  final t = type.toLowerCase().trim();
  if (t == 'series' || t == 'show' || t == 'tvshow') return 'tv';
  return t;
}

/// Resolves a scraper's code URL exactly as upstream does:
/// `manifestUrl.removeSuffix("/manifest.json") + "/" + filename`.
String nuvioScraperUrl(String manifestUrl, String filename) {
  if (filename.startsWith('http://') || filename.startsWith('https://')) {
    return filename;
  }
  final noQuery = manifestUrl.split('?').first;
  final base = noQuery.endsWith('/manifest.json')
      ? noQuery.substring(0, noQuery.length - '/manifest.json'.length)
      : noQuery.substring(0, noQuery.lastIndexOf('/'));
  return '$base/${filename.replaceFirst(RegExp(r'^/+'), '')}';
}

/// Upstream `PluginRuntimeResult`.
///
/// `seeders` / `peers` / `infoHash` reveal that this ecosystem is torrent-first;
/// Aero surfaces those as torrent links rather than pretending they are HTTP.
class NuvioStreamResult {
  const NuvioStreamResult({
    required this.title,
    required this.url,
    this.name,
    this.quality,
    this.size,
    this.language,
    this.provider,
    this.type,
    this.seeders,
    this.peers,
    this.infoHash,
    this.headers = const {},
    this.subtitles = const [],
  });

  final String title;
  final String url;
  final String? name;
  final String? quality;
  final String? size;
  final String? language;
  final String? provider;
  final String? type;
  final int? seeders;
  final int? peers;
  final String? infoHash;
  final Map<String, String> headers;
  final List<NuvioSubtitle> subtitles;

  bool get isTorrent =>
      (infoHash != null && infoHash!.isNotEmpty) ||
      url.startsWith('magnet:') ||
      (type?.toLowerCase().contains('torrent') ?? false);

  factory NuvioStreamResult.fromJson(Map<String, dynamic> j) => NuvioStreamResult(
        title: (j['title'] ?? j['name'] ?? 'Source').toString(),
        url: (j['url'] ?? j['link'] ?? '').toString(),
        name: j['name']?.toString(),
        quality: j['quality']?.toString(),
        size: j['size']?.toString(),
        language: j['language']?.toString(),
        provider: j['provider']?.toString(),
        type: j['type']?.toString(),
        seeders: (j['seeders'] as num?)?.toInt(),
        peers: (j['peers'] as num?)?.toInt(),
        infoHash: j['infoHash']?.toString(),
        headers: _strMap(j['headers']),
        subtitles: (j['subtitles'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => NuvioSubtitle.fromJson(Map<String, dynamic>.from(e)))
            .where((s) => s.url.isNotEmpty)
            .toList(),
      );

  static Map<String, String> _strMap(Object? raw) {
    final out = <String, String>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v != null) out[k.toString()] = v.toString();
      });
    }
    return out;
  }

  StreamLink toStreamLink({
    required String sourceId,
    required String sourceName,
  }) {
    final label = [
      if (quality != null && quality!.isNotEmpty) quality!,
      if (provider != null && provider!.isNotEmpty) provider!,
    ].join(' · ');
    return StreamLink(
      url: url,
      sourceId: sourceId,
      sourceName: sourceName,
      ecosystem: Ecosystem.nuvio,
      kind: isTorrent ? StreamKind.torrent : kindForUrl(url),
      quality: parseQualityLabel(quality ?? title),
      title: label.isEmpty ? title : label,
      description: [
        if (size != null && size!.isNotEmpty) size!,
        if (seeders != null) 'S:$seeders P:${peers ?? 0}',
      ].join(' · '),
      language: language,
      headers: headers,
      infoHash: infoHash,
      subtitles: subtitles.map((e) => e.toTrack()).toList(),
    );
  }
}

class NuvioSubtitle {
  const NuvioSubtitle({required this.url, this.label, this.lang});
  final String url;
  final String? label;
  final String? lang;

  factory NuvioSubtitle.fromJson(Map<String, dynamic> j) => NuvioSubtitle(
        url: (j['url'] ?? j['uri'] ?? '').toString(),
        label: (j['label'] ?? j['title'] ?? j['name'])?.toString(),
        lang: (j['lang'] ?? j['language'])?.toString(),
      );

  SubtitleTrack toTrack() => SubtitleTrack(
        id: url,
        url: url,
        lang: lang ?? 'und',
        label: label ?? lang ?? 'Subtitle',
      );
}

/// The entire Nuvio plugin API.
abstract class NuvioScraper {
  String get id;
  String get name;
  String get version;

  /// The only content function Nuvio defines.
  ///
  /// [tmdbId] is required — Nuvio has no URL-based identity. [mediaType] is
  /// `"movie"` or `"tv"`. [season]/[episode] are null for movies.
  Future<List<NuvioStreamResult>> getStreams({
    required String tmdbId,
    required String mediaType,
    int? season,
    int? episode,
  });

  /// Optional settings layout from `onSettings()`.
  Future<List<Map<String, dynamic>>> onSettings();

  Future<void> dispose();
}

/// JS injected before the scraper body, reproducing upstream's globals.
String nuvioPrelude({
  required String scraperId,
  Map<String, Object?> settings = const {},
  String tmdbApiKey = '',
}) => '''
var module = (typeof module === 'undefined') ? { exports: {} } : module;
globalThis.module = module;
globalThis.SCRAPER_ID = ${_js(scraperId)};
globalThis.SCRAPER_SETTINGS = ${_js(settings)};
globalThis.TMDB_API_KEY = ${_js(tmdbApiKey)};
if (typeof globalThis.global === 'undefined') globalThis.global = globalThis;
if (typeof globalThis.window === 'undefined') globalThis.window = globalThis;
if (typeof globalThis.self === 'undefined') globalThis.self = globalThis;

function __nuvioGetStreams(argsJson) {
  var fn = (module.exports && module.exports.getStreams) || globalThis.getStreams;
  if (typeof fn !== 'function') return Promise.resolve([]);
  var a = JSON.parse(argsJson || '{}');
  var season = (a.season === null || a.season === undefined) ? undefined : a.season;
  var episode = (a.episode === null || a.episode === undefined) ? undefined : a.episode;
  return Promise.resolve(fn(a.tmdbId, a.mediaType, season, episode))
    .then(function (r) { return r || []; })
    .catch(function (e) { console.error('getStreams error: ' + e); return []; });
}
function __nuvioOnSettings() {
  var fn = (module.exports && module.exports.onSettings) || globalThis.onSettings;
  if (typeof fn !== 'function') return Promise.resolve([]);
  return Promise.resolve(fn()).then(function (r) { return r || []; })
    .catch(function () { return []; });
}
globalThis.__nuvioGetStreams = __nuvioGetStreams;
globalThis.__nuvioOnSettings = __nuvioOnSettings;
''';

String _js(Object? v) {
  if (v is String) {
    return '"${v.replaceAll(r'\', r'\\').replaceAll('"', r'\"').replaceAll('\n', r'\n')}"';
  }
  if (v is Map) {
    final entries = v.entries.map((e) => '${_js(e.key.toString())}:${_js(e.value)}');
    return '{${entries.join(',')}}';
  }
  if (v == null) return 'null';
  return v.toString();
}
