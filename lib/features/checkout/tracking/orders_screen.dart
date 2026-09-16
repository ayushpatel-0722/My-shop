import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../../../core/models/order.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/auth_cubit.dart';

/// The shopper's order history.
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.orders)),
      body: Builder(
        builder: (context) {
          final userId = context.read<AuthCubit>().currentUser?.id ?? 'guest';
          return StreamBuilder<List<Order>>(
            stream: repo.orders(userId: userId),
            builder: (context, snap) {
              final list = snap.data ?? const <Order>[];
              if (list.isEmpty) {
                return const Center(child: Text('No orders yet'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (context, i) => _orderCard(context, list[i], l10n),
              );
            },
          );
        },
      ),
    );
  }

  Widget _orderCard(BuildContext context, Order order, AppLocalizations l10n) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.receipt_long)),
        title: Text('Order #${order.id.substring(0, 6).toUpperCase()}'),
        subtitle: Text(
          '${order.items.length} items · ${_statusLabel(order.orderStatus, l10n)}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatCurrency(order.totalAmount),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              formatDate(order.createdAt),
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        onTap: () => context.go(AppRoutes.orderPath(order.id)),
      ),
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
