import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/domain/order_status.dart';
import '../../../core/models/order.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/order_status_badge.dart';
import '../../auth/auth_cubit.dart';
import '../../auth/widgets/auth_bottom_sheet.dart';
import '../../marketplace/widgets/marketplace_bottom_nav.dart';

/// The shopper's order history.
///
/// Improvements over the previous version: status filters with live counts,
/// the real payable amount (including discount and delivery), item previews
/// and a cancel action for orders that have not been dispatched yet.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String _statusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authCubit = context.watch<AuthCubit>();
    final user = authCubit.currentUser;
    final isLoggedIn = authCubit.isLoggedIn && user != null;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text(
          l10n.orders,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
        ),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: !isLoggedIn
          ? _buildGuestView(context)
          : Column(
              children: [
                _StatusChips(
                  selected: _statusFilter,
                  onChanged: (value) => setState(() => _statusFilter = value),
                ),
                Expanded(
                  child: StreamBuilder<List<Order>>(
                    stream: repo.orders(userId: user.id),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting &&
                          (snap.data?.isEmpty ?? true)) {
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }
                      final all = snap.data ?? const <Order>[];
                      final list = _statusFilter == 'all'
                          ? all
                          : all
                                .where((o) => o.orderStatus == _statusFilter)
                                .toList();

                      if (all.isEmpty) {
                        return _buildEmptyOrdersView(context, l10n);
                      }
                      if (list.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text('No orders with this status'),
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) =>
                            _orderCard(context, list[i], l10n),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: const MarketplaceBottomNav(currentIndex: 2),
    );
  }

  Widget _buildGuestView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFFFEBEA),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 56,
                color: Color(0xFFFF5247),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Sign In to View Orders',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E2229),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Keep track of your active deliveries and past purchases.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5247),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed: () => AuthBottomSheet.show(context),
              icon: const Icon(Icons.login),
              label: const Text(
                'Continue with Google',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyOrdersView(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                size: 56,
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Orders Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E2229),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Explore products and place your first order today!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5247),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed: () => context.go(AppRoutes.home),
              child: const Text(
                'Start Shopping',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderCard(BuildContext context, Order order, AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final preview = order.items
        .take(2)
        .map((e) {
          final hasVariant = e.variantTitle.isNotEmpty;
          return hasVariant ? '${e.name} (${e.variantTitle})' : e.name;
        })
        .where((e) => e.isNotEmpty)
        .join(', ');

    return Container(
      key: Key('order-card-${order.id}'),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceContainerDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : const Color(0xFFF0F2F5),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.03),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => context.push(AppRoutes.orderPath(order.id)),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order ${order.reference}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isDark ? Colors.white : const Color(0xFF1E2229),
                    ),
                  ),
                  OrderStatusBadge(status: order.orderStatus),
                ],
              ),
              const SizedBox(height: 10),
              Divider(
                height: 1,
                color: isDark ? AppTheme.borderDark : const Color(0xFFF3F4F6),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${order.itemCount} '
                          '${order.itemCount == 1 ? 'item' : 'items'}',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF4B5563),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatDate(order.createdAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                        if (preview.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? const Color(0xFFCBD5E1)
                                  : const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        formatCurrency(order.totalAmount),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E2229),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right,
                        color: Color(0xFF9CA3AF),
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
              if (!order.isOpen) ...[
                const SizedBox(height: 8),
                Text(
                  order.isCancelled
                      ? 'Cancelled ${_fmtDate(order.cancelledAt)}'
                      : 'Delivered ${_fmtDate(order.createdAt)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ] else
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.info_outline, size: 16),
                    label: const Text('Track order'),
                    onPressed: () =>
                        context.push(AppRoutes.orderPath(order.id)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmtDate(DateTime? date) =>
      date == null ? '' : DateFormat('dd MMM').format(date);
}

/// Status filter chips with live counts for the signed-in shopper.
class _StatusChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _StatusChips({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthCubit>().currentUser?.id ?? '';

    return StreamBuilder<List<Order>>(
      stream: userId.isEmpty
          ? Stream<List<Order>>.empty()
          : repo.orders(userId: userId),
      builder: (context, snap) {
        final orders = snap.data ?? const <Order>[];
        int countOf(String status) =>
            orders.where((o) => o.orderStatus == status).length;

        return SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: [
              _chip(context, 'All', orders.length, 'all'),
              for (final status in OrderStatusRules.openStatuses)
                _chip(
                  context,
                  orderStatusLabel(context, status),
                  countOf(status),
                  status,
                ),
              _chip(
                context,
                orderStatusLabel(context, OrderStatus.cancelled),
                countOf(OrderStatus.cancelled),
                OrderStatus.cancelled,
              ),
              _chip(
                context,
                orderStatusLabel(context, OrderStatus.completed),
                countOf(OrderStatus.completed),
                OrderStatus.completed,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(BuildContext context, String label, int count, String value) {
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
