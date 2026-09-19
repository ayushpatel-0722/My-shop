import 'package:flutter/material.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../core/domain/order_status.dart';
import '../../../core/models/order.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/order_status_badge.dart';

/// Pizza-tracker-style order timeline (Section 17.3 / Section 11).
///
/// Now watches a **single** order (`repo.watchOrder`) instead of subscribing
/// to every order in the platform, shows the full bill and lets the shopper
/// cancel while the store has not dispatched the parcel yet.
class OrderTrackingScreen extends StatelessWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.orderStatus)),
      body: StreamBuilder<Order?>(
        stream: repo.watchOrder(orderId),
        builder: (context, snap) {
          final order = snap.data;

          if (order == null) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text('This order is no longer available.'),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _statusHeader(context, order),
              const SizedBox(height: 24),
              _timeline(context, order),
              const SizedBox(height: 24),
              _BillCard(order: order, l10n: l10n),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: Text(l10n.paymentStatus),
                  trailing: Chip(
                    label: Text(
                      order.isPaid ? l10n.paymentDone : l10n.paymentPending,
                    ),
                  ),
                ),
              ),
              if (order.address.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: const Text('Delivery address'),
                    subtitle: Text(order.address),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    for (final item in order.items)
                      ListTile(
                        dense: true,
                        title: Text(
                          item.name.isNotEmpty ? item.name : item.productId,
                        ),
                        subtitle: Text('${item.qty} × ${formatCurrency(item.unitPrice)}'),
                        trailing: Text(formatCurrency(item.itemTotal)),
                      ),
                  ],
                ),
              ),
              if (OrderStatusRules.isCancellable(order.orderStatus)) ...[
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  icon: const Icon(Icons.cancel_outlined),
                  label: Text(l10n.cancel),
                  onPressed: () => _confirmCancel(context, order),
                ),
              ],
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, Order order) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: Text(
          'Order ${order.reference} will be cancelled. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await repo.cancelOrder(order.id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not cancel order: $e')),
      );
    }
  }

  Widget _statusHeader(BuildContext context, Order order) {
    return Column(
      children: [
        Text(
          'Order ${order.reference}',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          '${order.itemCount} items · ${formatDate(order.createdAt)}',
        ),
        const SizedBox(height: 10),
        OrderStatusBadge(status: order.orderStatus),
      ],
    );
  }

  Widget _timeline(BuildContext context, Order order) {
    final chain = OrderStatus.trackerChain;
    final cancelled = order.isCancelled;
    final currentIndex = OrderStatusRules.trackerIndex(order.orderStatus);

    if (cancelled) {
      return Row(
        children: [
          const Icon(Icons.cancel, color: Color(0xFFDC2626)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Cancelled${order.cancelledAt == null ? '' : ' on ${formatDate(order.cancelledAt)}'}',
              style: const TextStyle(
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: List.generate(chain.length, (i) {
        final isDone = i <= currentIndex;
        final isCurrent = i == currentIndex;
        final label = orderStatusLabel(context, chain[i]);
        return IntrinsicHeight(
          child: Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade300,
                    ),
                    child: Icon(
                      isDone ? Icons.check : Icons.circle,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  if (i != chain.length - 1)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: i < currentIndex
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade300,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isDone
                        ? Theme.of(context).colorScheme.onSurface
                        : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// Itemised bill identical to the one shown at checkout.
class _BillCard extends StatelessWidget {
  final Order order;
  final AppLocalizations l10n;

  const _BillCard({required this.order, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            _row(l10n.subtotal, formatCurrency(order.subtotal)),
            if (order.discountAmount > 0)
              _row(
                '${l10n.discount}${order.voucherCode.isNotEmpty ? ' (${order.voucherCode})' : ''}',
                '− ${formatCurrency(order.discountAmount)}',
                color: Colors.green.shade700,
              ),
            _row(l10n.deliveryCharge, formatCurrency(order.deliveryCharge)),
            const Divider(height: 18),
            _row(
              l10n.totalAmount,
              formatCurrency(order.totalAmount),
              bold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    bool bold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
