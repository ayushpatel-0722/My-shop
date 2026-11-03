import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cache_consent.dart';
import 'cache_policy.dart';

/// Configures Firestore's on-device cache — the app's data cache.
///
/// Firestore keeps the documents it has read on disk, shows them immediately
/// on the next launch and brings fresh ones in behind them, and evicts the
/// least recently used beyond [CachePolicy.firestoreCacheBytes]. That already
/// is "show cached data, refresh in the background", so the app uses it rather
/// than keeping a second copy of the same documents.
///
///  * Android / iOS: persistent cache on, bounded.
///  * Web: persistent cache (IndexedDB) only after the shopper allowed it;
///    otherwise memory only, so the app works the same but nothing is kept.
class FirestoreCache {
  const FirestoreCache._();

  static const String _clearKey = 'firestore_cache_clear_pending';

  /// The Firestore settings for this platform and consent.
  static Settings settingsFor({
    required bool isWeb,
    required CacheConsent consent,
    CachePolicy policy = CachePolicy.standard,
  }) {
    if (!isWeb) {
      return Settings(
        persistenceEnabled: true,
        cacheSizeBytes: policy.firestoreCacheBytes,
      );
    }
    final allowed = consent == CacheConsent.allowed;
    return Settings(
      persistenceEnabled: allowed,
      cacheSizeBytes: policy.firestoreCacheBytes,
      // Several open tabs share one cache instead of fighting over it.
      webPersistentTabManager: allowed
          ? const WebPersistentMultipleTabManager()
          : null,
    );
  }

  /// Applies the settings. Must run before Firestore is first used. A failure
  /// (storage blocked or full) leaves Firestore on its defaults: the app still
  /// works, it just may not keep data.
  static void apply(
    FirebaseFirestore db, {
    required CacheConsent consent,
    CachePolicy policy = CachePolicy.standard,
  }) {
    try {
      db.settings = settingsFor(
        isWeb: kIsWeb,
        consent: consent,
        policy: policy,
      );
    } catch (e) {
      debugPrint('Firestore cache settings skipped: $e');
    }
  }

  /// Marks the on-device cache for deletion at the next start.
  ///
  /// Called when an account signs out or another signs in on this device, so
  /// that data cached while the previous account was active (orders, saved
  /// items) does not stay behind. Firestore can only delete its cache before
  /// it is used, hence "next start".
  static Future<void> markForClearing([SharedPreferences? prefs]) async {
    try {
      await (prefs ?? await SharedPreferences.getInstance()).setBool(
        _clearKey,
        true,
      );
    } catch (_) {}
  }

  static Future<bool> isClearPending([SharedPreferences? prefs]) async {
    try {
      return (prefs ?? await SharedPreferences.getInstance()).getBool(
            _clearKey,
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Deletes the cache if it was marked. Call first thing at startup, before
  /// any Firestore use. Returns whether it was cleared.
  static Future<bool> clearIfPending(
    FirebaseFirestore db, [
    SharedPreferences? prefs,
  ]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    if (!await isClearPending(p)) return false;
    try {
      await db.clearPersistence();
      await p.remove(_clearKey);
      return true;
    } catch (e) {
      // Another tab holds it open, or it is already in use: try next start.
      debugPrint('Firestore cache clear postponed: $e');
      return false;
    }
  }
}
