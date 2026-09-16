import 'package:flutter/material.dart';
import 'package:collection/collection.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../core/models/order.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/formatters.dart';

/// Pizza-tracker-style order timeline (Section 17.3 / Section 11).
class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  Order? _order;

  @override
  void initState() {
    super.initState();
    repo.orders().listen((list) {
      final o = list.where((e) => e.id == widget.orderId).firstOrNull;
      if (mounted) setState(() => _order = o);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final order = _order;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.orderStatus)),
      body: order == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _statusHeader(order, l10n),
                const SizedBox(height: 24),
                _timeline(order, l10n),
                const SizedBox(height: 32),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long),
                    title: Text(l10n.totalAmount),
                    trailing: Text(
                      formatCurrency(order.totalAmount),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.payments_outlined),
                    title: Text(l10n.paymentStatus),
                    trailing: Chip(
                      label: Text(order.paymentStatus == 'done'
                          ? l10n.paymentDone
                          : l10n.paymentPending),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _statusHeader(Order order, AppLocalizations l10n) {
    return Column(
      children: [
        Text(
          'Order #${order.id.substring(0, 6).toUpperCase()}',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text('${order.items.length} items · ${formatDate(order.createdAt)}'),
      ],
    );
  }

  Widget _timeline(Order order, AppLocalizations l10n) {
    final chain = OrderStatus.trackerChain;
    final currentIndex = chain.indexOf(order.orderStatus);
    return Column(
      children: List.generate(chain.length, (i) {
        final isDone = i <= currentIndex;
        final isCurrent = i == currentIndex;
        final label = _statusLabel(chain[i], l10n);
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

  String _statusLabel(String status, AppLocalizations l10n) {
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
