import 'package:aero_core/aero_core.dart';
import 'package:test/test.dart';

void main() {
  group('UrlRedactor.redact', () {
    test('masks secret query parameters', () {
      for (final k in ['token', 'api_key', 'apikey', 'password', 'access_token', 'sig']) {
        final out = UrlRedactor.redact('https://x.com/manifest.json?$k=supersecret');
        expect(out, contains('$k=REDACTED'), reason: k);
        expect(out, isNot(contains('supersecret')), reason: k);
      }
    });

    test('is case-insensitive about parameter names', () {
      expect(UrlRedactor.redact('https://x.com/m.json?API_KEY=abc'), contains('REDACTED'));
    });

    test('keeps non-secret query parameters', () {
      final out = UrlRedactor.redact('https://x.com/m.json?token=abc&genre=Action');
      expect(out, contains('genre=Action'));
      expect(out, isNot(contains('abc')));
    });

    test('masks an opaque token path segment', () {
      final out = UrlRedactor.redact(
          'https://addon.host/a1b2c3d4e5f6g7h8i9j0k1l2/manifest.json');
      expect(out, contains('/***/'));
      expect(out, isNot(contains('a1b2c3d4e5f6g7h8i9j0k1l2')));
      expect(out, endsWith('manifest.json'));
    });

    test('preserves ordinary path words and filenames', () {
      const url = 'https://x.com/catalog/movie/top.json';
      expect(UrlRedactor.redact(url), url);
      const words = 'https://x.com/internationalization/manifest.json';
      expect(UrlRedactor.redact(words), words, reason: 'no digits, so not a token');
    });

    test('masks userinfo credentials', () {
      final out = UrlRedactor.redact('https://user:hunter2@x.com/manifest.json');
      expect(out, isNot(contains('hunter2')));
      expect(out, contains('***'));
    });

    test('leaves a clean URL untouched', () {
      const url = 'https://cinemeta.strem.io/manifest.json';
      expect(UrlRedactor.redact(url), url);
    });

    test('returns non-URL input unchanged', () {
      expect(UrlRedactor.redact('not a url'), 'not a url');
      expect(UrlRedactor.redact(''), '');
    });
  });

  group('UrlRedactor.redactText', () {
    test('redacts URLs embedded in a message', () {
      final out = UrlRedactor.redactText(
          'GET https://x.com/m.json?token=leaked failed with 403');
      expect(out, isNot(contains('leaked')));
      expect(out, contains('failed with 403'));
    });

    test('handles several URLs in one line', () {
      final out = UrlRedactor.redactText(
          'a https://x.com/?token=one b https://y.com/?api_key=two');
      expect(out, isNot(contains('one')));
      expect(out, isNot(contains('two')));
    });

    test('leaves messages without URLs alone', () {
      expect(UrlRedactor.redactText('installed 3 plugins'), 'installed 3 plugins');
    });
  });

  group('AeroLog redacts at the choke point', () {
    setUp(() {
      AeroLog.instance.clear();
      AeroLog.instance.verbose = true;
    });
    tearDown(() {
      AeroLog.instance.clear();
      AeroLog.instance.verbose = false;
    });

    test('a logged message never contains the token', () {
      AeroLog.instance.i('stremio', 'fetch https://x.com/m.json?token=secret123');
      expect(AeroLog.instance.dump(), isNot(contains('secret123')));
    });

    test('a recorded network URI is redacted too', () {
      AeroLog.instance.network(
          'stremio', Uri.parse('https://x.com/m.json?api_key=secret456'));
      final entry = AeroLog.instance.entries.last;
      expect(entry.uri.toString(), isNot(contains('secret456')));
      expect(AeroLog.instance.dump(), isNot(contains('secret456')));
    });

    test('error entries are redacted', () {
      AeroLog.instance.e('stremio', 'HTTP 403 https://x.com/?token=secret789');
      expect(AeroLog.instance.dump(), isNot(contains('secret789')));
    });
  });
}
