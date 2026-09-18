import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wraps Keychain (iOS) / Keystore (Android) for anything that must never
/// sit in plain SharedPreferences: auth session material and nothing else.
/// Supabase's own client already persists its session through this same
/// mechanism when configured with `FlutterSecureStorage`-backed local
/// storage (see main.dart); this class exists for any additional secret
/// the app needs to keep (e.g. a cached device-pairing token).
class SecureSessionStore {
  SecureSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> delete(String key) => _storage.delete(key: key);

  Future<void> deleteAll() => _storage.deleteAll();
}
