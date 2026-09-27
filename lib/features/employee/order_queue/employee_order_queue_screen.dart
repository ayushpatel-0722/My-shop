import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../../../core/models/order.dart';
import '../../../core/services/service_locator.dart';
import '../../auth/auth_cubit.dart';

/// Employee operations hub — high-contrast, minimal, shows only assigned
/// packing tasks (Section 17.2). Employees never edit order status.
class EmployeeOrderQueueScreen extends StatelessWidget {
  const EmployeeOrderQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).queue('${l10n.packing}')),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: AppLocalizations.of(context).logout,
            onPressed: () async {
              await context.read<AuthCubit>().signOut();
              if (context.mounted) context.go(AppRoutes.role);
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Order>>(
        // Only this store's orders — the queue used to read every order of
        // every company on the platform.
        stream: repo.orders(
          companyId: context.watch<AuthCubit>().currentUser?.companyId ?? '',
        ),
        builder: (context, snap) {
          final employeeId =
              context.watch<AuthCubit>().currentUser?.id ?? '';
          final orders = (snap.data ?? const <Order>[])
              .where(
                (o) =>
                    o.orderStatus == OrderStatus.packing &&
                    (o.assignedEmployeeId == null ||
                        o.assignedEmployeeId!.isEmpty ||
                        o.assignedEmployeeId == employeeId),
              )
              .toList();

          if (snap.connectionState == ConnectionState.waiting &&
              orders.isEmpty) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          if (orders.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(AppLocalizations.of(context).noPackingTasksAssigned),
              ),
            );
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
                  title: Text(
                    o.reference,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    AppLocalizations.of(context).items5('${o.itemCount}', '${o.isSelfPickup ? AppLocalizations.of(context).pickup : AppLocalizations.of(context).delivery}', '${o.employeePackingDone ? AppLocalizations.of(context).packed : ''}'),
                  ),
                  trailing: FilledButton(
                    onPressed: () => context.go(
                      AppRoutes.packing.replaceFirst(':orderId', o.id),
                    ),
                    child: Text(AppLocalizations.of(context).pack),
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
