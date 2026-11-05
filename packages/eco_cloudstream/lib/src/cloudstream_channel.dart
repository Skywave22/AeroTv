import 'package:flutter/services.dart';

/// Thin MethodChannel client for the optional native CloudStream host.
///
/// The Kotlin side is intentionally not part of this repository. When (and if)
/// it is added, it must implement these methods and run in an isolated
/// process so a crashing plugin cannot take down the UI.
class CloudStreamChannel {
  CloudStreamChannel({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('tv.aero/cloudstream');

  final MethodChannel _channel;

  /// Returns false when no native host is compiled into this build.
  Future<bool> isHostPresent() async {
    try {
      final v = await _channel.invokeMethod<bool>('isHostPresent');
      return v ?? false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> loadPlugin(String path, {String? expectedSha256}) async {
    final res = await _channel.invokeMapMethod<String, dynamic>('loadPlugin', {
      'path': path,
      'sha256': expectedSha256,
    });
    return res ?? const {};
  }

  Future<List<Map<String, dynamic>>> invoke(
    String pluginId,
    String method,
    Map<String, dynamic> args,
  ) async {
    final res = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
      'invoke',
      {'pluginId': pluginId, 'method': method, 'args': args},
    );
    return res?.map((e) => Map<String, dynamic>.from(e)).toList() ?? const [];
  }

  Future<void> unload(String pluginId) =>
      _channel.invokeMethod<void>('unloadPlugin', {'pluginId': pluginId});
}
