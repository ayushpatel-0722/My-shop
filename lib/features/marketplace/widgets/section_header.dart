import 'package:flutter/material.dart';
import 'package:myshop/app/l10n/app_localizations.dart';
import 'package:myshop/app/theme/app_theme.dart';
import '../../../core/utils/responsive_extensions.dart';

/// Reusable section title with an optional "view all" action.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onViewAll;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = context.isDesktop;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isDesktop ? 8 : 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppTheme.shopperSectionHeading(context)),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: isDesktop ? 13.5 : 12,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onViewAll != null)
            InkWell(
              onTap: onViewAll,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 10 : 6,
                  vertical: isDesktop ? 6 : 4,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocalizations.of(context).seeAll,
                      style: TextStyle(
                        fontSize: isDesktop ? 14 : 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFF5247),
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: Color(0xFFFF5247),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
