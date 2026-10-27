import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:myshop/core/services/admin_company_name.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/order.dart';
import '../../../core/models/product.dart';
import '../../../core/models/review.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/services/qr_deep_link_service.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../admin_shell.dart';
import '../orders/widgets/order_items_dialog.dart';
import '../orders/widgets/payment_verification_dialog.dart';
import '../qr/widgets/entity_qr_dialog.dart';

/// Comprehensive Admin Dashboard matching the reference design:
///  * "Needs Attention Today" banner
///  * 2x2 Core Metric Grid (Today's Orders, Pending Action, Today's Revenue, Store Rating)
///  * Order Pipeline Preview (Pending & Confirmed columns with customer name primary)
///  * Payments Awaiting Confirmation list
///  * Operational Hub (12 modules with live count badges)
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String get _companyId => AuthSession.currentUser?.companyId ?? '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AdminShell(
      title: l10n.dashboard,
      actions: [
        IconButton(
          icon: const Icon(Icons.qr_code_2_rounded),
          tooltip: 'Shop QR & Share Link',
          onPressed: () {
            final user = AuthSession.currentUser;
            final shopId = user?.companyId.isNotEmpty == true
                ? user!.companyId
                : 'masala-mart';
            final shopName = AdminCompanyName.instance.displayName(user);
            showEntityQrDialog(
              context: context,
              type: QrEntityType.shop,
              title: shopName,
              shopId: shopId,
              shopName: shopName,
              subtitle: 'Shop ID: $shopId',
            );
          },
        ),
      ],
      child: StreamBuilder<List<Order>>(
        stream: repo.orders(companyId: _companyId),
        builder: (context, ordersSnap) {
          final orders = ordersSnap.data ?? const <Order>[];

          return StreamBuilder<List<Product>>(
            stream: repo.products(companyId: _companyId),
            builder: (context, productsSnap) {
              final products = productsSnap.data ?? const <Product>[];

              return StreamBuilder<List<Review>>(
                stream: repo.reviews(_companyId),
                builder: (context, reviewsSnap) {
                  final reviews = reviewsSnap.data ?? const <Review>[];

                  return _DashboardBody(
                    orders: orders,
                    products: products,
                    reviews: reviews,
                    isLoading:
                        ordersSnap.connectionState == ConnectionState.waiting &&
                        orders.isEmpty,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final List<Order> orders;
  final List<Product> products;
  final List<Review> reviews;
  final bool isLoading;

  const _DashboardBody({
    required this.orders,
    required this.products,
    required this.reviews,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    // Date metrics calculation for the current business day
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    final todayOrders = orders.where((o) {
      if (o.createdAt == null) return false;
      return o.createdAt!.isAfter(startOfToday) &&
          o.createdAt!.isBefore(endOfToday);
    }).toList();

    final pendingOrders = orders
        .where((o) => o.orderStatus == OrderStatus.pending)
        .toList();

    final confirmedOrders = orders
        .where((o) => o.orderStatus == OrderStatus.confirmed)
        .toList();

    final todayRevenue = todayOrders
        .where((o) => !o.isCancelled)
        .fold<double>(0, (sum, o) => sum + o.totalAmount);

    final pendingPayments = orders
        .where((o) => !o.isPaid && !o.isCancelled)
        .toList();

    final lowStockSkus = products
        .where((p) => !p.isUnlimitedStock && p.stockQty <= 5)
        .toList();

    final avgRating = reviews.isEmpty
        ? 5.0
        : (reviews.fold<double>(0, (sum, r) => sum + r.rating) /
              reviews.length);

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. "Needs Attention Today" Banner
              if (pendingOrders.isNotEmpty ||
                  pendingPayments.isNotEmpty ||
                  lowStockSkus.isNotEmpty) ...[
                _NeedsAttentionBanner(
                  pendingCount: pendingOrders.length,
                  unpaidCount: pendingPayments.length,
                  lowStockCount: lowStockSkus.length,
                ),
                const SizedBox(height: 18),
              ],

              // 2. 2x2 Metric Grid
              _MetricsGrid(
                todayOrdersCount: todayOrders.length,
                pendingCount: pendingOrders.length,
                todayRevenue: todayRevenue,
                storeRating: avgRating,
                reviewCount: reviews.length,
              ),
              const SizedBox(height: 24),

              // 3. Order Pipeline Preview (Pending & Confirmed)
              _OrderPipelinePreview(
                pendingOrders: pendingOrders,
                confirmedOrders: confirmedOrders,
              ),
              const SizedBox(height: 24),

              // 4. Payments Awaiting Confirmation Section
              if (pendingPayments.isNotEmpty) ...[
                _PaymentsAwaitingConfirmation(
                  orders: pendingPayments.take(4).toList(),
                ),
                const SizedBox(height: 24),
              ],

              // 5. Store Modules / Operational Hub (12 Modules)
              _OperationalHub(
                openOrdersCount: orders.where((o) => o.isOpen).length,
                productsCount: products.length,
                lowStockCount: lowStockSkus.length,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 1. "Needs Attention Today" Banner
// -----------------------------------------------------------------------------
class _NeedsAttentionBanner extends StatelessWidget {
  final int pendingCount;
  final int unpaidCount;
  final int lowStockCount;

  const _NeedsAttentionBanner({
    required this.pendingCount,
    required this.unpaidCount,
    required this.lowStockCount,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = context.isDesktop;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 18 : 16,
        vertical: isDesktop ? 16 : 14,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1), // Light amber
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD54F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: const Color(0xFFF57C00),
                size: isDesktop ? 24 : 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Needs Attention Today',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isDesktop ? 16.5 : 15,
                  color: const Color(0xFFE65100),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (pendingCount > 0)
                _ChipItem(
                  label: 'Awaiting Approval: $pendingCount',
                  icon: Icons.pending_actions,
                  color: const Color(0xFFD84315),
                  onTap: () => context.go(AppRoutes.adminOrders),
                ),
              if (unpaidCount > 0)
                _ChipItem(
                  label: 'Pending Payments: $unpaidCount',
                  icon: Icons.payment,
                  color: const Color(0xFFE65100),
                  onTap: () => context.go(AppRoutes.adminOrders),
                ),
              if (lowStockCount > 0)
                _ChipItem(
                  label: 'Low Stock SKUs: $lowStockCount',
                  icon: Icons.inventory_2_outlined,
                  color: const Color(0xFFBF360C),
                  onTap: () => context.go(AppRoutes.adminProducts),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChipItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ChipItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = context.isDesktop;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 12 : 10,
          vertical: isDesktop ? 6 : 5,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: isDesktop ? 15 : 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: isDesktop ? 13 : 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 2. 2x2 Core Metrics Grid
// -----------------------------------------------------------------------------
class _MetricsGrid extends StatelessWidget {
  final int todayOrdersCount;
  final int pendingCount;
  final double todayRevenue;
  final double storeRating;
  final int reviewCount;

  const _MetricsGrid({
    required this.todayOrdersCount,
    required this.pendingCount,
    required this.todayRevenue,
    required this.storeRating,
    required this.reviewCount,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        final double itemWidth = isNarrow
            ? (constraints.maxWidth - 12) / 2
            : (constraints.maxWidth - 36) / 4;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            // Card 1: Today's Orders
            SizedBox(
              width: itemWidth,
              child: _MetricCard(
                icon: Icons.receipt_long_outlined,
                iconColor: Colors.blue.shade700,
                iconBg: Colors.blue.shade50,
                title: 'Today\'s Orders',
                value: '$todayOrdersCount',
                subtitle: 'Placed since midnight',
                onTap: () => context.go(AppRoutes.adminOrders),
              ),
            ),

            // Card 2: Pending Action (Urgent)
            SizedBox(
              width: itemWidth,
              child: _MetricCard(
                icon: Icons.pending_actions_outlined,
                iconColor: Colors.orange.shade800,
                iconBg: Colors.orange.shade50,
                title: 'Pending Action',
                value: '$pendingCount',
                subtitle: 'Awaiting confirmation',
                badgeText: pendingCount > 0 ? 'URGENT' : null,
                badgeColor: Colors.red.shade700,
                onTap: () => context.go(AppRoutes.adminOrders),
              ),
            ),

            // Card 3: Today's Revenue
            SizedBox(
              width: itemWidth,
              child: _MetricCard(
                icon: Icons.currency_rupee,
                iconColor: Colors.green.shade700,
                iconBg: Colors.green.shade50,
                title: 'Today\'s Revenue',
                value: formatCurrency(todayRevenue),
                subtitle: 'Gross sales today',
                onTap: () => context.go(AppRoutes.adminReports),
              ),
            ),

            // Card 4: Store Rating
            SizedBox(
              width: itemWidth,
              child: _MetricCard(
                icon: Icons.star_rounded,
                iconColor: Colors.amber.shade800,
                iconBg: Colors.amber.shade50,
                title: 'Store Rating',
                value: '${storeRating.toStringAsFixed(1)} ★',
                subtitle: 'From $reviewCount reviews',
                onTap: () => context.go(AppRoutes.adminReviews),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String value;
  final String subtitle;
  final String? badgeText;
  final Color? badgeColor;
  final VoidCallback onTap;

  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.value,
    required this.subtitle,
    this.badgeText,
    this.badgeColor,
    required this.onTap,
  });

  @override
  State<_MetricCard> createState() => _MetricCardState();
}

class _MetricCardState extends State<_MetricCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaultBorder = AppTheme.adminCardBorder(context);
    final hoverBorder = widget.iconColor.withValues(alpha: 0.6);
    final isDesktop = context.isDesktop;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        transform: _isHovered
            ? Matrix4.translationValues(0.0, -2.0, 0.0)
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: _isHovered
              ? (isDark
                    ? AppTheme.adminCardHoverDark
                    : AppTheme.adminCardHoverLight)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovered ? hoverBorder : defaultBorder,
            width: _isHovered ? 1.5 : 1.0,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: widget.iconColor.withValues(
                      alpha: isDark ? 0.2 : 0.08,
                    ),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: EdgeInsets.all(isDesktop ? 16 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(isDesktop ? 8 : 7),
                        decoration: BoxDecoration(
                          color: widget.iconBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          widget.icon,
                          size: isDesktop ? 22 : 18,
                          color: widget.iconColor,
                        ),
                      ),
                      const Spacer(),
                      if (widget.badgeText != null)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 7 : 6,
                            vertical: isDesktop ? 3 : 2,
                          ),
                          decoration: BoxDecoration(
                            color: (widget.badgeColor ?? Colors.red).withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            widget.badgeText!,
                            style: AppTheme.adminBadgeText(
                              context,
                            ).copyWith(color: widget.badgeColor ?? Colors.red),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: isDesktop ? 14 : 12),
                  Text(
                    widget.value,
                    style: AppTheme.adminMetricValue(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(widget.title, style: AppTheme.adminMetricLabel(context)),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      fontSize: isDesktop ? 12.5 : 10.5,
                      color: Colors.grey.shade500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 3. Order Pipeline Preview (Pending & Confirmed)
// -----------------------------------------------------------------------------
class _OrderPipelinePreview extends StatelessWidget {
  final List<Order> pendingOrders;
  final List<Order> confirmedOrders;

  const _OrderPipelinePreview({
    required this.pendingOrders,
    required this.confirmedOrders,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text('Order Pipeline', style: AppTheme.adminSectionTitle(context)),
            TextButton.icon(
              icon: const Icon(Icons.view_kanban_outlined, size: 16),
              label: const Text('Pipeline Board'),
              onPressed: () => context.go(AppRoutes.adminOrders),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 650;
            return isMobile
                ? Column(
                    children: [
                      _PipelinePreviewColumn(
                        title: 'PENDING',
                        orders: pendingOrders.take(3).toList(),
                        color: Colors.orange.shade800,
                        isPendingColumn: true,
                      ),
                      const SizedBox(height: 12),
                      _PipelinePreviewColumn(
                        title: 'CONFIRMED',
                        orders: confirmedOrders.take(3).toList(),
                        color: Colors.blue.shade700,
                        isPendingColumn: false,
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _PipelinePreviewColumn(
                          title: 'PENDING',
                          orders: pendingOrders.take(3).toList(),
                          color: Colors.orange.shade800,
                          isPendingColumn: true,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _PipelinePreviewColumn(
                          title: 'CONFIRMED',
                          orders: confirmedOrders.take(3).toList(),
                          color: Colors.blue.shade700,
                          isPendingColumn: false,
                        ),
                      ),
                    ],
                  );
          },
        ),
      ],
    );
  }
}

class _PipelinePreviewColumn extends StatelessWidget {
  final String title;
  final List<Order> orders;
  final Color color;
  final bool isPendingColumn;

  const _PipelinePreviewColumn({
    required this.title,
    required this.orders,
    required this.color,
    required this.isPendingColumn,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = context.isDesktop;

    return Container(
      padding: EdgeInsets.all(isDesktop ? 16 : 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 4, height: isDesktop ? 18 : 16, color: color),
              const SizedBox(width: 8),
              Text(
                '$title (${orders.length})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isDesktop ? 14.5 : 13,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (orders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No orders in $title',
                  style: TextStyle(
                    fontSize: isDesktop ? 13 : 12,
                    color: Colors.grey,
                  ),
                ),
              ),
            )
          else
            for (final o in orders) ...[
              _CompactPreviewCard(order: o, isPending: isPendingColumn),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _CompactPreviewCard extends StatelessWidget {
  final Order order;
  final bool isPending;

  const _CompactPreviewCard({required this.order, required this.isPending});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = context.isDesktop;
    final dateStr = order.createdAt != null
        ? DateFormat('hh:mm a').format(order.createdAt!)
        : '';

    return Container(
      padding: EdgeInsets.all(isDesktop ? 12 : 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  order.customerName.isNotEmpty
                      ? order.customerName
                      : 'Guest Customer',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isDesktop ? 15 : 13.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                formatCurrency(order.totalAmount),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isDesktop ? 15.5 : 13.5,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                order.reference,
                style: TextStyle(
                  fontSize: isDesktop ? 12.5 : 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              if (dateStr.isNotEmpty)
                Text(
                  ' · $dateStr',
                  style: TextStyle(
                    fontSize: isDesktop ? 12 : 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 7 : 5,
                  vertical: isDesktop ? 2.5 : 1.5,
                ),
                decoration: BoxDecoration(
                  color: order.isSelfPickup
                      ? Colors.blue.withValues(alpha: 0.1)
                      : Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  order.isSelfPickup ? 'Pickup' : 'Delivery',
                  style: TextStyle(
                    fontSize: isDesktop ? 11 : 9.5,
                    fontWeight: FontWeight.bold,
                    color: order.isSelfPickup
                        ? Colors.blue.shade800
                        : Colors.teal.shade800,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 14),
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.shopping_bag_outlined,
                  size: isDesktop ? 18 : 16,
                ),
                tooltip: 'Preview Items',
                onPressed: () => OrderItemsPreviewDialog.show(context, order),
              ),
              const Spacer(),
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: () =>
                    context.push(AppRoutes.adminOrderDetailsPath(order.id)),
                child: Text(
                  'Details',
                  style: TextStyle(fontSize: isDesktop ? 13 : 12),
                ),
              ),
              if (isPending) ...[
                const SizedBox(width: 4),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: () => _quickConfirm(context, order),
                  child: Text(
                    'Confirm',
                    style: TextStyle(fontSize: isDesktop ? 13 : 12),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _quickConfirm(BuildContext context, Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Order'),
        content: Text('Mark order ${order.reference} as Confirmed?'),
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

    try {
      await repo.updateOrderStatus(
        order.id,
        OrderStatus.confirmed,
        companyId: order.companyId,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order ${order.reference} confirmed!'),
          backgroundColor: Colors.green.shade800,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

// -----------------------------------------------------------------------------
// 4. Payments Awaiting Confirmation Section
// -----------------------------------------------------------------------------
class _PaymentsAwaitingConfirmation extends StatelessWidget {
  final List<Order> orders;

  const _PaymentsAwaitingConfirmation({required this.orders});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = context.isDesktop;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.payments_outlined,
                  size: isDesktop ? 22 : 20,
                  color: Colors.orange.shade800,
                ),
                const SizedBox(width: 8),
                Text(
                  'Payments Awaiting Confirmation',
                  style: AppTheme.adminSectionTitle(context),
                ),
              ],
            ),
            TextButton(
              onPressed: () => context.go(AppRoutes.adminOrders),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: orders.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final o = orders[i];
              return ListTile(
                dense: !isDesktop,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 16 : 12,
                  vertical: isDesktop ? 4 : 0,
                ),
                title: Text(
                  o.customerName.isNotEmpty ? o.customerName : 'Guest Customer',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isDesktop ? 15 : 14,
                  ),
                ),
                subtitle: Row(
                  children: [
                    Text(
                      o.reference,
                      style: TextStyle(fontSize: isDesktop ? 12.5 : 11),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: o.hasPaymentMethod
                            ? (o.isUpi
                                  ? Colors.indigo.withValues(alpha: 0.1)
                                  : Colors.teal.withValues(alpha: 0.1))
                            : Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            o.isUpi
                                ? Icons.qr_code_2
                                : (o.isCash
                                      ? Icons.payments_outlined
                                      : Icons.schedule),
                            size: 11,
                            color: o.hasPaymentMethod
                                ? (o.isUpi
                                      ? Colors.indigo.shade700
                                      : Colors.teal.shade700)
                                : Colors.orange.shade800,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            o.paymentMethodDisplay,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: o.hasPaymentMethod
                                  ? (o.isUpi
                                        ? Colors.indigo.shade700
                                        : Colors.teal.shade700)
                                  : Colors.orange.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatCurrency(o.totalAmount),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isDesktop ? 15.5 : 14,
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 12 : 10,
                          vertical: isDesktop ? 8 : 4,
                        ),
                      ),
                      onPressed: () => _confirmPayment(context, o),
                      child: Text(
                        'Verify',
                        style: TextStyle(fontSize: isDesktop ? 13 : 12),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _confirmPayment(BuildContext context, Order order) async {
    await PaymentVerificationDialog.show(context, order);
  }
}

// -----------------------------------------------------------------------------
// 5. Store Modules / Operational Hub
// -----------------------------------------------------------------------------
class _OperationalHub extends StatelessWidget {
  final int openOrdersCount;
  final int productsCount;
  final int lowStockCount;

  const _OperationalHub({
    required this.openOrdersCount,
    required this.productsCount,
    required this.lowStockCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final modules = [
      _HubItem(
        icon: Icons.view_kanban,
        title: 'Orders Pipeline',
        subtitle: 'Manage & dispatch orders',
        route: AppRoutes.adminOrders,
        badge: openOrdersCount > 0 ? '$openOrdersCount' : null,
        badgeColor: Colors.orange.shade800,
        color: Colors.blue.shade700,
      ),
      _HubItem(
        icon: Icons.inventory_2,
        title: 'Products',
        subtitle: 'Catalog, pricing & stock',
        route: AppRoutes.adminProducts,
        badge: productsCount > 0 ? '$productsCount' : null,
        color: Colors.teal.shade700,
      ),
      _HubItem(
        icon: Icons.category,
        title: 'Categories',
        subtitle: 'Organize catalog taxonomy',
        route: AppRoutes.adminCategories,
        color: Colors.indigo.shade700,
      ),
      _HubItem(
        icon: Icons.local_offer,
        title: 'Vouchers',
        subtitle: 'Coupons & discounts',
        route: AppRoutes.adminVouchers,
        color: Colors.pink.shade700,
      ),
      _HubItem(
        icon: Icons.badge,
        title: 'Employees',
        subtitle: 'Staff roles & permissions',
        route: AppRoutes.adminEmployees,
        color: Colors.deepPurple.shade700,
      ),
      _HubItem(
        icon: Icons.admin_panel_settings,
        title: 'Admins',
        subtitle: 'Admin access controls',
        route: AppRoutes.adminAdmins,
        color: Colors.brown.shade700,
      ),
      _HubItem(
        icon: Icons.local_shipping,
        title: 'Delivery Charges',
        subtitle: 'Pincode delivery fees',
        route: AppRoutes.adminDelivery,
        color: Colors.blueGrey.shade700,
      ),
      _HubItem(
        icon: Icons.storefront,
        title: AppLocalizations.of(context).shopSettings,
        subtitle: AppLocalizations.of(context).shopSettingsSubtitle,
        route: AppRoutes.adminShopSettings,
        color: Colors.indigo.shade700,
      ),
      _HubItem(
        icon: Icons.image,
        title: 'Banners',
        subtitle: 'Promos & hero carousels',
        route: AppRoutes.adminBanners,
        color: Colors.amber.shade900,
      ),
      _HubItem(
        icon: Icons.star,
        title: 'Reviews',
        subtitle: 'Ratings & feedback',
        route: AppRoutes.adminReviews,
        color: Colors.orange.shade800,
      ),
      _HubItem(
        icon: Icons.recommend,
        title: 'Recommendations',
        subtitle: 'Cross-sells & suggested items',
        route: AppRoutes.adminRecommendations,
        color: Colors.cyan.shade800,
      ),
      _HubItem(
        icon: Icons.bar_chart,
        title: 'Reports',
        subtitle: 'Sales & revenue metrics',
        route: AppRoutes.adminReports,
        color: Colors.green.shade800,
      ),
      _HubItem(
        icon: Icons.qr_code_2,
        title: 'QR Codes',
        subtitle: 'Store & product deep links',
        route: AppRoutes.adminQr,
        color: Colors.purple.shade700,
      ),
      _HubItem(
        icon: Icons.grid_view_rounded,
        title: 'Home Explore Categories',
        subtitle: 'Curate home category pills',
        route: AppRoutes.adminExploreCategories,
        color: Colors.deepOrange.shade700,
      ),
      _HubItem(
        icon: Icons.local_fire_department,
        title: 'Home Trending Now',
        subtitle: 'Manage trending home shelf',
        route: AppRoutes.adminTrendingNow,
        color: Colors.amber.shade800,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              'Store Modules',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${modules.length} modules available',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.7,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final int crossAxisCount;
            final double childAspectRatio;

            if (constraints.maxWidth < 600) {
              // Mobile: compact 2-column layout
              crossAxisCount = 2;
              childAspectRatio = 1.15;
            } else if (constraints.maxWidth < 950) {
              // Tablet: 3 columns
              crossAxisCount = 3;
              childAspectRatio = 1.22;
            } else if (constraints.maxWidth < 1300) {
              // Desktop: 4 columns
              crossAxisCount = 4;
              childAspectRatio = 1.28;
            } else {
              // Wide desktop: 4 columns
              crossAxisCount = 4;
              childAspectRatio = 1.35;
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: childAspectRatio,
              ),
              itemCount: modules.length,
              itemBuilder: (context, i) => _StoreModuleCard(module: modules[i]),
            );
          },
        ),
      ],
    );
  }
}

class _StoreModuleCard extends StatefulWidget {
  final _HubItem module;

  const _StoreModuleCard({required this.module});

  @override
  State<_StoreModuleCard> createState() => _StoreModuleCardState();
}

class _StoreModuleCardState extends State<_StoreModuleCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final m = widget.module;

    final defaultBorderColor = AppTheme.adminCardBorder(context);
    final hoverBorderColor = m.color.withValues(alpha: 0.7);

    final cardBgColor = _isHovered
        ? (isDark ? AppTheme.adminCardHoverDark : AppTheme.adminCardHoverLight)
        : theme.colorScheme.surface;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        transform: _isHovered
            ? Matrix4.translationValues(0.0, -3.0, 0.0)
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isHovered ? hoverBorderColor : defaultBorderColor,
            width: _isHovered ? 1.5 : 1.0,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: m.color.withValues(alpha: isDark ? 0.25 : 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              try {
                context.go(m.route);
              } catch (_) {}
            },
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Themed icon container placed at top
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isHovered
                                ? m.color.withValues(alpha: 0.18)
                                : m.color.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(m.icon, color: m.color, size: 26),
                        ),
                        const SizedBox(height: 10),
                        // Centered title directly below icon
                        Text(
                          m.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            height: 1.2,
                            color: _isHovered
                                ? m.color
                                : theme.colorScheme.onSurface,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // Supporting text
                        Text(
                          m.subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.8),
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                if (m.badge != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: m.badgeColor ?? theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: (m.badgeColor ?? theme.colorScheme.primary)
                                .withValues(alpha: 0.35),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        m.badge!,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HubItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final String? badge;
  final Color? badgeColor;
  final Color color;

  const _HubItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    this.badge,
    this.badgeColor,
    required this.color,
  });
}
