import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/routes/app_router.dart';

/// Shows an add-to-cart success notification that remains visible until
/// dismissed by the user or replaced by another add-to-cart action.
void showAddToCartNotification(
  BuildContext context, {
  required String productName,
  String? variantLabel,
}) {
  final messenger = ScaffoldMessenger.of(context);
  // Dismiss any existing notification so notifications don't stack duplicates
  messenger.hideCurrentSnackBar();

  final variantSuffix = (variantLabel != null && variantLabel.trim().isNotEmpty)
      ? ' ($variantLabel)'
      : '';

  messenger.showSnackBar(
    SnackBar(
      key: const Key('add-to-cart-success-snackbar'),
      content: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF22C55E),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$productName$variantSuffix added to cart successfully.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(days: 365), // Persistent until manually dismissed
      showCloseIcon: true,
      closeIconColor: Colors.white70,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: const Color(0xFF1E293B),
      action: SnackBarAction(
        label: 'VIEW CART',
        textColor: const Color(0xFFFF6B61),
        onPressed: () {
          messenger.hideCurrentSnackBar();
          context.push(AppRoutes.cart);
        },
      ),
    ),
  );
}

