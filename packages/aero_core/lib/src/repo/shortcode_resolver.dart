/// Resolves a repository the user typed: a URL, a bare host, a custom scheme,
/// or a shortcode.
///
/// Contract verified against SkyStream's `RepositoryService` and
/// `CloudstreamRepository.resolveUrl`; see docs/specs/shortcodes.md. Aero ships
/// no codes and no default repositories — this only resolves what the user
/// enters.
///
/// Transport is injected so the whole state machine is testable without a
/// network, and so the caller can put the SSRF guard in front of it.
library;

import '../models/ecosystem.dart';

/// What the user's input turned out to be.
enum RepoInputKind { url, customScheme, bareHost, shortcode, invalid }

class RepoInput {
  const RepoInput(this.kind, this.value);
  final RepoInputKind kind;

  /// For [RepoInputKind.url]/[RepoInputKind.bareHost] the normalised https
  /// address; for [RepoInputKind.shortcode] the code as typed.
  final String value;
}

/// One shortener's answer, with redirects left unfollowed.
class ShortLinkAnswer {
  const ShortLinkAnswer({required this.status, this.location, this.body = ''});
  final int status;
  final String? location;
  final String body;
}

typedef ShortLinkFetch = Future<ShortLinkAnswer> Function(String url);

enum ShortcodeErrorKind { empty, invalidFormat, notFound, rateLimited, unreachable }

class ShortcodeException implements Exception {
  ShortcodeException(this.kind, this.message);
  final ShortcodeErrorKind kind;
  final String message;

  /// A missing code and an unreachable service are different problems, and
  /// only one of them is worth retrying.
  bool get isRetryable =>
      kind == ShortcodeErrorKind.rateLimited ||
      kind == ShortcodeErrorKind.unreachable;

  @override
  String toString() => message;
}

/// The resolved address, plus the short link a code was found at.
class ResolvedRepo {
  const ResolvedRepo({required this.url, this.shortLink});
  final String url;
  final String? shortLink;

  bool get cameFromCode => shortLink != null;
}

class ShortcodeResolver {
  ShortcodeResolver(this._fetch);

  final ShortLinkFetch _fetch;

  /// Hosts that shorten repository links. A pasted link on one of these is
  /// followed exactly as a code is.
  static const shorteners = {'cutt.ly', 'py.md'};

  static final _codeShape = RegExp(r'^[a-zA-Z0-9!_-]+$');
  static final _bareHostShape = RegExp(r'^[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)+');
  static final _httpShape = RegExp(r'^https?://');

  /// Ecosystems with a verified shortcode namespace. Others are added by URL:
  /// inventing a lookup for them would resolve to a stranger's link.
  static bool supportsShortcodes(Ecosystem eco) =>
      eco == Ecosystem.skystream || eco == Ecosystem.cloudstream;

  /// Classifies input without touching the network.
  static RepoInput classify(String raw, {Ecosystem? ecosystem}) {
    final text = raw.trim();
    if (text.isEmpty) return const RepoInput(RepoInputKind.invalid, '');

    // Share links are checked BEFORE the plain-scheme branch: a
    // `https://cs.repo/?<url>` link is itself https, so testing the scheme
    // first would treat the wrapper as the repository address.
    final cs = RegExp(r'^(cloudstreamrepo://|https://cs\.repo/\??)')
        .firstMatch(text);
    if (cs != null) {
      final rest = text.substring(cs.end);
      return RepoInput(RepoInputKind.customScheme,
          _secure(_httpShape.hasMatch(rest) ? rest : 'https://$rest'));
    }
    final sky = RegExp(r'^skystream://').firstMatch(text);
    if (sky != null) {
      return RepoInput(
          RepoInputKind.customScheme, _secure('https://${text.substring(sky.end)}'));
    }

    if (_httpShape.hasMatch(text)) {
      return RepoInput(RepoInputKind.url, _secure(text));
    }

    if (_bareHostShape.hasMatch(text) && !text.contains(' ')) {
      return RepoInput(RepoInputKind.bareHost, _secure('https://$text'));
    }

    if (_codeShape.hasMatch(text)) {
      if (ecosystem != null && !supportsShortcodes(ecosystem)) {
        return const RepoInput(RepoInputKind.invalid, '');
      }
      return RepoInput(RepoInputKind.shortcode, text);
    }

    return const RepoInput(RepoInputKind.invalid, '');
  }

  /// Short-link spellings to try, in order. Codes are case-sensitive, but a TV
  /// keyboard may capitalise the first letter, so each is tried as typed and
  /// then lowercased.
  static List<String> candidates(String code, {required Ecosystem ecosystem}) {
    final lower = code.toLowerCase();
    if (ecosystem == Ecosystem.cloudstream) {
      // `!CODE` selects py.md; anything else cutt.ly. No namespace.
      String at(String c) => c.startsWith('!')
          ? 'https://py.md/${c.substring(1)}'
          : 'https://cutt.ly/$c';
      return {at(code), if (lower != code) at(lower)}.toList();
    }
    // SkyStream: the namespaced form first, then the bare form. A bare
    // cutt.ly/Universe belongs to whoever registered it.
    return {
      'https://cutt.ly/sky-$code',
      'https://cutt.ly/sky-$lower',
      'https://cutt.ly/$code',
      'https://cutt.ly/$lower',
    }.toList();
  }

