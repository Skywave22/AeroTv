import 'package:aero_core/aero_core.dart';
import 'package:test/test.dart';

void main() {
  late DateTime now;
  late CircuitBreaker breaker;

  setUp(() {
    now = DateTime.utc(2026, 1, 1, 12);
    breaker = CircuitBreaker(clock: () => now);
  });

  group('opening', () {
    test('a healthy source is allowed', () {
      expect(breaker.allows('s'), isTrue);
      expect(breaker.describe('s'), 'No calls yet');
    });

    test('one or two errors do not open the circuit', () {
      breaker.onFail('s', FailKind.timeout);
      expect(breaker.allows('s'), isTrue);
      breaker.onFail('s', FailKind.timeout);
      expect(breaker.allows('s'), isTrue);
      expect(breaker.describe('s'), contains('2 recent failures'));
    });

    test('the third consecutive error opens it for 5 minutes', () {
      for (var i = 0; i < 3; i++) {
        breaker.onFail('s', FailKind.timeout);
      }
      expect(breaker.allows('s'), isFalse);
      expect(breaker.describe('s'), contains('retry in 5 min'));
      expect(breaker.openSources, ['s']);
    });

    test('backoff grows 5m -> 15m -> 1h and then caps', () {
      void trip() {
        for (var i = 0; i < 3; i++) {
          breaker.onFail('s', FailKind.network);
        }
      }

      trip();
      expect(breaker.stateOf('s').retryIn(now), const Duration(minutes: 5));

      now = now.add(const Duration(minutes: 6));
      expect(breaker.allows('s'), isTrue, reason: 'half-open after backoff');
      trip();
      expect(breaker.stateOf('s').retryIn(now), const Duration(minutes: 15));

      now = now.add(const Duration(minutes: 16));
      trip();
      expect(breaker.stateOf('s').retryIn(now), const Duration(hours: 1));

      now = now.add(const Duration(hours: 2));
      trip();
      expect(breaker.stateOf('s').retryIn(now), const Duration(hours: 1),
          reason: 'backoff must cap, not grow without bound');
    });

    test('sources are independent', () {
      for (var i = 0; i < 3; i++) {
        breaker.onFail('bad', FailKind.exception);
      }
      expect(breaker.allows('bad'), isFalse);
      expect(breaker.allows('good'), isTrue);
    });
  });

  group('closing', () {
    test('a success resets the consecutive count', () {
      breaker.onFail('s', FailKind.timeout);
      breaker.onFail('s', FailKind.timeout);
      breaker.onOk('s');
      breaker.onFail('s', FailKind.timeout);
      expect(breaker.allows('s'), isTrue,
          reason: 'the streak was broken by a success');
      expect(breaker.stateOf('s').consecutiveFails, 1);
    });

    test('a success closes an open circuit and clears backoff', () {
      for (var i = 0; i < 3; i++) {
        breaker.onFail('s', FailKind.timeout);
      }
      now = now.add(const Duration(minutes: 6));
      breaker.onOk('s');
      expect(breaker.allows('s'), isTrue);
      expect(breaker.stateOf('s').opens, 0);
      expect(breaker.describe('s'), 'Healthy');
    });

    test('Retry now closes it without waiting', () {
      for (var i = 0; i < 3; i++) {
        breaker.onFail('s', FailKind.timeout);
      }
      expect(breaker.allows('s'), isFalse);
      breaker.reset('s');
      expect(breaker.allows('s'), isTrue);
    });

    test('resetAll clears every source', () {
      for (var i = 0; i < 3; i++) {
        breaker.onFail('a', FailKind.timeout);
        breaker.onFail('b', FailKind.timeout);
      }
      breaker.resetAll();
      expect(breaker.openSources, isEmpty);
    });
  });

  group('no results is not a failure', () {
    test('ten empty answers never open the circuit', () {
      for (var i = 0; i < 10; i++) {
        breaker.onFail('s', FailKind.noResults);
      }
      expect(breaker.allows('s'), isTrue);
      expect(breaker.stateOf('s').consecutiveFails, 0);
    });

    test('an empty answer also breaks an error streak', () {
      breaker.onFail('s', FailKind.timeout);
      breaker.onFail('s', FailKind.timeout);
      breaker.onFail('s', FailKind.noResults);
      breaker.onFail('s', FailKind.timeout);
      expect(breaker.allows('s'), isTrue);
    });

    test('only real errors count as failures', () {
      for (final k in FailKind.values) {
        expect(k.countsAsFailure, k != FailKind.noResults, reason: '$k');
      }
    });
  });

  group('reporting', () {
    test('the reason is surfaced for the failures footer', () {
      for (var i = 0; i < 3; i++) {
        breaker.onFail('s', FailKind.sandboxBlocked);
      }
      expect(breaker.describe('s'), contains('blocked by sandbox'));
    });

    test('every failure kind has a readable label', () {
      for (final k in FailKind.values) {
        expect(k.label, isNotEmpty);
      }
    });

    test('a long wait is reported in hours', () {
      for (var r = 0; r < 3; r++) {
        for (var i = 0; i < 3; i++) {
          breaker.onFail('s', FailKind.timeout);
        }
        now = now.add(const Duration(hours: 2));
      }
      // After several trips the backoff is at its 1 h cap.
      for (var i = 0; i < 3; i++) {
        breaker.onFail('s', FailKind.timeout);
      }
      expect(breaker.describe('s'), contains('h'));
    });
  });
}
