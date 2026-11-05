import 'package:aero_core/aero_core.dart';
import 'package:drift/drift.dart';

import '../db/database.dart';

/// Tracks per-provider reliability so flaky sources can be auto-demoted.
class HealthRepository {
  HealthRepository(this.db);

  final AeroDatabase db;

  Future<ProviderHealth?> get(String sourceKey) async {
    final rows = await (db.select(db.providerHealthTable)
          ..where((t) => t.sourceKey.equals(sourceKey))
          ..limit(1))
        .get();
    if (rows.isEmpty) return null;
    return _map(rows.first);
  }

  Future<List<ProviderHealth>> all() async {
    final rows = await db.select(db.providerHealthTable).get();
    return rows.map(_map).toList();
  }

  /// Records one resolution outcome, keeping a decaying average so recent
  /// behaviour matters more than ancient history.
  Future<void> record(
    String sourceKey, {
    required bool ok,
    int? latencyMs,
    String? error,
  }) async {
    final current = await get(sourceKey);
    final succ = (current?.successCount ?? 0) + (ok ? 1 : 0);
    final fail = (current?.failCount ?? 0) + (ok ? 0 : 1);
    // Cap counters so a long-lived install doesn't become immune to change.
    const cap = 100;
    final s = succ > cap ? (succ * 0.8).round() : succ;
    final f = fail > cap ? (fail * 0.8).round() : fail;
    final prevAvg = current?.avgLatencyMs ?? 0;
    final avg = latencyMs == null
        ? prevAvg
        : (prevAvg == 0 ? latencyMs.toDouble() : prevAvg * 0.7 + latencyMs * 0.3);

    await db.into(db.providerHealthTable).insertOnConflictUpdate(
          ProviderHealthTableCompanion.insert(
            sourceKey: sourceKey,
            successCount: Value(s),
            failCount: Value(f),
            avgLatencyMs: Value(avg),
            lastChecked: Value(DateTime.now()),
            lastError: Value(ok ? null : error),
          ),
        );
  }

  Future<void> reset(String sourceKey) async {
    await (db.delete(db.providerHealthTable)
          ..where((t) => t.sourceKey.equals(sourceKey)))
        .go();
  }

  /// Source keys that should be excluded from auto-play.
  Future<Set<String>> flakyKeys() async {
    final rows = await all();
    return rows.where((h) => h.isFlaky).map((h) => h.sourceKey).toSet();
  }

  ProviderHealth _map(ProviderHealthRow r) => ProviderHealth(
        sourceKey: r.sourceKey,
        successCount: r.successCount,
        failCount: r.failCount,
        avgLatencyMs: r.avgLatencyMs,
        lastChecked: r.lastChecked,
        lastError: r.lastError,
      );
}
