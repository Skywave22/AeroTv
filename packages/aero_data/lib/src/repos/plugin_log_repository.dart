import 'package:aero_core/aero_core.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;

import '../db/database.dart';

/// Persisted, per-plugin diagnostic log.
///
/// [AeroLog] is a global in-memory ring buffer: useful live, useless after a
/// restart. This keeps the last [maxPerSource] entries for each plugin so a
/// failed play can still be explained, and so the Extensions Manager can show
/// "why did this source fail?" without re-running it.
///
/// Everything written here has already been redacted by [AeroLog.add]; the
/// repository redacts again on the way in because it is also callable directly.
class PluginLogRepository {
  PluginLogRepository(this.db);

  final AeroDatabase db;

  /// Hard cap per plugin. A plugin in a retry loop must not fill the disk.
  static const maxPerSource = 300;

  Future<void> append(
    String sourceKey,
    LogLevel level,
    String tag,
    String message, {
    Uri? uri,
    DateTime? at,
  }) async {
    await db.into(db.pluginLogs).insert(
          PluginLogsCompanion.insert(
            sourceKey: sourceKey,
            at: at ?? DateTime.now(),
            level: level.name,
            tag: tag,
            message: UrlRedactor.redactText(message),
            uri: Value(uri == null
                ? null
                : UrlRedactor.redact(uri.toString())),
          ),
        );
    await _trim(sourceKey);
  }

  /// Copies an [AeroLog] entry into a plugin's log.
  Future<void> record(String sourceKey, LogEntry e) =>
      append(sourceKey, e.level, e.tag, e.message, uri: e.uri, at: e.at);

  /// Newest first.
  Future<List<PluginLogRow>> forSource(String sourceKey,
      {int limit = 200, LogLevel? minLevel}) async {
    final q = db.select(db.pluginLogs)
      ..where((t) => t.sourceKey.equals(sourceKey))
      ..orderBy([(t) => OrderingTerm.desc(t.at), (t) => OrderingTerm.desc(t.id)])
      ..limit(limit);
    final rows = await q.get();
    if (minLevel == null) return rows;
    return rows.where((r) => _rank(r.level) >= _rank(minLevel.name)).toList();
  }

  /// Entries that mention a network destination — the "Network activity" view.
  Future<List<PluginLogRow>> networkActivity(String sourceKey,
      {int limit = 100}) async {
    final rows = await (db.select(db.pluginLogs)
          ..where((t) => t.sourceKey.equals(sourceKey) & t.uri.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.at)])
          ..limit(limit))
        .get();
    return rows;
  }

  /// Distinct hosts a plugin has contacted, most recent first. This is the
  /// answer to "where is this plugin actually sending my requests?".
  Future<List<String>> hostsFor(String sourceKey) async {
    final rows = await networkActivity(sourceKey, limit: maxPerSource);
    final seen = <String>{};
    final out = <String>[];
    for (final r in rows) {
      final h = Uri.tryParse(r.uri ?? '')?.host;
      if (h != null && h.isNotEmpty && seen.add(h)) out.add(h);
    }
    return out;
  }

  Future<int> countFor(String sourceKey) async {
    final rows = await (db.selectOnly(db.pluginLogs)
          ..addColumns([db.pluginLogs.id.count()])
          ..where(db.pluginLogs.sourceKey.equals(sourceKey)))
        .get();
    return rows.first.read(db.pluginLogs.id.count()) ?? 0;
  }

  /// Removes a plugin's log entirely. Called on uninstall.
  Future<int> clearSource(String sourceKey) =>
      (db.delete(db.pluginLogs)
            ..where((t) => t.sourceKey.equals(sourceKey)))
          .go();

  Future<int> clearAll() => db.delete(db.pluginLogs).go();

  /// Drops entries older than [age] across all plugins.
  Future<int> prune({Duration age = const Duration(days: 7)}) =>
      (db.delete(db.pluginLogs)
            ..where((t) => t.at.isSmallerThanValue(DateTime.now().subtract(age))))
          .go();

  /// Plain-text export for the "Copy logs" button.
  Future<String> dump(String sourceKey, {int limit = 200}) async {
    final rows = await forSource(sourceKey, limit: limit);
    return rows.reversed
        .map((r) => '[${r.at.toIso8601String().substring(11, 23)}] '
            '${r.level.toUpperCase().padRight(5)} ${r.tag}: ${r.message}')
        .join('\n');
  }

  Future<void> _trim(String sourceKey) async {
    // Keep the newest maxPerSource rows for this source only.
    await db.customStatement(
      'DELETE FROM plugin_logs WHERE source_key = ? AND id NOT IN '
      '(SELECT id FROM plugin_logs WHERE source_key = ? '
      'ORDER BY at DESC, id DESC LIMIT ?)',
      [sourceKey, sourceKey, maxPerSource],
    );
  }

  static int _rank(String level) => switch (level) {
        'debug' => 0,
        'info' => 1,
        'warn' => 2,
        'error' => 3,
        _ => 1,
      };
}
