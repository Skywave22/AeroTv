import 'dart:async';
import 'dart:isolate';

import 'package:aero_core/aero_core.dart';

import 'js_sandbox_policy.dart';

/// What a JS engine can actually enforce.
///
/// Reported honestly rather than assumed. `flutter_js` exposes no memory-limit
/// or interrupt-handler API, so the previous code called a `__setMemoryLimit`
/// that never existed behind a `typeof` guard and silently enforced nothing.
/// Callers can now see the gap instead of believing a cap is in place.
class JsEngineCapabilities {
  const JsEngineCapabilities({
    required this.name,
    this.memoryLimit = false,
    this.stackLimit = false,
    this.interruptHandler = false,
  });

  final String name;
  final bool memoryLimit;
  final bool stackLimit;
  final bool interruptHandler;

  /// The isolate supervisor can always kill a runaway, so a wall-clock
  /// deadline is enforceable even when the engine itself offers nothing.
  bool get needsIsolateForSafety => !interruptHandler || !memoryLimit;

  List<String> get unenforced => [
        if (!memoryLimit) 'memory cap',
        if (!stackLimit) 'stack limit',
        if (!interruptHandler) 'CPU interrupt',
      ];
}

/// The engine as seen from inside the worker isolate.
///
/// Kept tiny so the supervisor can be tested with a fake engine: the real
/// QuickJS binding cannot load on a Linux test host, which is why no test had
/// ever executed plugin code before.
abstract interface class JsWorkerEngine {
  JsEngineCapabilities get capabilities;
  Future<void> initialise(String code);
  /// [callbackStyle] selects SkyStream's `fn(args…, cb)` convention instead of
  /// a returned Promise. Threaded through so all three ecosystems can run here.
  Future<Object?> call(String fn, List<Object?> args, {bool callbackStyle});
  Future<void> dispose();
}

/// Everything an engine needs, sent across the isolate boundary.
class JsWorkerConfig {
  const JsWorkerConfig({
    required this.pluginName,
    required this.code,
    this.policy = const JsSandboxPolicy(),
  });
  final String pluginName;
  final String code;
  final JsSandboxPolicy policy;
}

/// Creates an engine inside the worker. Must be a top-level or static function
/// so it can be sent across the isolate boundary.
typedef JsWorkerEngineFactory = JsWorkerEngine Function(JsWorkerConfig config);

class _Spawn {
  const _Spawn(this.port, this.factory, this.code, this.pluginName, this.policy);
  final SendPort port;
  final JsWorkerEngineFactory factory;
  final String code;
  final String pluginName;
  final JsSandboxPolicy policy;
}

class _CallMsg {
  const _CallMsg(this.id, this.fn, this.args, this.callbackStyle);
  final int id;
  final String fn;
  final List<Object?> args;
  final bool callbackStyle;
}

/// Runs one plugin in its own isolate and kills it if it overruns.
///
/// Why this exists: `flutter_js`'s `evaluate` is a **synchronous** FFI call. On
/// the UI isolate a plugin containing `while (true) {}` blocks the event loop,
/// so a `Future.timeout` can never fire — the app freezes permanently, not for
/// the configured 20 s. Moving execution into a worker keeps the UI isolate
/// free, which makes the deadline real: on breach we terminate the isolate.
class JsWorker {
  JsWorker._(this._isolate, this._toWorker, this._responses, this.pluginName,
      this.capabilities);

  final Isolate _isolate;
  final SendPort _toWorker;
  final Stream<dynamic> _responses;
  final String pluginName;
  final JsEngineCapabilities capabilities;

  final Map<int, Completer<Object?>> _pending = {};
  StreamSubscription<dynamic>? _sub;
  int _seq = 0;
  bool _dead = false;

  /// True until the worker is disposed or killed for overrunning.
  bool get isAlive => !_dead;

