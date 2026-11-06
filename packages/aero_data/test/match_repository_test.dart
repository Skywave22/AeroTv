import 'package:aero_core/aero_core.dart';
import 'package:aero_data/aero_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AeroDatabase db;
  late MatchRepository matches;

  const dune = TitleCandidate(
      title: 'Dune', link: '/movies/dune-2021', year: 2021, type: 'movie');
  const dune2 = TitleCandidate(
      title: 'Dune: Part Two', link: '/movies/dune-2', year: 2024, type: 'movie');

  setUp(() async {
    db = AeroDatabase.memory();
    await db.select(db.profiles).get();
    matches = MatchRepository(db);
  });
  tearDown(() async => db.close());

  group('auto matches', () {
    test('nothing is remembered for an unseen title', () async {
      expect(await matches.lookup('vega:src', 'movie:tt1160419'), isNull);
    });

    test('a remembered decision round-trips with its score', () async {
      await matches.remember('vega:src', 'movie:tt1160419',
          const TitleMatch(dune, 0.97));
      final hit = await matches.lookup('vega:src', 'movie:tt1160419');
      expect(hit, isNotNull);
      expect(hit!.candidate.link, dune.link);
      expect(hit.candidate.year, 2021);
      expect(hit.candidate.type, 'movie');
      expect(hit.score, 0.97);
      expect(hit.pinned, isFalse);
    });

    test('decisions are scoped per source and per media item', () async {
      await matches.remember('a', 'm', const TitleMatch(dune, 0.9));
      expect(await matches.lookup('b', 'm'), isNull);
      expect(await matches.lookup('a', 'other'), isNull);
      expect(await matches.lookup('a', 'm'), isNotNull);
    });

    test('a new auto decision replaces the previous one', () async {
      await matches.remember('a', 'm', const TitleMatch(dune, 0.8));
      await matches.remember('a', 'm', const TitleMatch(dune2, 0.95));
      expect((await matches.lookup('a', 'm'))!.candidate.link, dune2.link);
    });

    test('an expired auto match is a miss', () async {
      await CacheRepository(db).put(
        MatchRepository.keyFor('a', 'm'),
        {
          'pinned': false,
          'score': 0.9,
          'candidate': {'title': 'Dune', 'link': '/dune'},
        },
        ttl: const Duration(milliseconds: -1),
      );
      expect(await matches.lookup('a', 'm'), isNull);
    });

    test('a malformed row is a miss, not a crash', () async {
      await CacheRepository(db).put(
        MatchRepository.keyFor('a', 'm'),
        {'pinned': false, 'score': 'not a number', 'candidate': {}},
        ttl: const Duration(days: 1),
      );
      expect(await matches.lookup('a', 'm'), isNull);
      // ...and the bad row is gone.
      expect(await CacheRepository(db).read(MatchRepository.keyFor('a', 'm')),
          isNull);
    });
  });

  group('user corrections', () {
    test('a pin is marked pinned and is always usable', () async {
      await matches.pin('a', 'm', dune2);
      final hit = await matches.lookup('a', 'm');
      expect(hit!.pinned, isTrue);
      expect(hit.isUsable, isTrue);
      expect(hit.candidate.link, dune2.link);
    });

    test('an auto match must clear the threshold to be usable', () {
      expect(const TitleMatch(dune, 0.99).isUsable, isTrue);
      expect(const TitleMatch(dune, 0.5).isUsable, isFalse);
      expect(const TitleMatch(dune, 0.1, pinned: true).isUsable, isTrue);
    });

    test('a later auto match never overwrites a pin', () async {
      await matches.pin('a', 'm', dune2);
      await matches.remember('a', 'm', const TitleMatch(dune, 0.999));
      final hit = await matches.lookup('a', 'm');
      expect(hit!.pinned, isTrue);
      expect(hit.candidate.link, dune2.link,
          reason: 'the user chose Part Two; a better score must not undo it');
    });

    test('a pin survives its nominal expiry', () async {
      await CacheRepository(db).put(
        MatchRepository.keyFor('a', 'm'),
        {
          'pinned': true,
          'score': 1.0,
          'candidate': {'title': 'Dune: Part Two', 'link': '/dune-2'},
        },
        ttl: const Duration(milliseconds: -1),
      );
      final hit = await matches.lookup('a', 'm');
      expect(hit, isNotNull, reason: 'a user choice must not silently revert');
      expect(hit!.pinned, isTrue);
    });

    test('unpin removes the correction', () async {
      await matches.pin('a', 'm', dune2);
      await matches.unpin('a', 'm');
      expect(await matches.lookup('a', 'm'), isNull);
    });

    test('unpin leaves an auto match alone', () async {
      await matches.remember('a', 'm', const TitleMatch(dune, 0.9));
      await matches.unpin('a', 'm');
      expect(await matches.lookup('a', 'm'), isNotNull);
    });

    test('a poster survives the round-trip for the picker', () async {
      await matches.pin('a', 'm',
          const TitleCandidate(title: 'Dune', link: '/d', poster: 'p.jpg'));
      expect((await matches.lookup('a', 'm'))!.candidate.poster, 'p.jpg');
    });
  });

  group('uninstall', () {
    test('forgetSource removes every decision for that source only', () async {
      await matches.remember('a', 'm1', const TitleMatch(dune, 0.9));
      await matches.pin('a', 'm2', dune2);
      await matches.remember('b', 'm1', const TitleMatch(dune, 0.9));

      expect(await matches.forgetSource('a'), 2);
      expect(await matches.lookup('a', 'm1'), isNull);
      expect(await matches.lookup('a', 'm2'), isNull);
      expect(await matches.lookup('b', 'm1'), isNotNull);
    });

    test('forgetSource does not touch unrelated cache keys', () async {
      final cache = CacheRepository(db);
      await cache.put('catalog:vega', {'x': 1}, ttl: const Duration(hours: 1));
      await matches.remember('vega', 'm', const TitleMatch(dune, 0.9));
      await matches.forgetSource('vega');
      expect(await cache.get('catalog:vega'), isNotNull);
    });

    test('a source key that is a prefix of another is not collateral damage',
        () async {
      await matches.remember('src', 'm', const TitleMatch(dune, 0.9));
      await matches.remember('src2', 'm', const TitleMatch(dune, 0.9));
      await matches.forgetSource('src');
      expect(await matches.lookup('src', 'm'), isNull);
      expect(await matches.lookup('src2', 'm'), isNotNull,
          reason: 'the key separator must prevent prefix bleed');
    });

    test('forgetting an unknown source is a no-op', () async {
      expect(await matches.forgetSource('nope'), 0);
    });
  });
}
