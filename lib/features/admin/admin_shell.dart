import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes/app_router.dart';
import '../../core/services/auth_session.dart';
import '../auth/auth_cubit.dart';
import 'package:my_shop/app/l10n/app_localizations.dart';

/// Shared scaffold for admin modules with a navigation drawer.
///
/// The shell listens to [AuthSession] (a plain `ChangeNotifier` kept in sync
/// by [AuthCubit]) rather than requiring an [AuthCubit] in the widget tree.
/// Admin screens therefore render inside a bare `MaterialApp`, which is what
/// the widget tests do.
class AdminShell extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;

  /// When true, shows a back arrow in the AppBar (in addition to the drawer).
  /// Use this for detail/form screens that are navigated to from a list screen.
  final bool showBack;

  /// Route to navigate to when the back button is tapped.
  /// Defaults to [AppRoutes.admin] (dashboard).
  final String backRoute;

  const AdminShell({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.showBack = false,
    this.backRoute = AppRoutes.admin,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AuthSession.instance,
      builder: (context, _) {
        final user = AuthSession.currentUser;
        final companyName = user?.companyName ?? '';

        // Only block while we genuinely have nobody to show. Widget tests and
        // deep links set the session without a restoring phase, and they must
        // not be stuck on a spinner.
        final blocking = AuthSession.isRestoring && user == null;

        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: actions,
            leading: showBack
                ? BackButton(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go(backRoute);
                      }
                    },
                  )
                : null,
          ),
          drawer: Drawer(
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context).adminConsole,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (companyName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            companyName,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _item(context, Icons.dashboard, AppLocalizations.of(context).dashboard, AppRoutes.admin),
                  _item(
                    context,
                    Icons.view_kanban,
                    AppLocalizations.of(context).ordersPipeline,
                    AppRoutes.adminOrders,
                  ),
                  _item(
                    context,
                    Icons.inventory_2,
                    AppLocalizations.of(context).products,
                    AppRoutes.adminProducts,
                  ),
                  _item(
                    context,
                    Icons.category,
                    AppLocalizations.of(context).categories,
                    AppRoutes.adminCategories,
                  ),
                  _item(
                    context,
                    Icons.local_offer,
                    AppLocalizations.of(context).vouchers,
                    AppRoutes.adminVouchers,
                  ),
                  _item(
                    context,
                    Icons.badge,
                    AppLocalizations.of(context).employees,
                    AppRoutes.adminEmployees,
                  ),
                  _item(
                    context,
                    Icons.admin_panel_settings,
                    AppLocalizations.of(context).admins,
                    AppRoutes.adminAdmins,
                  ),
                  _item(
                    context,
                    Icons.local_shipping,
                    AppLocalizations.of(context).deliveryCharges,
                    AppRoutes.adminDelivery,
                  ),
                  _item(
                    context,
                    Icons.image,
                    AppLocalizations.of(context).banners,
                    AppRoutes.adminBanners,
                  ),
                  _item(context, Icons.star, AppLocalizations.of(context).reviews, AppRoutes.adminReviews),
                  _item(
                    context,
                    Icons.recommend,
                    AppLocalizations.of(context).recommendations,
                    AppRoutes.adminRecommendations,
                  ),
                  _item(
                    context,
                    Icons.bar_chart,
                    AppLocalizations.of(context).reports,
                    AppRoutes.adminReports,
                  ),
                  _item(
                    context,
                    Icons.qr_code_2,
                    AppLocalizations.of(context).qrCodes,
                    AppRoutes.adminQr,
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.storefront),
                    title: Text(AppLocalizations.of(context).shopperApp),
                    onTap: () => context.go(AppRoutes.home),
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: Text(AppLocalizations.of(context).logout),
                    onTap: () async {
                      await context.read<AuthCubit>().signOut();
                      if (context.mounted) context.go(AppRoutes.role);
                    },
                  ),
                ],
              ),
            ),
          ),
          body: blocking
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                      SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context).restoringSession,
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : child,
        );
      },
    );
  }

  Widget _item(
    BuildContext context,
    IconData icon,
    String label,
    String route,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () => context.go(route),
    );
  }
}
