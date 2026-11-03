import 'package:flutter/foundation.dart';

import '../../../core/services/company_password.dart';
import '../../../core/services/service_locator.dart';

/// How an unlock attempt ended.
enum UnlockResult {
  unlocked,
  wrongPassword,

  /// No password has been set up in Firebase yet. The section stays locked.
  notConfigured,

  /// The password could not be read (offline, no permission). Stays locked.
  checkFailed,

  /// Too many wrong attempts in a row; try again after a short wait.
  tooManyAttempts,
}

/// Slows down guessing: after [maxAttempts] wrong passwords in a row, further
/// attempts are refused for [cooldown].
class AttemptLimiter {
  AttemptLimiter({
    this.maxAttempts = 5,
    this.cooldown = const Duration(seconds: 30),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final int maxAttempts;
  final Duration cooldown;
  final DateTime Function() _now;

  int _failures = 0;
  DateTime? _blockedUntil;

  bool get blocked => _blockedUntil != null && _now().isBefore(_blockedUntil!);

  /// Whole seconds until another attempt is allowed (0 when not blocked).
  int get secondsLeft => blocked
      ? (_blockedUntil!.difference(_now()).inMilliseconds / 1000).ceil()
      : 0;

  void fail() {
    _failures++;
    if (_failures >= maxAttempts) {
      _blockedUntil = _now().add(cooldown);
      _failures = 0;
    }
  }

  void reset() {
    _failures = 0;
    _blockedUntil = null;
  }
}

/// Whether one storefront section (Explore Categories, Trending Now, Ads
/// Banner) is open for editing.
///
/// Every controller starts **locked**, and each screen makes a new one, so a
/// section is locked again whenever it is opened. It unlocks only when the
/// typed password matches the one stored in Firebase (one password for all
/// companies, kept as a salted hash). Nothing is remembered: not the password,
/// not the unlocked state beyond this screen.
class StorefrontLockController extends ChangeNotifier {
  StorefrontLockController({
    Future<String?> Function()? loadHash,
    AttemptLimiter? limiter,
  }) : _loadHash = loadHash ?? (() => repo.storefrontLockHash()),
       limiter = limiter ?? AttemptLimiter();

  final Future<String?> Function() _loadHash;
  final AttemptLimiter limiter;

  bool _unlocked = false;
  bool _checking = false;

  bool get unlocked => _unlocked;
  bool get isChecking => _checking;

  /// Checks [password] against the Firebase setting.
  Future<UnlockResult> tryUnlock(String password) async {
    if (_checking) return UnlockResult.checkFailed; // one check at a time
    if (limiter.blocked) return UnlockResult.tooManyAttempts;
    _checking = true;
    notifyListeners();
    try {
      final String? stored;
      try {
        stored = await _loadHash();
      } catch (_) {
        return UnlockResult.checkFailed; // not a wrong guess: not counted
      }
      if (stored == null || stored.trim().isEmpty) {
        return UnlockResult.notConfigured;
      }
      if (CompanyPassword.verify(password, stored)) {
        limiter.reset();
        _unlocked = true;
        return UnlockResult.unlocked;
      }
      limiter.fail();
      return limiter.blocked
          ? UnlockResult.tooManyAttempts
          : UnlockResult.wrongPassword;
    } finally {
      _checking = false;
      notifyListeners();
    }
  }

  /// Locks the section again.
  void lock() {
    if (!_unlocked) return;
    _unlocked = false;
    notifyListeners();
  }
}
