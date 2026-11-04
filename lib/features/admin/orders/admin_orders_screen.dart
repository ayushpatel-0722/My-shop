import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:myshop/app/l10n/app_localizations.dart';
import 'package:myshop/core/widgets/app_toast.dart';

import '../../../app/routes/app_router.dart';
import '../../../core/domain/order_status.dart';
import '../../../core/models/order.dart';
import '../../../core/models/review.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../core/widgets/modern_shimmer.dart';
import '../../../core/widgets/order_status_badge.dart';
import '../admin_shell.dart';
import 'widgets/order_filter_bar.dart';
import 'widgets/order_items_dialog.dart';
import 'widgets/payment_verification_dialog.dart';

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
  DateTimeRange? _dateRange;

  bool get _hasFilters =>
      _searchCtrl.text.trim().isNotEmpty ||
      _statusFilter != 'all' ||
      _dateRange != null;

  void _clearFilters() => setState(() {
    _searchCtrl.clear();
    _statusFilter = 'all';
    _dateRange = null;
  });

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
      showBack: false,
      backRoute: AppRoutes.admin,
      title: AppLocalizations.of(context).ordersPipeline,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: OrderFilterBar(
              searchKey: const Key('order-search-field'),
              searchController: _searchCtrl,
              searchHint: AppLocalizations.of(context).referencePincodeProduct,
              onSearchChanged: (_) => setState(() {}),
              dateRange: _dateRange,
              onDateRangeChanged: (r) => setState(() => _dateRange = r),
              onClear: _clearFilters,
              hasActiveFilters: _hasFilters,
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
                          orderInDateRange(o.createdAt, _dateRange) &&
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
                    const SizedBox(height: 20),
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

        final chips = <Widget>[
          _chip(AppLocalizations.of(context).all3, orders.length, 'all'),
          for (final status in OrderStatusRules.boardColumns)
            _chip(orderStatusLabel(context, status), countOf(status), status),
        ];
        return LayoutBuilder(
          builder: (context, c) {
            // Wide windows wrap onto a second line instead of scrolling
            // sideways; phones keep one compact scrolling row.
            if (c.maxWidth >= 640) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Wrap(spacing: 8, runSpacing: 8, children: chips),
              );
            }
            return SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: chips,
              ),
            );
          },
        );
      },
    );
  }

  Widget _chip(String label, int count, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: FilterChip(
        label: Text('$label ($count)'),
        selected: selected == value,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: _Metric(
            label: l10n.openOrders,
            value: '$open',
            icon: Icons.timelapse,
            color: const Color(0xFFD97706),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Metric(
            label: l10n.allOrders,
            value: '${orders.length}',
            icon: Icons.receipt_long,
            color: const Color(0xFF2563EB),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Metric(
            label: l10n.revenue2,
            value: formatCurrency(revenue),
            icon: Icons.currency_rupee,
            color: const Color(0xFF16A34A),
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = context.isDesktop;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 16 : 10,
        vertical: isDesktop ? 14 : 12,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: isDesktop ? 20 : 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isDesktop ? 13 : 11.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: isDesktop ? 22 : 17,
              ),
            ),
          ),
        ],
      ),
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
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: orderStatusColor(status),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                orderStatusLabel(context, status),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: orderStatusColor(status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${orders.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: orderStatusColor(status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (orders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                AppLocalizations.of(context).nothingHere,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
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

const _btnRadius = 10.0;

final ButtonStyle _primaryStyle = FilledButton.styleFrom(
  minimumSize: const Size(0, 42),
  padding: const EdgeInsets.symmetric(horizontal: 18),
  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(_btnRadius),
  ),
);
final ButtonStyle _tonalStyle = FilledButton.styleFrom(
  minimumSize: const Size(0, 42),
  padding: const EdgeInsets.symmetric(horizontal: 16),
  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(_btnRadius),
  ),
);
final ButtonStyle _secondaryStyle = OutlinedButton.styleFrom(
  minimumSize: const Size(0, 42),
  padding: const EdgeInsets.symmetric(horizontal: 16),
  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(_btnRadius),
  ),
);
final ButtonStyle _actionIconStyle = IconButton.styleFrom(
  minimumSize: const Size(42, 42),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(_btnRadius),
  ),
);

