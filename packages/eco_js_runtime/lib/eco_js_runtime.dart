/// Sandboxed JavaScript host for the Vega / Nuvio / SkyStream ecosystems.
///
/// Every plugin runs in its own context with a memory cap, a wall-clock
/// timeout, and **no** direct network or file access: all I/O is brokered by
/// Dart so it can be logged, rate-limited and blocked.
library;

export 'src/js_host.dart';
export 'src/js_sandbox_policy.dart';
export 'src/host_api_shim.dart';
export 'src/js_plugin_bundle.dart';
export 'src/js_ecosystem_adapter.dart';
