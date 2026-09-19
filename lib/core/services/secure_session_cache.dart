import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import 'encryption_helper.dart';

/// Encrypted and local persistent cache for the signed-in [AppUser] profile.
///
/// Features:
/// - Authenticated symmetric encryption (HMAC-SHA256 CTR) before writing to disk.
/// - Uses `FlutterSecureStorage` with Android Keystore (`encryptedSharedPreferences`)
///   and iOS Keychain.
/// - Resilient encrypted `SharedPreferences` backup to guarantee instant session
///   restoration on Flutter Web across browser refreshes and tab restarts.
/// - Safety timeouts on all storage calls to prevent Flutter Web SubtleCrypto deadlocks.
/// - Complete cache purge on user / admin / employee sign-out or app data wipe.
class SecureSessionCache {
  SecureSessionCache._();
  static final SecureSessionCache instance = SecureSessionCache._();

  static const _key = 'cached_app_user_v2';
  static const _legacyKey = 'cached_app_user';
  static const _timeout = Duration(milliseconds: 1200);

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions.defaultOptions,
    iOptions: IOSOptions.defaultOptions,
    webOptions: WebOptions(
      dbName: 'myshop_secure_vault',
      publicKey: 'myshop_pub_key_v1',
    ),
  );

  /// Persist the signed-in user's profile encrypted.
  Future<void> save(AppUser user) async {
    final rawJson = jsonEncode(user.toMap());
    final encrypted = EncryptionHelper.encrypt(rawJson);

    // 1. Try secure storage with timeout
    try {
      await _storage
          .write(key: _key, value: encrypted)
          .timeout(_timeout);
    } catch (e) {
      debugPrint('SecureSessionCache storage write: $e');
    }

    // 2. Encrypted backup in SharedPreferences (rock solid on Web & native)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, encrypted);
    } catch (e) {
      debugPrint('SecureSessionCache prefs write: $e');
    }
  }

  /// Restore the cached [AppUser], or null if none exists.
  Future<AppUser?> restore() async {
    // 1. Try secure storage
    try {
      final encrypted = await _storage.read(key: _key).timeout(_timeout);
      if (encrypted != null && encrypted.isNotEmpty) {
        final decrypted = EncryptionHelper.decrypt(encrypted);
        if (decrypted.isNotEmpty) {
          final map = jsonDecode(decrypted) as Map<String, dynamic>;
          return AppUser.fromMap(map);
        }
      }
    } catch (e) {
      debugPrint('SecureSessionCache storage read: $e');
    }

    // 2. Backup: SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      var encrypted = prefs.getString(_key);

      // Check legacy key if new key not yet populated
      if (encrypted == null || encrypted.isEmpty) {
        encrypted = prefs.getString(_legacyKey);
      }

      if (encrypted != null && encrypted.isNotEmpty) {
        final decrypted = EncryptionHelper.decrypt(encrypted);
        if (decrypted.isNotEmpty) {
          final map = jsonDecode(decrypted) as Map<String, dynamic>;
          final user = AppUser.fromMap(map);
          // Upgrade to encrypted format for next time
          save(user);
          return user;
        }
      }
    } catch (e) {
      debugPrint('SecureSessionCache prefs read: $e');
    }

    return null;
  }

  /// Clear the cached session completely (on sign-out or app reset).
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key).timeout(_timeout);
      await _storage.delete(key: _legacyKey).timeout(_timeout);
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
      await prefs.remove(_legacyKey);
    } catch (_) {}
  }
}
