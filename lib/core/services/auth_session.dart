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

  static AddressEntry? _guestActiveAddress;
  static AddressEntry? _selectedAddress;

  static AddressEntry? get activeAddress {
    if (_selectedAddress != null) return _selectedAddress;
    if (currentUser != null && currentUser!.addresses.isNotEmpty) {
      return currentUser!.defaultAddress;
    }
    return _guestActiveAddress;
  }

  static void setActiveAddress(AddressEntry? address) {
    _selectedAddress = address;
    _guestActiveAddress = address;
    instance.notifyListeners();
  }

  static bool get isAdmin => currentUser?.isAdmin ?? false;
  static bool get isEmployee => currentUser?.isEmployee ?? false;
  static bool get isUser => currentUser?.isUser ?? false;
}
