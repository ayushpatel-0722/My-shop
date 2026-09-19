import 'package:flutter/foundation.dart';

import '../models/app_user.dart';

/// A global auth session used by the router's role guards.
///
/// [AuthCubit] keeps this in sync on every sign-in / sign-out / session restore
/// so go_router's `redirect` can enforce role-based access while preserving
/// the active route on browser reload.
class AuthSession with ChangeNotifier {
  AuthSession._();
  static final AuthSession instance = AuthSession._();

  static AppUser? currentUser;
  static bool isRestoring = true;
  static bool hasCompletedInitialBoot = false;

  static void set(AppUser? user, {bool restoring = false}) {
    currentUser = user;
    isRestoring = restoring;
    instance.notifyListeners();
  }

  static void setRestoring(bool restoring) {
    isRestoring = restoring;
    instance.notifyListeners();
  }

  static void markBootCompleted() {
    hasCompletedInitialBoot = true;
  }

  static bool get isAdmin => currentUser?.isAdmin ?? false;
  static bool get isEmployee => currentUser?.isEmployee ?? false;
  static bool get isUser => currentUser?.isUser ?? false;
}
