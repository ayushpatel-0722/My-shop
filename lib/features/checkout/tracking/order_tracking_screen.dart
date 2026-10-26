import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../../../core/domain/order_status.dart';
import '../../../core/models/order.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/modern_shimmer.dart';
import '../../../core/widgets/order_status_badge.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../auth/auth_cubit.dart';

/// Pizza-tracker-style order timeline (Section 17.3 / Section 11).
///
/// Now watches a **single** order (`repo.watchOrder`) instead of subscribing
/// to every order in the platform, shows the full bill and lets the shopper
/// cancel while the store has not dispatched the parcel yet.
class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  final String? companyId;
  const OrderTrackingScreen({super.key, required this.orderId, this.companyId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  bool _isCancelling = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go(AppRoutes.orders);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.orderStatus),
          leading: BackButton(
            onPressed: () {
              context.go(AppRoutes.orders);
            },
          ),
        ),
        body: StreamBuilder<Order?>(
          stream: repo.watchOrder(
            widget.orderId,
            companyId: widget.companyId ?? '',
          ),
          builder: (context, snap) {
            final order = snap.data;

            if (order == null) {
              if (snap.connectionState == ConnectionState.waiting) {
                return M3CenterLoader(
                  message: AppLocalizations.of(context).loadingOrderDetails,
                );
              }
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.receipt_long_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(
                          context,
                        ).thisOrderIsNoLongerAvailable,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'We could not locate this order. It might still be synchronizing or belong to another account.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          FilledButton.icon(
                            onPressed: () => context.go(AppRoutes.orders),
                            icon: const Icon(Icons.list_alt, size: 18),
                            label: const Text('View All Orders'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => context.go(AppRoutes.home),
                            icon: const Icon(Icons.home_outlined, size: 18),
                            label: Text(l10n.home),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }

            if (context.isDesktop) {
              return _buildDesktopLayout(context, order, l10n);
            }
            return _buildMobileLayout(context, order, l10n);
          },
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    Order order,
    AppLocalizations l10n,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            // Breadcrumbs
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => context.go(AppRoutes.home),
                    child: Text(
                      l10n.home,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => context.go(AppRoutes.orders),
                    child: const Text(
                      'My Orders',
                      style: TextStyle(
                        color: Color(0xFF3D38D9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Order #${order.reference}',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Top Status Banner
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: order.isCancelled
                            ? Theme.of(context).colorScheme.errorContainer
                                  .withValues(alpha: 0.5)
                            : Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        order.isCancelled
                            ? Icons.cancel_outlined
                            : Icons.check_circle_outline,
                        size: 32,
                        color: order.isCancelled
                            ? Theme.of(context).colorScheme.error
                            : Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(
                              context,
                            ).order3(order.reference),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppLocalizations.of(context).items(
                              '${order.itemCount}',
                              formatDate(order.createdAt),
                            ),
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OrderStatusBadge(status: order.orderStatus),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 2-Column Desktop Grid
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column (Timeline, History, Ordered Items, Delivery details)
                Expanded(
                  flex: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _timeline(context, order),
                      if (order.statusHistory.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _statusHistoryCard(context, order),
                      ],
                      const SizedBox(height: 16),
                      _itemsCard(context, order),
                      const SizedBox(height: 16),
                      _deliveryDetailsCard(context, order),
                    ],
                  ),
                ),
                const SizedBox(width: 20),

                // Right Column (Bill Card, Payment Status, Store Info, Actions)
                SizedBox(
                  width: 380,
                  child: Column(
                    children: [
                      _BillCard(order: order, l10n: l10n),
                      const SizedBox(height: 12),
                      _storeInfoCard(order),
                      const SizedBox(height: 12),
                      _paymentStatusCard(context, order, l10n),
                      const SizedBox(height: 16),
                      _actionsCard(context, order, l10n),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    Order order,
    AppLocalizations l10n,
  ) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _statusHeader(context, order),
        const SizedBox(height: 20),
        _timeline(context, order),
        if (order.statusHistory.isNotEmpty) ...[
          const SizedBox(height: 16),
          _statusHistoryCard(context, order),
        ],
        const SizedBox(height: 20),
        _BillCard(order: order, l10n: l10n),
        const SizedBox(height: 12),
        _storeInfoCard(order),
        const SizedBox(height: 12),
        _paymentStatusCard(context, order, l10n),
        if (order.customerName.isNotEmpty ||
            order.customerPhone.isNotEmpty ||
            order.address.isNotEmpty) ...[
          const SizedBox(height: 12),
          _deliveryDetailsCard(context, order),
        ],
        const SizedBox(height: 12),
        _itemsCard(context, order),
        const SizedBox(height: 20),
        _actionsCard(context, order, l10n),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _storeInfoCard(Order order) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        leading: const Icon(Icons.storefront_outlined),
        title: const Text('Store / Vendor'),
        subtitle: Text(
          order.companyName.isNotEmpty
              ? '${order.companyName} (${order.companyId})'
              : order.companyId,
        ),
      ),
    );
  }

  Widget _paymentStatusCard(
    BuildContext context,
    Order order,
    AppLocalizations l10n,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        leading: const Icon(Icons.payments_outlined),
        title: Text(l10n.paymentStatus),
        trailing: Chip(
          label: Text(order.isPaid ? l10n.paymentDone : l10n.paymentPending),
        ),
      ),
    );
  }

  Widget _deliveryDetailsCard(BuildContext context, Order order) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_shipping_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  order.isSelfPickup ? 'Pickup Details' : 'Delivery Details',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            if (order.customerName.isNotEmpty ||
                order.customerPhone.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 18,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${order.customerName}${order.customerPhone.isNotEmpty ? " · ${order.customerPhone}" : ""}${order.customerEmail.isNotEmpty ? " (${order.customerEmail})" : ""}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            if (order.isSelfPickup && order.pickupShop != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.store_outlined,
                    size: 18,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${order.pickupShop!.name}\n${order.pickupShop!.address}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ] else if (order.address.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.address,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _itemsCard(BuildContext context, Order order) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.shopping_bag_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Ordered Items (${order.items.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            for (final item in order.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    if (item.image.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          item.image,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.shopping_bag_outlined,
                              size: 20,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.shopping_bag_outlined,
                          size: 20,
                          color: Colors.grey,
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name.isNotEmpty ? item.name : item.productId,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                          if (item.variantTitle.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.variantTitle,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.qty} × ${formatCurrency(item.unitPrice)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatCurrency(item.itemTotal),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _actionsCard(
    BuildContext context,
    Order order,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (OrderStatusRules.isCustomerCancellable(order.orderStatus)) ...[
          OutlinedButton.icon(
            key: Key('tracking-cancel-order-${order.id}'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.error.withValues(alpha: 0.5),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: _isCancelling
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cancel_outlined),
            label: Text(l10n.cancel),
            onPressed: _isCancelling
                ? null
                : () => _confirmCancel(context, order),
          ),
          const SizedBox(height: 10),
        ] else if (order.isOpen) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    OrderStatusRules.customerCancellationIneligibleReason(
                          order.orderStatus,
                        ) ??
                        'This order is being processed and can no longer be cancelled.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: () => context.go(AppRoutes.home),
          icon: const Icon(Icons.shopping_bag_outlined, size: 18),
          label: const Text('Continue Shopping'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: () => context.go(AppRoutes.orders),
          icon: const Icon(Icons.list_alt, size: 18),
          label: const Text('View All Orders'),
        ),
      ],
    );
  }

  Future<void> _confirmCancel(BuildContext context, Order order) async {
    final l10n = AppLocalizations.of(context);
    final userId = context.read<AuthCubit>().currentUser?.id ?? order.userId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cancelThisOrder),
        content: Text(
          l10n.orderWillBeCancelledThisCannotBeUndone(order.reference),
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
            child: Text(l10n.yesCancel),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    setState(() => _isCancelling = true);

    try {
      await repo.cancelOrder(
        order.id,
        companyId: order.companyId,
        reason: 'Cancelled by customer',
        userId: userId,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order ${order.reference} cancelled successfully.'),
          backgroundColor: Colors.green.shade800,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      final errorColor = Theme.of(context).colorScheme.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is StateError ? e.message : 'Could not cancel order: $e',
          ),
          backgroundColor: errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Widget _statusHeader(BuildContext context, Order order) {
    return Column(
      children: [
        Text(
          AppLocalizations.of(context).order3(order.reference),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          AppLocalizations.of(
            context,
          ).items('${order.itemCount}', formatDate(order.createdAt)),
        ),
        const SizedBox(height: 10),
        OrderStatusBadge(status: order.orderStatus),
      ],
    );
  }

  Widget _statusHistoryCard(BuildContext context, Order order) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Order Timeline',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...order.statusHistory.reversed.map((entry) {
              final isCancelledEntry = entry.status == OrderStatus.cancelled;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 5, right: 10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCancelledEntry
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.note.isNotEmpty
                                ? entry.note
                                : entry.status.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: isCancelledEntry
                                  ? Theme.of(context).colorScheme.error
                                  : null,
                            ),
                          ),
                          Text(
                            formatDate(entry.timestamp),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _timeline(BuildContext context, Order order) {
    final chain = OrderStatus.trackerChain;
    final cancelled = order.isCancelled;
    final currentIndex = OrderStatusRules.trackerIndex(order.orderStatus);

    if (cancelled) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFDC2626).withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cancel, color: Color(0xFFDC2626)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).cancelled2(
                      order.cancelledAt == null
                          ? ''
                          : AppLocalizations.of(
                              context,
                            ).msgOn(formatDate(order.cancelledAt)),
                    ),
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            if (order.cancellationReason != null &&
                order.cancellationReason!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Reason: ${order.cancellationReason}',
                style: const TextStyle(
                  color: Color(0xFF991B1B),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
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

  Widget _row(String label, String value, {bool bold = false, Color? color}) {
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
