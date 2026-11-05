/// Test-only helpers for the JS ecosystems.
///
/// Import as `package:eco_js_runtime/testing.dart`. Deliberately **not**
/// exported from the main barrel so none of this ships in the app.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:aero_core/aero_core.dart';
import 'package:dio/dio.dart';

import 'eco_js_runtime.dart';

/// In-memory [JsPluginStore], so adapters can be constructed without Drift.
class MemoryPluginStore implements JsPluginStore {
  final Map<String, InstalledSource> sources = {};
  final Map<String, String> code = {};

  String _k(Ecosystem e, String id) => '${e.id}:$id';

  @override
  Future<List<InstalledSource>> load(Ecosystem ecosystem) async =>
      sources.values.where((s) => s.ecosystem == ecosystem).toList();

  @override
  Future<void> save(InstalledSource source) async {
    sources[_k(source.ecosystem, source.id)] = source;
  }

  @override
  Future<void> delete(Ecosystem ecosystem, String id) async {
    sources.remove(_k(ecosystem, id));
  }

  @override
  Future<String?> loadCode(Ecosystem ecosystem, String id) async =>
      code[_k(ecosystem, id)];

  @override
  Future<void> saveCode(Ecosystem ecosystem, String id, String value) async {
    code[_k(ecosystem, id)] = value;
  }
}

/// Serves canned bodies per URL so repository parsing can be tested without a
/// network or a real JS runtime.
class FakeHttp implements HttpClientAdapter {
  FakeHttp(this.routes);

  final Map<String, String> routes;
  final List<String> requested = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final url = options.uri.toString();
    requested.add(url);
    final body = routes[url];
    if (body == null) {
      return ResponseBody.fromString(
        '{"error":"not found"}',
        404,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A Dio backed by [FakeHttp]. Responses are plain text so
/// `JsSourceManager.fetchJson` performs the decode, matching production.
Dio fakeDio(Map<String, String> routes) {
  final dio = Dio(BaseOptions(responseType: ResponseType.plain));
  dio.httpClientAdapter = FakeHttp(routes);
  return dio;
}

/// Encodes [o] as a JSON response body.
String jsonText(Object? o) => jsonEncode(o);
