import 'dart:convert';
import 'dart:io';

import 'package:aero_data/aero_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late PairingSession session;
  late HttpClient client;

  setUp(() async {
    session = await PairingServer.start(
      addressOverride: '127.0.0.1',
      timeout: const Duration(seconds: 30),
    );
    client = HttpClient();
  });

  tearDown(() async {
    client.close(force: true);
    await session.close();
  });

  Future<HttpClientResponse> get(String path) async {
    final req = await client.getUrl(Uri.parse('http://127.0.0.1:${session.port}$path'));
    return req.close();
  }

  Future<HttpClientResponse> post(String path, Map<String, String> form) async {
    final req = await client.postUrl(Uri.parse('http://127.0.0.1:${session.port}$path'));
    req.headers.contentType = ContentType('application', 'x-www-form-urlencoded');
    req.write(form.entries
        .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&'));
    return req.close();
  }

  group('URL validation', () {
    test('accepts absolute http and https URLs', () {
      expect(PairingServer.validateAddonUrl('https://x.com/manifest.json'), isNull);
      expect(PairingServer.validateAddonUrl('http://x.com/manifest.json'), isNull);
      expect(PairingServer.validateAddonUrl('  https://x.com/m.json  '), isNull);
    });

    test('rejects empty, relative and non-http schemes', () {
      for (final bad in [
        '', '   ', 'not a url', 'x.com/manifest.json',
        'javascript:alert(1)', 'file:///etc/passwd', 'data:text/html,hi',
        'ftp://x.com/a', 'https://localhost/m.json',
      ]) {
        expect(PairingServer.validateAddonUrl(bad), isNotNull, reason: bad);
      }
    });
  });

  group('Pairing session', () {
    test('the QR URL carries the token and an ephemeral port', () {
      expect(session.port, greaterThan(0));
      expect(session.url, contains('t=${session.token}'));
      expect(session.token.length, 32);
    });

    test('serves a self-contained form with the token embedded', () async {
      final res = await get('/?t=${session.token}');
      expect(res.statusCode, 200);
      final body = await utf8.decoder.bind(res).join();
      expect(body, contains('<form'));
      expect(body, contains(session.token));
      expect(body, contains('Send to TV'));
      // No external resources: the phone may have no internet route.
      expect(body.contains('src="http'), isFalse);
      expect(body.contains('href="http'), isFalse);
      expect(body, contains('provides no content and no sources'));
    });

    test('rejects a request with no token', () async {
      final res = await get('/');
      expect(res.statusCode, 403);
      await utf8.decoder.bind(res).join();
    });

    test('rejects a wrong token', () async {
      final res = await get('/?t=deadbeef');
      expect(res.statusCode, 403);
      await utf8.decoder.bind(res).join();
    });

    test('a valid submission is emitted and closes the session', () async {
      final received = session.submissions.first;
      final res = await post('/add', {
        't': session.token,
        'url': 'https://addon.example/manifest.json',
      });
      expect(res.statusCode, 200);
      expect(await utf8.decoder.bind(res).join(), contains('Sent to your TV'));
      expect(await received, 'https://addon.example/manifest.json');
      // Single use.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(session.isClosed, isTrue);
    });

    test('a submission without the token is refused and emits nothing', () async {
      var emitted = 0;
      final sub = session.submissions.listen((_) => emitted++);
      final res = await post('/add', {'url': 'https://evil.example/m.json'});
      expect(res.statusCode, 403);
      await utf8.decoder.bind(res).join();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(emitted, 0);
      expect(session.isClosed, isFalse);
      await sub.cancel();
    });

    test('an invalid URL is rejected with a readable error, session stays open',
        () async {
      final res = await post('/add', {'t': session.token, 'url': 'javascript:alert(1)'});
      expect(res.statusCode, 400);
      final body = await utf8.decoder.bind(res).join();
      expect(body, contains('Only http and https'));
      expect(session.isClosed, isFalse);
    });

    test('unknown paths return 404', () async {
      final res = await get('/nope?t=${session.token}');
      expect(res.statusCode, 404);
      await utf8.decoder.bind(res).join();
    });
  });

  test('the session expires on its own', () async {
    final short = await PairingServer.start(
      addressOverride: '127.0.0.1',
      timeout: const Duration(milliseconds: 120),
    );
    expect(short.isClosed, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(short.isClosed, isTrue);
  });

  test('two sessions get different tokens and ports', () async {
    final other = await PairingServer.start(addressOverride: '127.0.0.1');
    addTearDown(other.close);
    expect(other.token, isNot(session.token));
    expect(other.port, isNot(session.port));
  });
}
