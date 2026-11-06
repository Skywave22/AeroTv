import 'dart:convert';
import 'dart:typed_data';

import 'package:aero_core/aero_core.dart';
import 'package:dio/dio.dart';
import 'package:eco_js_runtime/eco_js_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.answers);

  /// url -> (status, body, headers)
  final Map<String, (int, String, Map<String, List<String>>)> answers;
  final requested = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requested.add(options);
    final a = answers[options.uri.toString()];
    if (a == null) return ResponseBody.fromString('', 404);
    return ResponseBody.fromString(a.$2, a.$1, headers: a.$3);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const sky = Ecosystem.skystream;
  const target = 'https://raw.githubusercontent.com/u/r/main/repo.json';

  late FakeAdapter adapter;
  late Dio dio;
  late List<String> guarded;
  late RepoLinkService service;

  void setup(Map<String, (int, String, Map<String, List<String>>)> answers,
      {Set<String> blocked = const {}}) {
    adapter = FakeAdapter(answers);
    dio = Dio()..httpClientAdapter = adapter;
    guarded = [];
    service = RepoLinkService(
      dio: dio,
      guard: (host) async {
        guarded.add(host);
        return blocked.contains(host) ? 'private address' : null;
      },
    );
  }

  group('resolving', () {
    test('a plain https URL passes through without a request', () async {
      setup({});
      final r = await service.resolve(target, ecosystem: sky);
      expect(r.url, target);
      expect(adapter.requested, isEmpty);
      expect(guarded, ['raw.githubusercontent.com']);
    });

    test('a shortcode resolves and reports the short link', () async {
      setup({
        'https://cutt.ly/sky-universe': (
          302,
          '',
          {'location': [target]}
        ),
      });
      final r = await service.resolve('universe', ecosystem: sky);
      expect(r.url, target);
      expect(r.shortLink, 'https://cutt.ly/sky-universe');
    });

    test('the shortener is asked with a browser User-Agent', () async {
      setup({
        'https://cutt.ly/sky-x': (302, '', {'location': [target]}),
      });
      await service.resolve('x', ecosystem: sky);
      expect(adapter.requested.single.headers['User-Agent'],
          contains('Mozilla/5.0'));
    });

    test('redirects are not followed by Dio — one hop is ours to control',
        () async {
      setup({
        'https://cutt.ly/sky-x': (302, '', {'location': [target]}),
      });
      await service.resolve('x', ecosystem: sky);
      expect(adapter.requested.single.followRedirects, isFalse);
    });

    test('a 200 meta-refresh page is understood', () async {
      setup({
        'https://cutt.ly/sky-x': (
          200,
          '<meta http-equiv="refresh" content="0;url=$target">',
          <String, List<String>>{}
        ),
      });
      expect((await service.resolve('x', ecosystem: sky)).url, target);
    });

    test('a missing code is reported as such', () async {
      setup({});
      await expectLater(
        service.resolve('nosuchcode', ecosystem: sky),
        throwsA(isA<ShortcodeException>()
            .having((e) => e.kind, 'kind', ShortcodeErrorKind.notFound)),
      );
    });
  });

  group('SSRF: the resolved address is what gets guarded', () {
    test('a code pointing at loopback is refused', () async {
      setup({
        'https://cutt.ly/sky-evil': (
          302,
          '',
          {'location': ['https://127.0.0.1/repo.json']}
        ),
      }, blocked: {'127.0.0.1'});
      await expectLater(
        service.resolve('evil', ecosystem: sky),
        throwsA(isA<ShortcodeException>().having(
            (e) => e.message, 'message', contains('not allowed'))),
      );
      expect(guarded, contains('127.0.0.1'),
          reason: 'the redirect target must be checked, not just the code');
    });

    test('a code pointing at a link-local address is refused', () async {
      setup({
        'https://cutt.ly/sky-meta': (
          302,
          '',
          {'location': ['https://169.254.169.254/latest/meta-data']}
        ),
      }, blocked: {'169.254.169.254'});
      await expectLater(
        service.resolve('meta', ecosystem: sky),
        throwsA(isA<ShortcodeException>()),
      );
    });

    test('a pasted short link on a blocked host never gets requested', () async {
      setup({}, blocked: {'cutt.ly'});
      await expectLater(
        service.resolve('https://cutt.ly/x', ecosystem: sky),
        throwsA(isA<ShortcodeException>()),
      );
      expect(adapter.requested, isEmpty,
          reason: 'the guard runs before the request, not after');
    });

    test('a plain http URL is refused: repo code must come over TLS', () async {
      setup({});
      // classify() upgrades http to https, so the user still gets a safe
      // fetch rather than a silent plaintext one.
      final r = await service.resolve('http://example.com/repo.json',
          ecosystem: sky);
      expect(r.url, 'https://example.com/repo.json');
      expect(guarded, ['example.com']);
    });
  });

  group('transport failures', () {
    test('a 429 surfaces as rate limiting', () async {
      setup({
        'https://cutt.ly/sky-x': (429, '', <String, List<String>>{}),
      });
      await expectLater(
        service.resolve('x', ecosystem: sky),
        throwsA(isA<ShortcodeException>()
            .having((e) => e.kind, 'kind', ShortcodeErrorKind.rateLimited)),
      );
    });

    test('a 500 is a service problem, not a missing code', () async {
      setup({
        'https://cutt.ly/sky-x': (500, '', <String, List<String>>{}),
      });
      await expectLater(
        service.resolve('x', ecosystem: sky),
        throwsA(isA<ShortcodeException>()
            .having((e) => e.kind, 'kind', ShortcodeErrorKind.unreachable)),
      );
    });

    test('a non-string body does not crash the extractor', () async {
      adapter = FakeAdapter({});
      dio = Dio()
        ..httpClientAdapter = _JsonAdapter(
            'https://cutt.ly/sky-x', jsonEncode({'unexpected': true}));
      service = RepoLinkService(dio: dio, guard: (_) async => null);
      await expectLater(
        service.resolve('x', ecosystem: sky),
        throwsA(isA<ShortcodeException>()),
      );
    });
  });
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.url, this.body);
  final String url;
  final String body;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (options.uri.toString() != url) return ResponseBody.fromString('', 404);
    return ResponseBody.fromBytes(utf8.encode(body), 200, headers: {
      'content-type': ['application/json']
    });
  }

  @override
  void close({bool force = false}) {}
}
