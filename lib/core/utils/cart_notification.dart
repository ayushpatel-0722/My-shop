import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:myshop/app/l10n/app_localizations.dart';
import 'package:myshop/app/routes/app_router.dart';
import 'package:myshop/core/widgets/app_toast.dart';
import 'package:myshop/features/checkout/cart/cart_cubit.dart';

/// Tells the shopper a product went into the cart.
///
/// One toast at a time: a quick second add replaces the first instead of
/// stacking behind it, and the toast hides itself after [AppToast.duration]
/// even though it carries a "view cart" action.
void showAddToCartNotification(
  BuildContext context, {
  required String productName,
  String? variantLabel,
}) {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final hasVariant = variantLabel != null && variantLabel.trim().isNotEmpty;
  final itemCount = _cartItemCount(context);

  AppToast.success(
    context,
    hasVariant
        ? l10n.addedToCart2(productName, ' ($variantLabel)')
        : l10n.addedToCart(productName),
    detail: itemCount > 0 ? l10n.cartItemsInCart(itemCount) : null,
    actionLabel: l10n.viewCart,
    onAction: () {
      messenger.hideCurrentSnackBar();
      context.push(AppRoutes.cart);
    },
    key: const Key('add-to-cart-success-snackbar'),
  );
}

int _cartItemCount(BuildContext context) {
  try {
    return context.read<CartCubit>().state.totalItems;
  } on Object {
    // No cart in scope (e.g. a bare widget test): just skip the count.
    return 0;
  }
}
