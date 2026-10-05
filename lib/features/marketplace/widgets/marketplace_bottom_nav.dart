import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes/app_router.dart';
import '../../auth/auth_cubit.dart';
import '../../auth/widgets/auth_bottom_sheet.dart';
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
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFECEEF1), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(30, 34, 41, 0.06),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: NavigationBar(
        selectedIndex: currentIndex.clamp(0, 3),
        height: 64,
        elevation: 0,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFFFEBEA),
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
              final authCubit = context.read<AuthCubit>();
              if (!authCubit.isLoggedIn) {
                final ok = await AuthBottomSheet.show(context);
                if (ok && context.mounted) {
                  context.go(AppRoutes.orders);
                }
              } else {
                context.go(AppRoutes.orders);
              }
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
            selectedIcon: const Icon(Icons.person, color: Color(0xFFFF5247)),
            label: AppLocalizations.of(context).account,
          ),
        ],
      ),
    );
  }
}
