import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../../../core/widgets/modern_card.dart';
import '../admin_shell.dart';

/// Responsive module grid giving the Admin full oversight (Section 17.1).
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final modules = [
      (Icons.view_kanban, AppLocalizations.of(context).ordersPipeline, AppRoutes.adminOrders),
      (Icons.inventory_2, AppLocalizations.of(context).products, AppRoutes.adminProducts),
      (Icons.category, AppLocalizations.of(context).categories, AppRoutes.adminCategories),
      (Icons.local_offer, AppLocalizations.of(context).vouchers, AppRoutes.adminVouchers),
      (Icons.badge, AppLocalizations.of(context).employees, AppRoutes.adminEmployees),
      (Icons.admin_panel_settings, AppLocalizations.of(context).admins, AppRoutes.adminAdmins),
      (Icons.local_shipping, AppLocalizations.of(context).deliveryCharges, AppRoutes.adminDelivery),
      (Icons.image, AppLocalizations.of(context).banners, AppRoutes.adminBanners),
      (Icons.star, AppLocalizations.of(context).reviews, AppRoutes.adminReviews),
      (Icons.recommend, AppLocalizations.of(context).recommendations, AppRoutes.adminRecommendations),
      (Icons.bar_chart, AppLocalizations.of(context).reports, AppRoutes.adminReports),
      (Icons.qr_code_2, AppLocalizations.of(context).qrCodes, AppRoutes.adminQr),
    ];
    return AdminShell(
      title: l10n.dashboard,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: GridView.builder(
            padding: const EdgeInsets.all(24),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 300,
              mainAxisExtent: 180,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: modules.length,
            itemBuilder: (context, i) {
              final m = modules[i];
              return ModernCard(
                onTap: () => context.go(m.$3),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        m.$1,
                        size: 32,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      m.$2,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
