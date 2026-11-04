import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/routes/app_router.dart';
import '../../app/widgets/language_selector.dart';
import '../auth/widgets/auth_page_shell.dart';

/// The single decision screen that routes to one of the three login flows or
/// the company onboarding wizard (Section 3).
///
/// Phone: a single column of large, easy-to-tap role cards. Wide screens:
/// the same cards in a centred, width-limited card.
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AuthPageShell(
      title: l10n.continueAs,
      subtitle: l10n.selectRole,
      showBack: false,
      maxWidth: 480,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RoleCard(
            icon: Icons.admin_panel_settings,
            label: l10n.iAmAdmin,
            onTap: () => context.go(AppRoutes.adminLogin),
          ),
          const SizedBox(height: 12),
          _RoleCard(
            icon: Icons.inventory_2_outlined,
            label: l10n.iAmEmployee,
            onTap: () => context.go(AppRoutes.employeeLogin),
          ),
          const SizedBox(height: 12),
          _RoleCard(
            icon: Icons.shopping_bag_outlined,
            label: l10n.iAmShopper,
            onTap: () => context.go(AppRoutes.home),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Divider(color: scheme.outlineVariant)),
              const SizedBox(width: 12),
              Icon(Icons.business_outlined, size: 16, color: scheme.outline),
              const SizedBox(width: 12),
              Expanded(child: Divider(color: scheme.outlineVariant)),
            ],
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => context.go(AppRoutes.companyOnboarding),
            icon: const Icon(Icons.add_business),
            label: Text(l10n.createNewCompany),
          ),
          const SizedBox(height: 28),
          const Center(child: LanguageSelector()),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: scheme.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
