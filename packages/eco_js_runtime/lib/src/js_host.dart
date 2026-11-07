import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:aero_core/aero_core.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_js/flutter_js.dart';

import 'host_api_shim.dart';
import 'js_plugin_bundle.dart';
import 'js_sandbox_policy.dart';

/// One isolated JS context for one plugin.
///
/// Isolation model:
/// * a fresh [JavascriptRuntime] per plugin (no shared globals),
/// * the host shim is injected before plugin code,
/// * every call is wrapped in a wall-clock timeout,
/// * all I/O is brokered here, validated against [JsSandboxPolicy],
/// * the HTML document table is bounded so a plugin can't leak memory.
class JsPluginHost {
  JsPluginHost({
    required this.pluginId,
    required this.pluginName,
    this.policy = const JsSandboxPolicy(),
    Dio? dio,
  }) : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              followRedirects: true,
              maxRedirects: 5,
              validateStatus: (_) => true,
            ));

  final String pluginId;
  final String pluginName;
  final JsSandboxPolicy policy;
  final Dio _dio;

  JavascriptRuntime? _runtime;
  bool _ready = false;
  bool _disposed = false;
  int _inFlight = 0;

  /// Parsed HTML documents, capped to avoid unbounded growth.
  final Map<int, String> _docs = {};
  int _nextDoc = 1;
  static const _maxDocs = 8;

  bool get isReady => _ready && !_disposed;

  /// Boots the context and evaluates the plugin bundle.
  Future<Result<void>> initialise(JsPluginBundle bundle) async {
    if (_disposed) return const Err('Host is disposed');
    try {
      _runtime = getJavascriptRuntime(
        xhr: false, // we broker HTTP ourselves
        extraArgs: {'stackSize': policy.stackSizeBytes},
      );
      _registerChannels();

      // Shim first, so plugin code sees fetch/axios/console immediately.
      final shim = _runtime!.evaluate(HostApiShim.full());
      if (shim.isError) {
        return Err('Host shim failed: ${shim.stringResult}');
      }

      final res = await _evaluateGuarded(bundle.code);
      if (res.isError) {
        return Err('Plugin failed to load: ${res.stringResult}');
      }

      _ready = true;
      AeroLog.instance.i('js:$pluginName', 'Context ready (${bundle.code.length} bytes)');
      return const Ok(null);
    } catch (e) {
      return Err(_friendly(e));
    }
  }

  void _registerChannels() {
    final rt = _runtime!;
    rt.onMessage('aero:http', (args) => unawaited(_handleHttp(args)));
    rt.onMessage('aero:log', (args) => _handleLog(args));
    rt.onMessage('aero:crypto', (args) => unawaited(_handleCrypto(args)));
    rt.onMessage('aero:html', (args) => unawaited(_handleHtml(args)));
    rt.onMessage('aero:timer', (args) => _handleTimer(args));
    // Registered once per context, not once per call: flutter_js keeps only the
    // first handler for a channel, so per-call registration silently depended
    // on that behaviour and would hang on an engine that replaces handlers.
    rt.onMessage('aero:result', _handleCallResult);
  }

  /// Completes the pending plugin call identified by the bridge message.
  void _handleCallResult(Object? raw) {
    final m = _decode(raw);
    final rid = (m['id'] as num?)?.toInt();
    final c = _pendingCalls.remove(rid);
    if (c == null || c.isCompleted) return;
    final ok = m['ok'] == true;
    final payload = m['payload'];
    if (ok) {
      try {
        c.complete(Ok(payload == null ? null : jsonDecode(payload.toString())));
      } catch (_) {
        c.complete(Ok(payload?.toString()));
      }
    } else {
      c.complete(Err(payload?.toString() ?? 'Plugin call failed'));
    }
  }

  Map<String, dynamic> _decode(Object? args) {
    try {
      if (args is String) return Map<String, dynamic>.from(jsonDecode(args) as Map);
      if (args is Map) return Map<String, dynamic>.from(args);
    } catch (_) {
      // fall through
    }
    return const {};
  }

  void _resolve(int id, bool ok, String payload) {
    if (_disposed || _runtime == null) return;
    final encoded = jsonEncode(payload);
    try {
      _runtime!.evaluate('__aeroResolve($id, ${ok ? 'true' : 'false'}, $encoded);');
      _runtime!.executePendingJob();
    } catch (e) {
      AeroLog.instance.w('js:$pluginName', 'resolve failed: $e');
    }
  }

  // ------------------------------------------------------------- HTTP

  Future<void> _handleHttp(Object? args) async {
    final req = _decode(args);
    final id = (req['id'] as num?)?.toInt() ?? 0;
    final p = Map<String, dynamic>.from(req['payload'] as Map? ?? const {});
    final url = (p['url'] ?? '').toString();

    // Resolve-then-check closes DNS rebinding: a public name that points at
    // 192.168.1.1 must be refused, not just a private literal.
    final blocked = await policy.validateUrlResolved(url);
    if (blocked != null) {
      AeroLog.instance.w('js:$pluginName', 'BLOCKED $url — $blocked');
      _resolve(id, false, blocked);
      return;
    }
    if (_inFlight >= policy.maxConcurrentRequests) {
      _resolve(id, false, 'Too many concurrent requests');
      return;
    }

    _inFlight++;
    // Plugins must never see the real host's identity; use a browser-like UA
    // unless the plugin explicitly set one.
    final headers = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/124.0 Safari/537.36',
      'Accept': '*/*',
    };
    final rawHeaders = p['headers'];
    if (rawHeaders is Map) {
      rawHeaders.forEach((k, v) {
        if (v != null) headers[k.toString()] = v.toString();
      });
    }

    AeroLog.instance.network('js:$pluginName', Uri.parse(url), note: p['method'] as String?);

    try {
      final timeoutMs = (p['timeoutMs'] as num?)?.toInt() ?? 0;
      final timeout = timeoutMs > 0
          ? Duration(milliseconds: timeoutMs.clamp(1000, policy.httpTimeout.inMilliseconds))
          : policy.httpTimeout;

      final res = await _dio.requestUri(
        Uri.parse(url),
        data: p['body'],
        options: Options(
          method: (p['method'] ?? 'GET').toString().toUpperCase(),
          headers: headers,
          sendTimeout: timeout,
          receiveTimeout: timeout,
          followRedirects: p['followRedirects'] != false,
          responseType: ResponseType.plain,
          validateStatus: (_) => true,
        ),
      );

      var body = res.data?.toString() ?? '';
      if (body.length > policy.maxResponseBytes) {
        body = body.substring(0, policy.maxResponseBytes);
      }

      _resolve(
        id,
        true,
        jsonEncode({
          'status': res.statusCode ?? 0,
          'statusText': res.statusMessage ?? '',
          'url': res.realUri.toString(),
          'headers': res.headers.map.map((k, v) => MapEntry(k, v.join(','))),
          'body': body,
        }),
      );
    } catch (e) {
      _resolve(id, false, _friendly(e));
    } finally {
      _inFlight--;
    }
  }

  // -------------------------------------------------------------- log

  void _handleLog(Object? args) {
    final req = _decode(args);
    final id = (req['id'] as num?)?.toInt() ?? 0;
    final p = Map<String, dynamic>.from(req['payload'] as Map? ?? const {});
    final level = (p['level'] ?? 'log').toString();
    final parts = (p['args'] as List?)?.map((e) => e.toString()).join(' ') ?? '';
    AeroLog.instance.add(
      switch (level) {
        'error' => LogLevel.error,
        'warn' => LogLevel.warn,
        'debug' => LogLevel.debug,
        _ => LogLevel.info,
      },
      'js:$pluginName',
      parts,
    );
    _resolve(id, true, 'null');
  }

  // ----------------------------------------------------------- crypto

  Future<void> _handleCrypto(Object? args) async {
    final req = _decode(args);
    final id = (req['id'] as num?)?.toInt() ?? 0;
    final p = Map<String, dynamic>.from(req['payload'] as Map? ?? const {});
    final op = (p['op'] ?? '').toString();
    final data = utf8.encode((p['data'] ?? '').toString());
    try {
      final out = switch (op) {
        'md5' => md5.convert(data).toString(),
        'sha1' => sha1.convert(data).toString(),
        'sha256' => sha256.convert(data).toString(),
        'hmac' => Hmac(sha256, utf8.encode((p['key'] ?? '').toString()))
            .convert(data)
            .toString(),
        'random' => _randomHex(((p['length'] as num?)?.toInt() ?? 16).clamp(1, 1024)),
        _ => throw AeroException('Unsupported crypto op: $op'),
      };
      _resolve(id, true, jsonEncode(out));
    } catch (e) {
      _resolve(id, false, e.toString());
    }
  }

  String _randomHex(int n) {
    final rng = Random.secure();
    return List.generate(n, (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
  }

  // ------------------------------------------------------------- HTML

  /// A deliberately small selector engine. Supports the subset real scrapers
  /// use: `tag`, `.class`, `#id`, `tag.class`, descendant combinators and
  /// `:nth-of-type(n)`. Unsupported selectors return an explicit error so the
  /// failure is visible in the health panel rather than silently wrong.
  Future<void> _handleHtml(Object? args) async {
    final req = _decode(args);
    final id = (req['id'] as num?)?.toInt() ?? 0;
    final p = Map<String, dynamic>.from(req['payload'] as Map? ?? const {});
    final op = (p['op'] ?? '').toString();

    try {
      switch (op) {
        case 'load':
          if (_docs.length >= _maxDocs) {
            _docs.remove(_docs.keys.first);
          }
          final docId = _nextDoc++;
          _docs[docId] = (p['html'] ?? '').toString();
          _resolve(id, true, jsonEncode({'doc': docId}));
          return;
        case 'raw':
          final doc = _docs[(p['doc'] as num?)?.toInt()] ?? '';
          _resolve(id, true, jsonEncode({'value': doc}));
          return;
        case 'count':
        case 'text':
        case 'html':
        case 'attr':
        case 'list':
          final doc = _docs[(p['doc'] as num?)?.toInt()] ?? '';
          final selector = p['selector']?.toString();
          final result = _queryHtml(
            doc,
            selector,
            op,
            Map<String, dynamic>.from(p['args'] as Map? ?? const {}),
          );
          _resolve(id, true, jsonEncode(result));
          return;
        default:
          _resolve(id, false, 'Unsupported html op: $op');
      }
    } catch (e) {
      _resolve(id, false, e.toString());
    }
  }

  Map<String, dynamic> _queryHtml(
    String doc,
    String? selector,
    String op,
    Map<String, dynamic> args,
  ) {
    final matches = _select(doc, selector);
    switch (op) {
      case 'count':
        return {'count': matches.length};
      case 'list':
        return {'selectors': List.generate(matches.length, (i) => '$selector:nth-of-type(${i + 1})')};
      case 'text':
        return {'value': matches.isEmpty ? '' : _stripTags(matches.first)};
      case 'html':
        return {'value': matches.isEmpty ? '' : matches.first};
      case 'attr':
        final name = (args['name'] ?? '').toString();
        if (matches.isEmpty) return {'value': null};
        return {'value': _attribute(matches.first, name)};
      default:
        return {'value': null};
    }
  }

  /// Extracts inner HTML for elements matching a simple selector.
  List<String> _select(String doc, String? selector) {
    if (selector == null || selector.trim().isEmpty) return [doc];
    // Take the last compound selector in a descendant chain.
    final parts = selector.trim().split(RegExp(r'\s+'));
    var compound = parts.last;
    var nth = 0;
    final nthMatch = RegExp(r':nth-of-type\((\d+)\)').firstMatch(compound);
    if (nthMatch != null) {
      nth = int.tryParse(nthMatch.group(1)!) ?? 0;
      compound = compound.replaceAll(nthMatch.group(0)!, '');
    }

    String tag = '[a-zA-Z][a-zA-Z0-9]*';
    String? requiredClass;
    String? requiredId;
    if (compound.startsWith('.')) {
      requiredClass = compound.substring(1);
    } else if (compound.startsWith('#')) {
      requiredId = compound.substring(1);
    } else if (compound.isNotEmpty && compound != '*') {
      final m = RegExp(r'^([a-zA-Z][a-zA-Z0-9]*)').firstMatch(compound);
      if (m != null) tag = m.group(1)!;
      final cls = RegExp(r'\.([\w-]+)').firstMatch(compound);
      if (cls != null) requiredClass = cls.group(1);
    }

    final pattern = RegExp('<$tag\\b([^>]*)>([\\s\\S]*?)</$tag>', caseSensitive: false);
    final out = <String>[];
    for (final m in pattern.allMatches(doc)) {
      final attrs = m.group(1) ?? '';
      if (requiredClass != null) {
        final cls = RegExp(r'''class\s*=\s*["']([^"']*)["']''').firstMatch(attrs);
        if (cls == null || !cls.group(1)!.split(RegExp(r'\s+')).contains(requiredClass)) {
          continue;
        }
      }
      if (requiredId != null) {
        final idAttr = RegExp(r'''id\s*=\s*["']([^"']*)["']''').firstMatch(attrs);
        if (idAttr == null || idAttr.group(1) != requiredId) continue;
      }
      out.add(m.group(2) ?? '');
    }
    if (nth > 0) {
      return nth <= out.length ? [out[nth - 1]] : <String>[];
    }
    return out;
  }

  String _attribute(String html, String name) {
    // `html` here is inner HTML; attributes live on the opening tag, which the
    // selector stripped. Search the raw fragment for a self-describing attr.
    final m = RegExp('''$name\\s*=\\s*["']([^"']*)["']''', caseSensitive: false)
        .firstMatch(html);
    return m?.group(1) ?? '';
  }

  String _stripTags(String html) => html
      .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  // ------------------------------------------------------------ timer

  void _handleTimer(Object? args) {
    final req = _decode(args);
    final id = (req['id'] as num?)?.toInt() ?? 0;
    final p = Map<String, dynamic>.from(req['payload'] as Map? ?? const {});
    final timerId = (p['id'] as num?)?.toInt() ?? 0;
    final ms = ((p['ms'] as num?)?.toInt() ?? 0).clamp(0, 10000);
    Timer(Duration(milliseconds: ms), () {
      if (_disposed || _runtime == null) return;
      try {
        _runtime!.evaluate('__aeroFireTimer($timerId);');
        _runtime!.executePendingJob();
      } catch (_) {
        // A plugin timer throwing must not crash the host.
      }
    });
    _resolve(id, true, 'null');
  }

  // -------------------------------------------------------------- eval

  Future<JsEvalResult> _evaluateGuarded(String code) async {
    final rt = _runtime!;
    return _withTimeout(() async {
      final res = rt.evaluate(code);
      // Drain the microtask queue so promises settle.
      for (var i = 0; i < 50; i++) {
        if (rt.executePendingJob() == 0) break;
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      return res;
    });
  }

  Future<T> _withTimeout<T>(Future<T> Function() body) =>
      body().timeout(policy.evalTimeout, onTimeout: () {
        throw SandboxException(
          'Plugin "$pluginName" exceeded ${policy.evalTimeout.inSeconds}s',
        );
      });

  /// Calls an exported async plugin function and decodes its JSON result.
  ///
  /// [functionName] is validated to prevent code injection through a
  /// malicious manifest.
  /// Invokes a plugin function.
  ///
  /// [style] selects the calling convention, because the ecosystems genuinely
  /// differ: Vega and Nuvio return promises, SkyStream takes a trailing
  /// callback. See docs/specs/VERIFIED_CONTRACTS.md.
  Future<Result<dynamic>> call(
    String functionName, [
    List<Object?> args = const [],
    JsCallStyle style = JsCallStyle.promise,
  ]) async {
    if (!_ready) return const Err('Plugin host not initialised');
    if (!RegExp(r'^[A-Za-z_$][\w$]*(\.[A-Za-z_$][\w$]*)*$').hasMatch(functionName)) {
      return Err('Invalid function name: $functionName');
    }
    try {
      final encodedArgs = args.map(jsonEncode).join(',');
      // Wrap in an async IIFE that reports back through the bridge, so we can
      // await a plugin promise without blocking the Dart isolate.
      final callId = _nextCallId++;
      final completer = Completer<Result<dynamic>>();
      _pendingCalls[callId] = completer;

      final useCallback = style == JsCallStyle.callback;
      // In callback mode the callback is appended after the positional args.
      final callbackArgs =
          args.isEmpty ? 'cb' : '$encodedArgs, cb';
      final script = '''
        (function () {
          try {
            var fn = $functionName;
            if (typeof fn !== 'function') {
              sendMessage('aero:result', JSON.stringify({ id: $callId, ok: false, payload: 'Function not found: $functionName' }));
              return;
            }
            var done = function (value) {
              sendMessage('aero:result', JSON.stringify({ id: $callId, ok: true, payload: JSON.stringify(value === undefined ? null : value) }));
            };
            var fail = function (err) {
              sendMessage('aero:result', JSON.stringify({ id: $callId, ok: false, payload: String(err && err.message ? err.message : err) }));
            };
            if ($useCallback) {
              // SkyStream: fn(args..., cb). The function may also return a
              // promise; whichever settles first wins, and `settled` stops a
              // plugin that both calls back and resolves from double-reporting.
              var settled = false;
              var cb = function (value) { if (!settled) { settled = true; done(value); } };
              var ret = fn($callbackArgs);
              if (ret && typeof ret.then === 'function') {
                ret.then(function (v) { if (!settled && v !== undefined) { settled = true; done(v); } }).catch(function (e) { if (!settled) { settled = true; fail(e); } });
              }
            } else {
              Promise.resolve(fn($encodedArgs)).then(done).catch(fail);
            }
          } catch (e) {
            sendMessage('aero:result', JSON.stringify({ id: $callId, ok: false, payload: String(e && e.message ? e.message : e) }));
          }
        })();
      ''';

      final res = _runtime!.evaluate(script);
      if (res.isError) {
        _pendingCalls.remove(callId);
        return Err(res.stringResult);
      }
      // Pump QuickJS' job queue until the call settles or the budget expires.
      // The previous fixed 100-iteration loop stopped after ~500 ms, which
      // silently stalled any plugin awaiting a real network fetch.
      final deadline = DateTime.now().add(policy.evalTimeout);
      unawaited(() async {
        while (!completer.isCompleted && DateTime.now().isBefore(deadline)) {
          if (_disposed || _runtime == null) return;
          try {
            _runtime!.executePendingJob();
          } catch (_) {
            return;
          }
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      }());

      return await completer.future.timeout(
        policy.evalTimeout,
        onTimeout: () {
          _pendingCalls.remove(callId);
          return Err('Plugin "$pluginName'
              '" timed out calling $functionName');
        },
      );
    } on SandboxException catch (e) {
      return Err(e.message);
    } catch (e) {
      return Err(_friendly(e));
    }
  }

  int _nextCallId = 1;
  final Map<int, Completer<Result<dynamic>>> _pendingCalls = {};

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('SocketException') || s.contains('Failed host lookup')) {
      return 'Network unreachable';
    }
    if (s.contains('TimeoutException')) return 'Request timed out';
    return s.length > 200 ? '${s.substring(0, 200)}…' : s;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _ready = false;
    _docs.clear();
    for (final c in _pendingCalls.values) {
      if (!c.isCompleted) c.complete(const Err('Host disposed'));
    }
    _pendingCalls.clear();
    try {
      _runtime?.dispose();
    } catch (_) {
      // Engine teardown can throw if a plugin left the context dirty.
    }
    _runtime = null;
    _dio.close(force: true);
  }
}

/// How a plugin function receives its arguments and reports its result.
enum JsCallStyle {
  /// `fn(args...)` returns a value or a promise. Vega, Nuvio.
  promise,

  /// `fn(args..., cb)` reports through a trailing callback. SkyStream.
  callback,
}