/// A small rounded label with an optional icon (payment / delivery info).
class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  final MaterialColor color;

  const _Pill({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color.shade800),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color.shade800,
              ),
            ),
          ),
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
    final isDesktop = context.isDesktop;
    final perms = AuthSession.orderPermissions;
    final rawNext = OrderStatusRules.nextStage(order.orderStatus);
    final next = rawNext != null && perms.canMove(order.orderStatus, rawNext)
        ? rawNext
        : null;
    final cancellable =
        perms.canCancel && OrderStatusRules.isCancellable(order.orderStatus);
    final canVerifyPayment = perms.canVerifyPayment;
    final canConfirm = order.orderStatus == OrderStatus.pending && next != null;
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
        padding: EdgeInsets.all(isDesktop ? 16 : 14),
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
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isDesktop ? 16.5 : 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: order.reference,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            if (dateStr.isNotEmpty)
                              TextSpan(
                                text: ' · $dateStr',
                                style: const TextStyle(color: Colors.grey),
                              ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: isDesktop ? 13 : 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatCurrency(order.totalAmount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isDesktop ? 17.5 : 16,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Status and payment at a glance.
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OrderStatusBadge(status: order.orderStatus),
                _Pill(
                  icon: order.isUpi
                      ? Icons.qr_code_2
                      : (order.isCash
                            ? Icons.payments_outlined
                            : Icons.help_outline),
                  text: 'Payment: ${order.paymentMethodDisplay}',
                  color: order.isPaid
                      ? (order.isUpi ? Colors.indigo : Colors.teal)
                      : Colors.grey,
                ),
                _Pill(
                  icon: order.isPaid
                      ? Icons.check_circle_outline
                      : (order.isPaymentFailed
                            ? Icons.error_outline
                            : Icons.schedule),
                  text: 'Status: ${order.paymentStatusDisplay.toUpperCase()}',
                  color: order.isPaid
                      ? Colors.green
                      : (order.isPaymentFailed ? Colors.red : Colors.orange),
                ),
                _Pill(
                  icon: order.isSelfPickup
                      ? Icons.storefront_outlined
                      : Icons.local_shipping_outlined,
                  text: order.isSelfPickup ? 'Self Pickup' : 'Delivery',
                  color: order.isSelfPickup ? Colors.blue : Colors.teal,
                ),
              ],
            ),

            if (order.isCancelled) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.cancel_outlined,
                      size: isDesktop ? 16 : 14,
                      color: Colors.red.shade700,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Cancelled${order.cancellationReason != null ? ": ${order.cancellationReason}" : ""}${order.cancelledAt != null ? " (${DateFormat('dd MMM, hh:mm a').format(order.cancelledAt!)})" : ""}',
                        style: TextStyle(
                          fontSize: isDesktop ? 13 : 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.red.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (order.items.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 15,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${order.itemCount} item${order.itemCount == 1 ? '' : 's'}'
                      ' · ${order.items.map((i) => i.name).join(', ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isDesktop ? 13 : 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            if (order.canBeReviewed ||
                order.orderStatus == OrderStatus.completed)
              _OrderReviewSummary(
                key: Key('order-review-${order.id}'),
                order: order,
              ),

            if (_isLoading) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(),
            ],

            const Divider(height: 22),

            // Actions: secondary on the left, the one forward action on the
            // right. Buttons share one height, radius and text style.
            LayoutBuilder(
              builder: (context, c) {
                final compact = c.maxWidth < 520;
                final showPay =
                    canVerifyPayment && !order.isPaid && !order.isCancelled;

                final itemsBtn = IconButton.outlined(
                  key: Key('order-items-btn-${order.id}'),
                  icon: const Icon(Icons.shopping_bag_outlined, size: 20),
                  style: _actionIconStyle,
                  tooltip: 'View ordered items (${order.itemCount})',
                  onPressed: () => OrderItemsPreviewDialog.show(context, order),
                );
                final detailsBtn = OutlinedButton(
                  key: Key('order-details-btn-${order.id}'),
                  style: _secondaryStyle,
                  onPressed: () =>
                      context.push(AppRoutes.adminOrderDetailsPath(order.id)),
                  child: const Text('View Details'),
                );
                final payBtn = FilledButton.tonal(
                  key: Key('order-verify-payment-${order.id}'),
                  style: _tonalStyle,
                  onPressed: _isLoading
                      ? null
                      : () => PaymentVerificationDialog.show(context, order),
                  child: const Text('Confirm Payment'),
                );
                final Widget? forwardBtn = canConfirm
                    ? FilledButton(
                        key: Key('order-advance-${order.id}'),
                        style: _primaryStyle.copyWith(
                          backgroundColor: WidgetStatePropertyAll(
                            Colors.green.shade700,
                          ),
                        ),
                        onPressed: _isLoading
                            ? null
                            : () => _confirmOrder(context),
                        child: const Text('Confirm'),
                      )
                    : (next != null
                          ? FilledButton(
                              key: Key('order-advance-${order.id}'),
                              style: _primaryStyle,
                              onPressed: _isLoading
                                  ? null
                                  : () => _advance(context, next),
                              child: Text(orderStatusLabel(context, next)),
                            )
                          : null);
                final cancelBtn = cancellable
                    ? IconButton(
                        key: Key('order-cancel-${order.id}'),
                        icon: Icon(
                          Icons.cancel_outlined,
                          size: 22,
                          color: theme.colorScheme.error,
                        ),
                        tooltip: 'Cancel Order',
                        onPressed: _isLoading
                            ? null
                            : () => _confirmCancel(context),
                      )
                    : null;

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          itemsBtn,
                          const SizedBox(width: 8),
                          Expanded(child: detailsBtn),
                          if (cancelBtn != null) ...[
                            const SizedBox(width: 4),
                            cancelBtn,
                          ],
                        ],
                      ),
                      if (showPay || forwardBtn != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (showPay) Expanded(child: payBtn),
                            if (showPay && forwardBtn != null)
                              const SizedBox(width: 8),
                            if (forwardBtn != null) Expanded(child: forwardBtn),
                          ],
                        ),
                      ],
                    ],
                  );
                }
                return Row(
                  children: [
                    itemsBtn,
                    const SizedBox(width: 8),
                    detailsBtn,
                    const Spacer(),
                    if (showPay) ...[payBtn, const SizedBox(width: 8)],
                    ?forwardBtn,
                    if (cancelBtn != null) ...[
                      const SizedBox(width: 4),
                      cancelBtn,
                    ],
                  ],
                );
              },
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
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green.shade700,
            ),
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
      ScaffoldMessenger.of(context).showAppToast(
        SnackBar(
          content: Text('Order ${order.reference} marked as Confirmed!'),
          backgroundColor: Colors.green.shade800,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showAppToast(
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
      await repo.updateOrderStatus(order.id, next, companyId: order.companyId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showAppToast(
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
      ScaffoldMessenger.of(context).showAppToast(
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
      ScaffoldMessenger.of(context).showAppToast(
        SnackBar(
          content: Text('Order ${order.reference} cancelled.'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showAppToast(
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

/// The review(s) the customer sent for a delivered / completed order, shown on
/// the order card so the shop sees feedback without opening the order.
class _OrderReviewSummary extends StatefulWidget {
  final Order order;
  const _OrderReviewSummary({super.key, required this.order});

  @override
  State<_OrderReviewSummary> createState() => _OrderReviewSummaryState();
}

class _OrderReviewSummaryState extends State<_OrderReviewSummary> {
  late final Future<List<Review>> _reviews = _load();

  Future<List<Review>> _load() async {
    try {
      return await repo.orderReviews(
        widget.order.id,
        companyId: widget.order.companyId,
      );
    } catch (_) {
      return const <Review>[];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<Review>>(
      future: _reviews,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final reviews = snap.data ?? const <Review>[];
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: reviews.isEmpty
                  ? theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    )
                  : Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: reviews.isEmpty
                    ? theme.colorScheme.outlineVariant
                    : Colors.amber.withValues(alpha: 0.4),
              ),
            ),
            child: reviews.isEmpty
                ? Row(
                    children: [
                      Icon(
                        Icons.rate_review_outlined,
                        size: 15,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Waiting for customer review',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [for (final r in reviews) _line(theme, r)],
                  ),
          ),
        );
      },
    );
  }

  Widget _line(ThemeData theme, Review r) {
    final when = r.createdAt != null
        ? DateFormat('dd MMM, hh:mm a').format(r.createdAt!.toLocal())
        : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                Icon(
                  i <= r.rating
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  size: 16,
                  color: Colors.amber.shade700,
                ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  [
                    if (r.productName.isNotEmpty) r.productName,
                    if (when.isNotEmpty) when,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                ),
              ),
            ],
          ),
          if (r.message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                r.message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
        ],
      ),
    );
  }
}
