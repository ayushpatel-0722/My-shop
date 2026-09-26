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
import '../../auth/auth_cubit.dart';
import '../../auth/widgets/auth_bottom_sheet.dart';
import 'cart_cubit.dart';
import 'wishlist_cubit.dart';

/// Cart grouped by company (Section 3 / multi-company cart support).
///
/// The line-item card shows everything a shopper needs to decide without
/// opening the product page: thumbnail, variant subtext, the real purchasing
/// unit on the stepper ("– 500 g +"), a stock warning when the shelf is
/// almost bare, and a live subtotal. Swiping a card left removes it — with
/// "Move to Wishlist" and "Undo" offered in the snackbar so a mis-swipe
/// never loses the item for good.
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authCubit = context.watch<AuthCubit>();
    if (!authCubit.isLoggedIn) {
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
        body: _buildGuestView(context),
      );
    }

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
                        _CartLineCard(item: item, companyId: entry.key),
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
                Icons.shopping_cart_outlined,
                size: 56,
                color: Color(0xFFFF5247),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Sign In to View Cart',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E2229),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add products to your cart after signing in to continue checkout.',
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
              onPressed: () async {
                final ok = await AuthBottomSheet.show(context);
                if (ok && context.mounted) {
                  context.go(AppRoutes.cart);
                }
              },
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
              : 'Store';
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

/// One product line inside its company block.
class _CartLineCard extends StatelessWidget {
  final CartItem item;
  final String companyId;

  const _CartLineCard({required this.item, required this.companyId});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CartCubit>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final variantSku = item.variant?.sku ?? '';
    final variantTitle = item.variant?.title ?? '';
    final canAdd = item.qty < item.maxQty;
    final stockWarning = item.stockWarningLabel();
    final hasImage =
        item.product.images.isNotEmpty &&
        item.product.images.first.trim().isNotEmpty;

    void removeLine() => cubit.remove(
      companyId,
      item.product.id,
      variantSku: variantSku,
      variantTitle: variantTitle,
    );

    return Dismissible(
      key: Key('cart-line-${item.cartKey}'),
      direction: DismissDirection.endToStart,
      // Red "Remove" action revealed by the left swipe; the wishlist hint sits
      // above it because a swipe is fast and the alternative must be visible
      // before the finger lifts.
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Icon(Icons.bookmark_add_outlined, color: Colors.white70, size: 16),
            SizedBox(height: 2),
            Text(
              'Move to Wishlist?',
              style: TextStyle(color: Colors.white70, fontSize: 10),
            ),
            SizedBox(height: 6),
            Icon(Icons.delete_outline, color: Colors.white, size: 26),
            SizedBox(height: 2),
            Text(
              'Remove',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (_) => _removeWithOffers(context, removeLine),
      child: Container(
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
            // Product thumbnail — opens the product detail page.
            GestureDetector(
              onTap: () => context.push(AppRoutes.productPath(item.product.id)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: hasImage
                      ? Image.network(
                          item.product.images.first.trim(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _thumbFallback(isDark),
                        )
                      : _thumbFallback(isDark),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Details, stepper and live subtotal.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + small remove icon (kept for precise one-tap use).
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1E2229),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: removeLine,
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),

                  // Variant subtext (e.g. "Size M, Red") / pack size.
                  Text(
                    item.subLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Unit price, small and muted, above the stepper row.
                  Text(
                    _unitPriceLabel,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Stepper (unit-aware) + stock chip + live line subtotal.
                  Row(
                    children: [
                      _Stepper(
                        label: item.stepperLabel,
                        canAdd: canAdd && item.isInStock,
                        isDark: isDark,
                        onRemove: () => cubit.decrement(
                          companyId,
                          item.product.id,
                          variantSku: variantSku,
                          variantTitle: variantTitle,
                        ),
                        onAdd: () => cubit.increment(
                          companyId,
                          item.product.id,
                          variantSku: variantSku,
                          variantTitle: variantTitle,
                        ),
                      ),
                      if (stockWarning != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          key: Key('stock-warning-${item.cartKey}'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7E6),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFFD591)),
                          ),
                          child: Text(
                            stockWarning,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFD46B08),
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        formatCurrency(item.lineTotal),
                        key: Key('line-total-${item.cartKey}'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),

                  if (!item.isInStock)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Out of stock',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
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

  Widget _thumbFallback(bool isDark) => Container(
    color: isDark ? AppTheme.surfaceDark : Colors.grey.shade100,
    child: const Icon(Icons.shopping_bag_outlined, color: Colors.grey),
  );

  /// "₹48 per 500 g" / "₹68 each" — the price of ONE stepper step.
  String get _unitPriceLabel {
    final price = formatCurrency(item.effectivePrice, symbol: '₹');
    if (item.product.type == 'weight_based' && item.product.unit > 0) {
      return '$price per ${CartItem.formatAmount(item.product.unit, item.product.unitType)}';
    }
    return '$price each';
  }

  /// Removes the line and immediately offers the way to keep the product.
  void _removeWithOffers(BuildContext context, VoidCallback removeLine) {
    final wishlist = context.read<WishlistCubit>();
    final removed = item;
    removeLine();

    // "Move to Wishlist" is the alternative to deleting the item outright.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${removed.product.name} removed from cart'),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'MOVE TO WISHLIST',
            onPressed: () {
              wishlist.addFromCart(removed);
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      '${removed.product.name} saved to your wishlist',
                    ),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
            },
          ),
        ),
      );
  }
}

/// "– 500 g +" stepper whose middle label is the product's real unit.
class _Stepper extends StatelessWidget {
  final String label;
  final bool canAdd;
  final bool isDark;
  final VoidCallback onRemove;
  final VoidCallback onAdd;

  const _Stepper({
    required this.label,
    required this.canAdd,
    required this.isDark,
    required this.onRemove,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white70 : const Color(0xFF475569);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : const Color(0xFFCBD5E1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onRemove,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              child: Icon(Icons.remove, size: 16, color: fg),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 46),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                textAlign: TextAlign.center,
                key: Key('stepper-label-$label'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ),
          ),
          InkWell(
            onTap: canAdd ? onAdd : null,
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              child: Icon(
                Icons.add,
                size: 16,
                color: canAdd
                    ? fg
                    : (isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
