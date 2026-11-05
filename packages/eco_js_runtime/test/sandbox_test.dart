import 'package:eco_js_runtime/eco_js_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JsSandboxPolicy.validateUrl', () {
    const policy = JsSandboxPolicy();

    test('allows normal public https/http URLs', () {
      expect(policy.validateUrl('https://example.com/api'), isNull);
      expect(policy.validateUrl('http://example.com/api'), isNull);
      expect(policy.validateUrl('https://cdn.provider.tv/v.m3u8?x=1'), isNull);
    });

    test('blocks localhost and loopback (SSRF)', () {
      expect(policy.validateUrl('http://localhost:8080/admin'), isNotNull);
      expect(policy.validateUrl('http://127.0.0.1/'), isNotNull);
      expect(policy.validateUrl('http://0.0.0.0/'), isNotNull);
      expect(policy.validateUrl('http://[::1]/'), isNotNull);
    });

    test('blocks cloud metadata endpoint', () {
      expect(policy.validateUrl('http://169.254.169.254/latest/meta-data/'), isNotNull);
    });

    test('blocks private LAN ranges', () {
      expect(policy.validateUrl('http://192.168.1.1/router'), isNotNull);
      expect(policy.validateUrl('http://10.0.0.5/'), isNotNull);
    });

    test('blocks .local and .internal hostnames', () {
      expect(policy.validateUrl('http://printer.local/'), isNotNull);
      expect(policy.validateUrl('https://db.internal/'), isNotNull);
    });

    test('blocks non-http schemes', () {
      expect(policy.validateUrl('file:///etc/passwd'), isNotNull);
      expect(policy.validateUrl('content://media/1'), isNotNull);
      expect(policy.validateUrl('ftp://x.com/f'), isNotNull);
      expect(policy.validateUrl('javascript:alert(1)'), isNotNull);
    });

    test('rejects malformed URLs', () {
      expect(policy.validateUrl('not a url'), isNotNull);
      expect(policy.validateUrl(''), isNotNull);
      expect(policy.validateUrl('https://'), isNotNull);
    });

    test('can enforce https-only', () {
      const strict = JsSandboxPolicy(allowInsecureHttp: false);
      expect(strict.validateUrl('http://example.com'), isNotNull);
      expect(strict.validateUrl('https://example.com'), isNull);
    });

    test('does not over-block a host that merely contains a blocked name', () {
      expect(policy.validateUrl('https://notlocalhost.com/'), isNull);
      expect(policy.validateUrl('https://my-localhost.net/'), isNull);
    });
  });

  group('JsPluginBundle', () {
    test('hash is stable and pin verification works', () {
      const code = 'function getPosts(){return []}';
      final hash = JsPluginBundle.hashOf(code);
      expect(hash.length, 64);
      expect(JsPluginBundle.hashOf(code), hash);
      expect(JsPluginBundle.hashOf('$code '), isNot(hash));

      final bundle = JsPluginBundle(
        sourceUrl: 'https://x/p.js',
        code: code,
        manifest: const {'id': 'p', 'name': 'P', 'version': '1.0.0'},
        sha256: hash,
      );
      expect(bundle.matchesPin(hash), isTrue);
      expect(bundle.matchesPin(hash.toUpperCase()), isTrue);
      expect(bundle.matchesPin('deadbeef'), isFalse);
      expect(bundle.matchesPin(null), isTrue, reason: 'no pin means no check');
      expect(bundle.id, 'p');
      expect(bundle.name, 'P');
      expect(bundle.version, '1.0.0');
    });

    test('falls back to URL for id when manifest is empty', () {
      final bundle = JsPluginBundle(
        sourceUrl: 'https://x/p.js',
        code: '',
        manifest: const {},
        sha256: '',
      );
      expect(bundle.id, 'https://x/p.js');
      expect(bundle.version, '0.0.0');
    });

    test('round-trips through JSON', () {
      final bundle = JsPluginBundle(
        sourceUrl: 'https://x/p.js',
        code: 'var a=1;',
        manifest: const {'id': 'p'},
        sha256: 'abc',
        fetchedAt: DateTime.utc(2026, 1, 1),
      );
      final back = JsPluginBundle.fromJson(bundle.toJson());
      expect(back.code, bundle.code);
      expect(back.sha256, 'abc');
      expect(back.fetchedAt, DateTime.utc(2026, 1, 1));
    });
  });

  group('HostApiShim', () {
    test('injects the bridge and denies dangerous globals', () {
      final js = HostApiShim.full();
      expect(js, contains('__aeroSend'));
      expect(js, contains('global.fetch'));
      expect(js, contains('global.axios'));
      expect(js, contains('global.XMLHttpRequest = undefined'));
      expect(js, contains('global.WebSocket = undefined'));
      expect(js, contains('global.eval = undefined'));
      expect(js, contains('setInterval is not available'));
    });

    test('can omit the HTML parser', () {
      final js = HostApiShim.full(includeHtmlParser: false);
      expect(js, contains('__aeroSend'));
      expect(js, isNot(contains('global.cheerio')));
    });
  });
}
