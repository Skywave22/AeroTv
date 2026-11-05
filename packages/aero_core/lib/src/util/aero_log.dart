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
    final e = LogEntry(level: level, tag: tag, message: message, uri: uri);
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
