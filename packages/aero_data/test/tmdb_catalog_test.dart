import 'dart:convert';
import 'dart:typed_data';

import 'package:aero_core/aero_core.dart';
import 'package:aero_data/aero_data.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeTmdb implements HttpClientAdapter {
  FakeTmdb(this.answers);

  /// path -> status + payload
  final Map<String, (int, Object)> answers;
  final requested = <Uri>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requested.add(options.uri);
    // Dio keeps the baseUrl's `/3` prefix in the resolved path.
    final path = options.uri.path.replaceFirst(RegExp(r'^/3'), '');
    final a = answers[path];
    if (a == null) return ResponseBody.fromString('{}', 404);
    final body = a.$2 is String ? a.$2 as String : jsonEncode(a.$2);
    return ResponseBody.fromBytes(utf8.encode(body), a.$1, headers: {
      'content-type': ['application/json']
    });
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object> movie(int id, String title) => {
      'id': id,
      'title': title,
      'overview': 'A film.',
      'poster_path': '/p$id.jpg',
      'backdrop_path': '/b$id.jpg',
      'release_date': '2021-10-01',
      'vote_average': 7.8,
    };

Map<String, Object> show(int id, String name) => {
      'id': id,
      'name': name,
      'overview': 'A series.',
      'poster_path': '/p$id.jpg',
      'first_air_date': '2019-07-04',
      'vote_average': 8.5,
    };

