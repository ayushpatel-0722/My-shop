import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:myshop/app/routes/app_router.dart';
import 'package:myshop/app/l10n/app_localizations.dart';

/// Read-only "Customer Details" card (name, email, mobile).
///
/// The values come from the signed-in user's profile and are NOT editable
/// here. When the name or mobile number is missing the card shows a warning
/// with an "Update Profile" link and the order flow stays blocked until the
/// profile is complete.
class CustomerDetailsCard extends StatelessWidget {
  final String name;
  final String email;
  final String mobile;

  const CustomerDetailsCard({
    super.key,
    required this.name,
    required this.email,
    required this.mobile,
  });

  /// True when the profile has everything an order needs.
  bool get isComplete => name.trim().isNotEmpty && mobile.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person_pin_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context).customerDetails,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _readOnlyRow(
              context,
              icon: Icons.person_outline,
              label: AppLocalizations.of(context).name,
              value: name,
              missing: name.trim().isEmpty,
            ),
            const SizedBox(height: 8),
            _readOnlyRow(
              context,
              icon: Icons.phone_outlined,
              label: AppLocalizations.of(context).mobile,
              value: mobile,
              missing: mobile.trim().isEmpty,
            ),
            const SizedBox(height: 8),
            _readOnlyRow(
              context,
              icon: Icons.email_outlined,
              label: AppLocalizations.of(context).email,
              value: email,
              missing: false,
            ),
            if (!isComplete) ...[
              const SizedBox(height: 10),
              Container(
                key: const Key('customer-profile-warning'),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade700),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: Colors.amber.shade900,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(
                          context,
                        ).pleaseCompleteYourProfileNameMobileBeforePlacingAnOrder,
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                    TextButton(
                      key: const Key('update-profile-link'),
                      onPressed: () => context.go(AppRoutes.account),
                      child: Text(AppLocalizations.of(context).updateProfile),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _readOnlyRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required bool missing,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 17, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            key: Key('customer-${label.toLowerCase()}'),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: missing
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
