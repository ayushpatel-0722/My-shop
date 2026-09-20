import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:myshop/app/theme/app_theme.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../../../core/models/cart_item.dart';
import '../../../core/models/company.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/formatters.dart';
import 'cart_cubit.dart';

/// Cart grouped by company (Section 3 / multi-company cart support).
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.cart),
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
      ),
      body: BlocBuilder<CartCubit, CartState>(
        builder: (context, state) {
          if (state.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shopping_cart_outlined, size: 64),
                  const SizedBox(height: 12),
                  const Text('Your cart is empty'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.go(AppRoutes.home),
                    child: Text(l10n.home),
                  ),
                ],
              ),
            );
          }
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final entry in state.byCompany.entries) ...[
                      _companyHeader(entry.key),
                      for (final item in entry.value)
                        _cartTile(context, item, entry.key),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
              _checkoutBar(context, state),
            ],
          );
        },
      ),
    );
  }

  Widget _companyHeader(String companyId) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: StreamBuilder<List<Company>>(
        stream: repo.companies(),
        builder: (context, snapshot) {
          final companies = snapshot.data ?? [];
          final comp = companies.where((c) => c.id == companyId).firstOrNull;
          final name = (comp != null && comp.name.isNotEmpty)
              ? comp.name
              : (companyId.isEmpty ? 'Store' : 'Store');
          return Row(
            children: [
              const Icon(Icons.storefront, size: 18),
              const SizedBox(width: 8),
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _cartTile(BuildContext context, CartItem item, String companyId) {
    final cubit = context.read<CartCubit>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final v = item.variant;
    final maxQty = v != null
        ? (v.isUnlimitedStock ? 99 : v.stockQty)
        : (item.product.isUnlimitedStock ? 99 : item.product.stockQty);
    final inStock = v != null
        ? (v.isUnlimitedStock || v.stockQty > 0)
        : item.product.isInStock;
    final canAdd = item.qty < (maxQty < 1 ? 1 : maxQty);
    final hasImage =
        item.product.images.isNotEmpty &&
        item.product.images.first.trim().isNotEmpty;
    final variantSku = v?.sku ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceContainerDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.03),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 72,
              height: 72,
              child: hasImage
                  ? Image.network(
                      item.product.images.first.trim(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: isDark
                            ? AppTheme.surfaceDark
                            : Colors.grey.shade100,
                        child: const Icon(
                          Icons.image_not_supported,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : Container(
                      color: isDark
                          ? AppTheme.surfaceDark
                          : Colors.grey.shade100,
                      child: const Icon(
                        Icons.shopping_bag_outlined,
                        color: Colors.grey,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // Product Details & Variant Tag
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF1E2229),
                  ),
                ),
                const SizedBox(height: 4),

                // Variant Label / Dimension Tag
                if (item.variantLabel.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
                            : const Color(0xFFBFDBFE),
                      ),
                    ),
                    child: Text(
                      item.variantLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFF60A5FA)
                            : const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ] else ...[
                  Text(
                    '${item.product.unit} ${item.product.unitType}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],

                // Unit Price & Line Total
                Row(
                  children: [
                    Text(
                      formatCurrency(item.effectivePrice, symbol: '₹'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    if (item.qty > 1) ...[
                      const SizedBox(width: 4),
                      Text(
                        '× ${item.qty} = ${formatCurrency(item.lineTotal, symbol: '₹')}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),

                if (!inStock)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      'Out of stock',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else if (item.product.isLowStock())
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Only $maxQty left',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Quantity Selector & Remove Button
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: 19,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF94A3B8),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => cubit.remove(
                  companyId,
                  item.product.id,
                  variantSku: variantSku,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.surfaceDark
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? AppTheme.borderDark
                        : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => cubit.decrement(
                        companyId,
                        item.product.id,
                        variantSku: variantSku,
                      ),
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Icon(
                          Icons.remove,
                          size: 16,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF475569),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '${item.qty}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: canAdd
                          ? () => cubit.increment(
                              companyId,
                              item.product.id,
                              variantSku: variantSku,
                            )
                          : null,
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Icon(
                          Icons.add,
                          size: 16,
                          color: canAdd
                              ? (isDark
                                    ? Colors.white70
                                    : const Color(0xFF475569))
                              : (isDark
                                    ? Colors.white24
                                    : const Color(0xFFCBD5E1)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _checkoutBar(BuildContext context, CartState state) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
        color: isDark ? AppTheme.surfaceContainerDark : Colors.white,
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.totalAmount,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  Text(
                    formatCurrency(state.totalAmount),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: () => context.push(AppRoutes.checkout),
              child: Text(l10n.checkout),
            ),
          ],
        ),
      ),
    );
  }
}
