import 'package:flutter/material.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../core/services/auth_session.dart';

import 'storefront_lock_controller.dart';

/// The one lock shared by the "Home Screen Config" group in the admin menu
/// and the three screens inside it (Explore Categories, Trending Now, Ads
/// Banner), so unlocking the group opens all three.
///
/// It is held in memory only (never saved on the device). It stays unlocked
/// while the admin moves around the admin console, and locks only when the
/// admin locks it by hand (lock icon + confirmation) or logs out / the
/// account changes.
class StorefrontAccess {
  StorefrontAccess._();

  static StorefrontLockController _controller = StorefrontLockController();
  static bool _watchingAuth = false;
  static String? _lastUserId;

  static StorefrontLockController get controller {
    _watchAuth();
    return _controller;
  }

  /// Signing out (or switching to another account) locks the group, so the
  /// next login always starts locked. Nothing is stored on the device.
  static void _watchAuth() {
    if (_watchingAuth) return;
    _watchingAuth = true;
    _lastUserId = AuthSession.currentUser?.id;
    AuthSession.instance.addListener(() {
      final id = AuthSession.currentUser?.id;
      if (id != _lastUserId) {
        _lastUserId = id;
        lock();
      }
    });
  }

  /// Locks the group (no-op when already locked).
  static void lock() => _controller.lock();

  /// Asks "Do you want to lock all storefront configuration sections?" and
  /// locks the group on OK. Returns whether it was locked.
  static Future<bool> confirmAndLock(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('storefront-lock-confirm-dialog'),
        content: Text(l10n.storefrontLockConfirmBody),
        actions: [
          TextButton(
            key: const Key('storefront-lock-confirm-cancel'),
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('storefront-lock-confirm-ok'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.storefrontLockConfirmOk),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    lock();
    return true;
  }

  /// A fresh, locked controller. For tests and sign-out.
  @visibleForTesting
  static void reset() {
    _controller.dispose();
    _controller = StorefrontLockController();
  }
}
