import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/auth/auth_cubit.dart';
import '../../features/auth/widgets/auth_bottom_sheet.dart';
import '../services/auth_session.dart';

/// Centralized authentication guard and routing helper.
///
/// Ensures protected actions (such as Saved Addresses, My Orders, etc.)
/// require authentication, displaying friendly guidance to guest users,
/// prompting for login, and resuming the requested action seamlessly
/// upon successful authentication.
class AuthGuard {
  const AuthGuard._();

  /// Checks if the current user is authenticated.
  static bool isAuthenticated(BuildContext context) {
    AuthCubit? authCubit;
    try {
      authCubit = context.read<AuthCubit>();
    } catch (_) {}
    return (authCubit?.isLoggedIn ?? false) || AuthSession.currentUser != null;
  }

  /// Runs [onAuthenticated] if the user is authenticated.
  ///
  /// If the user is unauthenticated (guest):
  /// 1. Displays [message] in a floating SnackBar (if provided).
  /// 2. Presents [AuthBottomSheet] displaying [message].
  /// 3. Resumes [onAuthenticated] if login succeeds.
  /// 4. Returns safely to the caller without loops or errors if cancelled.
  static Future<bool> runWithAuth(
    BuildContext context, {
    required VoidCallback onAuthenticated,
    String? message,
    String? title,
    bool requireAddress = false,
  }) async {
    if (isAuthenticated(context)) {
      onAuthenticated();
      return true;
    }

    if (message != null && message.trim().isNotEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    final success = await AuthBottomSheet.show(
      context,
      message: message,
      title: title,
      requireAddress: requireAddress,
    );

    if (success && context.mounted) {
      onAuthenticated();
      return true;
    }

    return false;
  }
}
