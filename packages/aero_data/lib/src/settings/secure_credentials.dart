import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Plugin credentials (debrid keys, repo tokens) never touch SQLite in plain
/// text. They live in the platform keystore/keychain.
class SecureCredentials {
  SecureCredentials({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              // v11 uses the encrypted Jetpack-backed implementation by default.
              aOptions: AndroidOptions(),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _storage;

  String _key(String sourceKey, String field) => 'aero.cred.$sourceKey.$field';

  Future<void> set(String sourceKey, String field, String value) =>
      _storage.write(key: _key(sourceKey, field), value: value);

  Future<String?> get(String sourceKey, String field) =>
      _storage.read(key: _key(sourceKey, field));

  Future<void> delete(String sourceKey, String field) =>
      _storage.delete(key: _key(sourceKey, field));

  /// Removes every credential belonging to a source (called on uninstall).
  Future<void> deleteAllFor(String sourceKey) async {
    final all = await _storage.readAll();
    final prefix = 'aero.cred.$sourceKey.';
    for (final k in all.keys.where((k) => k.startsWith(prefix))) {
      await _storage.delete(key: k);
    }
  }

  Future<void> wipe() => _storage.deleteAll();
}
