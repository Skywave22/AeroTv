import 'package:aero_core/aero_core.dart';
import 'package:dio/dio.dart';

import 'ip_guard.dart';

/// Resolves what the user typed into the "Add repository" box, then makes sure
/// the address it resolved to is one we are willing to fetch.
///
/// Two untrusted steps in a row: a shortcode is a redirect controlled by
/// whoever registered it, and the repository it points at is code the app will
/// run. So the SSRF guard is applied to the *resolved* address, not just the
/// text in the box — otherwise `cutt.ly/evil` pointing at `127.0.0.1` would
/// walk straight past it.
class RepoLinkService {
  RepoLinkService({Dio? dio, IpGuardCheck? guard})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            )),
        _guard = guard ?? _defaultGuard;

  final Dio _dio;
  final IpGuardCheck _guard;

  /// Injectable so tests do not perform real DNS.
  static Future<String?> _defaultGuard(String host) =>
      IpGuard.checkResolved(host);

  /// The shorteners answer a different page to a bare HTTP client, so a
  /// desktop browser User-Agent is part of the contract, not a nicety.
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  /// Resolves and validates. Throws [ShortcodeException] with a message that
  /// is safe to show the user.
  Future<ResolvedRepo> resolve(String input,
      {required Ecosystem ecosystem}) async {
    final resolver = ShortcodeResolver(_fetchGuarded);
    final resolved = await resolver.resolve(input, ecosystem: ecosystem);
    await _ensureAllowed(resolved.url);
    return resolved;
  }

  /// One shortener hop, guarded before the request goes out.
  Future<ShortLinkAnswer> _fetchGuarded(String url) async {
    await _ensureAllowed(url);
    final Response<dynamic> res;
    try {
      res = await _dio.get<dynamic>(
        url,
        options: Options(
          followRedirects: false,
          responseType: ResponseType.plain,
          validateStatus: (s) => s != null && s < 500,
          headers: const {'User-Agent': _userAgent},
        ),
      );
    } on DioException catch (e) {
      throw ShortcodeException(
          ShortcodeErrorKind.unreachable, e.message ?? 'request failed');
    }
    return ShortLinkAnswer(
      status: res.statusCode ?? 0,
      location: res.headers.value('location'),
      body: res.data is String ? res.data as String : '',
    );
  }

  Future<void> _ensureAllowed(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw ShortcodeException(
          ShortcodeErrorKind.invalidFormat, 'Invalid URL format');
    }
    if (uri.scheme != 'https') {
      throw ShortcodeException(ShortcodeErrorKind.invalidFormat,
          'Repositories must be served over HTTPS');
    }
    final blocked = await _guard(uri.host);
    if (blocked != null) {
      throw ShortcodeException(ShortcodeErrorKind.invalidFormat,
          'That address is not allowed: $blocked');
    }
  }
}

/// Returns a reason when [host] must not be contacted, or null when it may.
typedef IpGuardCheck = Future<String?> Function(String host);
