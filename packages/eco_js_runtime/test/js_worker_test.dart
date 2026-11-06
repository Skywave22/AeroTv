import 'dart:async';

import 'package:eco_js_runtime/eco_js_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake engines let the supervisor be tested on a host where the real QuickJS
/// binding cannot load. They reproduce the *failure modes* that matter:
/// a blocking loop, a never-settling promise, a throw, and a bad shape.
class _OkEngine implements JsWorkerEngine {
  @override
  JsEngineCapabilities get capabilities =>
      const JsEngineCapabilities(name: 'fake-ok', memoryLimit: true, interruptHandler: true);
  @override
  Future<void> initialise(String code) async {}
  @override
  Future<Object?> call(String fn, List<Object?> args, {bool callbackStyle = false}) async =>
      {'fn': fn, 'args': args, 'cb': callbackStyle};
  @override
  Future<void> dispose() async {}
}

/// Simulates `while (true) {}`: a synchronous block that never yields.
class _BlockingEngine implements JsWorkerEngine {
  @override
  JsEngineCapabilities get capabilities =>
      const JsEngineCapabilities(name: 'fake-blocking');
  @override
  Future<void> initialise(String code) async {}
  @override
  Future<Object?> call(String fn, List<Object?> args, {bool callbackStyle = false}) async {
    // A real synchronous FFI loop blocks the isolate the same way: no timer
    // on THAT isolate can fire. Only an outside supervisor can stop it.
    final sw = Stopwatch()..start();
    while (sw.elapsed < const Duration(minutes: 5)) {
      // burn CPU without yielding
    }
    return null;
  }
  @override
  Future<void> dispose() async {}
}

/// Simulates a promise that never resolves.
class _HangingEngine implements JsWorkerEngine {
  @override
  JsEngineCapabilities get capabilities => const JsEngineCapabilities(name: 'fake-hanging');
  @override
  Future<void> initialise(String code) async {}
  @override
  Future<Object?> call(String fn, List<Object?> args, {bool callbackStyle = false}) =>
      Completer<Object?>().future;
  @override
  Future<void> dispose() async {}
}

class _ThrowingEngine implements JsWorkerEngine {
  @override
  JsEngineCapabilities get capabilities => const JsEngineCapabilities(name: 'fake-throwing');
  @override
  Future<void> initialise(String code) async {}
  @override
  Future<Object?> call(String fn, List<Object?> args, {bool callbackStyle = false}) async =>
      throw StateError('plugin exploded');
  @override
  Future<void> dispose() async {}
}

class _BadBootEngine implements JsWorkerEngine {
  @override
  JsEngineCapabilities get capabilities => const JsEngineCapabilities(name: 'fake-badboot');
  @override
  Future<void> initialise(String code) async => throw StateError('syntax error');
  @override
  Future<Object?> call(String fn, List<Object?> args, {bool callbackStyle = false}) async => null;
  @override
  Future<void> dispose() async {}
}

// Top-level factories: required so they can cross the isolate boundary.
JsWorkerEngine okEngine(JsWorkerConfig config) => _OkEngine();
JsWorkerEngine blockingEngine(JsWorkerConfig config) => _BlockingEngine();
JsWorkerEngine hangingEngine(JsWorkerConfig config) => _HangingEngine();
JsWorkerEngine throwingEngine(JsWorkerConfig config) => _ThrowingEngine();
JsWorkerEngine badBootEngine(JsWorkerConfig config) => _BadBootEngine();

