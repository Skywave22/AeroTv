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

/// Shared sandbox lifecycle for the JS ecosystems.
///
/// This owns *only* the parts that genuinely are common: downloading, hash
/// pinning, booting a sandbox, caching it, health checks and teardown.
///
/// It deliberately knows **nothing** about function names, argument shapes or
/// repository formats. Phase 0 verification showed the three JS ecosystems
/// differ in calling convention, module layout and capability surface, so each
/// one now has its own provider interface on top of this manager. See
/// `docs/specs/VERIFIED_CONTRACTS.md`.
class JsSourceManager {
  JsSourceManager({
    required this.ecosystem,
    required this.store,
    this.policy = const JsSandboxPolicy(),
    Dio? dio,
  }) : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 25),
              validateStatus: (s) => s != null && s < 400,
            ));

  final Ecosystem ecosystem;
  final JsPluginStore store;
  final JsSandboxPolicy policy;
  final Dio _dio;

  final Map<String, JsPluginHost> _hosts = {};
  final Map<String, Future<JsPluginHost?>> _booting = {};

  /// Extra JS evaluated before the plugin body, e.g. injected globals.
  final Map<String, String> _preludes = {};

  Dio get http => _dio;

  Future<List<InstalledSource>> installed() => store.load(ecosystem);

  Future<InstalledSource?> source(String id) async {
    for (final s in await store.load(ecosystem)) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Next priority so newly installed plugins sort after existing ones.
  Future<int> nextPriority() async {
    final all = await store.load(ecosystem);
    if (all.isEmpty) return 10;
    return all.map((e) => e.priority).reduce((a, b) => a > b ? a : b) + 10;
  }

  /// Registers JS to run before a plugin's own code on every boot.
  void setPrelude(String sourceId, String js) => _preludes[sourceId] = js;

  /// Boots (or reuses) the sandbox for a plugin, re-verifying its hash.
  Future<JsPluginHost?> hostFor(InstalledSource s) async {
    final existing = _hosts[s.id];
    if (existing != null && existing.isReady) return existing;

    return _booting.putIfAbsent(s.id, () async {
      try {
        var code = await store.loadCode(ecosystem, s.id);
        // Recover instead of giving up: a pruned cache row, a restored backup
        // or an interrupted install must not brick an installed plugin.
        if (code == null || code.isEmpty) {
          AeroLog.instance.i(
              ecosystem.id, 'No cached code for ${s.name} — refetching');
          final fetched = await fetchCode(s.url, expectedSha256: s.sha256);
          if (fetched.isErr) {
            AeroLog.instance.e(
                ecosystem.id, 'Refetch failed: ${fetched.errorOrNull}');
            return null;
          }
          code = fetched.valueOrNull!;
          await store.saveCode(ecosystem, s.id, code);
        }
        // Re-verify the pin at every boot, not just at install time.
        final actual = JsPluginBundle.hashOf(code);
        if (s.sha256 != null &&
            s.sha256!.isNotEmpty &&
            actual.toLowerCase() != s.sha256!.toLowerCase()) {
          AeroLog.instance.e(
              ecosystem.id, 'Hash mismatch for ${s.name} — refusing to execute');
          return null;
        }
        final host = JsPluginHost(
          pluginId: s.id,
          pluginName: s.name,
          policy: policy,
        );
        final prelude = _preludes[s.id];
        final res = await host.initialise(JsPluginBundle(
          sourceUrl: s.url,
          code: prelude == null || prelude.isEmpty ? code : '$prelude\n$code',
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

  /// Convenience: resolve a source id to a live host, or null.
  Future<JsPluginHost?> hostById(String sourceId) async {
    final s = await source(sourceId);
    if (s == null) return null;
    return hostFor(s);
  }

  /// Drops a cached host so the next call re-boots with fresh code.
  Future<void> evict(String sourceId) async {
    await _hosts.remove(sourceId)?.dispose();
    _preludes.remove(sourceId);
  }

  /// Validates a user-supplied URL before any network access.
  String? validateUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.host.contains('.')) {
      return 'Enter a valid plugin or repository URL';
    }
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      return 'Only http and https URLs are supported';
    }
    return null;
  }

  /// Downloads plugin code, enforcing the size cap and optional hash pin.
  Future<Result<String>> fetchCode(String url, {String? expectedSha256}) async {
    final bad = validateUrl(url);
    if (bad != null) return Err(bad);
    try {
      final res = await _dio.getUri<String>(
        Uri.parse(url),
        options: Options(responseType: ResponseType.plain),
      );
      final code = res.data ?? '';
      if (code.trim().isEmpty) return const Err('The plugin file is empty');
      if (code.length > 8 * 1024 * 1024) {
        return const Err('Plugin is too large (over 8 MB)');
      }
      final hash = JsPluginBundle.hashOf(code);
      if (expectedSha256 != null &&
          expectedSha256.isNotEmpty &&
          hash.toLowerCase() != expectedSha256.toLowerCase()) {
        return const Err(
          'Hash mismatch: the downloaded plugin does not match the pinned '
          'checksum. It may have been tampered with.',
        );
      }
      return Ok(code);
    } catch (e) {
      return Err(friendlyError(e));
    }
  }

  /// Fetches and decodes a JSON repository index.
  Future<Result<Object?>> fetchJson(String url) async {
    final bad = validateUrl(url);
    if (bad != null) return Err(bad);
    try {
      final res = await _dio.getUri(Uri.parse(url));
      final data = res.data;
      final decoded = data is String ? jsonDecode(data) : data;
      return Ok(decoded);
    } catch (e) {
      return Err(friendlyError(e));
    }
  }

  Future<void> persist(InstalledSource s, String code) async {
    await store.save(s);
    await store.saveCode(ecosystem, s.id, code);
    await evict(s.id);
    AeroLog.instance.i(ecosystem.id, 'Installed ${s.name} v${s.version}');
  }

  Future<void> uninstall(String sourceId) async {
    await evict(sourceId);
    await store.delete(ecosystem, sourceId);
    await store.saveCode(ecosystem, sourceId, '');
  }

  Future<Result<Duration>> healthCheck(String sourceId) async {
    final s = await source(sourceId);
    if (s == null) return const Err('Plugin not installed');
    final sw = Stopwatch()..start();
    final host = await hostFor(s);
    sw.stop();
    if (host == null || !host.isReady) {
      return const Err('Plugin failed to start. Check the log for details.');
    }
    return Ok(sw.elapsed);
  }

  Future<void> dispose() async {
    for (final h in _hosts.values) {
      await h.dispose();
    }
    _hosts.clear();
    _preludes.clear();
    _dio.close(force: true);
  }

  static String friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('SocketException') || s.contains('Failed host lookup')) {
      return 'Could not reach that URL. Check your connection.';
    }
    if (s.contains('TimeoutException')) return 'The server took too long to respond.';
    if (s.contains('404')) return 'Not found (404). Check the URL.';
    if (s.contains('403')) return 'Access denied (403). The source may be private.';
    return s.length > 180 ? '${s.substring(0, 180)}…' : s;
  }
}

/// Normalises the many ways upstream spells a quality into [Quality].
///
/// SkyStream alone accepts `1080`, `"1080p"`, `"4K"`, `"UHD"`, `"2K"`,
/// `"1440p"`, `"Auto"` and `0`.
Quality parseQualityLabel(Object? raw) {
  if (raw == null) return Quality.unknown;
  if (raw is num) {
    final n = raw.toInt();
    if (n <= 0) return Quality.unknown; // 0 == HLS master / auto
    return Quality.fromHeight(n);
  }
  final s = raw.toString().trim().toLowerCase();
  if (s.isEmpty || s == 'auto' || s == 'unknown') return Quality.unknown;
  if (s == '4k' || s == 'uhd' || s == '2160p') return Quality.uhd;
  if (s == '2k' || s == '1440p' || s == 'qhd') return Quality.qhd;
  if (s == '1080p' || s == 'fhd') return Quality.fullHd;
  final digits = RegExp(r'(\d{3,4})').firstMatch(s);
  if (digits != null) {
    return Quality.fromHeight(int.parse(digits.group(1)!));
  }
  return Quality.parse(s);
}

/// Maps a playable URL to its container/protocol.
StreamKind kindForUrl(String url) {
  final u = url.toLowerCase();
  if (u.startsWith('magnet:') || u.endsWith('.torrent')) return StreamKind.torrent;
  if (u.contains('.m3u8')) return StreamKind.hls;
  if (u.contains('.mpd')) return StreamKind.dash;
  return StreamKind.direct;
}

/// Reads an HTTP header map out of arbitrary plugin JSON.
Map<String, String> readHeaders(Object? raw) {
  final out = <String, String>{};
  if (raw is Map) {
    raw.forEach((k, v) {
      if (v != null) out[k.toString()] = v.toString();
    });
  }
  return out;
}
