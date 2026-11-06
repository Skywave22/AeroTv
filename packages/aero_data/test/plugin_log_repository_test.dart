import 'package:aero_core/aero_core.dart';
import 'package:aero_data/aero_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AeroDatabase db;
  late PluginLogRepository logs;

  setUp(() async {
    db = AeroDatabase.memory();
    await db.select(db.profiles).get();
    logs = PluginLogRepository(db);
  });
  tearDown(() async => db.close());

  group('writing and reading', () {
    test('an empty log reads back empty', () async {
      expect(await logs.forSource('p'), isEmpty);
      expect(await logs.countFor('p'), 0);
      expect(await logs.dump('p'), '');
    });

    test('entries round-trip with level, tag and message', () async {
      await logs.append('p', LogLevel.error, 'http', 'boom');
      final rows = await logs.forSource('p');
      expect(rows, hasLength(1));
      expect(rows.first.level, 'error');
      expect(rows.first.tag, 'http');
      expect(rows.first.message, 'boom');
      expect(rows.first.sourceKey, 'p');
    });

    test('newest first', () async {
      final t0 = DateTime(2026, 1, 1, 12);
      await logs.append('p', LogLevel.info, 't', 'old', at: t0);
      await logs.append('p', LogLevel.info, 't', 'new',
          at: t0.add(const Duration(seconds: 1)));
      expect((await logs.forSource('p')).map((r) => r.message), ['new', 'old']);
    });

    test('two entries in the same millisecond still order deterministically',
        () async {
      final t = DateTime(2026, 1, 1, 12);
      await logs.append('p', LogLevel.info, 't', 'first', at: t);
      await logs.append('p', LogLevel.info, 't', 'second', at: t);
      expect((await logs.forSource('p')).first.message, 'second',
          reason: 'the autoincrement id breaks the tie');
    });

    test('logs are scoped per plugin', () async {
      await logs.append('a', LogLevel.info, 't', 'from a');
      await logs.append('b', LogLevel.info, 't', 'from b');
      expect((await logs.forSource('a')).single.message, 'from a');
      expect(await logs.countFor('b'), 1);
    });

    test('limit is honoured', () async {
      for (var i = 0; i < 10; i++) {
        await logs.append('p', LogLevel.info, 't', 'm$i');
      }
      expect(await logs.forSource('p', limit: 3), hasLength(3));
    });

    test('an AeroLog entry can be recorded directly', () async {
      await logs.record('p', LogEntry(level: LogLevel.warn, tag: 'js',
          message: 'careful'));
      expect((await logs.forSource('p')).single.level, 'warn');
    });
  });

  group('redaction', () {
    test('a token in the message is redacted before it is stored', () async {
      await logs.append('p', LogLevel.info, 'http',
          'GET https://addon.example/abc123def456ghi789jkl/manifest.json');
      final stored = (await logs.forSource('p')).single.message;
      expect(stored, contains('***'));
      expect(stored, isNot(contains('abc123def456ghi789jkl')));
    });

    test('a secret query parameter is redacted in the stored uri', () async {
      await logs.append('p', LogLevel.info, 'http', 'call',
          uri: Uri.parse('https://api.example/v1?api_key=SUPERSECRET'));
      final stored = (await logs.forSource('p')).single.uri!;
      expect(stored, contains('REDACTED'));
      expect(stored, isNot(contains('SUPERSECRET')));
    });
  });

  group('caps and pruning', () {
    test('a chatty plugin is capped, keeping the newest entries', () async {
      for (var i = 0; i < PluginLogRepository.maxPerSource + 25; i++) {
        await logs.append('p', LogLevel.info, 't', 'm$i');
      }
      expect(await logs.countFor('p'), PluginLogRepository.maxPerSource);
      expect((await logs.forSource('p', limit: 1)).single.message,
          'm${PluginLogRepository.maxPerSource + 24}');
    });

    test('one chatty plugin does not evict another plugin\'s log', () async {
      await logs.append('quiet', LogLevel.error, 't', 'keep me');
      for (var i = 0; i < PluginLogRepository.maxPerSource + 10; i++) {
        await logs.append('loud', LogLevel.info, 't', 'm$i');
      }
      expect((await logs.forSource('quiet')).single.message, 'keep me');
    });

    test('prune drops old entries and keeps recent ones', () async {
      await logs.append('p', LogLevel.info, 't', 'ancient',
          at: DateTime.now().subtract(const Duration(days: 30)));
      await logs.append('p', LogLevel.info, 't', 'fresh');
      expect(await logs.prune(), 1);
      expect((await logs.forSource('p')).single.message, 'fresh');
    });
  });

  group('filtering and network activity', () {
    test('minLevel filters out quieter entries', () async {
      await logs.append('p', LogLevel.debug, 't', 'd');
      await logs.append('p', LogLevel.info, 't', 'i');
      await logs.append('p', LogLevel.warn, 't', 'w');
      await logs.append('p', LogLevel.error, 't', 'e');
      expect((await logs.forSource('p', minLevel: LogLevel.warn))
          .map((r) => r.message).toSet(), {'w', 'e'});
    });

    test('networkActivity returns only entries with a destination', () async {
      await logs.append('p', LogLevel.info, 't', 'no uri');
      await logs.append('p', LogLevel.info, 'http', 'call',
          uri: Uri.parse('https://one.example/a'));
      final rows = await logs.networkActivity('p');
      expect(rows, hasLength(1));
      expect(rows.single.uri, contains('one.example'));
    });

    test('hostsFor lists distinct hosts, newest first', () async {
      final t = DateTime(2026, 1, 1, 12);
      await logs.append('p', LogLevel.info, 'http', 'a',
          uri: Uri.parse('https://one.example/a'), at: t);
      await logs.append('p', LogLevel.info, 'http', 'b',
          uri: Uri.parse('https://two.example/b'),
          at: t.add(const Duration(seconds: 1)));
      await logs.append('p', LogLevel.info, 'http', 'c',
          uri: Uri.parse('https://one.example/c'),
          at: t.add(const Duration(seconds: 2)));
      expect(await logs.hostsFor('p'), ['one.example', 'two.example']);
    });
  });

  group('uninstall', () {
    test('clearSource removes only that plugin', () async {
      await logs.append('a', LogLevel.info, 't', 'x');
      await logs.append('b', LogLevel.info, 't', 'y');
      expect(await logs.clearSource('a'), 1);
      expect(await logs.forSource('a'), isEmpty);
      expect(await logs.forSource('b'), hasLength(1));
    });

    test('clearAll empties the table', () async {
      await logs.append('a', LogLevel.info, 't', 'x');
      await logs.append('b', LogLevel.info, 't', 'y');
      await logs.clearAll();
      expect(await logs.countFor('a'), 0);
      expect(await logs.countFor('b'), 0);
    });

    test('dump is chronological plain text', () async {
      final t = DateTime(2026, 1, 1, 12);
      await logs.append('p', LogLevel.info, 't', 'first', at: t);
      await logs.append('p', LogLevel.error, 't', 'second',
          at: t.add(const Duration(seconds: 1)));
      final text = await logs.dump('p');
      expect(text.indexOf('first'), lessThan(text.indexOf('second')));
      expect(text, contains('ERROR'));
    });
  });
}
