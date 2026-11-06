import 'package:aero_core/aero_core.dart';
import 'package:dio/dio.dart';
import 'package:eco_stremio/eco_stremio.dart';
import 'package:test/test.dart';

import 'support/fake_addon.dart';

void main() {
  const manifestUrl = 'https://addon.example/manifest.json';
  const catalogUrl = 'https://addon.example/catalog/movie/top.json';
  const metaUrl = 'https://addon.example/meta/movie/tt0111161.json';

  late FakeAddon http;
  late MemoryJsonCache cache;
  late StremioAdapter adapter;

  StremioAdapter build({Map<String, Object?>? routes}) {
    http = FakeAddon(routes ??
        {
          manifestUrl: manifestWith([
            {'id': 'top', 'type': 'movie', 'name': 'Top'},
          ]),
          catalogUrl: catalogPage(['tt0111161', 'tt0068646']),
          metaUrl: {
            'meta': {
              'id': 'tt0111161',
              'type': 'movie',
              'name': 'The Shawshank Redemption',
            },
          },
        });
    final dio = Dio(BaseOptions(responseType: ResponseType.plain));
    dio.httpClientAdapter = http;
    cache = MemoryJsonCache();
    return StremioAdapter(
      store: FakeStore(testSource()),
      api: StremioApi(dio: dio),
      cache: cache,
    );
  }

  StremioAdapter restart() {
    final dio = Dio(BaseOptions(responseType: ResponseType.plain));
    dio.httpClientAdapter = http;
    return StremioAdapter(
      store: FakeStore(testSource()),
      api: StremioApi(dio: dio),
      cache: cache,
    );
  }

  group('Catalog cache (stale-while-revalidate)', () {
    test('first browse fetches; second makes no request', () async {
      adapter = build();
      final first = await adapter.browse('org.example.addon', 'top', const CatalogQuery());
      expect(first.items, hasLength(2));
      expect(http.countOf(catalogUrl), 1);

      final second = await adapter.browse('org.example.addon', 'top', const CatalogQuery());
      expect(second.items, hasLength(2));
      expect(http.countOf(catalogUrl), 1,
          reason: 'a fresh cache hit must not refetch');
    });

    test('a stale entry is served immediately and refreshed behind', () async {
      adapter = build();
      await adapter.browse('org.example.addon', 'top', const CatalogQuery());
      final key = CacheKeys.catalog('stremio', 'org.example.addon', 'movie', 'top', {});
      final hit = await cache.read(key);
      await cache.write(key, hit!.value, ttl: const Duration(milliseconds: -1));
      expect((await cache.read(key))!.isStale, isTrue);

      final before = http.countOf(catalogUrl);
      final stale = await adapter.browse('org.example.addon', 'top', const CatalogQuery());
      expect(stale.items, hasLength(2));
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(http.countOf(catalogUrl), before + 1,
          reason: 'a stale read triggers exactly one background refresh');
      expect((await cache.read(key))!.isFresh, isTrue);
    });

    test('repeated stale reads do not stampede the add-on', () async {
      adapter = build();
      await adapter.browse('org.example.addon', 'top', const CatalogQuery());
      final key = CacheKeys.catalog('stremio', 'org.example.addon', 'movie', 'top', {});
      final hit = await cache.read(key);
      await cache.write(key, hit!.value, ttl: const Duration(milliseconds: -1));
      http.delays[catalogUrl] = const Duration(milliseconds: 80);
      final before = http.countOf(catalogUrl);
      await Future.wait([
        adapter.browse('org.example.addon', 'top', const CatalogQuery()),
        adapter.browse('org.example.addon', 'top', const CatalogQuery()),
        adapter.browse('org.example.addon', 'top', const CatalogQuery()),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(http.countOf(catalogUrl) - before, 1);
    });

    test('different query extras are cached separately', () async {
      const genreUrl = 'https://addon.example/catalog/movie/top/genre=Action.json';
      adapter = build(routes: {
        manifestUrl: manifestWith([
          {'id': 'top', 'type': 'movie', 'name': 'Top'},
        ]),
        catalogUrl: catalogPage(['tt0111161']),
        genreUrl: catalogPage(['tt0068646']),
      });
      await adapter.browse('org.example.addon', 'top', const CatalogQuery());
      await adapter.browse('org.example.addon', 'top', const CatalogQuery(genre: 'Action'));
      expect(http.countOf(catalogUrl), 1);
      expect(http.countOf(genreUrl), 1);
    });
  });

  group('Manifest cache', () {
    test('persists so a restart does not refetch it', () async {
      adapter = build();
      await adapter.catalogs('org.example.addon');
      expect(http.countOf(manifestUrl), 1);
      await restart().catalogs('org.example.addon');
      expect(http.countOf(manifestUrl), 1,
          reason: 'the manifest must survive a restart');
    });

    test('falls back to stale when the add-on is unreachable', () async {
      adapter = build();
      await adapter.catalogs('org.example.addon');
      final key = CacheKeys.manifest('stremio', 'org.example.addon');
      final hit = await cache.read(key);
      await cache.write(key, hit!.value, ttl: const Duration(milliseconds: -1));
      http.failing.add(manifestUrl);
      final rows = await restart().catalogs('org.example.addon');
      expect(rows, hasLength(1));
    });
  });

  group('Meta cache', () {
    const ref = MediaRef(id: 'tt0111161', type: MediaType.movie);

    test('second details call is served from cache', () async {
      adapter = build();
      expect((await adapter.details('org.example.addon', ref)).isOk, isTrue);
      expect(http.countOf(metaUrl), 1);
      expect((await adapter.details('org.example.addon', ref)).isOk, isTrue);
      expect(http.countOf(metaUrl), 1);
    });

    test('stale meta is used when the network fails', () async {
      adapter = build();
      await adapter.details('org.example.addon', ref);
      final key = CacheKeys.meta('stremio', 'org.example.addon', 'movie', 'tt0111161');
      final hit = await cache.read(key);
      await cache.write(key, hit!.value, ttl: const Duration(milliseconds: -1));
      http.failing.add(metaUrl);
      expect((await adapter.details('org.example.addon', ref)).isOk, isTrue);
    });
  });
}
