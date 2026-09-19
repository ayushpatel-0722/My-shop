import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/routes/app_router.dart';
import '../../app/widgets/language_selector.dart';

/// The single decision screen that routes to one of the three login flows or
/// the company onboarding wizard (Section 3).
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.storefront,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.continueAs,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.selectRole,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              _roleCard(
                context,
                icon: Icons.admin_panel_settings,
                label: l10n.iAmAdmin,
                onTap: () => context.go(AppRoutes.adminLogin),
              ),
              const SizedBox(height: 12),
              _roleCard(
                context,
                icon: Icons.inventory_2_outlined,
                label: l10n.iAmEmployee,
                onTap: () => context.go(AppRoutes.employeeLogin),
              ),
              const SizedBox(height: 12),
              _roleCard(
                context,
                icon: Icons.shopping_bag_outlined,
                label: l10n.iAmShopper,
                onTap: () => context.go(AppRoutes.home),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.go(AppRoutes.companyOnboarding),
                icon: const Icon(Icons.add_business),
                label: Text(l10n.createNewCompany),
              ),
              const Spacer(),
              const LanguageSelector(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Icon(icon, size: 28),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
