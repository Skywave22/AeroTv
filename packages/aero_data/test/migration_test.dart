import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aero_data/aero_data.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('aero_migration'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('v1 -> v2 rewrites Unix-second dates as ISO-8601 text', () async {
    final file = File('${tmp.path}/v1.sqlite');

    // ---- Build a v1 database by hand and close it. -----------------------
    // The executor must be *closed* before AeroDatabase opens it, otherwise
    // Drift treats it as already-open and skips the migration entirely.
    final seed = NativeDatabase(file);
    await seed.ensureOpen(_RawUser());
    await seed.runCustom('PRAGMA user_version = 1', []);
    await seed.runCustom('''
      CREATE TABLE watch_history (
        media_id TEXT NOT NULL,
        profile_id TEXT NOT NULL DEFAULT 'default',
        season INTEGER NOT NULL,
        episode INTEGER NOT NULL,
        position_ms INTEGER NOT NULL DEFAULT 0,
        duration_ms INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL,
        meta_json TEXT NOT NULL DEFAULT '{}',
        PRIMARY KEY (media_id, profile_id, season, episode)
      )
    ''', []);
    // 2026-01-01T00:00:00Z and one second later, stored the v1 way.
    await seed.runCustom(
      'INSERT INTO watch_history (media_id, season, episode, updated_at) '
      "VALUES ('tt1', 1, 1, 1767225600)",
      [],
    );
    await seed.runCustom(
      'INSERT INTO watch_history (media_id, season, episode, updated_at) '
      "VALUES ('tt1', 1, 2, 1767225601)",
      [],
    );
    final before =
        await seed.runSelect('SELECT typeof(updated_at) AS t FROM watch_history', []);
    expect(before.every((r) => r['t'] == 'integer'), isTrue);
    await seed.close();

    // ---- Open the real database: onUpgrade must run. ---------------------
    final db = AeroDatabase(NativeDatabase(file));
    addTearDown(db.close);

    final after = await db
        .customSelect(
          'SELECT typeof(updated_at) AS t, updated_at AS v '
          'FROM watch_history ORDER BY updated_at DESC',
        )
        .get();

    expect(after.every((r) => r.data['t'] == 'text'), isTrue,
        reason: 'v1 integer timestamps should have been rewritten as text');

    // Newest first, and the value must round-trip as a DateTime.
    final newest = after.first.data['v'] as String;
    expect(newest, contains('T'));
    expect(DateTime.tryParse(newest), isNotNull);

    // Ordering must still put episode 2 ahead of episode 1.
    final rows = await db.select(db.watchHistory).get();
    expect(rows.length, 2);
    final sorted = [...rows]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    expect(sorted.first.episode, 2);

    // Idempotency: re-running the conversion must not change anything.
    await db.customStatement(
      'UPDATE watch_history SET updated_at = '
      "strftime('%Y-%m-%dT%H:%M:%f', updated_at, 'unixepoch', 'localtime') "
      "WHERE typeof(updated_at) = 'integer'",
    );
    final again = await db
        .customSelect(
            'SELECT updated_at AS v FROM watch_history ORDER BY updated_at DESC')
        .get();
    expect(again.first.data['v'], newest);
  });
}

/// Minimal QueryExecutorUser so raw SQL can run before Drift opens the file.
class _RawUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}
