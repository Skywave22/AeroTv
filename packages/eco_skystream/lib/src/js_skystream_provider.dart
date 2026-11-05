import 'dart:convert';

import 'package:aero_core/aero_core.dart';
import 'package:eco_js_runtime/eco_js_runtime.dart';

import 'skystream_provider.dart';

/// Runs a real SkyStream `plugin.js` inside the sandbox.
///
/// SkyStream functions are **callback-style** (`fn(args…, cb)`) and report
/// through a `{success, data, errorCode, message}` envelope. Both facts are
/// handled here so the rest of Aero never sees them.
class JsSkyStreamProvider implements SkyStreamProvider {
  JsSkyStreamProvider({
    required this.host,
    required this.manifest,
  });

  final JsPluginHost host;

  /// The parsed `plugin.json`. Injected into JS as `manifest`.
  final Map<String, dynamic> manifest;

  @override
  String get packageName => (manifest['packageName'] ?? host.pluginId).toString();

  @override
  String get name => (manifest['name'] ?? packageName).toString();

  @override
  String get baseUrl => (manifest['baseUrl'] ?? '').toString();

  @override
  int get version => (manifest['version'] as num?)?.toInt() ?? 1;

  @override
  List<String> get languages =>
      (manifest['languages'] as List? ?? const ['en'])
          .map((e) => e.toString())
          .toList();

  @override
  Set<SkyProviderType> get supportedTypes {
    final cats = (manifest['categories'] as List? ?? const [])
        .map((e) => SkyProviderType.fromWire(e.toString()))
        .where((t) => t != SkyProviderType.other)
        .toSet();
    return cats.isEmpty
        ? {SkyProviderType.movie, SkyProviderType.series}
        : cats;
  }

  @override
  bool get hasSearch => true;

  /// JS injected before the plugin body so `manifest` and the helper classes
  /// exist. Upstream injects these natively; we reproduce the same surface.
  static String preludeFor(Map<String, dynamic> manifest) {
    final encoded = jsonEncode(manifest);
    return '''
var manifest = $encoded;
globalThis.manifest = manifest;
function MultimediaItem(o){ Object.assign(this, o); }
function Episode(o){ Object.assign(this, o); }
function StreamResult(o){ Object.assign(this, o); }
function Actor(o){ Object.assign(this, o); }
function Trailer(o){ Object.assign(this, o); }
function NextAiring(o){ Object.assign(this, o); }
globalThis.MultimediaItem = MultimediaItem;
globalThis.Episode = Episode;
globalThis.StreamResult = StreamResult;
globalThis.Actor = Actor;
globalThis.Trailer = Trailer;
globalThis.NextAiring = NextAiring;
if (typeof module === 'undefined') { var module = { exports: {} }; }
''';
  }

  /// Calls a callback-style function and unwraps the response envelope.
  Future<Result<Object?>> _invoke(String fn, List<Object?> args) async {
    final res = await host.call(fn, args, JsCallStyle.callback);
    if (res.isErr) return Err(res.errorOrNull ?? 'Plugin call failed');
    final v = res.valueOrNull;
    if (v is Map) {
      final m = Map<String, dynamic>.from(v);
      // Envelope form: {success, data, errorCode, message}
      if (m.containsKey('success')) {
        if (m['success'] == true) return Ok(m['data']);
        final code = m['errorCode']?.toString();
        final msg = m['message']?.toString();
        return Err([code, msg].where((e) => e != null && e.isNotEmpty).join(': '));
      }
      // Some plugins return the bare payload.
      return Ok(m);
    }
    return Ok(v);
  }

  static List<Map<String, dynamic>> _maps(Object? v) => (v is List ? v : const [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  @override
  Future<Map<String, List<SkyMediaItem>>> getHome() async {
    final res = await _invoke('getHome', const []);
    if (res.isErr) {
      AeroLog.instance.w('skystream', 'getHome failed: ${res.errorOrNull}');
      return const {};
    }
    final data = res.valueOrNull;
    if (data is! Map) return const {};
    final out = <String, List<SkyMediaItem>>{};
    data.forEach((key, value) {
      final items = _maps(value)
          .map(SkyMediaItem.fromJson)
          .where((i) => i.title.isNotEmpty && i.url.isNotEmpty)
          .toList();
      if (items.isNotEmpty) out[key.toString()] = items;
    });
    return out;
  }

  @override
  Future<List<SkyMediaItem>> search(String query, {int page = 1}) async {
    if (query.trim().isEmpty) return const [];
    final res = await _invoke('search', [query.trim(), page]);
    if (res.isErr) {
      AeroLog.instance.w('skystream', 'search failed: ${res.errorOrNull}');
      return const [];
    }
    return _maps(res.valueOrNull)
        .map(SkyMediaItem.fromJson)
        .where((i) => i.title.isNotEmpty && i.url.isNotEmpty)
        .toList();
  }

  @override
  Future<SkyMediaItem> load(String url) async {
    final res = await _invoke('load', [url]);
    if (res.isErr) {
      throw AeroException(res.errorOrNull ?? 'Could not load details');
    }
    final data = res.valueOrNull;
    if (data is! Map) throw const AeroException('Plugin returned no details');
    return SkyMediaItem.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<List<SkyStreamResult>> loadStreams(String url) async {
    final res = await _invoke('loadStreams', [url]);
    if (res.isErr) {
      AeroLog.instance.w('skystream', 'loadStreams failed: ${res.errorOrNull}');
      return const [];
    }
    return _maps(res.valueOrNull)
        .map(SkyStreamResult.fromJson)
        .where((s) => s.url.isNotEmpty)
        .toList();
  }

  @override
  Future<void> dispose() => host.dispose();
}