  static Future<JsWorker> spawn({
    required String pluginName,
    required String code,
    required JsWorkerEngineFactory factory,
    JsSandboxPolicy policy = const JsSandboxPolicy(),
    Duration bootTimeout = const Duration(seconds: 20),
  }) async {
    final fromWorker = ReceivePort();
    final errors = ReceivePort();
    final exits = ReceivePort();

    final isolate = await Isolate.spawn<_Spawn>(
      _workerMain,
      _Spawn(fromWorker.sendPort, factory, code, pluginName, policy),
      onError: errors.sendPort,
      onExit: exits.sendPort,
      debugName: 'plugin:$pluginName',
    );

    final broadcast = fromWorker.asBroadcastStream();
    // First message is the worker's SendPort, then the boot result.
    final ready = await broadcast.first.timeout(bootTimeout);
    if (ready is! SendPort) {
      isolate.kill(priority: Isolate.immediate);
      fromWorker.close();
      errors.close();
      exits.close();
      throw StateError('Worker did not start');
    }

    final boot = await broadcast.first.timeout(bootTimeout);
    final caps = boot is Map && boot['capabilities'] is JsEngineCapabilities
        ? boot['capabilities'] as JsEngineCapabilities
        : const JsEngineCapabilities(name: 'unknown');

    if (boot is Map && boot['error'] != null) {
      isolate.kill(priority: Isolate.immediate);
      fromWorker.close();
      errors.close();
      exits.close();
      throw StateError('${boot['error']}');
    }

    final worker = JsWorker._(isolate, ready, broadcast, pluginName, caps);
    worker._listen(errors, exits);
    return worker;
  }

  void _listen(ReceivePort errors, ReceivePort exits) {
    _sub = _responses.listen((msg) {
      if (msg is! Map) return;
      if (msg['log'] != null) {
        AeroLog.instance.i('js:$pluginName', '${msg['log']}');
        return;
      }
      final id = msg['id'] as int?;
      if (id == null) return;
      final c = _pending.remove(id);
      if (c == null || c.isCompleted) return;
      if (msg['error'] != null) {
        c.completeError(StateError('${msg['error']}'));
      } else {
        c.complete(msg['value']);
      }
    });

    errors.listen((e) {
      _failAll('Plugin crashed: ${e is List ? e.first : e}');
    });
    exits.listen((_) {
      _failAll('Plugin worker exited');
    });
  }

  void _failAll(String reason) {
    _dead = true;
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(StateError(reason));
    }
    _pending.clear();
  }

  /// Calls [fn] and enforces [deadline] by killing the isolate on breach.
  ///
  /// A killed worker is not reusable: the caller must spawn a fresh one. That
  /// is deliberate — a context that ran away is not trustworthy.
  Future<Result<Object?>> call(
    String fn,
    List<Object?> args, {
    Duration deadline = const Duration(seconds: 20),
    bool callbackStyle = false,
  }) async {
    if (_dead) return const Err('Plugin worker is no longer running');
    final id = ++_seq;
    final c = Completer<Object?>();
    _pending[id] = c;
    _toWorker.send(_CallMsg(id, fn, args, callbackStyle));

    try {
      final value = await c.future.timeout(deadline);
      return Ok(value);
    } on TimeoutException {
      // The whole point: the UI isolate is free, so this actually fires.
      _kill('exceeded ${deadline.inSeconds}s');
      return Err('Plugin "$pluginName" exceeded ${deadline.inSeconds}s '
          'and was terminated');
    } catch (e) {
      return Err('$e');
    }
  }

  void _kill(String reason) {
    AeroLog.instance.w('js:$pluginName', 'Terminated: $reason');
    _isolate.kill(priority: Isolate.immediate);
    _failAll('Plugin terminated: $reason');
  }

  Future<void> dispose() async {
    if (_dead) return;
    _dead = true;
    _toWorker.send('dispose');
    // Give it a moment to release native resources, then force it.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    _isolate.kill(priority: Isolate.immediate);
    await _sub?.cancel();
    _pending.clear();
  }
}

/// Worker entry point. Owns the engine; never touches the UI.
Future<void> _workerMain(_Spawn spawn) async {
  final commands = ReceivePort();
  spawn.port.send(commands.sendPort);

  // The worker has its own AeroLog; forward entries so the in-app log viewer
  // and per-plugin export still see plugin console output.
  final stopLogs = AeroLog.instance.listen((e) {
    spawn.port.send({'log': e.toString()});
  });

  JsWorkerEngine? engine;
  try {
    engine = spawn.factory(JsWorkerConfig(
      pluginName: spawn.pluginName,
      code: spawn.code,
      policy: spawn.policy,
    ));
    await engine.initialise(spawn.code);
    spawn.port.send({'capabilities': engine.capabilities});
  } catch (e) {
    spawn.port.send({'error': 'Plugin failed to load: $e'});
    stopLogs();
    commands.close();
    return;
  }

  await for (final msg in commands) {
    if (msg == 'dispose') {
      await engine.dispose();
      stopLogs();
      commands.close();
      return;
    }
    if (msg is! _CallMsg) continue;
    try {
      final value = await engine.call(msg.fn, msg.args,
          callbackStyle: msg.callbackStyle);
      spawn.port.send({'id': msg.id, 'value': value});
    } catch (e) {
      spawn.port.send({'id': msg.id, 'error': '$e'});
    }
  }
}
