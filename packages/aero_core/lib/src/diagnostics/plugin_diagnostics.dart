/// The "Run test" action in the Extensions Manager.
///
/// Exercises a plugin's declared capabilities in order and reports which step
/// broke, so a user can tell "the repo is down" apart from "search works but
/// streams are empty" without reading a log.
///
/// The runner never throws: a plugin that crashes must produce a report, not
/// take the diagnostics screen down with it.
library;

import '../resolver/circuit_breaker.dart';

enum DiagnosticStatus { pass, warn, fail, skipped }

/// What a probe reports back when it succeeds.
class ProbeResult {
  const ProbeResult({this.count, this.detail});

  /// How many items came back. Zero is a warning, not a failure: the plugin
  /// answered correctly, it just had nothing.
  final int? count;
  final String? detail;
}

typedef DiagnosticProbe = Future<ProbeResult> Function();

class DiagnosticStep {
  const DiagnosticStep({
    required this.name,
    required this.status,
    required this.elapsed,
    this.detail,
    this.count,
    this.failKind,
  });

  final String name;
  final DiagnosticStatus status;
  final Duration elapsed;
  final String? detail;
  final int? count;
  final FailKind? failKind;

  bool get failed => status == DiagnosticStatus.fail;

  String get label => switch (status) {
        DiagnosticStatus.pass => 'OK',
        DiagnosticStatus.warn => 'Empty',
        DiagnosticStatus.fail => 'Failed',
        DiagnosticStatus.skipped => 'Skipped',
      };
}

class DiagnosticReport {
  DiagnosticReport({
    required this.sourceKey,
    required this.steps,
    required this.startedAt,
  });

  final String sourceKey;
  final List<DiagnosticStep> steps;
  final DateTime startedAt;

  Duration get total => steps.fold(Duration.zero, (a, s) => a + s.elapsed);

  /// True when nothing failed. An empty result is still a working plugin.
  bool get ok => !steps.any((s) => s.failed);

  /// The first failing step, which is the one worth showing the user.
  DiagnosticStep? get firstFailure => steps.where((s) => s.failed).firstOrNull;

  /// The failure kind to feed the circuit breaker, if any.
  FailKind? get failKind => firstFailure?.failKind;

  String get summary {
    if (steps.every((s) => s.status == DiagnosticStatus.skipped)) {
      return 'Nothing to test: this source declares no testable capabilities.';
    }
    final f = firstFailure;
    if (f != null) return '${f.name} failed: ${f.detail ?? "unknown error"}';
    final warns = steps.where((s) => s.status == DiagnosticStatus.warn).length;
    if (warns > 0) return 'Working, but $warns step(s) returned nothing.';
    return 'All checks passed in ${total.inMilliseconds} ms.';
  }

  String toText() {
    final b = StringBuffer('Diagnostics for $sourceKey\n');
    for (final s in steps) {
      b.write('  ${s.label.padRight(8)} ${s.name.padRight(12)} '
          '${s.elapsed.inMilliseconds} ms');
      if (s.count != null) b.write('  (${s.count} items)');
      if (s.detail != null) b.write('  — ${s.detail}');
      b.write('\n');
    }
    b.write('$summary\n');
    return b.toString();
  }
}

abstract final class PluginDiagnostics {
  /// Runs [probes] in order. A null probe is reported as skipped, which is how
  /// a stream-only plugin shows "Home: skipped" rather than "Home: failed".
  ///
  /// Stops after the first failure by default: later steps almost always fail
  /// for the same reason, and re-running them just wastes the user's time.
  static Future<DiagnosticReport> run(
    String sourceKey, {
    required Map<String, DiagnosticProbe?> probes,
    Duration perStepTimeout = const Duration(seconds: 30),
    bool stopOnFailure = true,
    DateTime Function()? clock,
  }) async {
    final now = clock ?? DateTime.now;
    final started = now();
    final steps = <DiagnosticStep>[];
    var halted = false;

    for (final entry in probes.entries) {
      final probe = entry.value;
      if (halted || probe == null) {
        steps.add(DiagnosticStep(
          name: entry.key,
          status: DiagnosticStatus.skipped,
          elapsed: Duration.zero,
          detail: probe == null ? 'not supported' : 'skipped after a failure',
        ));
        continue;
      }

      final sw = Stopwatch()..start();
      try {
        final r = await probe().timeout(perStepTimeout);
        sw.stop();
        final empty = r.count != null && r.count == 0;
        steps.add(DiagnosticStep(
          name: entry.key,
          status: empty ? DiagnosticStatus.warn : DiagnosticStatus.pass,
          elapsed: sw.elapsed,
          count: r.count,
          detail: r.detail,
        ));
      } catch (e) {
        sw.stop();
        final kind = classify(e);
        steps.add(DiagnosticStep(
          name: entry.key,
          status: DiagnosticStatus.fail,
          elapsed: sw.elapsed,
          detail: describe(e, kind),
          failKind: kind,
        ));
        if (stopOnFailure) halted = true;
      }
    }

    return DiagnosticReport(
        sourceKey: sourceKey, steps: steps, startedAt: started);
  }

  /// Maps an exception onto the same vocabulary the circuit breaker uses, so
  /// a diagnostic failure and a live failure are counted identically.
  static FailKind classify(Object error) {
    final s = error.toString().toLowerCase();
    if (s.contains('blocked') || s.contains('not allowed')) {
      return FailKind.sandboxBlocked;
    }
    if (s.contains('timeout') || s.contains('timed out')) {
      return FailKind.timeout;
    }
    if (s.contains('socket') ||
        s.contains('connection') ||
        s.contains('network') ||
        s.contains('failed host lookup')) {
      return FailKind.network;
    }
    if (RegExp(r'\b5\d\d\b').hasMatch(s)) return FailKind.http5xx;
    if (s.contains('format') ||
        s.contains("type '") ||
        s.contains('unexpected') ||
        s.contains('nosuchmethod')) {
      return FailKind.badShape;
    }
    return FailKind.exception;
  }

  static String describe(Object error, FailKind kind) {
    final raw = error.toString().replaceFirst(RegExp(r'^\w+Exception: '), '');
    final trimmed = raw.length > 160 ? '${raw.substring(0, 157)}...' : raw;
    return '${kind.label}: $trimmed';
  }
}
