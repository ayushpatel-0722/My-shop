import 'package:flutter/material.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../core/models/order.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/formatters.dart';
import '../admin_shell.dart';

/// Master order pipeline — Kanban board (Section 17.1). Only the Admin can
/// advance an order's status.
class AdminOrdersScreen extends StatelessWidget {
  const AdminOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AdminShell(
      title: 'Orders Pipeline',
      child: StreamBuilder<List<Order>>(
        stream: repo.orders(),
        builder: (context, snap) {
          final orders = snap.data ?? const <Order>[];
          if (orders.isEmpty) {
            return const Center(child: Text('No orders yet'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final status in OrderStatus.trackerChain) ...[
                _columnHeader(context, status, l10n),
                for (final o in orders.where((e) => e.orderStatus == status))
                  _orderCard(context, o, l10n),
                const SizedBox(height: 16),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _columnHeader(BuildContext context, String status, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        _label(status, l10n),
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _orderCard(BuildContext context, Order order, AppLocalizations l10n) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          ListTile(
            title: Text('#${order.id.substring(0, 6).toUpperCase()} · ${order.companyName}'),
            subtitle: Text('${order.items.length} items · ${formatCurrency(order.totalAmount)}'),
            trailing: _advanceButton(context, order, l10n),
          ),
          SwitchListTile(
            title: Text(l10n.paymentStatus),
            subtitle: Text(order.paymentStatus == 'done'
                ? l10n.paymentDone
                : l10n.paymentPending),
            value: order.paymentStatus == 'done',
            onChanged: (_) => repo.togglePaymentStatus(order.id),
          ),
        ],
      ),
    );
  }

  Widget _advanceButton(BuildContext context, Order order, AppLocalizations l10n) {
    final chain = OrderStatus.trackerChain;
    final idx = chain.indexOf(order.orderStatus);
    if (idx >= chain.length - 1) return const SizedBox.shrink();
    final next = chain[idx + 1];
    return FilledButton.tonal(
      onPressed: () => repo.updateOrderStatus(order.id, next),
      child: Text(_label(next, l10n)),
    );
  }

  String _label(String status, AppLocalizations l10n) {
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
}
