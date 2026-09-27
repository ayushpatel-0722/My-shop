import 'package:flutter/material.dart';

import '../../app/l10n/app_localizations.dart';
import '../models/order.dart';
import '../../app/l10n/l10n_service.dart';

/// Plain English fallback used when the widget tree has no localizations
/// delegate (isolated screens, widget tests, storybook-style previews).
const Map<String, String> _englishStatusLabels = {
  OrderStatus.pending: 'Pending',
  OrderStatus.confirmed: 'Confirmed',
  OrderStatus.packing: 'Packing',
  OrderStatus.ready: 'Ready',
  OrderStatus.onTheWay: 'On the way',
  OrderStatus.completed: 'Completed',
  OrderStatus.cancelled: 'Cancelled',
};

/// Human readable status label.
///
/// Never throws: falls back to English when [AppLocalizations] is not mounted.
String orderStatusLabel(BuildContext context, String status) {
  final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
  if (l10n == null) return _englishStatusLabels[status] ?? status;

  switch (status) {
    case OrderStatus.pending:
      return l10n.pending;
    case OrderStatus.confirmed:
      return l10n.confirmed;
    case OrderStatus.cancelled:
      return l10n.cancelled;
    case OrderStatus.packing:
      return l10n.packing;
    case OrderStatus.ready:
      return l10n.ready;
    case OrderStatus.onTheWay:
      return l10n.onTheWay;
    case OrderStatus.completed:
      return l10n.completed;
    default:
      return status;
  }
}

/// Colour used for the status chip / timeline dot.
Color orderStatusColor(String status) {
  switch (status) {
    case OrderStatus.confirmed:
      return const Color(0xFF2563EB);
    case OrderStatus.packing:
      return const Color(0xFFD97706);
    case OrderStatus.ready:
    case OrderStatus.onTheWay:
      return const Color(0xFF7C3AED);
    case OrderStatus.completed:
      return const Color(0xFF1E8F66);
    case OrderStatus.cancelled:
      return const Color(0xFFDC2626);
    case OrderStatus.pending:
    default:
      return const Color(0xFFFF5247);
  }
}

/// Small coloured pill showing the current status of an order.
class OrderStatusBadge extends StatelessWidget {
  final String status;

  const OrderStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = orderStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        orderStatusLabel(context, status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
