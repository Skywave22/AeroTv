import 'package:aero_core/aero_core.dart';
import 'package:test/test.dart';

/// A shortener that answers from a script, so every branch of the one-hop
/// state machine can be exercised without a network.
class FakeShortener {
  FakeShortener(this.answers);

  final Map<String, Object> answers;
  final requested = <String>[];

  Future<ShortLinkAnswer> call(String url) async {
    requested.add(url);
    final a = answers[url];
    if (a == null) return const ShortLinkAnswer(status: 404);
    if (a is ShortLinkAnswer) return a;
    if (a is Exception) throw a;
    throw StateError('bad fixture');
  }
}

ShortLinkAnswer redirect(String to) =>
    ShortLinkAnswer(status: 302, location: to);
ShortLinkAnswer page(String body) => ShortLinkAnswer(status: 200, body: body);

void main() {
  const sky = Ecosystem.skystream;
  const cs = Ecosystem.cloudstream;

  group('classify', () {
    const cases = <String, RepoInputKind>{
      'https://example.com/repo.json': RepoInputKind.url,
      'http://example.com/repo.json': RepoInputKind.url,
      'raw.githubusercontent.com/u/r/main/repo.json': RepoInputKind.bareHost,
      'github.com/user/repo': RepoInputKind.bareHost,
      'skystream://example.com/repo.json': RepoInputKind.customScheme,
      'cloudstreamrepo://example.com/repo.json': RepoInputKind.customScheme,
      'https://cs.repo/?https://example.com/repo.json': RepoInputKind.customScheme,
      'universe': RepoInputKind.shortcode,
      'my-repo_2': RepoInputKind.shortcode,
      '!somecode': RepoInputKind.shortcode,
      'not a url at all': RepoInputKind.invalid,
      '': RepoInputKind.invalid,
    };
    cases.forEach((input, kind) {
      test('"$input" -> ${kind.name}', () {
        expect(ShortcodeResolver.classify(input, ecosystem: sky).kind, kind);
      });
    });

    test('http is upgraded to https: a repo address decides what code runs', () {
      expect(
          ShortcodeResolver.classify('http://example.com/repo.json',
                  ecosystem: sky)
              .value,
          'https://example.com/repo.json');
    });

    test('a custom scheme without a scheme in its payload gets https', () {
      expect(
          ShortcodeResolver.classify('cloudstreamrepo://example.com/r.json',
                  ecosystem: cs)
              .value,
          'https://example.com/r.json');
    });

    test('cs.repo keeps an explicit scheme in its payload', () {
      expect(
          ShortcodeResolver.classify(
                  'https://cs.repo/?https://example.com/r.json',
                  ecosystem: cs)
              .value,
          'https://example.com/r.json');
    });

    test('only verified ecosystems accept a bare code', () {
      for (final eco in [Ecosystem.vega, Ecosystem.nuvio, Ecosystem.stremio]) {
        expect(ShortcodeResolver.supportsShortcodes(eco), isFalse);
        expect(ShortcodeResolver.classify('universe', ecosystem: eco).kind,
            RepoInputKind.invalid,
            reason: 'inventing a lookup would resolve to a stranger\'s link');
      }
      expect(ShortcodeResolver.supportsShortcodes(sky), isTrue);
      expect(ShortcodeResolver.supportsShortcodes(cs), isTrue);
    });

    test('a URL still works for an ecosystem without shortcodes', () {
      expect(
          ShortcodeResolver.classify('https://example.com/manifest.json',
                  ecosystem: Ecosystem.nuvio)
              .kind,
          RepoInputKind.url);
    });
  });

  group('candidate order', () {
    test('SkyStream tries the namespace before the bare code', () {
      expect(ShortcodeResolver.candidates('Universe', ecosystem: sky), [
        'https://cutt.ly/sky-Universe',
        'https://cutt.ly/sky-universe',
        'https://cutt.ly/Universe',
        'https://cutt.ly/universe',
      ]);
    });

    test('an already-lowercase code is not tried twice', () {
      expect(ShortcodeResolver.candidates('universe', ecosystem: sky), [
        'https://cutt.ly/sky-universe',
        'https://cutt.ly/universe',
      ]);
    });

    test('CloudStream has no namespace', () {
      expect(ShortcodeResolver.candidates('Code', ecosystem: cs),
          ['https://cutt.ly/Code', 'https://cutt.ly/code']);
    });

    test('a leading ! selects py.md for CloudStream', () {
      expect(ShortcodeResolver.candidates('!Code', ecosystem: cs),
          ['https://py.md/Code', 'https://py.md/code']);
    });
  });

  group('resolving a code', () {
    test('the first spelling that answers wins', () async {
      final f = FakeShortener({
        'https://cutt.ly/sky-universe':
            redirect('https://raw.githubusercontent.com/u/r/main/repo.json'),
      });
      final r = await ShortcodeResolver(f.call).resolve('universe', ecosystem: sky);
      expect(r.url, 'https://raw.githubusercontent.com/u/r/main/repo.json');
      expect(r.shortLink, 'https://cutt.ly/sky-universe');
      expect(r.cameFromCode, isTrue);
      expect(f.requested, ['https://cutt.ly/sky-universe']);
    });

    test('a capitalised code falls through to the lowercase spelling', () async {
      final f = FakeShortener({
        'https://cutt.ly/sky-universe': redirect('https://example.com/r.json'),
      });
      final r = await ShortcodeResolver(f.call).resolve('Universe', ecosystem: sky);
      expect(r.url, 'https://example.com/r.json');
      expect(f.requested.first, 'https://cutt.ly/sky-Universe');
      expect(f.requested, contains('https://cutt.ly/sky-universe'));
    });

    test('the bare form is reached when the namespace does not exist', () async {
      final f = FakeShortener({
        'https://cutt.ly/universe': redirect('https://example.com/r.json'),
      });
      final r = await ShortcodeResolver(f.call).resolve('universe', ecosystem: sky);
      expect(r.shortLink, 'https://cutt.ly/universe');
      expect(f.requested.length, 2);
    });

    test('no spelling answers -> that code does not exist', () async {
      final f = FakeShortener({});
      await expectLater(
        ShortcodeResolver(f.call).resolve('nope', ecosystem: sky),
        throwsA(isA<ShortcodeException>()
            .having((e) => e.kind, 'kind', ShortcodeErrorKind.notFound)
            .having((e) => e.isRetryable, 'retryable', isFalse)),
      );
    });

    test('empty input asks for a URL or code', () async {
      final f = FakeShortener({});
      await expectLater(
        ShortcodeResolver(f.call).resolve('   ', ecosystem: sky),
        throwsA(isA<ShortcodeException>()
            .having((e) => e.kind, 'kind', ShortcodeErrorKind.empty)),
      );
      expect(f.requested, isEmpty);
    });

    test('an unsupported ecosystem explains itself instead of looking up', () async {
      final f = FakeShortener({});
      await expectLater(
        ShortcodeResolver(f.call).resolve('universe', ecosystem: Ecosystem.vega),
        throwsA(isA<ShortcodeException>().having(
            (e) => e.message, 'message', contains('not added by shortcode'))),
      );
      expect(f.requested, isEmpty);
    });
  });

  group('one hop', () {
    test('a 302 Location is the target', () async {
      final f = FakeShortener({
        'https://cutt.ly/sky-x': redirect('https://example.com/repo.json'),
      });
      expect((await ShortcodeResolver(f.call).resolve('x', ecosystem: sky)).url,
          'https://example.com/repo.json');
    });

    test('a 200 meta refresh is followed', () async {
      final f = FakeShortener({
        'https://cutt.ly/sky-x': page(
            '<html><head><meta http-equiv="refresh" '
            'content="0;url=https://example.com/repo.json"></head></html>'),
      });
      expect((await ShortcodeResolver(f.call).resolve('x', ecosystem: sky)).url,
          'https://example.com/repo.json');
    });

    test('a 200 window.location is followed, both quote styles', () async {
      for (final body in [
        '<script>window.location.href = "https://example.com/r.json";</script>',
        "<script>location = 'https://example.com/r.json';</script>",
        '<script>window.location="https://example.com/r.json"</script>',
      ]) {
        final f = FakeShortener({'https://cutt.ly/sky-x': page(body)});
        expect(
            (await ShortcodeResolver(f.call).resolve('x', ecosystem: sky)).url,
            'https://example.com/r.json',
            reason: body);
      }
    });

    test('HTML entities in the target are unescaped', () async {
      final f = FakeShortener({
        'https://cutt.ly/sky-x': page(
            '<meta http-equiv="refresh" content="0;url='
            'https://example.com/r.json?a=1&amp;b=2">'),
      });
      expect((await ShortcodeResolver(f.call).resolve('x', ecosystem: sky)).url,
          'https://example.com/r.json?a=1&b=2');
    });

    test('a relative target is resolved against the short link', () async {
      final f = FakeShortener({
        'https://cutt.ly/sky-x': redirect('/dest/repo.json'),
      });
      expect((await ShortcodeResolver(f.call).resolve('x', ecosystem: sky)).url,
          'https://cutt.ly/dest/repo.json');
    });

    test('an http target is upgraded to https', () async {
      final f = FakeShortener({
        'https://cutt.ly/sky-x': redirect('http://example.com/r.json'),
      });
      expect((await ShortcodeResolver(f.call).resolve('x', ecosystem: sky)).url,
          'https://example.com/r.json');
    });

    test('429 is rate limiting, not a missing code', () async {
      final f = FakeShortener({
        'https://cutt.ly/sky-x': const ShortLinkAnswer(status: 429),
      });
      await expectLater(
        ShortcodeResolver(f.call).resolve('x', ecosystem: sky),
        throwsA(isA<ShortcodeException>()
            .having((e) => e.kind, 'kind', ShortcodeErrorKind.rateLimited)
            .having((e) => e.isRetryable, 'retryable', isTrue)
            .having((e) => e.message, 'message', contains('try again'))),
      );
    });

    test('a transport failure is unreachable, not a missing code', () async {
      final f = FakeShortener({
        'https://cutt.ly/sky-x': Exception('SocketException: no route'),
      });
      await expectLater(
        ShortcodeResolver(f.call).resolve('x', ecosystem: sky),
        throwsA(isA<ShortcodeException>()
            .having((e) => e.kind, 'kind', ShortcodeErrorKind.unreachable)
            .having((e) => e.message, 'message',
                contains('Could not reach the shortcode service'))),
      );
    });

    test('410 is a missing code', () async {
      final f = FakeShortener({
        'https://cutt.ly/sky-x': const ShortLinkAnswer(status: 410),
      });
      await expectLater(
        ShortcodeResolver(f.call).resolve('x', ecosystem: sky),
        throwsA(isA<ShortcodeException>()
            .having((e) => e.kind, 'kind', ShortcodeErrorKind.notFound)),
      );
    });

    test('only one hop is followed, never a chain', () async {
      final f = FakeShortener({
        'https://cutt.ly/sky-x': redirect('https://cutt.ly/second'),
        'https://cutt.ly/second': redirect('https://example.com/final.json'),
      });
      final r = await ShortcodeResolver(f.call).resolve('x', ecosystem: sky);
      expect(r.url, 'https://cutt.ly/second',
          reason: 'the second shortener link is returned, not chased');
      expect(f.requested, ['https://cutt.ly/sky-x']);
    });
  });

  group('target validation', () {
    const short = 'https://cutt.ly/sky-x';
    test('dead ends are rejected', () {
      for (final dead in [
        'https://cutt.ly/404',
        'https://cutt.ly/404?page=1',
        'https://cutt.ly',
        'https://cutt.ly/',
        'https://py.md/404',
        'https://py.md',
      ]) {
        expect(ShortcodeResolver.isDeadEnd(dead), isTrue, reason: dead);
      }
      expect(ShortcodeResolver.isDeadEnd('https://example.com/r.json'), isFalse);
    });

    test('the short link\'s own page is not a target', () {
      expect(ShortcodeResolver.followable(short, '$short?utm=1'), isNull);
      expect(ShortcodeResolver.followable(short, '$short#frag'), isNull);
    });

    test('non-web schemes are rejected', () {
      for (final bad in [
        'javascript:alert(1)',
        'file:///etc/passwd',
        'data:text/html,hi',
        'ftp://example.com/r.json',
      ]) {
        expect(ShortcodeResolver.followable(short, bad), isNull, reason: bad);
      }
    });

    test('a scheme with no host is rejected', () {
      expect(ShortcodeResolver.followable(short, 'http:foo'), isNull);
    });

    test('an empty target is rejected', () {
      expect(ShortcodeResolver.followable(short, '   '), isNull);
    });

    test('a loopback target is still returned here — the SSRF guard owns that',
        () {
      // The resolver's job is shape; IpGuard decides reachability. Keeping the
      // separation means the guard cannot be bypassed by a code that resolves
      // to a private address, because every resolved URL goes through it.
      expect(ShortcodeResolver.followable(short, 'https://127.0.0.1/r.json'),
          'https://127.0.0.1/r.json');
    });

    test('a page with nothing recognisable is a dead end', () {
      expect(
          ShortcodeResolver.extractTarget(short, '<html>nothing here</html>'),
          isNull);
      expect(ShortcodeResolver.extractTarget(short, ''), isNull);
    });
  });

  group('pasted links', () {
    test('a plain URL is returned untouched and never fetched', () async {
      final f = FakeShortener({});
      final r = await ShortcodeResolver(f.call)
          .resolve('https://example.com/repo.json', ecosystem: sky);
      expect(r.url, 'https://example.com/repo.json');
      expect(r.cameFromCode, isFalse);
      expect(f.requested, isEmpty);
    });

    test('a pasted cutt.ly link is followed one hop', () async {
      final f = FakeShortener({
        'https://cutt.ly/kaisen-repo': redirect('https://example.com/repo.json'),
      });
      final r = await ShortcodeResolver(f.call)
          .resolve('https://cutt.ly/kaisen-repo', ecosystem: sky);
      expect(r.url, 'https://example.com/repo.json');
      expect(f.requested, ['https://cutt.ly/kaisen-repo']);
    });

    test('a bare host is normalised without a lookup', () async {
      final f = FakeShortener({});
      final r = await ShortcodeResolver(f.call).resolve(
          'raw.githubusercontent.com/u/r/main/repo.json',
          ecosystem: sky);
      expect(r.url, 'https://raw.githubusercontent.com/u/r/main/repo.json');
      expect(f.requested, isEmpty);
    });
  });
}
