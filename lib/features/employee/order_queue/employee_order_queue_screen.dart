import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../../../core/models/order.dart';
import '../../../core/services/service_locator.dart';

/// Employee operations hub — high-contrast, minimal, shows only assigned
/// packing tasks (Section 17.2). Employees never edit order status.
class EmployeeOrderQueueScreen extends StatelessWidget {
  const EmployeeOrderQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('${l10n.packing} Queue')),
      body: StreamBuilder<List<Order>>(
        stream: repo.orders(),
        builder: (context, snap) {
          final orders = (snap.data ?? const <Order>[])
              .where((o) => o.orderStatus == OrderStatus.packing)
              .toList();
          if (orders.isEmpty) {
            return const Center(child: Text('No packing tasks assigned'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, i) {
              final o = orders[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.inventory_2, size: 32),
                  title: Text('#${o.id.substring(0, 6).toUpperCase()}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      '${o.items.length} items · ${o.deliveryType == 'self_pickup' ? 'Pickup' : 'Delivery'}'),
                  trailing: FilledButton(
                    onPressed: () =>
                        context.go(AppRoutes.packing.replaceFirst(':orderId', o.id)),
                    child: const Text('Pack'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
