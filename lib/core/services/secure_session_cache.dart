import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';

/// Encrypted and local persistent cache for the signed-in [AppUser] profile.
///
/// Uses `flutter_secure_storage` with automatic fallback and synchronization
/// via `SharedPreferences` to ensure flawless session restoration on Web
/// across browser refreshes and restarts.
///
/// **No passwords are stored** — only role metadata (id, companyId, name,
/// email, role) so the app can restore the session instantly on restart.
class SecureSessionCache {
  SecureSessionCache._();
  static final SecureSessionCache instance = SecureSessionCache._();

  static const _key = 'cached_app_user';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions.defaultOptions,
    iOptions: IOSOptions.defaultOptions,
    webOptions: WebOptions.defaultOptions,
  );

  /// Persist the signed-in user's profile.
  Future<void> save(AppUser user) async {
    final json = jsonEncode(user.toMap());
    try {
      await _storage.write(key: _key, value: json);
    } catch (e) {
      debugPrint('SecureSessionCache storage write: $e');
    }
    // Always backup to SharedPreferences (rock solid on Web & native)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, json);
    } catch (e) {
      debugPrint('SecureSessionCache prefs write: $e');
    }
  }

  /// Restore the cached [AppUser], or null if none exists.
  Future<AppUser?> restore() async {
    // 1. Try secure storage
    try {
      final json = await _storage.read(key: _key);
      if (json != null && json.isNotEmpty) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        return AppUser.fromMap(map);
      }
    } catch (e) {
      debugPrint('SecureSessionCache storage read: $e');
    }

    // 2. Backup: SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_key);
      if (json != null && json.isNotEmpty) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        return AppUser.fromMap(map);
      }
    } catch (e) {
      debugPrint('SecureSessionCache prefs read: $e');
    }

    return null;
  }

  /// Clear the cached session (on sign-out).
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
