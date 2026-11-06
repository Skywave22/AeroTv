import 'package:flutter_js/flutter_js.dart';

import 'js_host.dart' show JsCallStyle, JsPluginHost;
import 'js_plugin_bundle.dart';
import 'js_worker.dart';

/// Adapts the existing QuickJS host to the worker-isolate engine interface.
///
/// Capability reporting is deliberately pessimistic: `flutter_js` exposes no
/// memory-limit, stack-limit or interrupt-handler API that we can verify. The
/// previous code called a `__setMemoryLimit` global that does not exist behind
/// a `typeof` guard, so a memory cap was silently absent. Saying so lets the
/// supervisor know it must rely on isolate termination for safety.
class FlutterJsWorkerEngine implements JsWorkerEngine {
  FlutterJsWorkerEngine(this._config);

  final JsWorkerConfig _config;
  JsPluginHost? _host;

  @override
  JsEngineCapabilities get capabilities => const JsEngineCapabilities(
        name: 'flutter_js/quickjs',
        // Not exposed by the plugin API; do not claim otherwise.
        memoryLimit: false,
        stackLimit: false,
        interruptHandler: false,
      );

  @override
  Future<void> initialise(String code) async {
    final host = JsPluginHost(
      pluginId: _config.pluginName,
      pluginName: _config.pluginName,
      policy: _config.policy,
    );
    final res = await host.initialise(JsPluginBundle(
      sourceUrl: 'worker://${_config.pluginName}',
      code: code,
      manifest: const {},
      sha256: JsPluginBundle.hashOf(code),
    ));
    if (res.isErr) throw StateError(res.errorOrNull!);
    _host = host;
  }

  @override
  Future<Object?> call(String fn, List<Object?> args,
      {bool callbackStyle = false}) async {
    final host = _host;
    if (host == null) throw StateError('Engine not initialised');
    final res = await host.call(
      fn,
      args,
      callbackStyle ? JsCallStyle.callback : JsCallStyle.promise,
    );
    if (res.isErr) throw StateError(res.errorOrNull!);
    return res.valueOrNull;
  }

  @override
  Future<void> dispose() async {
    await _host?.dispose();
    _host = null;
  }
}

/// Top-level factory so it can be sent to the worker isolate.
JsWorkerEngine flutterJsEngine(JsWorkerConfig config) =>
    FlutterJsWorkerEngine(config);

/// True when the QuickJS native library is actually loadable here.
///
/// Tests on a Linux host cannot load `libquickjs_c_bridge_plugin.so`, which is
/// why no test had ever executed plugin code. Callers can use this to skip
/// real-engine assertions instead of silently passing.
bool quickJsAvailable() {
  try {
    final rt = getJavascriptRuntime(xhr: false);
    final ok = !rt.evaluate('1').isError;
    rt.dispose();
    return ok;
  } catch (_) {
    return false;
  }
}
