import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/jwt_decoder.dart';

/// Stores the JWT access token. Uses platform secure storage on iOS/Android
/// and falls back to SharedPreferences on the browser target.
/// Validates token expiration on read to avoid 401 round-trips.
/// On web, the storage key is flavor-specific so tokens from the consumer,
/// driver, partner, and admin apps don't collide on the same domain.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage, String? flavorKey})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                keyCipherAlgorithm:
                    KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
                storageCipherAlgorithm:
                    StorageCipherAlgorithm.AES_GCM_NoPadding,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
              webOptions: WebOptions(
                dbName: 'PondyConnect',
                publicKey: 'pcWebKeys',
              ),
            ),
        _key = flavorKey ?? _defaultKey;

  static const _defaultKey = 'auth.access_token';

  final String _key;

  final FlutterSecureStorage _storage;

  /// Reads the token and returns null if missing or expired (offline check).
  Future<String?> read() async {
    // On web, use SharedPreferences as primary storage (more reliable than
    // flutter_secure_storage's IndexedDB which can fail in some browsers).
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString(_key);
        if (token == null || token.isEmpty) return null;
        if (JwtDecoder.isExpired(token)) {
          await prefs.remove(_key);
          return null;
        }
        return token;
      } catch (_) {
        return null;
      }
    }

    try {
      final token = await _storage.read(key: _key);
      if (token == null || token.isEmpty) return null;
      if (JwtDecoder.isExpired(token)) {
        await clear(); // Proactively remove expired token
        return null;
      }
      return token;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String token) async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_key, token);
      } catch (_) {
        // Swallow — the token is also set in-memory on the ApiClient.
      }
      return;
    }

    try {
      await _storage.write(key: _key, value: token);
    } catch (_) {
      // Swallow — the token is also set in-memory on the ApiClient.
    }
  }

  Future<void> clear() async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_key);
      } catch (_) {}
      return;
    }

    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }
}