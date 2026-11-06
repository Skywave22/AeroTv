import 'dart:async';

import 'package:aero_core/aero_core.dart';
import 'package:test/test.dart';

void main() {
  group('happy path', () {
    test('every supported step runs and passes', () async {
      final r = await PluginDiagnostics.run('p', probes: {
        'Home': () async => const ProbeResult(count: 5),
        'Search': () async => const ProbeResult(count: 2),
        'Streams': () async => const ProbeResult(count: 9),
      });
      expect(r.ok, isTrue);
      expect(r.steps.map((s) => s.status),
          everyElement(DiagnosticStatus.pass));
      expect(r.summary, contains('All checks passed'));
      expect(r.failKind, isNull);
    });

    test('steps run in the declared order', () async {
      final order = <String>[];
      await PluginDiagnostics.run('p', probes: {
        'Home': () async { order.add('home'); return const ProbeResult(); },
        'Search': () async { order.add('search'); return const ProbeResult(); },
      });
      expect(order, ['home', 'search']);
    });

    test('elapsed time is measured per step and totalled', () async {
      final r = await PluginDiagnostics.run('p', probes: {
        'Slow': () async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return const ProbeResult(count: 1);
        },
      });
      expect(r.steps.single.elapsed.inMilliseconds, greaterThanOrEqualTo(25));
      expect(r.total, r.steps.single.elapsed);
    });
  });

  group('empty is not broken', () {
    test('zero results is a warning, and the report is still ok', () async {
      final r = await PluginDiagnostics.run('p', probes: {
        'Search': () async => const ProbeResult(count: 0),
      });
      expect(r.ok, isTrue);
      expect(r.steps.single.status, DiagnosticStatus.warn);
      expect(r.steps.single.label, 'Empty');
      expect(r.summary, contains('returned nothing'));
    });

    test('a null count is not treated as empty', () async {
      final r = await PluginDiagnostics.run('p', probes: {
        'Ping': () async => const ProbeResult(detail: 'reachable'),
      });
      expect(r.steps.single.status, DiagnosticStatus.pass);
    });
  });

  group('capability awareness', () {
    test('an unsupported step is skipped, not failed', () async {
      final r = await PluginDiagnostics.run('p', probes: {
        'Home': null,
        'Streams': () async => const ProbeResult(count: 3),
      });
      expect(r.ok, isTrue);
      expect(r.steps.first.status, DiagnosticStatus.skipped);
      expect(r.steps.first.detail, 'not supported');
      expect(r.steps.last.status, DiagnosticStatus.pass);
    });

    test('a stream-only plugin reports a clean bill of health', () async {
      final r = await PluginDiagnostics.run('nuvio:x', probes: {
        'Home': null,
        'Search': null,
        'Streams': () async => const ProbeResult(count: 4),
      });
      expect(r.ok, isTrue);
      expect(r.summary, contains('All checks passed'));
    });

    test('a plugin with nothing testable says so', () async {
      final r = await PluginDiagnostics.run('p',
          probes: {'Home': null, 'Search': null});
      expect(r.summary, contains('no testable capabilities'));
    });
  });

  group('failure handling', () {
    test('a throwing probe produces a report, never an exception', () async {
      final r = await PluginDiagnostics.run('p', probes: {
        'Home': () async => throw StateError('plugin exploded'),
      });
      expect(r.ok, isFalse);
      expect(r.steps.single.status, DiagnosticStatus.fail);
      expect(r.firstFailure!.name, 'Home');
      expect(r.summary, contains('Home failed'));
    });

    test('later steps are skipped after a failure', () async {
      var ran = false;
      final r = await PluginDiagnostics.run('p', probes: {
        'Home': () async => throw Exception('down'),
        'Search': () async { ran = true; return const ProbeResult(); },
      });
      expect(ran, isFalse);
      expect(r.steps.last.status, DiagnosticStatus.skipped);
      expect(r.steps.last.detail, 'skipped after a failure');
    });

    test('stopOnFailure: false runs every step', () async {
      var ran = false;
      final r = await PluginDiagnostics.run('p', stopOnFailure: false, probes: {
        'Home': () async => throw Exception('down'),
        'Search': () async { ran = true; return const ProbeResult(count: 1); },
      });
      expect(ran, isTrue);
      expect(r.steps.last.status, DiagnosticStatus.pass);
      expect(r.firstFailure!.name, 'Home');
    });

    test('a hanging probe times out instead of wedging the screen', () async {
      final r = await PluginDiagnostics.run(
        'p',
        perStepTimeout: const Duration(milliseconds: 60),
        probes: {'Home': () => Completer<ProbeResult>().future},
      );
      expect(r.ok, isFalse);
      expect(r.failKind, FailKind.timeout);
    });
  });

  group('failure classification matches the circuit breaker', () {
    const cases = <String, FailKind>{
      'TimeoutException after 20s': FailKind.timeout,
      'SocketException: Failed host lookup': FailKind.network,
      'Connection refused': FailKind.network,
      'DioException 503 from host': FailKind.http5xx,
      'URL blocked by sandbox policy': FailKind.sandboxBlocked,
      'FormatException: Unexpected character': FailKind.badShape,
      "type 'String' is not a subtype of type 'Map'": FailKind.badShape,
      'Something went wrong': FailKind.exception,
    };
    cases.forEach((message, expected) {
      test('"$message" -> ${expected.name}', () {
        expect(PluginDiagnostics.classify(Exception(message)), expected);
      });
    });

    test('a diagnostic failure feeds the breaker the same kind', () async {
      final breaker = CircuitBreaker();
      final r = await PluginDiagnostics.run('p', probes: {
        'Home': () async => throw Exception('SocketException: no route'),
      });
      breaker.onFail('p', r.failKind!);
      expect(breaker.stateOf('p').lastError, FailKind.network);
    });

    test('a long error message is truncated for the UI', () {
      final d = PluginDiagnostics.describe(
          Exception('x' * 500), FailKind.exception);
      expect(d.length, lessThan(200));
      expect(d, contains('...'));
    });
  });

  group('reporting', () {
    test('toText lists every step with its timing', () async {
      final r = await PluginDiagnostics.run('vega:demo', probes: {
        'Home': () async => const ProbeResult(count: 7),
        'Streams': () async => throw Exception('Connection refused'),
      });
      final text = r.toText();
      expect(text, contains('vega:demo'));
      expect(text, contains('Home'));
      expect(text, contains('(7 items)'));
      expect(text, contains('Failed'));
      expect(text, contains('ms'));
    });
  });
}
