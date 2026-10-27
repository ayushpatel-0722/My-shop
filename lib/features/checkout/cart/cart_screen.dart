import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:myshop/app/theme/app_theme.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../../../core/domain/cart_calculator.dart';
import '../../../core/models/cart_item.dart';
import '../../../core/models/company.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../core/widgets/app_product_image.dart';
import '../../../core/widgets/back_to_admin_button.dart';
import '../../auth/auth_cubit.dart';
import '../../auth/widgets/auth_bottom_sheet.dart';
import '../../marketplace/widgets/web_header.dart';
import 'cart_cubit.dart';
import 'wishlist_cubit.dart';

/// Cart grouped by company (Section 3 / multi-company cart support).
///
/// The line-item card shows everything a shopper needs to decide without
/// opening the product page: thumbnail, variant label, the price of ONE pack
/// ("₹300 / 500g" — always from the cart item's variant snapshot, never the
/// product default), the MRP with strikethrough, a quantity stepper with the
/// pack unit ("× 500g") and the converted total ("Total: 1 kg"). Swiping a
/// card left removes it — with "Move to Wishlist" and "Undo" offered in the
/// snackbar so a mis-swipe never loses the item for good.
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

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go(AppRoutes.home);
        }
      },
      child: Scaffold(
        appBar: context.isDesktop
            ? const PreferredSize(
                preferredSize: Size.fromHeight(64),
                child: WebHeader(),
              )
            : AppBar(
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
                actions: const [BackToAdminButton()],
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
                    Text(AppLocalizations.of(context).yourCartIsEmpty),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => context.go(AppRoutes.home),
                      child: Text(l10n.home),
                    ),
                  ],
                ),
              );
            }
            if (context.isDesktop) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: ListView(
                        padding: EdgeInsets.zero,
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
                    const SizedBox(width: 24),
                    SizedBox(
                      width: 360,
                      child: _desktopCartSummary(context, state),
                    ),
                  ],
                ),
              );
            }
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
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
      ),
    );
  }

  Widget _desktopCartSummary(BuildContext context, CartState state) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const calc = CartCalculator();
    final summary = calc.summary(state.items);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.04),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.summary,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Items (${state.totalItems}):',
                style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              Text(
                formatCurrency(summary.totalMrp),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (summary.totalDiscount > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Discount:',
                  style: TextStyle(fontSize: 14, color: Color(0xFF16A34A)),
                ),
                Text(
                  '-${formatCurrency(summary.totalDiscount)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.totalAmount,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                formatCurrency(summary.grandTotal),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF5247),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF5247),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => context.push(AppRoutes.checkout),
              child: Text(
                l10n.checkout,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
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
            Text(
              AppLocalizations.of(context).signInToViewCart,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E2229),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(
                context,
              ).addProductsToYourCartAfterSigningInToContinueCheckout,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
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
              label: Text(
                AppLocalizations.of(context).continueWithGoogle,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
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
              : AppLocalizations.of(context).store2;
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
    const calc = CartCalculator();
    final summary = calc.summary(state.items);
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
                  Row(
                    children: [
                      Text(
                        l10n.totalAmount,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      if (summary.totalDiscount > 0) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            AppLocalizations.of(
                              context,
                            ).youSave(formatCurrency(summary.totalDiscount)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        formatCurrency(summary.grandTotal),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      if (summary.totalDiscount > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          formatCurrency(summary.totalMrp),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
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
    final canAdd = item.qty < item.maxQty;
    final stockWarning = item.stockWarningLabel();

    void removeLine() => cubit.removeByCartKey(item.cartKey);

    Future<void> handleDecrement() async {
      if (item.qty > 1) {
        cubit.decrementByCartKey(item.cartKey);
      } else {
        final shouldRemove = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Remove item?'),
            content: Text('Remove "${item.product.name}" from your cart?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                ),
                child: const Text('Remove'),
              ),
            ],
          ),
        );
        if (shouldRemove == true && context.mounted) {
          _removeWithOffers(context, removeLine);
        }
      }
    }

    final dismissBg = Container(
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
    );

    return Dismissible(
      key: Key('cart-line-${item.cartKey}'),
      direction: DismissDirection.endToStart,
      background: dismissBg,
      secondaryBackground: dismissBg,
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
                  child: AppProductImage.product(
                    product: item.product,
                    fit: BoxFit.cover,
                    fallback: _thumbFallback(isDark),
                  ),
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

                  // Variant label (e.g. "500g") / pack size.
                  if (item.subLabel.isNotEmpty) ...[
                    Text(
                      item.subLabel,
                      key: Key('cart-variant-${item.cartKey}'),
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
                  ],

                  // Unit price of ONE pack + strikethrough MRP — always
                  // driven by the variant snapshot ("₹300 / 500g").
                  Row(
                    children: [
                      Text(
                        _unitPriceLabel,
                        key: Key('unit-price-${item.cartKey}'),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                      if (item.effectiveMrp > item.effectivePrice) ...[
                        const SizedBox(width: 6),
                        Text(
                          formatCurrency(item.effectiveMrp),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFF64748B)
                                : const Color(0xFF94A3B8),
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Stepper (quantity of packs) + live subtotal.
                  Row(
                    children: [
                      _Stepper(
                        qtyLabel: item.stepperLabel,
                        cartKey: item.cartKey,
                        canAdd: canAdd && item.isInStock,
                        canRemove: true,
                        isDark: isDark,
                        onRemove: handleDecrement,
                        onAdd: () => cubit.incrementByCartKey(item.cartKey),
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

                  // "Total: 1 kg" — packs converted for readability.
                  if (item.totalUnitLabel.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        AppLocalizations.of(
                          context,
                        ).total2(item.totalUnitLabel),
                        key: Key('cart-total-unit-${item.cartKey}'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),

                  if (!item.isInStock)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        AppLocalizations.of(context).outOfStock,
                        style: const TextStyle(
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

  /// "₹300 / 500g" — the price of ONE stepper step, taken from the variant
  /// snapshot on the cart item (never the product's default variant).
  String get _unitPriceLabel {
    final price = formatCurrency(item.effectivePrice, symbol: '₹');
    return '$price ${item.unitPriceLine}';
  }

  /// Removes the line and immediately offers the way to keep the product.
  void _removeWithOffers(BuildContext context, VoidCallback removeLine) {
    final messenger = ScaffoldMessenger.of(context);
    final wishlist = context.read<WishlistCubit>();
    final removed = item;
    removeLine();

    // "Move to Wishlist" is the alternative to deleting the item outright.
    messenger
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
              messenger
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

/// Clean "– 2 +" quantity stepper strictly displaying [ − ] count [ + ].
class _Stepper extends StatelessWidget {
  final String qtyLabel;
  final String cartKey;
  final bool canAdd;
  final bool canRemove;
  final bool isDark;
  final VoidCallback onRemove;
  final VoidCallback onAdd;

  const _Stepper({
    required this.qtyLabel,
    required this.cartKey,
    required this.canAdd,
    required this.canRemove,
    required this.isDark,
    required this.onRemove,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white70 : const Color(0xFF475569);
    final dim = isDark ? Colors.white24 : const Color(0xFFCBD5E1);
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
            onTap: canRemove ? onRemove : null,
            key: Key('stepper-minus-$cartKey'),
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Icon(Icons.remove, size: 16, color: canRemove ? fg : dim),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 28),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                qtyLabel,
                textAlign: TextAlign.center,
                key: Key('stepper-qty-$cartKey'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ),
          ),
          InkWell(
            onTap: canAdd ? onAdd : null,
            key: Key('stepper-plus-$cartKey'),
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Icon(Icons.add, size: 16, color: canAdd ? fg : dim),
            ),
          ),
        ],
      ),
    );
  }
}
