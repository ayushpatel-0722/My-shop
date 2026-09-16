import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  }) =>
      AuthState(
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

  /// Attempt to restore the previous session from:
  /// 1. Firebase Auth's persisted token (automatic on Web/mobile)
  /// 2. Encrypted local cache (fast, no network)
  /// 3. Firestore lookup as fallback (network required)
  Future<void> _restoreSession() async {
    try {
      final fbUser = fb_auth.FirebaseAuth.instance.currentUser;
      if (fbUser == null) {
        // No Firebase session — user is not signed in.
        AuthSession.set(null, restoring: false);
        emit(const AuthState(
          status: AuthStatus.unauthenticated,
          restoring: false,
        ));
        return;
      }

      // Try fast path: encrypted local cache.
      var user = await _cache.restore();
      if (user != null && user.id == fbUser.uid) {
        AuthSession.set(user, restoring: false);
        emit(AuthState(
          status: AuthStatus.authenticated,
          user: user,
          restoring: false,
        ));
        _registerPush(user);
        debugPrint('Session restored from encrypted cache (${user.role}).');
        return;
      }

      // Cache miss or stale — fetch from Firestore.
      user = await _repo.resolveCurrentUser();
      if (user != null) {
        await _cache.save(user);
        AuthSession.set(user, restoring: false);
        emit(AuthState(
          status: AuthStatus.authenticated,
          user: user,
          restoring: false,
        ));
        _registerPush(user);
        debugPrint('Session restored from Firestore (${user.role}).');
        return;
      }
    } catch (e) {
      debugPrint('_restoreSession error: $e');
    }

    // Fallthrough: could not restore.
    AuthSession.set(null, restoring: false);
    emit(const AuthState(
      status: AuthStatus.unauthenticated,
      restoring: false,
    ));
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
        emit(const AuthState(
          status: AuthStatus.error,
          error: 'Invalid email, password, or company credentials.',
        ));
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
        emit(const AuthState(
          status: AuthStatus.error,
          error: 'Invalid employee email, password, or company name.',
        ));
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

  Future<void> createUserAccount(String name, String mobile) =>
      _repo.createUserAccount(name, mobile);

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
    await _repo.signOut();
    await _cache.clear();
    AuthSession.set(null);
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  void clearError() =>
      emit(state.copyWith(error: null, status: AuthStatus.unauthenticated));
}
