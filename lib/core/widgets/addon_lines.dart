import 'package:flutter/material.dart';

import '../../app/l10n/app_localizations.dart';
import '../models/product_addon.dart';
import '../utils/formatters.dart';

/// The add-ons of one cart / order line as small "+ Title  +₹500" rows.
///
/// Prices are per unit of the product, matching the unit price shown beside
/// them. Renders nothing for a line without add-ons.
class AddOnLines extends StatelessWidget {
  final List<AddOnSnapshot> addOns;
  final String symbol;
  final TextStyle? style;

  const AddOnLines({
    super.key,
    required this.addOns,
    this.symbol = '₹',
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (addOns.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final base =
        style ??
        Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
        );
    return Column(
      key: const Key('addon-lines'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final a in addOns)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              a.price > 0
                  ? '+ ${a.title}  ·  +${formatCurrency(a.price, symbol: symbol)}'
                  : '+ ${a.title}  ·  ${l10n.addOnFree}',
              style: base,
            ),
          ),
      ],
    );
  }
}
