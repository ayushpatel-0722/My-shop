import 'package:flutter/material.dart';
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
import 'package:my_shop/app/l10n/app_localizations.dart';

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
                if (all.isEmpty) {
                  return _CenteredMessage(
                    icon: Icons.receipt_long_outlined,
                    message: AppLocalizations.of(context).noOrdersYet2,
                    detail:
                        AppLocalizations.of(context).ordersFromYourStoreWillAppearHereInstantly,
                  );
                }
                if (visible.isEmpty) {
                  return _CenteredMessage(
                    icon: Icons.filter_alt_off_outlined,
                    message: AppLocalizations.of(context).noOrdersMatchTheseFilters,
                    detail: AppLocalizations.of(context).clearTheSearchBoxOrPickAnotherStatus,
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

class _OrderCard extends StatelessWidget {
  final Order order;

  const _OrderCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = OrderStatusRules.nextStage(order.orderStatus);
    final cancellable = OrderStatusRules.isCancellable(order.orderStatus);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  order.reference,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 8),
                OrderStatusBadge(status: order.orderStatus),
                const Spacer(),
                Text(
                  formatCurrency(order.totalAmount),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              AppLocalizations.of(context).itemS2('${order.itemCount}', '${order.isSelfPickup ? AppLocalizations.of(context).selfPickup : AppLocalizations.of(context).homeDelivery2}', '${order.pincode.isNotEmpty ? ' · ${order.pincode}' : ''}'),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (order.createdAt != null)
              Text(
                DateFormat(AppLocalizations.of(context).ddMmmHhMmA).format(order.createdAt!),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            if (order.customerName.isNotEmpty ||
                order.customerPhone.isNotEmpty ||
                order.customerEmail.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context).str2('${order.customerName.isNotEmpty ? order.customerName : AppLocalizations.of(context).customer}', '${order.customerPhone.isNotEmpty ? " · ${order.customerPhone}" : ""}', '${order.customerEmail.isNotEmpty ? " (${order.customerEmail})" : ""}'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (order.address.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                order.address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            _BillBreakdown(order: order),
            const Divider(height: 16),
            Container(
              decoration: BoxDecoration(
                color: order.isPaid
                    ? Colors.green.withValues(alpha: 0.08)
                    : Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: order.isPaid
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: SwitchListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                title: Text(
                  order.isPaid
                      ? AppLocalizations.of(context).paymentDoneReceived
                      : AppLocalizations.of(context).paymentPendingManualOffline,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: order.isPaid
                        ? Colors.green.shade800
                        : Colors.orange.shade900,
                  ),
                ),
                subtitle: Text(
                  order.isPaid
                      ? AppLocalizations.of(context).paymentConfirmedByStore
                      : AppLocalizations.of(context).customerWillPayOfflineToggleToMarkAsDone,
                  style: const TextStyle(fontSize: 11),
                ),
                value: order.isPaid,
                onChanged: (_) => repo.togglePaymentStatus(order.id),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (next != null)
                  Expanded(
                    child: FilledButton.tonal(
                      key: Key('order-advance-${order.id}'),
                      onPressed: () => _advance(context, next),
                      child: Text(AppLocalizations.of(context).mark('${orderStatusLabel(context, next)}')),
                    ),
                  ),
                if (next != null && cancellable) const SizedBox(width: 8),
                if (cancellable)
                  Expanded(
                    child: OutlinedButton(
                      key: Key('order-cancel-${order.id}'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                      onPressed: () => _confirmCancel(context),
                      child: Text(AppLocalizations.of(context).cancelOrder),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _advance(BuildContext context, String next) async {
    try {
      await repo.updateOrderStatus(order.id, next);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).order2('${order.reference}', '${orderStatusLabel(context, next)}'),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).couldNotUpdateOrder('${e}'))));
    }
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).cancelThisOrder),
        content: Text(
          AppLocalizations.of(context).orderWillBeCancelledAndTheCustomerWillSeeItUnderCancelled('${order.reference}'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context).keep),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context).cancelOrder),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await repo.cancelOrder(order.id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).couldNotCancelOrder('${e}'))));
    }
  }
}

/// Itemised money block so the admin sees the same bill as the customer.
class _BillBreakdown extends StatelessWidget {
  final Order order;

  const _BillBreakdown({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _row(AppLocalizations.of(context).items4, formatCurrency(order.subtotal)),
          if (order.discountAmount > 0)
            _row(
              AppLocalizations.of(context).discount2('${order.voucherCode.isNotEmpty ? ' (${order.voucherCode})' : ''}'),
              '− ${formatCurrency(order.discountAmount)}',
              color: Colors.green.shade700,
            ),
          _row(AppLocalizations.of(context).delivery, formatCurrency(order.deliveryCharge)),
          const Divider(height: 12),
          _row(AppLocalizations.of(context).payable, formatCurrency(order.totalAmount), bold: true),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
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
