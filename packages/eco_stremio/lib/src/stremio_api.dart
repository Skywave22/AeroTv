import 'package:aero_core/aero_core.dart';
import 'package:dio/dio.dart';

import 'stremio_manifest.dart';

/// Thin HTTP layer over the Stremio addon protocol.
///
/// Every request goes through one [Dio] so headers, timeouts, retries and
/// logging are centrally controlled and visible in the debug panel.
class StremioApi {
  StremioApi({Dio? dio, this.timeout = const Duration(seconds: 12)})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: timeout,
              receiveTimeout: timeout,
              sendTimeout: timeout,
              // Add-ons return JSON but often with a text/plain content type.
              responseType: ResponseType.json,
              headers: {
                'Accept': 'application/json',
                'User-Agent': 'AeroTV/0.1 (Stremio-compatible)',
              },
              // 404 is a normal "no results" answer for many add-ons.
              validateStatus: (s) => s != null && s < 500,
            )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        AeroLog.instance.network(
          'stremio',
          options.uri,
          note: options.extra['sourceName'] as String?,
        );
        handler.next(options);
      },
      onError: (e, handler) {
        AeroLog.instance.w('stremio', 'HTTP ${e.response?.statusCode} ${e.requestOptions.uri}');
        handler.next(e);
      },
    ));
  }

  final Dio _dio;
  final Duration timeout;

  Dio get dio => _dio;

  /// Normalises a user-supplied URL to a manifest URL.
  ///
  /// Handles: bare hosts, `stremio://` deep links, trailing slashes, and
  /// configurable add-ons whose path segment carries user config.
  static String normaliseManifestUrl(String input) {
    var s = input.trim();
    if (s.isEmpty) throw const AeroException('URL is empty');

    // stremio://host/manifest.json → https://host/manifest.json
    if (s.startsWith('stremio://')) {
      s = 'https://${s.substring('stremio://'.length)}';
    }
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      s = 'https://$s';
    }
    // Strip a trailing /manifest.json so we can re-append canonically.
    s = s.replaceAll(RegExp(r'/+$'), '');
    if (s.endsWith('/manifest.json')) return s;
    return '$s/manifest.json';
  }

  /// Base URL for resource requests: the manifest URL minus `manifest.json`.
  /// Preserves any configuration path segment.
  static String baseUrlOf(String manifestUrl) =>
      manifestUrl.replaceFirst(RegExp(r'manifest\.json$'), '');

  /// Percent-encodes a path segment but keeps `:` (episode ids use colons).
  static String encodeId(String id) => Uri.encodeComponent(id).replaceAll('%3A', ':');

  /// Builds `/catalog/{type}/{id}/{extra}.json`.
  static String catalogUrl(
    String manifestUrl,
    String type,
    String catalogId,
    Map<String, String> extra,
  ) {
    final base = baseUrlOf(manifestUrl);
    final parts = <String>['catalog', type, encodeId(catalogId)];
    if (extra.isNotEmpty) {
      // Stremio expects extras as `k=v` joined by `&`, in a single segment.
      final extras = extra.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      parts.add(extras);
    }
    return '$base${parts.join('/')}.json';
  }

  static String resourceUrl(
    String manifestUrl,
    String resource,
    String type,
    String id, [
    Map<String, String> extra = const {},
  ]) {
    final base = baseUrlOf(manifestUrl);
    final parts = <String>[resource, type, encodeId(id)];
    if (extra.isNotEmpty) {
      parts.add(extra.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&'));
    }
    return '$base${parts.join('/')}.json';
  }

  Future<StremioManifest> fetchManifest(String manifestUrl) async {
    final url = normaliseManifestUrl(manifestUrl);
    final res = await _dio.getUri(Uri.parse(url));
    if (res.statusCode != 200) {
      throw AeroException('Manifest fetch failed (HTTP ${res.statusCode})');
    }
    final data = res.data;
    final map = _asMap(data);
    if (map == null) {
      throw const AeroException('Manifest is not a JSON object');
    }
    final manifest = StremioManifest.fromJson(map);
    if (manifest.id.isEmpty) {
      throw const AeroException('Manifest is missing a valid "id"');
    }
    return manifest;
  }

  Future<Map<String, dynamic>> getJson(String url, {String? sourceName}) async {
    final res = await _dio.getUri(
      Uri.parse(url),
      options: Options(extra: {'sourceName': sourceName}),
    );
    if (res.statusCode == 404) return const {};
    if (res.statusCode != 200) {
      throw AeroException('HTTP ${res.statusCode} for $url');
    }
    return _asMap(res.data) ?? const {};
  }

  /// Some add-ons serve JSON with the wrong content type; decode defensively.
  static Map<String, dynamic>? _asMap(Object? data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  void close() => _dio.close(force: true);
}
