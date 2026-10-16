import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/routes/app_router.dart';
import '../../../core/domain/order_status.dart';
import '../../../core/models/order.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/modern_shimmer.dart';
import '../../../core/widgets/order_status_badge.dart';
import '../admin_shell.dart';
import 'package:myshop/app/l10n/app_localizations.dart';
import 'widgets/order_items_dialog.dart';

/// Master order pipeline for the signed-in store.
///
/// Fixes over the previous version:
///  * **Scoped** to the admin's company instead of reading every order in the
///    platform (`repo.orders()` with no filters leaked other stores' data).
///  * **Cancelled orders are visible** — they used to disappear because the
///    board only rendered `trackerChain` columns.
///  * **Searchable** by reference, store, pincode or product name.
///  * **Legal transitions only** — the advance button is driven by
///    [OrderStatusRules] and cancellation is offered until dispatch.
///  * **Itemised totals** — subtotal / discount / delivery are shown, so the
///    admin sees exactly what the customer was charged.
class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'all';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _companyId => AuthSession.currentUser?.companyId ?? '';

  /// Matches the reference, customer name/phone/email, customer id, pincode, address or any item name.
  bool _matches(Order order, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    if (order.id.toLowerCase().contains(q)) return true;
    if (order.customerName.toLowerCase().contains(q)) return true;
    if (order.customerPhone.toLowerCase().contains(q)) return true;
    if (order.customerEmail.toLowerCase().contains(q)) return true;
    if (order.pincode.toLowerCase().contains(q)) return true;
    if (order.address.toLowerCase().contains(q)) return true;
    if (order.userId.toLowerCase().contains(q)) return true;
    if (order.companyName.toLowerCase().contains(q)) return true;
    return order.items.any((item) => item.name.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      showBack: true,
      backRoute: AppRoutes.admin,
      title: AppLocalizations.of(context).ordersPipeline,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              key: const Key('order-search-field'),
              controller: _searchCtrl,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).searchOrders,
                hintText: AppLocalizations.of(context).referencePincodeProduct,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          _StatusFilterBar(
            selected: _statusFilter,
            onChanged: (value) => setState(() => _statusFilter = value),
          ),
          Expanded(
            child: StreamBuilder<List<Order>>(
              stream: repo.orders(companyId: _companyId),
              builder: (context, snap) {
                final all = snap.data ?? const <Order>[];
                final query = _searchCtrl.text.trim();
                final visible = all
                    .where(
                      (o) =>
                          (_statusFilter == 'all' ||
                              o.orderStatus == _statusFilter) &&
                          _matches(o, query),
                    )
                    .toList();

                if (snap.connectionState == ConnectionState.waiting &&
                    all.isEmpty) {
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: 4,
                    itemBuilder: (_, _) => const M3OrderCardSkeleton(),
                  );
                }
                if (snap.hasError && all.isEmpty) {
                  return _CenteredMessage(
                    icon: Icons.error_outline,
                    message: 'Error loading orders',
                    detail: '${snap.error}',
                  );
                }
                if (all.isEmpty) {
                  return _CenteredMessage(
                    icon: Icons.receipt_long_outlined,
                    message: AppLocalizations.of(context).noOrdersYet2,
                    detail: AppLocalizations.of(
                      context,
                    ).ordersFromYourStoreWillAppearHereInstantly,
                  );
                }
                if (visible.isEmpty) {
                  return _CenteredMessage(
                    icon: Icons.filter_alt_off_outlined,
                    message: AppLocalizations.of(
                      context,
                    ).noOrdersMatchTheseFilters,
                    detail: AppLocalizations.of(
                      context,
                    ).clearTheSearchBoxOrPickAnotherStatus,
                  );
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    _PipelineSummary(orders: all),
                    const SizedBox(height: 12),
                    for (final status in _visibleColumns(visible))
                      _PipelineColumn(
                        status: status,
                        orders: visible
                            .where((o) => o.orderStatus == status)
                            .toList(),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Only render columns that contain something (plus the filter's own column).
  List<String> _visibleColumns(List<Order> orders) {
    final statuses = orders.map((o) => o.orderStatus).toSet();
    if (_statusFilter != 'all') statuses.add(_statusFilter);
    return OrderStatusRules.boardColumns
        .where(statuses.contains)
        .toList(growable: false);
  }
}

/// Chips: All + every pipeline status with a live count.
class _StatusFilterBar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _StatusFilterBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Order>>(
      stream: repo.orders(companyId: AuthSession.currentUser?.companyId ?? ''),
      builder: (context, snap) {
        final orders = snap.data ?? const <Order>[];
        int countOf(String status) =>
            orders.where((o) => o.orderStatus == status).length;

        return SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _chip(AppLocalizations.of(context).all3, orders.length, 'all'),
              for (final status in OrderStatusRules.boardColumns)
                _chip(
                  orderStatusLabel(context, status),
                  countOf(status),
                  status,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(String label, int count, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text('$label ($count)'),
        selected: selected == value,
        onSelected: (_) => onChanged(value),
      ),
    );
  }
}

/// Headline counters for the pipeline.
class _PipelineSummary extends StatelessWidget {
  final List<Order> orders;

  const _PipelineSummary({required this.orders});

  @override
  Widget build(BuildContext context) {
    final open = orders.where((o) => o.isOpen).length;
    final revenue = orders
        .where((o) => !o.isCancelled)
        .fold<double>(0, (sum, o) => sum + o.totalAmount);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: _Metric(
                label: AppLocalizations.of(context).openOrders,
                value: '$open',
                icon: Icons.timelapse,
              ),
            ),
            Expanded(
              child: _Metric(
                label: AppLocalizations.of(context).allOrders,
                value: '${orders.length}',
                icon: Icons.receipt_long,
              ),
            ),
            Expanded(
              child: _Metric(
                label: AppLocalizations.of(context).revenue2,
                value: formatCurrency(revenue),
                icon: Icons.currency_rupee,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _Metric({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

class _PipelineColumn extends StatelessWidget {
  final String status;
  final List<Order> orders;

  const _PipelineColumn({required this.status, required this.orders});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 4, height: 18, color: orderStatusColor(status)),
              const SizedBox(width: 8),
              Text(
                orderStatusLabel(context, status),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '(${orders.length})',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (orders.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                AppLocalizations.of(context).nothingHere,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            )
          else
            for (final order in orders) ...[
              _OrderCard(key: Key('order-card-${order.id}'), order: order),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _OrderCard extends StatefulWidget {
  final Order order;

  const _OrderCard({super.key, required this.order});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _isLoading = false;

  Order get order => widget.order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = OrderStatusRules.nextStage(order.orderStatus);
    final cancellable = OrderStatusRules.isCancellable(order.orderStatus);
    final dateStr = order.createdAt != null
        ? DateFormat('dd MMM, hh:mm a').format(order.createdAt!)
        : '';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Primary text is Customer Name + Total Amount
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.customerName.isNotEmpty
                            ? order.customerName
                            : (order.customerPhone.isNotEmpty
                                ? order.customerPhone
                                : 'Guest Customer'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            order.reference,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          if (dateStr.isNotEmpty) ...[
                            Text(
                              ' · $dateStr',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatCurrency(order.totalAmount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Middle row: Status badges & Fulfillment info
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OrderStatusBadge(status: order.orderStatus),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: order.isPaid
                        ? Colors.green.withValues(alpha: 0.12)
                        : Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    order.isPaid ? 'PAID' : 'PAYMENT PENDING',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: order.isPaid
                          ? Colors.green.shade800
                          : Colors.orange.shade900,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: order.isSelfPickup
                        ? Colors.blue.withValues(alpha: 0.1)
                        : Colors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        order.isSelfPickup
                            ? Icons.storefront_outlined
                            : Icons.local_shipping_outlined,
                        size: 12,
                        color: order.isSelfPickup
                            ? Colors.blue.shade800
                            : Colors.teal.shade800,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        order.isSelfPickup ? 'Self Pickup' : 'Delivery',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: order.isSelfPickup
                              ? Colors.blue.shade800
                              : Colors.teal.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (_isLoading) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(),
            ],

            const Divider(height: 20),

            // Bottom action row: Items button, View Details, Confirm/Advance, Cancel
            Row(
              children: [
                // Quick items dialog button
                IconButton.outlined(
                  key: Key('order-items-btn-${order.id}'),
                  icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'View ordered items (${order.itemCount})',
                  onPressed: () => OrderItemsPreviewDialog.show(context, order),
                ),
                const SizedBox(width: 8),

                // View Details Button
                Expanded(
                  child: OutlinedButton.icon(
                    key: Key('order-details-btn-${order.id}'),
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text(
                      'View Details',
                      style: TextStyle(fontSize: 12.5),
                    ),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: () => context.push(
                      AppRoutes.adminOrderDetailsPath(order.id),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Main forward action: Mark Confirmed or next stage
                if (order.orderStatus == OrderStatus.pending) ...[
                  FilledButton(
                    key: Key('order-advance-${order.id}'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: _isLoading ? null : () => _confirmOrder(context),
                    child: const Text(
                      'Confirm',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                ] else if (next != null) ...[
                  FilledButton.tonal(
                    key: Key('order-advance-${order.id}'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: _isLoading
                        ? null
                        : () => _advance(context, next),
                    child: Text(
                      orderStatusLabel(context, next),
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                ],

                // Cancel button
                if (cancellable) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    key: Key('order-cancel-${order.id}'),
                    icon: Icon(
                      Icons.cancel_outlined,
                      size: 20,
                      color: theme.colorScheme.error,
                    ),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Cancel Order',
                    onPressed: _isLoading ? null : () => _confirmCancel(context),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmOrder(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Order'),
        content: Text(
          'Mark order ${order.reference} as Confirmed? The customer will see the order as Confirmed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await repo.updateOrderStatus(
        order.id,
        OrderStatus.confirmed,
        companyId: order.companyId,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order ${order.reference} marked as Confirmed!'),
          backgroundColor: Colors.green.shade800,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).couldNotUpdateOrder('$e')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _advance(BuildContext context, String next) async {
    setState(() => _isLoading = true);
    try {
      await repo.updateOrderStatus(
        order.id,
        next,
        companyId: order.companyId,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).order2(order.reference, orderStatusLabel(context, next)),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).couldNotUpdateOrder('$e')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).cancelThisOrder),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(
                context,
              ).orderWillBeCancelledAndTheCustomerWillSeeItUnderCancelled(
                order.reference,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Cancellation Reason',
                hintText: 'e.g. Out of stock, customer requested',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(AppLocalizations.of(context).keep),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () {
              final r = reasonCtrl.text.trim();
              Navigator.pop(ctx, r.isEmpty ? 'Cancelled by admin' : r);
            },
            child: Text(AppLocalizations.of(context).cancelOrder),
          ),
        ],
      ),
    );

    if (reason == null) return;

    setState(() => _isLoading = true);
    try {
      await repo.cancelOrder(
        order.id,
        companyId: order.companyId,
        reason: reason,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order ${order.reference} cancelled.'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).couldNotCancelOrder('$e')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}


class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final String detail;

  const _CenteredMessage({
    required this.icon,
    required this.message,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
