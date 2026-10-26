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
import '../../../core/utils/responsive_extensions.dart';
import '../../../core/widgets/modern_shimmer.dart';
import '../../../core/widgets/order_status_badge.dart';
import '../../../core/widgets/app_product_image.dart';
import '../../auth/auth_cubit.dart';
import '../../auth/widgets/auth_bottom_sheet.dart';
import '../../checkout/cart/cart_cubit.dart';
import '../../marketplace/widgets/marketplace_bottom_nav.dart';
import '../../marketplace/widgets/web_header.dart';

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
  final Set<String> _cancellingOrderIds = <String>{};

  Future<void> _confirmCancelOrder(
    BuildContext context,
    Order order,
    String userId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Order?'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Order'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel Order'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    setState(() => _cancellingOrderIds.add(order.id));

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
      if (mounted) {
        setState(() => _cancellingOrderIds.remove(order.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authCubit = context.watch<AuthCubit>();
    final user = authCubit.currentUser;
    final isLoggedIn = authCubit.isLoggedIn && user != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go(AppRoutes.home);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        appBar: context.isDesktop
            ? PreferredSize(
                preferredSize: const Size.fromHeight(64),
                child: WebHeader(currentIndex: 2),
              )
            : AppBar(
                title: Text(
                  l10n.orders,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 19,
                  ),
                ),
                automaticallyImplyLeading: false,
                backgroundColor: Colors.white,
                elevation: 0,
                scrolledUnderElevation: 1,
              ),
        body: !isLoggedIn
            ? _buildGuestView(context)
            : StreamBuilder<List<Order>>(
                stream: repo.orders(userId: user.id),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting &&
                      (snap.data?.isEmpty ?? true)) {
                    if (context.isDesktop) {
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1140),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 20,
                                    bottom: 12,
                                  ),
                                  child: Text(
                                    l10n.orders,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                _StatusChips(
                                  selected: _statusFilter,
                                  onChanged: (value) =>
                                      setState(() => _statusFilter = value),
                                  orders: const [],
                                ),
                                Expanded(
                                  child: ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    itemCount: 4,
                                    itemBuilder: (_, _) =>
                                        const M3OrderCardSkeleton(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        _StatusChips(
                          selected: _statusFilter,
                          onChanged: (value) =>
                              setState(() => _statusFilter = value),
                          orders: const [],
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            itemCount: 4,
                            itemBuilder: (_, _) => const M3OrderCardSkeleton(),
                          ),
                        ),
                      ],
                    );
                  }

                  if (snap.hasError && (snap.data?.isEmpty ?? true)) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Color(0xFFDC2626),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Unable to load orders',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${snap.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF5247),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => setState(() {}),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Try Again'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final all = snap.data ?? const <Order>[];
                  final list = _statusFilter == 'all'
                      ? all
                      : all
                            .where((o) => o.orderStatus == _statusFilter)
                            .toList();

                  if (context.isDesktop) {
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1140),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Breadcrumbs
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 20,
                                  bottom: 8,
                                ),
                                child: Row(
                                  children: [
                                    InkWell(
                                      onTap: () => context.go(AppRoutes.home),
                                      child: Text(
                                        l10n.home,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.chevron_right,
                                      size: 14,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      l10n.orders,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Title & Count
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    Text(
                                      l10n.orders,
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Text(
                                        '${all.length} ${all.length == 1 ? 'order' : 'orders'}',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              _StatusChips(
                                selected: _statusFilter,
                                onChanged: (value) =>
                                    setState(() => _statusFilter = value),
                                orders: all,
                              ),
                              const SizedBox(height: 8),

                              Expanded(
                                child: RefreshIndicator(
                                  onRefresh: () async {
                                    setState(() {});
                                  },
                                  child: all.isEmpty
                                      ? _buildEmptyOrdersView(context, l10n)
                                      : list.isEmpty
                                      ? Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(32),
                                            child: Text(
                                              AppLocalizations.of(
                                                context,
                                              ).noOrdersWithThisStatus,
                                            ),
                                          ),
                                        )
                                      : ListView.separated(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          itemCount: list.length,
                                          separatorBuilder: (_, _) =>
                                              const SizedBox(height: 16),
                                          itemBuilder: (context, i) =>
                                              _orderCard(
                                                context,
                                                list[i],
                                                l10n,
                                              ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    child: Column(
                      children: [
                        _StatusChips(
                          selected: _statusFilter,
                          onChanged: (value) =>
                              setState(() => _statusFilter = value),
                          orders: all,
                        ),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: () async {
                              setState(() {});
                            },
                            child: all.isEmpty
                                ? _buildEmptyOrdersView(context, l10n)
                                : list.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(32),
                                      child: Text(
                                        AppLocalizations.of(
                                          context,
                                        ).noOrdersWithThisStatus,
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      8,
                                      16,
                                      16,
                                    ),
                                    itemCount: list.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, i) =>
                                        _orderCard(context, list[i], l10n),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

        bottomNavigationBar: context.isDesktop
            ? null
            : const MarketplaceBottomNav(currentIndex: 2),
      ),
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
            Text(
              AppLocalizations.of(context).signInToViewOrders,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E2229),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(
                context,
              ).keepTrackOfYourActiveDeliveriesAndPastPurchases,
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
              onPressed: () => AuthBottomSheet.show(
                context,
                message: 'Please log in to view your orders.',
              ),
              icon: const Icon(Icons.login),
              label: Text(
                AppLocalizations.of(context).continueWithGoogle,
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
            Text(
              AppLocalizations.of(context).noOrdersYet,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E2229),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(
                context,
              ).exploreProductsAndPlaceYourFirstOrderToday,
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
              child: Text(
                AppLocalizations.of(context).startShopping,
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
    final canReview = order.isCompleted && (order.reviewId ?? '').isEmpty;
    final userId = context.read<AuthCubit>().currentUser?.id ?? '';

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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push(
            AppRoutes.orderPath(order.id, companyId: order.companyId),
          ),
          borderRadius: BorderRadius.circular(16),
          child: FutureBuilder<Company?>(
            future: repo.company(order.companyId),
            builder: (context, companySnap) {
              final company = companySnap.data;
              if (context.isDesktop) {
                return _buildDesktopOrderCard(
                  context,
                  order: order,
                  company: company,
                  isDark: isDark,
                  l10n: l10n,
                  userId: userId,
                  canReview: canReview,
                );
              }
              return _buildMobileOrderCard(
                context,
                order: order,
                company: company,
                isDark: isDark,
                l10n: l10n,
                userId: userId,
                canReview: canReview,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopOrderCard(
    BuildContext context, {
    required Order order,
    required Company? company,
    required bool isDark,
    required AppLocalizations l10n,
    required String userId,
    required bool canReview,
  }) {
    final etaText = OrderEta.label(order, company, DateTime.now());
    final isHome = !order.isSelfPickup;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Header Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
              ),
            ),
          ),
          child: Row(
            children: [
              // 1. Order Date
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ORDER PLACED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    formatDate(order.createdAt),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1E2229),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 32),

              // 2. Order Total
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TOTAL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        formatCurrency(order.totalAmount),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E2229),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _PaymentChip(paid: order.isPaid),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 32),

              // 3. Store Identity
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'STORE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _StoreAvatar(
                          logoUrl: company?.logoUrl ?? '',
                          name: order.companyName,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            order.companyName.isEmpty
                                ? l10n.store2
                                : order.companyName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E2229),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 4. Order Reference + Status Badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.order3(order.reference),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFCBD5E1)
                              : const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _PaymentIcon(paid: order.isPaid),
                    ],
                  ),
                  const SizedBox(height: 4),
                  OrderStatusBadge(status: order.orderStatus),
                ],
              ),
            ],
          ),
        ),

        // Main Card Body
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status / ETA banner
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (order.isCancelled) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.cancel_outlined,
                            size: 15,
                            color: Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Cancelled${order.cancellationReason != null ? ": ${order.cancellationReason}" : ""}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (etaText != null) ...[
                    _etaLine(order, company),
                  ] else if (order.isCompleted) ...[
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: Color(0xFF1E8F66),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Delivered',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E8F66),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isHome
                              ? Icons.local_shipping_outlined
                              : Icons.store_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          orderStatusLabel(context, order.orderStatus),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),

              // Status Progress Indicator
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  key: Key('order-progress-${order.id}'),
                  value: OrderEta.progress(order.orderStatus),
                  minHeight: 5,
                  backgroundColor: isDark
                      ? AppTheme.borderDark
                      : const Color(0xFFF1F5F9),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    order.isCancelled
                        ? const Color(0xFFDC2626)
                        : order.isCompleted
                        ? const Color(0xFF1E8F66)
                        : const Color(0xFFFF5247),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Items and Actions 2-Column Split
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Items List
                  Expanded(child: _buildDesktopItemsList(order, isDark, l10n)),
                  const SizedBox(width: 24),

                  // Right: Action Column
                  SizedBox(
                    width: 220,
                    child: _buildDesktopActionColumn(
                      context,
                      order: order,
                      userId: userId,
                      canReview: canReview,
                      l10n: l10n,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopItemsList(
    Order order,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final shown = order.items.take(3).toList();
    final remaining = order.items.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: AppProductImage(
                      url: line.image,
                      fit: BoxFit.cover,
                      fallback: Container(
                        color: isDark
                            ? AppTheme.surfaceDark
                            : const Color(0xFFF1F5F9),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.shopping_bag_outlined,
                          size: 22,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (line.variantLabel.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppTheme.surfaceDark
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isDark
                                      ? AppTheme.borderDark
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Text(
                                line.variantLabel,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(0xFF475569),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            'Qty: ${line.qty}',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            formatCurrency(line.unitPrice * line.qty),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E2229),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (remaining > 0)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.surfaceDark : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
                ),
              ),
              child: Text(
                l10n.more('$remaining'),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDesktopActionColumn(
    BuildContext context, {
    required Order order,
    required String userId,
    required bool canReview,
    required AppLocalizations l10n,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Track Order Button
        FilledButton.tonalIcon(
          onPressed: () => context.push(
            AppRoutes.orderPath(order.id, companyId: order.companyId),
          ),
          icon: const Icon(Icons.location_on_outlined, size: 16),
          label: Text(
            l10n.trackOrder,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Buy It Again Button
        OutlinedButton.icon(
          key: Key('reorder-${order.id}'),
          onPressed: () => _reorder(context, order),
          icon: const Icon(Icons.refresh, size: 16),
          label: Text(
            l10n.reorder,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),

        // Cancel Order Button
        if (order.isOpen) ...[
          const SizedBox(height: 8),
          if (OrderStatusRules.isCustomerCancellable(order.orderStatus)) ...[
            OutlinedButton.icon(
              key: Key('cancel-order-${order.id}'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                side: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.4),
                ),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: _cancellingOrderIds.contains(order.id)
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cancel_outlined, size: 14),
              label: const Text(
                'Cancel Order',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              onPressed: _cancellingOrderIds.contains(order.id)
                  ? null
                  : () => _confirmCancelOrder(context, order, userId),
            ),
          ] else ...[
            Tooltip(
              message:
                  OrderStatusRules.customerCancellationIneligibleReason(
                    order.orderStatus,
                  ) ??
                  'Orders can only be cancelled while pending.',
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'In Progress',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ],

        // Review Stars on Completed Orders
        if (canReview) ...[
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Rate your order:',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(5, (i) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => context.push(
                      '${AppRoutes.leaveReview.replaceFirst(':orderId', order.id)}'
                      '?companyId=${order.companyId}&rating=${i + 1}',
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.star_outline,
                        size: 22,
                        color: Colors.amber.shade700,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildMobileOrderCard(
    BuildContext context, {
    required Order order,
    required Company? company,
    required bool isDark,
    required AppLocalizations l10n,
    required String userId,
    required bool canReview,
  }) {
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
                      ? AppLocalizations.of(context).store2
                      : order.companyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : const Color(0xFF1E2229),
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
                    AppLocalizations.of(context).order3(order.reference),
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

          if (order.isCancelled) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.cancel_outlined,
                    size: 14,
                    color: Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Cancelled${order.cancellationReason != null ? ": ${order.cancellationReason}" : ""}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Bottom row: total + payment status.
          Row(
            children: [
              Text(
                formatCurrency(order.totalAmount),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? Colors.white : const Color(0xFF1E2229),
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
  }

  Future<void> _reorder(BuildContext context, Order order) async {
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
                ? AppLocalizations.of(
                    context,
                  ).addedToCartNoLongerAvailable(added, '$missing')
                : AppLocalizations.of(context).itemsAddedToCart(added),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: AppLocalizations.of(context).viewCart,
            onPressed: () => context.push(AppRoutes.cart),
          ),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).theseProductsAreNoLongerAvailable,
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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

  /// Status-dependent actions: track, cancel, one-tap reorder, and the tappable
  /// star-rating shortcut on completed-but-unreviewed orders.
  Widget _actionRow(BuildContext context, Order order) {
    final canReview = order.isCompleted && (order.reviewId ?? '').isEmpty;
    final userId = context.read<AuthCubit>().currentUser?.id ?? '';

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          if (order.isOpen) ...[
            TextButton.icon(
              icon: const Icon(Icons.info_outline, size: 16),
              label: Text(AppLocalizations.of(context).trackOrder),
              onPressed: () => context.push(
                AppRoutes.orderPath(order.id, companyId: order.companyId),
              ),
            ),
            if (OrderStatusRules.isCustomerCancellable(order.orderStatus)) ...[
              const SizedBox(width: 4),
              OutlinedButton.icon(
                key: Key('cancel-order-${order.id}'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.error.withValues(alpha: 0.4),
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                icon: _cancellingOrderIds.contains(order.id)
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cancel_outlined, size: 14),
                label: const Text(
                  'Cancel Order',
                  style: TextStyle(fontSize: 12),
                ),
                onPressed: _cancellingOrderIds.contains(order.id)
                    ? null
                    : () => _confirmCancelOrder(context, order, userId),
              ),
            ] else ...[
              const SizedBox(width: 4),
              Tooltip(
                message:
                    OrderStatusRules.customerCancellationIneligibleReason(
                      order.orderStatus,
                    ) ??
                    'Orders can only be cancelled while pending.',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'In Progress',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.outline,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ],
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
      message: paid
          ? AppLocalizations.of(context).paid
          : AppLocalizations.of(context).paymentOnDelivery,
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
        paid
            ? AppLocalizations.of(context).paid
            : AppLocalizations.of(context).payOnDelivery,
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
              AppLocalizations.of(context).more('$remaining'),
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
    return CircleAvatar(
      radius: 15,
      backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFF1F5F9),
      child: ClipOval(
        child: AppProductImage(
          url: image,
          width: 30,
          height: 30,
          fit: BoxFit.cover,
          fallback: const Icon(
            Icons.shopping_bag_outlined,
            size: 14,
            color: Color(0xFF94A3B8),
          ),
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
      message: AppLocalizations.of(context).reorder,
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
                ? AppLocalizations.of(
                    context,
                  ).addedToCartNoLongerAvailable(added, '$missing')
                : AppLocalizations.of(context).itemsAddedToCart(added),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: AppLocalizations.of(context).viewCart,
            onPressed: () => context.push(AppRoutes.cart),
          ),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).theseProductsAreNoLongerAvailable,
          ),
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
  final List<Order> orders;

  const _StatusChips({
    required this.selected,
    required this.onChanged,
    required this.orders,
  });

  @override
  Widget build(BuildContext context) {
    int countOf(String status) =>
        orders.where((o) => o.orderStatus == status).length;

    final chips = [
      _chip(context, AppLocalizations.of(context).all3, orders.length, 'all'),
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
    ];

    if (context.isDesktop) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Wrap(spacing: 8, runSpacing: 8, children: chips),
      );
    }

    return SizedBox(
      height: 46,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(children: chips),
      ),
    );
  }

  Widget _chip(BuildContext context, String label, int count, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        label: Text('$label ($count)'),
        selected: selected == value,
        onSelected: (_) => onChanged(value),
      ),
    );
  }
}