  /// Resolves any accepted input to an https address.
  Future<ResolvedRepo> resolve(String raw, {required Ecosystem ecosystem}) async {
    if (raw.trim().isEmpty) {
      throw ShortcodeException(
          ShortcodeErrorKind.empty, 'Enter a repository URL or code');
    }
    final input = classify(raw, ecosystem: ecosystem);
    switch (input.kind) {
      case RepoInputKind.invalid:
        throw ShortcodeException(
            ShortcodeErrorKind.invalidFormat,
            supportsShortcodes(ecosystem)
                ? 'Invalid URL format'
                : 'Enter a repository URL — ${ecosystem.displayName} '
                    'repositories are not added by shortcode');
      case RepoInputKind.customScheme:
      case RepoInputKind.bareHost:
        return ResolvedRepo(url: input.value);
      case RepoInputKind.url:
        final host = Uri.tryParse(input.value)?.host ?? '';
        if (!shorteners.contains(host)) return ResolvedRepo(url: input.value);
        // A pasted short link is followed one hop, like a code.
        final found = await _tryCandidates([input.value]);
        return ResolvedRepo(url: found.url);
      case RepoInputKind.shortcode:
        final found =
            await _tryCandidates(candidates(input.value, ecosystem: ecosystem));
        return ResolvedRepo(url: found.url, shortLink: found.shortLink);
    }
  }

  Future<({String url, String shortLink})> _tryCandidates(
      List<String> links) async {
    Object? lastError;
    var sawTransportError = false;
    for (final candidate in links) {
      try {
        final target = await followOne(candidate);
        if (target != null) return (url: target, shortLink: candidate);
      } on ShortcodeException catch (e) {
        lastError = e;
        if (e.isRetryable) sawTransportError = true;
      }
    }
    if (sawTransportError && lastError is ShortcodeException) {
      throw ShortcodeException(lastError.kind,
          'Could not reach the shortcode service: ${lastError.message}');
    }
    throw ShortcodeException(
        ShortcodeErrorKind.notFound, "That shortcode doesn't exist");
  }

  /// Follows exactly one hop. Handles a redirect header and the increasingly
  /// common "200 + meta refresh / window.location" page.
  Future<String?> followOne(String shortUrl) async {
    final ShortLinkAnswer answer;
    try {
      answer = await _fetch(shortUrl);
    } on ShortcodeException {
      rethrow;
    } catch (e) {
      throw ShortcodeException(
          ShortcodeErrorKind.unreachable, e.toString());
    }

    final status = answer.status;
    if (status >= 300 && status < 400) {
      final loc = answer.location;
      return loc == null ? null : followable(shortUrl, loc);
    }
    if (status == 404 || status == 410) return null;
    if (status == 429) {
      throw ShortcodeException(ShortcodeErrorKind.rateLimited,
          'too many lookups, try again in a minute');
    }
    if (status >= 400) {
      throw ShortcodeException(
          ShortcodeErrorKind.unreachable, 'it answered $status');
    }
    return extractTarget(shortUrl, answer.body);
  }

  static final _metaRefresh = RegExp(
    r'<meta[^>]+http-equiv=["]?refresh["]?[^>]+content=["][^"]*url=([^">\s]+)',
    caseSensitive: false,
  );
  static final _jsDouble = RegExp(
    r'(?:window\.)?location(?:\.href)?\s*=\s*["]([^"]+)["]',
    caseSensitive: false,
  );
  static final _jsSingle = RegExp(
    r"(?:window\.)?location(?:\.href)?\s*=\s*'([^']+)'",
    caseSensitive: false,
  );

  /// Pulls a target out of a 200 page, or null when the page is a dead end.
  static String? extractTarget(String shortUrl, String body) {
    if (body.isEmpty) return null;
    for (final re in [_metaRefresh, _jsDouble, _jsSingle]) {
      final m = re.firstMatch(body);
      if (m == null) continue;
      final target = followable(shortUrl, unescapeHtml(m.group(1)!));
      if (target != null) return target;
    }
    return null;
  }

  /// Where a target found in [shortUrl]'s answer leads.
  ///
  /// Resolved against the short URL (it may be relative), forced to https,
  /// and rejected when it is not a web address, is the short link's own page
  /// again, or is a known dead end.
  static String? followable(String shortUrl, String target) {
    final trimmed = target.trim();
    if (trimmed.isEmpty) return null;
    final Uri link;
    final Uri resolved;
    try {
      link = Uri.parse(shortUrl);
      resolved = link.resolve(trimmed);
    } on FormatException {
      return null;
    }
    if (resolved.scheme != 'https' && resolved.scheme != 'http') return null;
    if (resolved.host.isEmpty) return null;
    // Only the query or fragment changed: that is not where a code leads.
    if (resolved.host == link.host && resolved.path == link.path) return null;
    final address = _secure(resolved.toString());
    return isDeadEnd(address) ? null : address;
  }

  static bool isDeadEnd(String location) {
    final trimmed = location.replaceAll(RegExp(r'/$'), '').trim();
    return trimmed.isEmpty ||
        trimmed.startsWith('https://cutt.ly/404') ||
        trimmed == 'https://cutt.ly' ||
        trimmed.startsWith('https://py.md/404') ||
        trimmed == 'https://py.md';
  }

  static String unescapeHtml(String value) => value
      .replaceAll('&amp;', '&')
      .replaceAll('&#39;', "'")
      .replaceAll('&quot;', '"')
      .trim();

  /// A repository address decides which code the app downloads and runs, so
  /// plain HTTP would let anyone on the network swap it.
  static String _secure(String url) =>
      url.startsWith('http://') ? 'https://${url.substring(7)}' : url;
}
