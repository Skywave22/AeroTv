/// A tiny Result type so adapters can report failures without throwing
/// across isolate/platform-channel boundaries.
sealed class Result<T> {
  const Result();

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  T? get valueOrNull => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>() => null,
      };

  String? get errorOrNull => switch (this) {
        Ok<T>() => null,
        Err<T>(:final message) => message,
      };

  R when<R>({required R Function(T value) ok, required R Function(String error) err}) =>
      switch (this) {
        Ok<T>(:final value) => ok(value),
        Err<T>(:final message) => err(message),
      };

  T orElse(T fallback) => valueOrNull ?? fallback;
}

class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

class Err<T> extends Result<T> {
  const Err(this.message, [this.detail]);
  final String message;
  final Object? detail;

  @override
  String toString() => 'Err($message)';
}

/// Base class for adapter-level failures.
class AeroException implements Exception {
  const AeroException(this.message, [this.cause]);
  final String message;
  final Object? cause;

  @override
  String toString() =>
      'AeroException: $message${cause == null ? '' : ' ($cause)'}';
}

/// Thrown when an ecosystem cannot run on the current platform.
class UnsupportedPlatformException extends AeroException {
  const UnsupportedPlatformException(super.message);
}

/// Thrown when a plugin exceeds its sandbox budget.
class SandboxException extends AeroException {
  const SandboxException(super.message, [super.cause]);
}
