import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/models/admin.dart';
import '../../core/models/app_user.dart';
import '../../core/models/company.dart';
import '../../core/services/auth_session.dart';
import '../../core/services/secure_session_cache.dart';
import '../../core/services/service_locator.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

enum AuthStatus { unauthenticated, authenticating, authenticated, error }

class AuthState {
  final AuthStatus status;
  final AppUser? user;
  final String? error;

  /// True while the cubit is checking Firebase Auth + encrypted cache.
  final bool restoring;

  const AuthState({
    this.status = AuthStatus.unauthenticated,
    this.user,
    this.error,
    this.restoring = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    String? error,
    bool? restoring,
  }) => AuthState(
    status: status ?? this.status,
    user: user ?? this.user,
    error: error ?? this.error,
    restoring: restoring ?? this.restoring,
  );
}

/// Global authentication controller shared by all three roles.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(const AuthState(restoring: true)) {
    // Restore a persisted Firebase session on startup, if any.
    _restoreSession();
  }

  final _repo = repo;
  final _cache = SecureSessionCache.instance;

  AppUser? get currentUser => state.user;
  bool get isLoggedIn => state.user != null;

  /// True while the initial session restore is in progress.
  bool get isRestoring => state.restoring;

  /// Registers the device's FCM token against the signed-in account.
  void _registerPush(AppUser user) {
    ServiceLocator.instance.notificationService?.init(userId: user.id);
  }

  /// Attempt to restore the previous session:
  /// 1. Encrypted local cache (fastest, offline-ready, avoids web startup null race)
  /// 2. Firebase Auth persisted token + repository resolution fallback
  Future<void> _restoreSession() async {
    try {
      // 1. Fast-path: Check encrypted local cache FIRST
      final cachedUser = await _cache.restore();
      if (cachedUser != null) {
        AuthSession.set(cachedUser, restoring: false);
        emit(
          AuthState(
            status: AuthStatus.authenticated,
            user: cachedUser,
            restoring: false,
          ),
        );
        _registerPush(cachedUser);
        debugPrint(
          'Session restored from encrypted cache (${cachedUser.role}: ${cachedUser.name}).',
        );

        // In background: if Firebase is available, sync and verify token
        _backgroundSyncFirebase(cachedUser);
        return;
      }

      // 2. Cache miss: Check if Firebase Auth has an active session
      var fbUser = fb_auth.FirebaseAuth.instance.currentUser;
      if (fbUser == null && kIsWeb) {
        try {
          fbUser = await fb_auth.FirebaseAuth.instance
              .authStateChanges()
              .first
              .timeout(const Duration(milliseconds: 600));
        } catch (_) {}
      }

      if (fbUser != null) {
        final user = await _repo.resolveCurrentUser();
        if (user != null) {
          await _cache.save(user);
          AuthSession.set(user, restoring: false);
          emit(
            AuthState(
              status: AuthStatus.authenticated,
              user: user,
              restoring: false,
            ),
          );
          _registerPush(user);
          debugPrint('Session restored from Firebase (${user.role}).');
          return;
        }
      }
    } catch (e) {
      debugPrint('_restoreSession error: $e');
    }

    // Fallthrough: no valid session found.
    AuthSession.set(null, restoring: false);
    emit(const AuthState(status: AuthStatus.unauthenticated, restoring: false));
  }

  void _backgroundSyncFirebase(AppUser cachedUser) {
    Future.microtask(() async {
      try {
        final fbUser = fb_auth.FirebaseAuth.instance.currentUser;
        if (fbUser != null && fbUser.uid == cachedUser.id) {
          final refreshed = await _repo.resolveCurrentUser();
          if (refreshed != null && refreshed.id == cachedUser.id) {
            await _cache.save(refreshed);
            AuthSession.set(refreshed, restoring: false);
            if (!isClosed) {
              emit(
                AuthState(
                  status: AuthStatus.authenticated,
                  user: refreshed,
                  restoring: false,
                ),
              );
            }
          }
        }
      } catch (e) {
        debugPrint('Background Firebase sync: $e');
      }
    });
  }

  // ---- Admin (two-step) ----
  Future<bool> adminLogin({
    required String companyName,
    required String companyPassword,
    required String email,
    required String password,
  }) async {
    emit(const AuthState(status: AuthStatus.authenticating));
    try {
      final user = await _repo.adminLogin(
        companyName: companyName,
        companyPassword: companyPassword,
        email: email,
        password: password,
      );
      if (user == null) {
        emit(
          const AuthState(
            status: AuthStatus.error,
            error: 'Invalid email, password, or company credentials.',
          ),
        );
        return false;
      }
      AuthSession.set(user);
      await _cache.save(user);
      emit(AuthState(status: AuthStatus.authenticated, user: user));
      _registerPush(user);
      return true;
    } on fb_auth.FirebaseAuthException catch (e) {
      String msg = 'Authentication failed.';
      if (e.code == 'invalid-credential' ||
          e.code == 'wrong-password' ||
          e.code == 'user-not-found') {
        msg = 'Invalid admin email or password.';
      } else if (e.code == 'user-disabled') {
        msg = 'This admin account has been disabled.';
      } else if (e.code == 'too-many-requests') {
        msg = 'Too many attempts. Please wait a moment and try again.';
      } else if (e.message != null && e.message!.isNotEmpty) {
        msg = e.message!;
      }
      emit(AuthState(status: AuthStatus.error, error: msg));
      return false;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      emit(AuthState(status: AuthStatus.error, error: msg));
      return false;
    }
  }

  // ---- Employee ----
  Future<bool> employeeLogin({
    required String companyName,
    required String email,
    required String password,
  }) async {
    emit(const AuthState(status: AuthStatus.authenticating));
    try {
      final user = await _repo.employeeLogin(
        companyName: companyName,
        email: email,
        password: password,
      );
      if (user == null) {
        emit(
          const AuthState(
            status: AuthStatus.error,
            error: 'Invalid employee email, password, or company name.',
          ),
        );
        return false;
      }
      AuthSession.set(user);
      await _cache.save(user);
      emit(AuthState(status: AuthStatus.authenticated, user: user));
      _registerPush(user);
      return true;
    } on fb_auth.FirebaseAuthException catch (e) {
      String msg = 'Authentication failed.';
      if (e.code == 'invalid-credential' ||
          e.code == 'wrong-password' ||
          e.code == 'user-not-found') {
        msg = 'Invalid employee email or password.';
      } else if (e.code == 'user-disabled') {
        msg = 'This employee account has been disabled.';
      } else if (e.code == 'too-many-requests') {
        msg = 'Too many attempts. Please wait a moment and try again.';
      } else if (e.message != null && e.message!.isNotEmpty) {
        msg = e.message!;
      }
      emit(AuthState(status: AuthStatus.error, error: msg));
      return false;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      emit(AuthState(status: AuthStatus.error, error: msg));
      return false;
    }
  }

  // ---- User OTP flow ----
  Future<bool> userExists(String mobile) => _repo.userExists(mobile);

  Future<bool> sendOtp(String mobile) async {
    try {
      await _repo.sendOtp(mobile);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> verifyOtp(String mobile, String otp) async {
    emit(const AuthState(status: AuthStatus.authenticating));
    try {
      final user = await _repo.verifyOtp(mobile, otp);
      if (user == null) {
        emit(const AuthState(status: AuthStatus.error, error: 'invalid_otp'));
        return false;
      }
      AuthSession.set(user);
      await _cache.save(user);
      emit(AuthState(status: AuthStatus.authenticated, user: user));
      _registerPush(user);
      return true;
    } catch (_) {
      emit(const AuthState(status: AuthStatus.error, error: 'invalid_otp'));
      return false;
    }
  }

  Future<void> createUserAccount(
    String name,
    String mobile, {
    String email = '',
    String authProvider = '',
    String googleId = '',
    List<AddressEntry> addresses = const [],
  }) => _repo.createUserAccount(
    name,
    mobile,
    email: email,
    authProvider: authProvider,
    googleId: googleId,
    addresses: addresses,
  );

  /// Updates the currently authenticated user's mobile number in repository,
  /// session, and cache.
  Future<bool> updateUserMobile(String mobileNumber) async {
    final current = currentUser;
    if (current == null) return false;
    try {
      await _repo.updateUserMobile(current.id, mobileNumber);
      final updatedUser = current.copyWith(mobileNumber: mobileNumber);
      AuthSession.set(updatedUser);
      await _cache.save(updatedUser);
      emit(AuthState(status: AuthStatus.authenticated, user: updatedUser));
      return true;
    } catch (e) {
      debugPrint('[AuthCubit] updateUserMobile error: $e');
      return false;
    }
  }

  /// Saves a structured address for the currently authenticated user.
  Future<bool> saveUserAddress(AddressEntry address) async {
    final current = currentUser;
    if (current == null) return false;
    try {
      await _repo.saveUserAddress(current.id, address);
      final updatedList = List<AddressEntry>.from(current.addresses);
      if (address.isDefault || updatedList.isEmpty) {
        for (var i = 0; i < updatedList.length; i++) {
          final a = updatedList[i];
          updatedList[i] = AddressEntry(
            houseNo: a.houseNo,
            address: a.address,
            pincode: a.pincode,
            isDefault: false,
            label: a.label,
            lat: a.lat,
            lng: a.lng,
          );
        }
      }
      updatedList.add(address);
      final updatedUser = current.copyWith(addresses: updatedList);
      AuthSession.set(updatedUser);
      await _cache.save(updatedUser);
      emit(AuthState(status: AuthStatus.authenticated, user: updatedUser));
      return true;
    } catch (e) {
      debugPrint('[AuthCubit] saveUserAddress error: $e');
      return false;
    }
  }

  /// Sign-in using Google directly without blocking prompts.
  /// Once authenticated, resolves or creates the shopper record and sets session.
  Future<bool> signInWithGoogle([BuildContext? context]) async {
    emit(const AuthState(status: AuthStatus.authenticating));
    try {
      fb_auth.UserCredential cred;
      if (kIsWeb) {
        final provider = fb_auth.GoogleAuthProvider();
        cred = await fb_auth.FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        // Mobile/Desktop flow using google_sign_in package
        final gsi = GoogleSignIn();
        final account = await gsi.signIn();
        if (account == null) {
          emit(const AuthState(status: AuthStatus.unauthenticated));
          return false;
        }
        final auth = await account.authentication;
        final credential = fb_auth.GoogleAuthProvider.credential(
          accessToken: auth.accessToken,
          idToken: auth.idToken,
        );
        cred = await fb_auth.FirebaseAuth.instance.signInWithCredential(
          credential,
        );
      }

      final fbUser = fb_auth.FirebaseAuth.instance.currentUser ?? cred.user;
      if (fbUser == null) {
        emit(const AuthState(status: AuthStatus.unauthenticated));
        return false;
      }

      var appUser = await _repo.resolveCurrentUser();
      if (appUser == null) {
        final name = fbUser.displayName?.isNotEmpty == true
            ? fbUser.displayName!
            : 'Shopper';
        final mobile = fbUser.phoneNumber ?? '';
        final email = fbUser.email ?? '';
        await _repo.createUserAccount(
          name,
          mobile,
          email: email,
          authProvider: 'google',
          googleId: fbUser.uid,
        );
        appUser = await _repo.resolveCurrentUser();
      }

      if (appUser != null) {
        AuthSession.set(appUser);
        await _cache.save(appUser);
        emit(AuthState(status: AuthStatus.authenticated, user: appUser));
        _registerPush(appUser);
        return true;
      }

      emit(const AuthState(status: AuthStatus.unauthenticated));
      return false;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      debugPrint('[AuthCubit] signInWithGoogle failed: $msg');
      emit(AuthState(status: AuthStatus.error, error: msg));
      return false;
    }
  }

  // ---- Company + accounts ----
  Future<Company> createCompany(Company company) =>
      _repo.createCompany(company);

  Future<Admin> createAdminAccount(
    Admin admin, {
    required String password,
  }) async {
    final created = await _repo.createAdminAccount(admin, password: password);
    final user = AppUser(
      id: created.id,
      companyId: created.companyId,
      name: created.name,
      email: created.email,
      role: 'admin',
    );
    AuthSession.set(user);
    await _cache.save(user);
    emit(AuthState(status: AuthStatus.authenticated, user: user));
    _registerPush(user);
    // Cloud Function `setCustomClaims` may take a short time to run after the
    // `admins/{uid}` doc is created. Refresh the ID token a few times to pick
    // up the new `role` and `companyId` claims so the client can enter admin
    // areas immediately without a manual sign-out/sign-in.
    try {
      final fbUser = fb_auth.FirebaseAuth.instance.currentUser;
      if (fbUser != null) {
        for (var i = 0; i < 6; i++) {
          try {
            final idr = await fbUser.getIdTokenResult(true);
            final claims = idr.claims ?? {};
            if (claims['role'] == 'admin') break;
          } catch (_) {}
          await Future.delayed(const Duration(milliseconds: 800));
        }
      }
    } catch (_) {}

    return created;
  }

  void setAuthenticatedUser(AppUser user) {
    AuthSession.set(user);
    _cache.save(user);
    emit(AuthState(status: AuthStatus.authenticated, user: user));
    _registerPush(user);
  }

  Future<void> signOut() async {
    try {
      await _repo.signOut();
    } catch (e) {
      debugPrint('signOut repo error: $e');
    }
    await _cache.clear();
    AuthSession.set(null, restoring: false);
    emit(const AuthState(status: AuthStatus.unauthenticated, restoring: false));
  }

  void clearError() =>
      emit(state.copyWith(error: null, status: AuthStatus.unauthenticated));
}
