/// Per-source circuit breaker.
///
/// A plugin that is down should not be retried on every play: it adds latency
/// to the source sheet and hammers a dead host. After three consecutive
/// *errors* the source is skipped for a growing backoff, and one success closes
/// it again.
///
/// State is deliberately in-memory. A breaker is about the current session's
/// view of a host; persisting it would keep a source disabled across an app
/// restart long after the host recovered.
library;

/// Why a call failed. Only real errors trip the breaker.
enum FailKind {
  timeout,
  network,
  http5xx,
  badShape,
  sandboxBlocked,
  exception,

  /// The plugin worked and legitimately found nothing. Not a failure.
  noResults,
}

extension FailKindX on FailKind {
  bool get countsAsFailure => this != FailKind.noResults;

  String get label => switch (this) {
        FailKind.timeout => 'timed out',
        FailKind.network => 'network error',
        FailKind.http5xx => 'server error',
        FailKind.badShape => 'unexpected response',
        FailKind.sandboxBlocked => 'blocked by sandbox',
        FailKind.exception => 'plugin error',
        FailKind.noResults => 'no results',
      };
}

class BreakerState {
  BreakerState({
    this.consecutiveFails = 0,
    this.opens = 0,
    this.openUntil,
    this.lastError,
  });

  int consecutiveFails;
  int opens;
  DateTime? openUntil;
  FailKind? lastError;

  bool isOpen(DateTime now) => openUntil != null && openUntil!.isAfter(now);

  Duration? retryIn(DateTime now) =>
      isOpen(now) ? openUntil!.difference(now) : null;
}

class CircuitBreaker {
  CircuitBreaker({
    this.failureThreshold = 3,
    this.backoffSteps = const [
      Duration(minutes: 5),
      Duration(minutes: 15),
      Duration(hours: 1),
    ],
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final int failureThreshold;
  final List<Duration> backoffSteps;
  final DateTime Function() _now;

  final Map<String, BreakerState> _state = {};

  BreakerState stateOf(String sourceKey) =>
      _state.putIfAbsent(sourceKey, BreakerState.new);

  /// Whether a call to [sourceKey] may proceed right now.
  bool allows(String sourceKey) {
    final s = _state[sourceKey];
    if (s == null) return true;
    return !s.isOpen(_now());
  }

  /// Records an outcome. [FailKind.noResults] is a success for health purposes:
  /// the plugin answered, it just had nothing.
  void onFail(String sourceKey, FailKind kind) {
    if (!kind.countsAsFailure) {
      onOk(sourceKey);
      return;
    }
    final s = stateOf(sourceKey);
    final now = _now();
    s.consecutiveFails++;
    s.lastError = kind;
    if (s.consecutiveFails < failureThreshold) return;

    // Only trip on a *fresh* failure: either the circuit was closed, or it was
    // half-open (backoff expired) and this call is the failed probe. Extra
    // failures while already open must not keep escalating the backoff.
    if (s.isOpen(now)) return;

    final idx = s.opens.clamp(0, backoffSteps.length - 1);
    s.openUntil = now.add(backoffSteps[idx]);
    s.opens++;
  }

  void onOk(String sourceKey) {
    final s = _state[sourceKey];
    if (s == null) return;
    s.consecutiveFails = 0;
    s.opens = 0;
    s.openUntil = null;
    s.lastError = null;
  }

  /// User-initiated "Retry now": closes the circuit without waiting.
  void reset(String sourceKey) => onOk(sourceKey);

  void resetAll() => _state.clear();

  /// Human-readable status for the Extensions Manager health dot.
  String describe(String sourceKey) {
    final s = _state[sourceKey];
    if (s == null) return 'No calls yet';
    final wait = s.retryIn(_now());
    if (wait != null) {
      final mins = wait.inMinutes;
      final when = mins >= 60
          ? '${wait.inHours} h'
          : mins >= 1
              ? '$mins min'
              : '${wait.inSeconds} s';
      final why = s.lastError?.label ?? 'errors';
      return '${s.consecutiveFails} failures ($why), retry in $when';
    }
    if (s.consecutiveFails > 0) {
      final n = s.consecutiveFails;
      return '$n recent ${n == 1 ? "failure" : "failures"}: '
          '${s.lastError?.label ?? "unknown"}';
    }
    return 'Healthy';
  }

  /// Sources currently skipped, for the source sheet's failures footer.
  List<String> get openSources {
    final now = _now();
    return _state.entries
        .where((e) => e.value.isOpen(now))
        .map((e) => e.key)
        .toList();
  }
}
