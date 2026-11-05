/// Vega's native plugin contract, mirrored from upstream.
///
/// Verified against `vega-org/vega-app@main` (`src/lib/providers/types.ts`,
/// `src/lib/services/ExtensionManager.ts`, `src/lib/sandbox/protocol.ts`)
/// on 2026-11-05.
///
/// Two things make Vega unlike the others:
///  * a provider is **six separate JS files**, not one bundle;
///  * every function takes **one destructured object** and returns a promise.
library;

import 'package:aero_core/aero_core.dart';

/// `{title, filter}` — a catalog or genre entry.
class VegaCatalog {
  const VegaCatalog({required this.title, required this.filter});
  final String title;
  final String filter;

  factory VegaCatalog.fromJson(Map<String, dynamic> j) => VegaCatalog(
        title: (j['title'] ?? j['name'] ?? '').toString(),
        filter: (j['filter'] ?? j['value'] ?? '').toString(),
      );
}

/// Upstream `Post` — the grid/card shape.
class VegaPost {
  const VegaPost({
    required this.title,
    required this.link,
    required this.image,
    this.provider,
    this.tag,
    this.cornerTag,
    this.aspectRatio,
  });

  final String title;
  final String link;
  final String image;
  final String? provider;
  final String? tag;
  final String? cornerTag;
  final double? aspectRatio;

  factory VegaPost.fromJson(Map<String, dynamic> j) => VegaPost(
        title: (j['title'] ?? '').toString(),
        link: (j['link'] ?? j['url'] ?? '').toString(),
        image: (j['image'] ?? j['poster'] ?? '').toString(),
        provider: j['provider']?.toString(),
        tag: j['tag']?.toString(),
        cornerTag: j['cornerTag']?.toString(),
        aspectRatio: j['aspectRatio'] is num
            ? (j['aspectRatio'] as num).toDouble()
            : double.tryParse('${j['aspectRatio']}'),
      );

  MediaItem toMediaItem() => MediaItem(
        ref: MediaRef(
          id: link,
          type: MediaType.movie,
          imdbId: extractImdbId(link),
          title: title,
        ),
        title: title,
        poster: image.isEmpty ? null : image,
      );
}

/// Upstream `SkipInterval` — intro/recap markers.
class VegaSkip {
  const VegaSkip({required this.from, required this.to, this.title});
  final double from;
  final double to;
  final String? title;

  factory VegaSkip.fromJson(Map<String, dynamic> j) => VegaSkip(
        from: (j['from'] as num?)?.toDouble() ?? 0,
        to: (j['to'] as num?)?.toDouble() ?? 0,
        title: j['title']?.toString(),
      );
}

/// Upstream `TextTracks` entry.
class VegaTextTrack {
  const VegaTextTrack({
    required this.title,
    required this.language,
    required this.uri,
    this.type,
  });
  final String title;
  final String language;
  final String uri;

  /// MIME: `text/vtt`, `application/x-subrip`, `application/ttml+xml`.
  final String? type;

  factory VegaTextTrack.fromJson(Map<String, dynamic> j) => VegaTextTrack(
        title: (j['title'] ?? j['label'] ?? '').toString(),
        language: (j['language'] ?? j['lang'] ?? 'und').toString(),
        uri: (j['uri'] ?? j['url'] ?? '').toString(),
        type: j['type']?.toString(),
      );

  SubtitleTrack toSubtitle() => SubtitleTrack(
        id: uri,
        url: uri,
        lang: language,
        label: title.isEmpty ? language : title,
        format: switch (type) {
          'text/vtt' => 'vtt',
          'application/x-subrip' => 'srt',
          'application/ttml+xml' => 'ttml',
          _ => null,
        },
      );
}

/// Upstream `Stream`.
class VegaStream {
  const VegaStream({
    required this.server,
    required this.link,
    required this.type,
    this.quality,
    this.tag,
    this.tags = const [],
    this.headers = const {},
    this.subtitles = const [],
    this.skip = const [],
  });

  final String server;
  final String link;
  final String type;
  final String? quality;
  final String? tag;
  final List<String> tags;
  final Map<String, String> headers;
  final List<VegaTextTrack> subtitles;
  final List<VegaSkip> skip;

