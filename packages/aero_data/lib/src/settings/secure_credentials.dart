import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The storage surface [SecureCredentials] needs.
///
/// Kept abstract so tests (and desktop builds without a keystore) can use an
/// in-memory implementation instead of the platform channel, without silently
/// falling back to "credentials go nowhere" in production.
abstract class CredentialStore {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
  Future<Map<String, String>> readAll();
  Future<void> deleteAll();
}

/// In-memory store for tests. Never persisted, never used implicitly.
class InMemoryCredentialStore implements CredentialStore {
  final Map<String, String> _values = {};

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<Map<String, String>> readAll() async => Map.of(_values);

  @override
  Future<void> deleteAll() async => _values.clear();
}

/// Plugin credentials (debrid keys, repo tokens) never touch SQLite in plain
/// text. They live in the platform keystore/keychain.
class SecureCredentials {
  SecureCredentials({CredentialStore? store, FlutterSecureStorage? storage})
      : _store = store ?? _PlatformCredentialStore(storage ?? const FlutterSecureStorage(
              // v11 uses the encrypted Jetpack-backed implementation by default.
              aOptions: AndroidOptions(),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            ));

  /// In-memory instance for tests. Not a production fallback.
  SecureCredentials.inMemory() : _store = InMemoryCredentialStore();

  final CredentialStore _store;

  String _key(String sourceKey, String field) => 'aero.cred.$sourceKey.$field';

  Future<void> set(String sourceKey, String field, String value) =>
      _store.write(_key(sourceKey, field), value);

  Future<String?> get(String sourceKey, String field) =>
      _store.read(_key(sourceKey, field));

  Future<void> delete(String sourceKey, String field) =>
      _store.delete(_key(sourceKey, field));

  /// Removes every credential belonging to a source (called on uninstall).
  Future<void> deleteAllFor(String sourceKey) async {
    final all = await _store.readAll();
    final prefix = 'aero.cred.$sourceKey.';
    for (final k in all.keys.where((k) => k.startsWith(prefix))) {
      await _store.delete(k);
    }
  }

  Future<void> wipe() => _store.deleteAll();
}

class _PlatformCredentialStore implements CredentialStore {
  _PlatformCredentialStore(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<Map<String, String>> readAll() => _storage.readAll();

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}