void main() {
  group('JsWorker supervisor', () {
    test('a well-behaved plugin returns its result', () async {
      final w = await JsWorker.spawn(
          pluginName: 'ok', code: '', factory: okEngine);
      addTearDown(w.dispose);
      final r = await w.call('getStreams', ['tt123']);
      expect(r.isOk, isTrue, reason: r.errorOrNull);
      expect((r.valueOrNull as Map)['fn'], 'getStreams');
      expect(w.isAlive, isTrue);
    });

    test('an infinite loop is killed at the deadline and the host survives',
        () async {
      final w = await JsWorker.spawn(
          pluginName: 'runaway', code: '', factory: blockingEngine);
      addTearDown(w.dispose);

      final sw = Stopwatch()..start();
      final r = await w.call('loop', const [],
          deadline: const Duration(milliseconds: 400));
      sw.stop();

      // The supervisor's own isolate stayed free, so the deadline fired.
      expect(r.isErr, isTrue);
      expect(r.errorOrNull, contains('exceeded'));
      expect(sw.elapsed, lessThan(const Duration(seconds: 5)),
          reason: 'must be killed promptly, not run to completion');
      expect(w.isAlive, isFalse, reason: 'a runaway context is not reusable');

      // And the host can carry on with a different plugin.
      final fresh = await JsWorker.spawn(
          pluginName: 'ok2', code: '', factory: okEngine);
      addTearDown(fresh.dispose);
      expect((await fresh.call('x', const [])).isOk, isTrue);
    });

    test('a never-resolving promise hits the deadline', () async {
      final w = await JsWorker.spawn(
          pluginName: 'hang', code: '', factory: hangingEngine);
      addTearDown(w.dispose);
      final r = await w.call('never', const [],
          deadline: const Duration(milliseconds: 300));
      expect(r.isErr, isTrue);
      expect(r.errorOrNull, contains('exceeded'));
      expect(w.isAlive, isFalse);
    });

    test('a throwing plugin becomes a typed error, not a crash', () async {
      final w = await JsWorker.spawn(
          pluginName: 'throw', code: '', factory: throwingEngine);
      addTearDown(w.dispose);
      final r = await w.call('boom', const []);
      expect(r.isErr, isTrue);
      expect(r.errorOrNull, contains('plugin exploded'));
      // A throw is recoverable; the worker stays usable.
      expect(w.isAlive, isTrue);
    });

    test('a plugin that fails to load reports a clear error', () async {
      expect(
        () => JsWorker.spawn(
            pluginName: 'bad', code: '', factory: badBootEngine),
        throwsA(isA<StateError>()),
      );
    });

    test('calls after disposal fail cleanly', () async {
      final w = await JsWorker.spawn(
          pluginName: 'ok', code: '', factory: okEngine);
      await w.dispose();
      final r = await w.call('x', const []);
      expect(r.isErr, isTrue);
      expect(r.errorOrNull, contains('no longer running'));
    });

    test('callback style reaches the engine (SkyStream convention)', () async {
      final w = await JsWorker.spawn(
          pluginName: 'ok', code: '', factory: okEngine);
      addTearDown(w.dispose);
      final cb = await w.call('getHome', const [], callbackStyle: true);
      expect((cb.valueOrNull as Map)['cb'], isTrue);
      final pr = await w.call('getStreams', const []);
      expect((pr.valueOrNull as Map)['cb'], isFalse);
    });

    test('concurrent calls are matched to their own results', () async {
      final w = await JsWorker.spawn(
          pluginName: 'ok', code: '', factory: okEngine);
      addTearDown(w.dispose);
      final results = await Future.wait([
        w.call('a', const [1]),
        w.call('b', const [2]),
        w.call('c', const [3]),
      ]);
      expect(results.map((r) => (r.valueOrNull as Map)['fn']), ['a', 'b', 'c']);
    });
  });

  group('Engine capabilities are reported honestly', () {
    test('an engine with no limits says so', () {
      const caps = JsEngineCapabilities(name: 'flutter_js');
      expect(caps.memoryLimit, isFalse);
      expect(caps.interruptHandler, isFalse);
      expect(caps.needsIsolateForSafety, isTrue);
      expect(caps.unenforced, containsAll(['memory cap', 'CPU interrupt']));
    });

    test('a fully capable engine does not need the isolate for safety', () {
      const caps = JsEngineCapabilities(
        name: 'quickjs-ng',
        memoryLimit: true,
        stackLimit: true,
        interruptHandler: true,
      );
      expect(caps.needsIsolateForSafety, isFalse);
      expect(caps.unenforced, isEmpty);
    });

    test('the worker surfaces the engine capabilities', () async {
      final w = await JsWorker.spawn(
          pluginName: 'ok', code: '', factory: okEngine);
      addTearDown(w.dispose);
      expect(w.capabilities.name, 'fake-ok');
      expect(w.capabilities.memoryLimit, isTrue);
    });
  });
}
