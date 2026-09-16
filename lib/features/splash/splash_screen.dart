import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes/app_router.dart';
import '../auth/auth_cubit.dart';

/// Branded splash screen (Section 3). Shows the logo while the auth session is
/// being restored, then routes to the appropriate dashboard (if already signed
/// in) or the role-selection screen (if not).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Safety timeout: if the auth restore takes too long (e.g. offline + cache
    // miss), force navigation to role selection after 4 seconds.
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted || _navigated) return;
      _navigated = true;
      context.go(AppRoutes.role);
    });
  }

  void _navigateBasedOnAuth(AuthState authState) {
    if (_navigated || !mounted) return;

    if (authState.restoring) return; // still checking

    _navigated = true;

    if (authState.status == AuthStatus.authenticated &&
        authState.user != null) {
      final user = authState.user!;
      if (user.isAdmin) {
        context.go(AppRoutes.admin);
      } else if (user.isEmployee) {
        context.go(AppRoutes.employeeHome);
      } else {
        context.go(AppRoutes.home);
      }
    } else {
      context.go(AppRoutes.role);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) => _navigateBasedOnAuth(state),
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(28),
                ),
                child:
                    const Icon(Icons.storefront, size: 52, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Text(
                'Bazaar',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Multi-tenant commerce',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
