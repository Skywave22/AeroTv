import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// A short-lived LAN server that lets a phone hand an add-on URL to the TV.
///
/// Typing a long manifest URL with a D-pad is miserable. The TV shows a QR
/// code; the phone opens a one-field form and posts the URL back. The manifest
/// is then validated on the TV, where the confirm dialog already lives.
///
/// Security model:
/// * a cryptographically random, single-use token is embedded in the QR;
/// * every request must present it, so a stranger on the same Wi-Fi cannot
///   inject an add-on by guessing the port;
/// * the session ends on first successful submission or after [timeout];
/// * only http/https URLs are accepted, and nothing is logged.
class PairingSession {
  PairingSession._(this._server, this.token, this.address, this.timeout);

  final HttpServer _server;
  final String token;
  final String address;
  final Duration timeout;

  final _controller = StreamController<String>.broadcast();
  Timer? _expiry;
  bool _closed = false;

  /// Emits each accepted URL. The first one also ends the session.
  Stream<String> get submissions => _controller.stream;

  int get port => _server.port;

  /// The URL to render as a QR code.
  String get url => 'http://$address:$port/?t=$token';

  bool get isClosed => _closed;

  void _startExpiry() {
    _expiry = Timer(timeout, close);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _expiry?.cancel();
    await _server.close(force: true);
    await _controller.close();
  }
}

class PairingServer {
  /// Starts a session on an ephemeral port.
  ///
  /// [addressOverride] exists for tests; in the app the LAN address is
  /// discovered from the device's network interfaces.
  static Future<PairingSession> start({
    Duration timeout = const Duration(minutes: 5),
    String? addressOverride,
  }) async {
    final address = addressOverride ?? await lanAddress();
    if (address == null) {
      throw const SocketException('No local network address found. '
          'Connect the TV to Wi-Fi or Ethernet and try again.');
    }

    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    final token = _newToken();
    final session = PairingSession._(server, token, address, timeout);
    session._startExpiry();

    server.listen((req) async {
      try {
        await _handle(req, session);
      } catch (_) {
        // Never let a malformed request kill the session.
      }
    }, onError: (_) {});

    return session;
  }

  static Future<void> _handle(HttpRequest req, PairingSession s) async {
    if (s.isClosed) {
      req.response.statusCode = HttpStatus.gone;
      await req.response.close();
      return;
    }

    // Token may come from the query (GET) or the form body (POST).
    var supplied = req.uri.queryParameters['t'];
    String? submitted;

    if (req.method == 'POST') {
      final body = await utf8.decoder.bind(req).join();
      final form = Uri.splitQueryString(body);
      supplied ??= form['t'];
      submitted = form['url']?.trim();
    }

    if (supplied != s.token) {
      req.response
        ..statusCode = HttpStatus.forbidden
        ..headers.contentType = ContentType.html
        ..write(_page('Wrong or missing code',
            '<p>This pairing code is not valid. Scan the QR code on your TV again.</p>'));
      await req.response.close();
      return;
    }

    if (req.method == 'POST') {
      final error = validateAddonUrl(submitted ?? '');
      if (error != null) {
        req.response
          ..statusCode = HttpStatus.badRequest
          ..headers.contentType = ContentType.html
          ..write(_page('Check the URL', '<p>${_escape(error)}</p>'
              '<p><a href="/?t=${s.token}">Try again</a></p>'));
        await req.response.close();
        return;
      }

      req.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write(_page('Sent to your TV',
            '<p>Confirm the add-on on your TV screen. You can close this page.</p>'));
      await req.response.close();

      s._controller.add(submitted!);
      // Single use: the session is done once a URL has been handed over.
      await s.close();
      return;
    }

    if (req.method != 'GET' || req.uri.path != '/') {
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
      return;
    }

    req.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.html
      ..write(_page('Add to Aero TV', '''
<p>Paste the add-on manifest URL below. It will appear on your TV for confirmation.</p>
<form method="post" action="/add">
  <input type="hidden" name="t" value="${s.token}">
  <input type="url" name="url" inputmode="url" autocomplete="off"
         placeholder="https://example.com/manifest.json" required>
  <button type="submit">Send to TV</button>
</form>
<p class="hint">Aero TV provides no content and no sources. Only add add-ons you trust.</p>'''));
    await req.response.close();
  }

  /// Accepts only absolute http/https URLs. Keeps javascript:, file: and data:
  /// out, and rejects anything the manifest fetcher could not use anyway.
  static String? validateAddonUrl(String input) {
    final s = input.trim();
    if (s.isEmpty) return 'Enter a URL.';
    final uri = Uri.tryParse(s);
    if (uri == null || !uri.hasScheme) {
      return 'That does not look like a URL. It should start with https://';
    }
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      return 'Only http and https URLs are supported.';
    }
    if (uri.host.isEmpty || !uri.host.contains('.')) {
      return 'That URL has no valid host name.';
    }
    return null;
  }

  /// Best-effort LAN IPv4 address, preferring private ranges.
  static Future<String?> lanAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      final candidates = <String>[];
      for (final i in interfaces) {
        for (final a in i.addresses) {
          if (a.isLoopback) continue;
          candidates.add(a.address);
        }
      }
      if (candidates.isEmpty) return null;
      // Prefer a private LAN range over anything else (e.g. a VPN tunnel).
      bool private(String a) =>
          a.startsWith('192.168.') ||
          a.startsWith('10.') ||
          RegExp(r'^172\.(1[6-9]|2[0-9]|3[01])\.').hasMatch(a);
      return candidates.firstWhere(private, orElse: () => candidates.first);
    } catch (_) {
      return null;
    }
  }

  static String _newToken() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  static String _escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  /// Self-contained page: no external CSS or fonts, because the phone may have
  /// no internet route while talking to the TV over LAN.
  static String _page(String title, String body) => '''
<!DOCTYPE html>
<html lang="en"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${_escape(title)}</title>
<style>
  :root { color-scheme: dark; }
  body { margin:0; min-height:100vh; display:flex; align-items:center;
         justify-content:center; background:#0E0F14; color:#F2F3F7;
         font:16px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif; }
  main { width:100%; max-width:420px; padding:28px; }
  h1 { font-size:22px; margin:0 0 12px; }
  p { color:#A8ADBD; margin:0 0 18px; }
  input[type=url] { width:100%; box-sizing:border-box; padding:14px;
         font-size:16px; border-radius:12px; border:1px solid #2A2D3A;
         background:#171922; color:#F2F3F7; margin-bottom:14px; }
  input[type=url]:focus { outline:2px solid #7B5CFF; border-color:transparent; }
  button { width:100%; padding:14px; font-size:16px; font-weight:600;
         border:0; border-radius:12px; background:#7B5CFF; color:#fff; }
  a { color:#7B5CFF; }
  .hint { font-size:13px; color:#6E7488; margin-top:18px; }
</style></head>
<body><main><h1>${_escape(title)}</h1>$body</main></body></html>''';
}
