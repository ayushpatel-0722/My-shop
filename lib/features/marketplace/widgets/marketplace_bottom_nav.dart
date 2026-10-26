import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes/app_router.dart';
import '../../../core/utils/auth_guard.dart';
import 'package:myshop/app/l10n/app_localizations.dart';

/// Reusable 4-item bottom navigation bar for the shopper / marketplace experience:
/// 1. Home
/// 2. Categories (All shops & shop categories)
/// 3. Orders
/// 4. Account
class MarketplaceBottomNav extends StatelessWidget {
  const MarketplaceBottomNav({super.key, required this.currentIndex});

  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final navBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFECEEF1);

    return Container(
      decoration: BoxDecoration(
        color: navBg,
        border: Border(top: BorderSide(color: borderColor, width: 1)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(30, 34, 41, 0.06),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Align(
        alignment: Alignment.center,
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: NavigationBar(
            selectedIndex: currentIndex.clamp(0, 3),
            height: 64,
            elevation: 0,
            backgroundColor: navBg,
            indicatorColor: isDark
                ? const Color(0xFF332022)
                : const Color(0xFFFFEBEA),
            onDestinationSelected: (index) async {
              if (index == currentIndex) return;

              switch (index) {
                case 0:
                  context.go(AppRoutes.home);
                  break;
                case 1:
                  context.go(AppRoutes.categories);
                  break;
                case 2:
                  AuthGuard.runWithAuth(
                    context,
                    message: 'Please log in to view your orders.',
                    onAuthenticated: () {
                      context.go(AppRoutes.orders);
                    },
                  );
                  break;
                case 3:
                  context.go(AppRoutes.account);
                  break;
              }
            },
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home, color: Color(0xFFFF5247)),
                label: AppLocalizations.of(context).home,
              ),
              NavigationDestination(
                icon: const Icon(Icons.grid_view_outlined),
                selectedIcon: const Icon(
                  Icons.grid_view_rounded,
                  color: Color(0xFFFF5247),
                ),
                label: AppLocalizations.of(context).categories,
              ),
              NavigationDestination(
                icon: const Icon(Icons.receipt_long_outlined),
                selectedIcon: const Icon(
                  Icons.receipt_long_rounded,
                  color: Color(0xFFFF5247),
                ),
                label: AppLocalizations.of(context).orders,
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline),
                selectedIcon: const Icon(
                  Icons.person,
                  color: Color(0xFFFF5247),
                ),
                label: AppLocalizations.of(context).account,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