void main() {
  late AeroDatabase db;
  late FakeTmdb adapter;
  late TmdbCatalogRepository repo;

  TmdbCatalogRepository build(Map<String, (int, Object)> answers,
      {String key = 'USER_KEY'}) {
    adapter = FakeTmdb(answers);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.themoviedb.org/3'))
      ..httpClientAdapter = adapter;
    return TmdbCatalogRepository(db: db, apiKey: key, dio: dio);
  }

  setUp(() async {
    db = AeroDatabase.memory();
    await db.select(db.profiles).get();
    repo = build({
      '/trending/all/week': (200, {
        'results': [
          {'media_type': 'movie', ...movie(1, 'Dune')},
          {'media_type': 'tv', ...show(2, 'Severance')},
        ]
      }),
      '/movie/popular': (200, {'results': [movie(3, 'Arrival')]}),
      '/tv/popular': (200, {'results': [show(4, 'Dark')]}),
      '/movie/top_rated': (200, {'results': [movie(5, 'Heat')]}),
    });
  });
  tearDown(() async => db.close());

  group('configuration', () {
    test('no key means no rows, and no network at all', () async {
      repo = build({}, key: '');
      expect(repo.isConfigured, isFalse);
      expect(await repo.rows(), isEmpty);
      expect(adapter.requested, isEmpty,
          reason: 'Aero ships no key and must not call TMDB without one');
    });

    test('a whitespace key is treated as absent', () async {
      repo = build({}, key: '   ');
      expect(await repo.rows(), isEmpty);
      expect(adapter.requested, isEmpty);
    });

    test('a configured repo reports itself configured', () {
      expect(repo.isConfigured, isTrue);
    });
  });

  group('rows', () {
    test('feeds become rows in the declared order', () async {
      final rows = await repo.rows();
      expect(rows.map((r) => r.title), [
        'Trending this week',
        'Popular movies',
        'Popular series',
        'Top rated movies',
      ]);
      expect(rows.every((r) => r.sourceId == 'tmdb'), isTrue);
    });

    test('maxFeeds is honoured', () async {
      expect((await repo.rows(maxFeeds: 2)).length, 2);
    });

    test('the user key and language are sent', () async {
      await repo.rows(maxFeeds: 1);
      expect(adapter.requested.single.queryParameters['api_key'], 'USER_KEY');
      expect(adapter.requested.single.queryParameters['language'], 'en-US');
    });

    test('a failing feed is dropped, the rest still render', () async {
      repo = build({
        '/trending/all/week': (500, 'server error'),
        '/movie/popular': (200, {'results': [movie(3, 'Arrival')]}),
      });
      final rows = await repo.rows(maxFeeds: 2);
      expect(rows.map((r) => r.title), ['Popular movies']);
    });

    test('an empty feed is dropped rather than shown as a blank row', () async {
      repo = build({
        '/trending/all/week': (200, {'results': []}),
        '/movie/popular': (200, {'results': [movie(3, 'Arrival')]}),
      });
      expect((await repo.rows(maxFeeds: 2)).length, 1);
    });

    test('a malformed payload does not throw', () async {
      repo = build({'/trending/all/week': (200, 'not json at all')});
      expect(await repo.rows(maxFeeds: 1), isEmpty);
    });
  });

  group('parsing', () {
    test('a movie maps to a tmdb-keyed ref with no IMDb id yet', () {
      final item = TmdbCatalogRepository.parseItem(
          {'media_type': 'movie', ...movie(603, 'The Matrix')},
          MediaType.other)!;
      expect(item.title, 'The Matrix');
      expect(item.ref.id, 'tmdb:603');
      expect(item.ref.tmdbId, '603');
      expect(item.ref.imdbId, isNull,
          reason: 'IMDb is filled by MetadataResolver at play time');
      expect(item.ref.hasImdb, isFalse);
      expect(item.type, MediaType.movie);
      expect(item.year, 2021);
      expect(item.poster, 'https://image.tmdb.org/t/p/w500/p603.jpg');
      expect(item.background, 'https://image.tmdb.org/t/p/w1280/b603.jpg');
      expect(item.imdbRating, 7.8);
    });

    test('a series uses name and first_air_date', () {
      final item = TmdbCatalogRepository.parseItem(
          {'media_type': 'tv', ...show(1396, 'Breaking Bad')},
          MediaType.other)!;
      expect(item.title, 'Breaking Bad');
      expect(item.type, MediaType.series);
      expect(item.year, 2019);
    });

    test('the feed type wins when the entry has no media_type', () {
      final item =
          TmdbCatalogRepository.parseItem(show(1, 'Dark'), MediaType.series)!;
      expect(item.type, MediaType.series);
    });

    test('trending people are skipped: they are not playable', () {
      expect(
          TmdbCatalogRepository.parseItem(
              {'id': 9, 'media_type': 'person', 'name': 'Someone'},
              MediaType.other),
          isNull);
    });

    test('an entry with no id or no title is skipped', () {
      expect(TmdbCatalogRepository.parseItem({'title': 'X'}, MediaType.movie),
          isNull);
      expect(TmdbCatalogRepository.parseItem({'id': 1}, MediaType.movie), isNull);
      expect(
          TmdbCatalogRepository.parseItem(
              {'id': 1, 'title': '   '}, MediaType.movie),
          isNull);
    });

    test('missing artwork and a zero rating become null, not empty strings', () {
      final item = TmdbCatalogRepository.parseItem({
        'id': 1,
        'title': 'Bare',
        'poster_path': '',
        'vote_average': 0,
        'overview': '   ',
      }, MediaType.movie)!;
      expect(item.poster, isNull);
      expect(item.background, isNull);
      expect(item.imdbRating, isNull);
      expect(item.description, isNull);
      expect(item.year, isNull);
    });
  });

  group('caching', () {
    test('a second call is served from cache', () async {
      await repo.rows(maxFeeds: 1);
      final first = adapter.requested.length;
      await repo.rows(maxFeeds: 1);
      expect(adapter.requested.length, first,
          reason: 'Home rebuilds must not re-hit TMDB');
    });

    test('a cached row keeps its items and order', () async {
      final a = await repo.rows(maxFeeds: 1);
      final b = await repo.rows(maxFeeds: 1);
      expect(b.single.items.map((i) => i.title),
          a.single.items.map((i) => i.title));
      expect(b.single.items.first.ref.tmdbId,
          a.single.items.first.ref.tmdbId);
    });

    test('one malformed cached card does not empty the row', () async {
      await CacheRepository(db).put('tmdb:catalog:trending:en-US', {
        'items': [
          const MediaItem(
            ref: MediaRef(id: 'tmdb:1', type: MediaType.movie),
            title: 'Good',
          ).toJson(),
          {'broken': true},
        ],
      }, ttl: const Duration(hours: 1));
      final rows = await repo.rows(maxFeeds: 1);
      expect(rows.single.items.map((i) => i.title), ['Good']);
      expect(adapter.requested, isEmpty);
    });
  });
}
