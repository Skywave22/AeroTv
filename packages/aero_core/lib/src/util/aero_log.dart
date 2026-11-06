/// Redacts credentials from URLs before they reach the log or the UI.
///
/// Stremio add-on URLs routinely embed a user token in the path
/// (`https://host/<token>/manifest.json`) or in the query (`?api_key=...`).
/// Logs are exportable and shown on screen, so those must never leak.
abstract final class UrlRedactor {
  /// Query parameters whose values are secrets.
  static const _secretKeys = {
    'token', 'api_key', 'apikey', 'key', 'auth', 'authorization',
    'password', 'pass', 'secret', 'access_token', 'refresh_token', 'sig',
    'signature', 'session', 'sessionid', 'credential', 'credentials',
  };

  /// Path segments that look like an opaque credential.
  static final _opaqueSegment = RegExp(r'^[A-Za-z0-9_\-]{20,}$');

  /// Returns a copy of [url] safe to display or log.
  static String redact(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return url;

    var changed = false;
    var userInfo = uri.userInfo;
    if (userInfo.isNotEmpty) {
      userInfo = '***';
      changed = true;
    }

    Map<String, String>? query;
    if (uri.hasQuery) {
      query = {};
      uri.queryParameters.forEach((k, v) {
        if (_secretKeys.contains(k.toLowerCase())) {
          query![k] = 'REDACTED';
          changed = true;
        } else {
          query![k] = v;
        }
      });
    }

    final segments = uri.pathSegments.map((seg) {
      // Keep filenames and short slugs; mask long opaque tokens.
      if (seg.contains('.')) return seg;
      if (_opaqueSegment.hasMatch(seg) && _hasDigitAndLetter(seg)) {
        changed = true;
        return '***';
      }
      return seg;
    }).toList();

    if (!changed) return url;
    return uri
        .replace(
          userInfo: userInfo.isEmpty ? null : userInfo,
          pathSegments: segments,
          queryParameters: query,
        )
        .toString();
  }

  /// A long segment is only treated as a credential if it mixes digits and
  /// letters, so ordinary long words in a path are preserved.
  static bool _hasDigitAndLetter(String s) =>
      s.contains(RegExp(r'[0-9]')) && s.contains(RegExp(r'[A-Za-z]'));

  /// Redacts every URL-looking substring inside a free-text message.
  static String redactText(String text) => text.replaceAllMapped(
        RegExp(r'https?://[^\s"'"'"'<>]+'),
        (m) => redact(m.group(0)!),
      );
}

/// Log severity levels for the in-app log viewer.
enum LogLevel { debug, info, warn, error }

/// One structured log entry. Plugin network destinations are logged here so
/// the debug panel can show exactly where untrusted code is calling out to.
class LogEntry {
  LogEntry({
    required this.level,
    required this.tag,
    required this.message,
    DateTime? at,
    this.uri,
  }) : at = at ?? DateTime.now();

  final LogLevel level;
  final String tag;
  final String message;
  final DateTime at;
  final Uri? uri;

  @override
  String toString() {
    final t = at.toIso8601String().substring(11, 23);
    return '[$t] ${level.name.toUpperCase().padRight(5)} $tag: $message';
  }
}

/// Ring-buffer logger. Deliberately dependency-free and synchronous so it can
/// be used from pure-Dart packages and from isolates via plain maps.
class AeroLog {
  AeroLog._();

  static final AeroLog instance = AeroLog._();

  final List<LogEntry> _entries = [];
  final List<void Function(LogEntry)> _listeners = [];

  /// Cap memory use on low-end TV boxes.
  int maxEntries = 500;

  /// When true, debug entries are retained too.
  bool verbose = false;

  List<LogEntry> get entries => List.unmodifiable(_entries);

  void add(LogLevel level, String tag, String message, {Uri? uri}) {
    if (level == LogLevel.debug && !verbose) return;
    // One choke point: every log line and every recorded URI is redacted, so
    // no caller can accidentally leak a token into the exportable log.
    final e = LogEntry(
      level: level,
      tag: tag,
      message: UrlRedactor.redactText(message),
      uri: uri == null ? null : Uri.tryParse(UrlRedactor.redact(uri.toString())),
    );
    _entries.add(e);
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
    for (final l in List.of(_listeners)) {
      try {
        l(e);
      } catch (_) {
        // A broken listener must never break logging.
      }
    }
  }

  void d(String tag, String msg) => add(LogLevel.debug, tag, msg);
  void i(String tag, String msg) => add(LogLevel.info, tag, msg);
  void w(String tag, String msg) => add(LogLevel.warn, tag, msg);
  void e(String tag, String msg, {Uri? uri}) =>
      add(LogLevel.error, tag, msg, uri: uri);

  void network(String tag, Uri uri, {String? note}) =>
      add(LogLevel.debug, tag, note == null ? 'GET $uri' : 'GET $uri — $note', uri: uri);

  void Function() listen(void Function(LogEntry) listener) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  void clear() => _entries.clear();

  String dump() => _entries.map((e) => e.toString()).join('\n');
}
