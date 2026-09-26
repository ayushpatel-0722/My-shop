import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/domain/order_eta.dart';
import '../../../core/domain/order_status.dart';
import '../../../core/models/company.dart';
import '../../../core/models/order.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/modern_shimmer.dart';
import '../../../core/widgets/order_status_badge.dart';
import '../../auth/auth_cubit.dart';
import '../../auth/widgets/auth_bottom_sheet.dart';
import '../../checkout/cart/cart_cubit.dart';
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
                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: 4,
                          itemBuilder: (_, _) => const M3OrderCardSkeleton(),
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
        child: FutureBuilder<Company?>(
          future: repo.company(order.companyId),
          builder: (context, companySnap) {
            final company = companySnap.data;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: store identity + payment hint + status.
                  Row(
                    children: [
                      _StoreAvatar(
                        logoUrl: company?.logoUrl ?? '',
                        name: order.companyName,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          order.companyName.isEmpty
                              ? 'Store'
                              : order.companyName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1E2229),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _PaymentIcon(paid: order.isPaid),
                      const SizedBox(width: 8),
                      OrderStatusBadge(status: order.orderStatus),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Meta row: reference + date, progress bar along its edge.
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Order ${order.reference}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: isDark
                                  ? const Color(0xFFCBD5E1)
                                  : const Color(0xFF4B5563),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            formatDate(order.createdAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          key: Key('order-progress-${order.id}'),
                          value: OrderEta.progress(order.orderStatus),
                          minHeight: 4,
                          backgroundColor: isDark
                              ? AppTheme.borderDark
                              : const Color(0xFFF3F4F6),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            order.isCancelled
                                ? const Color(0xFFDC2626)
                                : order.isCompleted
                                ? const Color(0xFF1E8F66)
                                : const Color(0xFFFF5247),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Item preview: thumbnails + "+N more".
                  _ItemPreview(order: order, isDark: isDark),
                  const SizedBox(height: 12),

                  // Delivery ETA while the parcel is actually moving.
                  _etaLine(order, company),

                  // Bottom row: total + payment status.
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
                      const Spacer(),
                      _PaymentChip(paid: order.isPaid),
                    ],
                  ),

                  // Action row.
                  _actionRow(context, order),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// The one-line ETA shown under the item preview for moving orders.
  Widget _etaLine(Order order, Company? company) {
    final text = OrderEta.label(order, company, DateTime.now());
    if (text == null) return const SizedBox.shrink();
    final pickup = order.isSelfPickup;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            pickup ? Icons.store_outlined : Icons.local_shipping_outlined,
            size: 14,
            color: pickup ? const Color(0xFF7C3AED) : const Color(0xFF2563EB),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            key: Key('order-eta-${order.id}'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: pickup ? const Color(0xFF7C3AED) : const Color(0xFF2563EB),
            ),
          ),
        ],
      ),
    );
  }

  /// Status-dependent actions: track, one-tap reorder, and the tappable
  /// star-rating shortcut on completed-but-unreviewed orders.
  Widget _actionRow(BuildContext context, Order order) {
    final canReview = order.isCompleted && (order.reviewId ?? '').isEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          if (order.isOpen)
            TextButton.icon(
              icon: const Icon(Icons.info_outline, size: 16),
              label: const Text('Track order'),
              onPressed: () => context.push(AppRoutes.orderPath(order.id)),
            ),
          const Spacer(),

          // Rate directly from the card: tapping a star opens the review
          // sheet pre-filled with that rating.
          if (canReview) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) {
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => context.push(
                    '${AppRoutes.leaveReview.replaceFirst(':orderId', order.id)}'
                    '?companyId=${order.companyId}&rating=${i + 1}',
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Icon(
                      Icons.star_outline,
                      size: 22,
                      color: Colors.amber.shade700,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(width: 8),
          ],

          // One-tap reorder, available whatever the status.
          _ReorderButton(order: order),
        ],
      ),
    );
  }
}

/// Circular store logo with a letter fallback.
class _StoreAvatar extends StatelessWidget {
  final String logoUrl;
  final String name;

