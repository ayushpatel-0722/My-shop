import 'package:flutter/material.dart';

import '../../../../app/l10n/app_localizations.dart';

/// What the admin chose in a plan-limit dialog.
enum PlanLimitChoice { cancel, confirm, upgrade }

/// A friendly "you have reached your plan limit" card: an icon, what happened,
/// how full the plan is, and what to do next. Never wider than 600.
///
/// Used for both limits (publishing and total products); the caller supplies
/// the words and numbers.
Future<PlanLimitChoice> showPlanLimitDialog(
  BuildContext context, {
  required Key dialogKey,
  required IconData icon,
  required Color color,
  required String title,
  required String message,
  required String usageLabel,
  required int used,
  required int total,

  /// The main button (e.g. "Save as unpublished"); null for none.
  String? confirmLabel,
  Key? confirmKey,

  /// Dismiss button label and key.
  required String cancelLabel,
  required Key cancelKey,

  /// Button that goes to the plan page.
  required Key upgradeKey,
}) async {
  final l10n = AppLocalizations.of(context);
  final choice = await showDialog<PlanLimitChoice>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return Dialog(
        key: dialogKey,
        backgroundColor: theme.colorScheme.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Coloured header with the icon.
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  color: color.withValues(alpha: 0.10),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: color, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.45,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.85,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      // How full the plan is.
                      Container(
                        key: const Key('plan-limit-usage'),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    usageLabel,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Text(
                                  l10n.productLimitUsed(used, total),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: total == 0
                                    ? 1
                                    : (used / total).clamp(0, 1).toDouble(),
                                minHeight: 8,
                                color: color,
                                backgroundColor: color.withValues(alpha: 0.15),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        key: cancelKey,
                        onPressed: () =>
                            Navigator.pop(ctx, PlanLimitChoice.cancel),
                        child: Text(cancelLabel),
                      ),
                      OutlinedButton.icon(
                        key: upgradeKey,
                        icon: const Icon(Icons.workspace_premium_outlined),
                        onPressed: () =>
                            Navigator.pop(ctx, PlanLimitChoice.upgrade),
                        label: Text(l10n.upgradePlan),
                      ),
                      if (confirmLabel != null)
                        FilledButton(
                          key: confirmKey,
                          onPressed: () =>
                              Navigator.pop(ctx, PlanLimitChoice.confirm),
                          child: Text(confirmLabel),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return choice ?? PlanLimitChoice.cancel;
}