  factory VegaStream.fromJson(Map<String, dynamic> j) => VegaStream(
        server: (j['server'] ?? j['source'] ?? 'Server').toString(),
        link: (j['link'] ?? j['url'] ?? '').toString(),
        type: (j['type'] ?? '').toString(),
        quality: j['quality']?.toString(),
        tag: j['tag']?.toString(),
        tags: (j['tags'] as List? ?? const []).map((e) => e.toString()).toList(),
        headers: _strMap(j['headers']),
        subtitles: (j['subtitles'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => VegaTextTrack.fromJson(Map<String, dynamic>.from(e)))
            .where((t) => t.uri.isNotEmpty)
            .toList(),
        skip: (j['skip'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => VegaSkip.fromJson(Map<String, dynamic>.from(e)))
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
}

/// Upstream `EpisodeLink`.
class VegaEpisodeLink {
  const VegaEpisodeLink({
    required this.title,
    required this.link,
    this.id,
    this.description,
    this.image,
  });
  final String title;
  final String link;
  final String? id;
  final String? description;
  final String? image;

  factory VegaEpisodeLink.fromJson(Map<String, dynamic> j) => VegaEpisodeLink(
        title: (j['title'] ?? '').toString(),
        link: (j['link'] ?? j['url'] ?? '').toString(),
        id: j['id']?.toString(),
        description: j['description']?.toString(),
        image: j['image']?.toString(),
      );
}

/// Upstream `Link` — a season/dub grouping inside `Info.linkList`.
class VegaLink {
  const VegaLink({
    required this.title,
    this.quality,
    this.episodesLink,
    this.directLinks = const [],
  });

  final String title;
  final String? quality;

  /// Follow with `GetEpisodeLinks` to list episodes.
  final String? episodesLink;

  /// Already-playable targets (usually movies or single files).
  final List<VegaEpisodeLink> directLinks;

  factory VegaLink.fromJson(Map<String, dynamic> j) => VegaLink(
        title: (j['title'] ?? '').toString(),
        quality: j['quality']?.toString(),
        episodesLink: j['episodesLink']?.toString(),
        directLinks: (j['directLinks'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => VegaEpisodeLink.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// Upstream `Info` — full metadata.
class VegaInfo {
  const VegaInfo({
    required this.title,
    required this.image,
    required this.synopsis,
    required this.type,
    required this.linkList,
    this.logo,
    this.poster,
    this.imdbId,
    this.tmdbId,
    this.tags = const [],
    this.cast = const [],
    this.rating,
    this.trailerUrl,
  });

  final String title;
  final String image;
  final String synopsis;
  final String type;
  final List<VegaLink> linkList;
  final String? logo;
  final String? poster;
  final String? imdbId;
  final String? tmdbId;
  final List<String> tags;
  final List<String> cast;
  final String? rating;
  final String? trailerUrl;

  factory VegaInfo.fromJson(Map<String, dynamic> j) => VegaInfo(
        title: (j['title'] ?? '').toString(),
        image: (j['image'] ?? '').toString(),
        synopsis: (j['synopsis'] ?? j['description'] ?? '').toString(),
        type: (j['type'] ?? 'movie').toString(),
        linkList: (j['linkList'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => VegaLink.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        logo: j['logo']?.toString(),
        poster: j['poster']?.toString(),
        imdbId: j['imdbId']?.toString(),
        tmdbId: j['tmdbId']?.toString(),
        tags: (j['tags'] as List? ?? const []).map((e) => e.toString()).toList(),
        cast: (j['cast'] as List? ?? const []).map((e) => e.toString()).toList(),
        rating: j['rating']?.toString(),
        trailerUrl: j['trailerUrl']?.toString(),
      );

  MediaType get mediaType =>
      type.toLowerCase().contains('series') || type.toLowerCase() == 'tv'
          ? MediaType.series
          : MediaType.movie;

  MediaItem toMediaItem(String link) => MediaItem(
        ref: MediaRef(
          id: link,
          type: mediaType,
          imdbId: extractImdbId(imdbId ?? link),
          tmdbId: tmdbId,
          title: title,
        ),
        title: title,
        poster: (poster ?? image).isEmpty ? null : (poster ?? image),
        background: image.isEmpty ? null : image,
        logo: logo,
        description: synopsis,
        genres: tags,
        imdbRating: double.tryParse(rating ?? ''),
      );
}

/// The Vega provider surface. Every method mirrors an upstream function that
/// takes a single object argument.
abstract class VegaProvider {
  String get value;
  String get displayName;
  String get version;

  /// `catalog` may be a static array or a function upstream.
  Future<List<VegaCatalog>> catalog();
  Future<List<VegaCatalog>> genres();

  Future<List<VegaPost>> getHomePosts({required String filter, int page = 1});
  Future<List<VegaPost>> getSearchPosts({required String query, int page = 1});
  Future<VegaInfo> getMetaData(String link);
  Future<List<VegaEpisodeLink>> getEpisodeLinks(String url);
  Future<List<VegaStream>> getStream({required String link, String type = 'movie'});

  /// Whether the optional `episodes.js` module was present.
  bool get hasEpisodeModule;

  Future<void> dispose();
}

/// Files Vega downloads for every provider. Verified in
/// `ExtensionManager.ts` (`requiredFiles` / `optionalFiles`).
const List<String> kVegaRequiredModules = ['posts', 'meta', 'stream', 'catalog'];
const List<String> kVegaOptionalModules = ['episodes', 'settings'];

/// Builds the folder URL for a provider's modules.
///
/// `path` comes from the manifest and is attacker-controlled, so it is
/// validated against traversal before use — upstream does the same via
/// `isValidProviderPath`.
String? vegaProviderFilesUrl(String sourceUrl, String value, String? path) {
  if (path != null && path.isNotEmpty && !isSafeVegaPath(path)) return null;
  final base = sourceUrl.endsWith('/') ? sourceUrl.substring(0, sourceUrl.length - 1) : sourceUrl;
  final folder = (path == null || path.isEmpty) ? 'dist/$value' : path;
  return '$base/$folder';
}

/// Rejects absolute URLs, traversal and backslashes in a manifest `path`.
bool isSafeVegaPath(String path) {
  if (path.isEmpty) return true;
  if (path.contains('://')) return false;
  if (path.contains('\\')) return false;
  if (path.startsWith('/')) return false;
  for (final seg in path.split('/')) {
    if (seg == '..') return false;
  }
  return true;
}