  const _StoreAvatar({required this.logoUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl.trim().isNotEmpty;
    final initial = name.trim().isNotEmpty
        ? name.trim().substring(0, 1).toUpperCase()
        : 'S';
    return CircleAvatar(
      radius: 14,
      backgroundColor: const Color(0xFFFFEBEA),
      foregroundColor: const Color(0xFFB3261E),
      child: ClipOval(
        child: hasLogo
            ? Image.network(
                logoUrl.trim(),
                width: 28,
                height: 28,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : Text(
                initial,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}

/// Wallet icon hinting the payment state, next to the status badge.
class _PaymentIcon extends StatelessWidget {
  final bool paid;

  const _PaymentIcon({required this.paid});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: paid ? 'Paid' : 'Payment on delivery',
      child: Icon(
        paid ? Icons.check_circle : Icons.account_balance_wallet_outlined,
        size: 16,
        color: paid ? const Color(0xFF1E8F66) : const Color(0xFF9CA3AF),
      ),
    );
  }
}

/// Small "Paid" / "Pay on delivery" chip in the bottom row.
class _PaymentChip extends StatelessWidget {
  final bool paid;

  const _PaymentChip({required this.paid});

  @override
  Widget build(BuildContext context) {
    final color = paid ? const Color(0xFF1E8F66) : const Color(0xFFD46B08);
    final bg = paid ? const Color(0xFFE6F7F2) : const Color(0xFFFFF7E6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        paid ? 'Paid' : 'Pay on delivery',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

/// Thumbnails of the first lines plus a "+N more" chip.
class _ItemPreview extends StatelessWidget {
  final Order order;
  final bool isDark;

  const _ItemPreview({required this.order, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final shown = order.items.take(3).toList();
    final remaining = order.items.length - shown.length;

    return Row(
      children: [
        for (final line in shown)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _previewThumb(line.image, line.name, isDark),
          ),
        if (remaining > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDark : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
              ),
            ),
            child: Text(
              '+$remaining more',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ),
      ],
    );
  }

  Widget _previewThumb(String image, String name, bool isDark) {
    final hasImage = image.trim().isNotEmpty;
    return CircleAvatar(
      radius: 15,
      backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFF1F5F9),
      child: ClipOval(
        child: hasImage
            ? Image.network(
                image.trim(),
                width: 30,
                height: 30,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.shopping_bag_outlined,
                  size: 14,
                  color: Color(0xFF94A3B8),
                ),
              )
            : const Icon(
                Icons.shopping_bag_outlined,
                size: 14,
                color: Color(0xFF94A3B8),
              ),
      ),
    );
  }
}

/// Circular one-tap "add these same items to cart" button.
class _ReorderButton extends StatelessWidget {
  final Order order;

  const _ReorderButton({required this.order});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Reorder',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _reorder(context),
        child: Container(
          key: Key('reorder-${order.id}'),
          padding: const EdgeInsets.all(6),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFFFEBEA),
          ),
          child: const Icon(Icons.refresh, size: 16, color: Color(0xFFB3261E)),
        ),
      ),
    );
  }

  Future<void> _reorder(BuildContext context) async {
    final cart = context.read<CartCubit>();
    var added = 0;
    var missing = 0;

    for (final line in order.items) {
      final product = await repo.product(line.productId);
      if (product == null) {
        missing++;
        continue;
      }
      final variant = line.variantSku.isEmpty
          ? null
          : product.variants.firstWhereOrNull((v) => v.sku == line.variantSku);
      cart.add(
        product,
        variant: variant,
        companyId: order.companyId,
        companyName: order.companyName,
        qty: line.qty,
      );
      added++;
    }

    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    if (added > 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            missing > 0
                ? '$added item${added == 1 ? '' : 's'} added to cart · $missing no longer available'
                : '$added item${added == 1 ? '' : 's'} added to cart',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'VIEW CART',
            onPressed: () => context.push(AppRoutes.cart),
          ),
        ),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('These products are no longer available'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
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
