import 'dart:io';

import 'package:aero_core/aero_core.dart';
import 'package:aero_data/aero_data.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('aero_mig');
    file = File('${dir.path}/aero.sqlite');
  });
  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  test('a v2 install upgrades to v3 without losing user data', () async {
    // Build a database, then rewind it to look like a v2 install: the
    // plugin_logs table does not exist yet and user_version is 2.
    final v2 = AeroDatabase(NativeDatabase(file));
    await v2.select(v2.profiles).get();
    await CacheRepository(v2)
        .put('catalog:keep', {'title': 'Saved'}, ttl: const Duration(days: 1));
    await v2.into(v2.installedSources).insert(
          InstalledSourcesCompanion.insert(
            id: 'keep',
            ecosystem: 'vega',
            name: 'Keep me',
            url: 'https://example.test',
          ),
        );
    await v2.customStatement('DROP TABLE plugin_logs');
    await v2.customStatement('PRAGMA user_version = 2');
    await v2.close();

    // Reopen: onUpgrade must add the table and leave everything else alone.
    final v3 = AeroDatabase(NativeDatabase(file));
    addTearDown(v3.close);

    final sources = await v3.select(v3.installedSources).get();
    expect(sources.map((s) => s.id), contains('keep'),
        reason: 'installed plugins must survive the upgrade');
    expect((await CacheRepository(v3).get('catalog:keep'))!['title'], 'Saved',
        reason: 'cached catalogues must survive the upgrade');

    // The new table exists and is writable.
    final logs = PluginLogRepository(v3);
    await logs.append('vega:keep', LogLevel.info, 'test', 'after upgrade');
    expect((await logs.forSource('vega:keep')).single.message, 'after upgrade');

    final version =
        await v3.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.first, 3);
  });

  test('the upgrade is additive: it does not recreate existing tables',
      () async {
    final v2 = AeroDatabase(NativeDatabase(file));
    await v2.select(v2.profiles).get();
    await v2.customStatement('DROP TABLE plugin_logs');
    await v2.customStatement('PRAGMA user_version = 2');
    await v2.close();

    final v3 = AeroDatabase(NativeDatabase(file));
    addTearDown(v3.close);
    // The seeded default profile is created in onCreate only; an upgrade must
    // not duplicate or reset it.
    expect(await v3.select(v3.profiles).get(), hasLength(1));
  });

  test('opening a fresh database lands directly on v3', () async {
    final db = AeroDatabase(NativeDatabase(file));
    addTearDown(db.close);
    await db.select(db.profiles).get();
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.first, 3);
    await PluginLogRepository(db).append('p', LogLevel.info, 't', 'ok');
    expect(await PluginLogRepository(db).countFor('p'), 1);
  });
}
