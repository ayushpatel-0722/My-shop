import 'package:shared_preferences/shared_preferences.dart';

/// The shopper's answer to "may this browser keep app data for faster
/// loading?". Only asked on the web: Android and iOS apps have their own
/// storage and need no browser permission.
enum CacheConsent { undecided, allowed, declined }

/// Remembers the answer on this browser (not per account, because browser
/// storage is shared by everyone using it).
///
/// The answer is stored with the policy version, so a changed policy can ask
/// again; anything unreadable counts as "not decided yet".
class CacheConsentStore {
  CacheConsentStore([this._prefs]);

  /// Bump to ask everyone again (for example when more data is cached).
  static const int policyVersion = 1;
  static const String _key = 'cache_consent';

  final SharedPreferences? _prefs;

  Future<SharedPreferences> _p() async =>
      _prefs ?? SharedPreferences.getInstance();

  Future<CacheConsent> read() async {
    try {
      final raw = (await _p()).getString(_key);
      if (raw == null) return CacheConsent.undecided;
      final parts = raw.split(':');
      if (parts.length != 2 || int.tryParse(parts[1]) != policyVersion) {
        return CacheConsent.undecided;
      }
      return switch (parts[0]) {
        'allowed' => CacheConsent.allowed,
        'declined' => CacheConsent.declined,
        _ => CacheConsent.undecided,
      };
    } catch (_) {
      return CacheConsent.undecided;
    }
  }

  Future<void> write(CacheConsent value) async {
    try {
      final p = await _p();
      if (value == CacheConsent.undecided) {
        await p.remove(_key);
      } else {
        await p.setString(_key, '${value.name}:$policyVersion');
      }
    } catch (_) {
      // Storage unavailable: the answer is only kept for this session.
    }
  }
}
