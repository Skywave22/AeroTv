import 'dart:convert';
import 'dart:typed_data';

import 'package:aero_core/aero_core.dart';
import 'package:dio/dio.dart';
import 'package:eco_stremio/eco_stremio.dart';

/// Serves canned add-on responses so caching can be tested without a network.
class FakeAddon implements HttpClientAdapter {
  FakeAddon(this.routes);
  final Map<String, Object?> routes;
  final List<String> requested = [];
  final Set<String> failing = {};
  final Map<String, Duration> delays = {};

  int countOf(String url) => requested.where((u) => u == url).length;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final url = options.uri.toString();
    requested.add(url);
    final delay = delays[url];
    if (delay != null) await Future<void>.delayed(delay);
    if (failing.contains(url)) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        message: 'simulated failure',
      );
    }
    final body = routes[url];
    if (body == null) {
      return ResponseBody.fromString('{"error":"not found"}', 404, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });
    }
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

class FakeStore implements StremioStore {
  FakeStore(this.source);
  InstalledSource source;
  @override
  Future<List<InstalledSource>> load() async => [source];
  @override
  Future<void> save(InstalledSource s) async => source = s;
  @override
  Future<void> delete(String id) async {}
}

InstalledSource testSource({
  String url = 'https://addon.example/manifest.json',
  String id = 'org.example.addon',
}) =>
    InstalledSource(
      id: id,
      ecosystem: Ecosystem.stremio,
      name: 'Example Add-on',
      url: url,
      version: '1.0.0',
    );

Map<String, Object?> manifestWith(List<Map<String, Object?>> catalogs) => {
      'id': 'org.example.addon',
      'version': '1.0.0',
      'name': 'Example Add-on',
      'types': ['movie', 'series'],
      'resources': ['catalog', 'meta', 'stream'],
      'idPrefixes': ['tt'],
      'catalogs': catalogs,
    };

Map<String, Object?> catalogPage(List<String> ids) => {
      'metas': [
        for (final id in ids)
          {'id': id, 'type': 'movie', 'name': 'Title $id', 'poster': 'p.jpg'},
      ],
    };
