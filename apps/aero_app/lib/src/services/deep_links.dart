import 'dart:async';

import 'package:flutter/services.dart';

/// Turns an incoming `stremio://` or `aerotv://` link into an add-on install.
///
/// Add-on sites publish `stremio://host/path/manifest.json` install links.
/// Aero TV speaks the same protocol, so claiming the scheme lets a user tap
/// "Install" on a website instead of copying a URL by hand.
///
/// The native side only forwards the two schemes we handle, and this class
/// re-checks them, so an unrelated intent can never drive navigation.
class DeepLinkService {
  DeepLinkService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('tv.aero/deeplink');

  final MethodChannel _channel;
  final _controller = StreamController<String>.broadcast();
  bool _started = false;

  /// Emits normalised https manifest URLs ready for the install flow.
  Stream<String> get addonLinks => _controller.stream;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onLink') {
        final url = normaliseAddonLink(call.arguments as String?);
        if (url != null) _controller.add(url);
      }
      return null;
    });
    // A link that launched the app arrives before the handler exists.
    try {
      final initial = await _channel.invokeMethod<String>('consumeInitialLink');
      final url = normaliseAddonLink(initial);
      if (url != null) _controller.add(url);
    } on PlatformException {
      // Desktop and tests have no native side; nothing to consume.
    } on MissingPluginException {
      // Same: not an error.
    }
  }

  Future<void> dispose() async {
    _channel.setMethodCallHandler(null);
    await _controller.close();
    _started = false;
  }

  /// `stremio://host/path` -> `https://host/path/manifest.json`.
  ///
  /// Returns null for anything that is not one of our schemes or does not
  /// yield a usable host, so callers can ignore it safely.
  static String? normaliseAddonLink(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final trimmed = raw.trim();
    if (!trimmed.startsWith('stremio://') && !trimmed.startsWith('aerotv://')) {
      return null;
    }
    final https = trimmed.replaceFirst(RegExp(r'^(stremio|aerotv)://'), 'https://');
    final uri = Uri.tryParse(https);
    if (uri == null || uri.host.isEmpty || !uri.host.contains('.')) return null;

    // The Extensions screen owns navigation; a bare host is not an add-on.
    if (uri.path.isEmpty || uri.path == '/') return null;
    if (uri.path.endsWith('/manifest.json')) return uri.toString();
    final path =
        uri.path.endsWith('/') ? '${uri.path}manifest.json' : '${uri.path}/manifest.json';
    return uri.replace(path: path).toString();
  }
}
