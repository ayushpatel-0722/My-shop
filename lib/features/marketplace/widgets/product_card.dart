import 'package:flutter/material.dart';
import 'package:myshop/core/services/auth_session.dart';
import 'package:myshop/features/auth/widgets/auth_bottom_sheet.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes/app_router.dart';
import '../../checkout/cart/cart_cubit.dart';

import '../../../core/models/company.dart';
import '../../../core/models/product.dart';
import '../../../core/utils/formatters.dart';

/// Product card styled to match the Vibrant Marketplace design system.
///
/// Features:
/// - Resilient image loading with graceful fallback when image is missing/broken.
/// - Top-left discount badge (% OFF).
/// - Floating circular Coral Red '+' add-to-cart action button.
/// - Royal Blue brand name badge, bold product title, and Emerald rating pill.
/// - Formatted pricing with strikethrough MRP and savings highlight.
class ProductCard extends StatelessWidget {
  final Product product;
  final Company? company;
  final VoidCallback? onTap;

  const ProductCard({
    super.key,
    required this.product,
    this.company,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final symbol = company?.currencySymbol ?? '₹';
    final hasImage =
        product.images.isNotEmpty && product.images.first.trim().isNotEmpty;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E6EC), width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with Overlays (Discount Tag & Floating Add Button)
            AspectRatio(
              aspectRatio: 1.1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Product Image or Resilient Fallback
                  if (hasImage)
                    Image.network(
                      product.images.first.trim(),
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: const Color(0xFFF8F9FA),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: scheme.primary,
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded /
                                          progress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, _, _) => _fallbackImage(context),
                    )
                  else
                    _fallbackImage(context),

                  // Discount Badge (Top Left)
                  if (product.isDiscounted)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5247),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFFF5247,
                              ).withValues(alpha: 0.35),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '-${_discountPercent()}% OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),

                  // Floating '+' Add to Cart Button (Bottom Right)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Material(
                      color: const Color(0xFFFF5247),
                      shape: const CircleBorder(),
                      elevation: 3,
                      shadowColor: const Color(
                        0xFFFF5247,
                      ).withValues(alpha: 0.4),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          if (AuthSession.currentUser == null) {
                            AuthBottomSheet.show(
                              context,
                              onAuthenticated: () {
                                _doAddToCart(context);
                              },
                            );
                          } else {
                            _doAddToCart(context);
                          }
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(7.5),
                          child: Icon(Icons.add, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Product Details
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Brand / Company Name (Royal Blue)
                  if (company != null && company!.name.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        company!.name.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF3D38D9),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                  // Product Title
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFF1E2229),
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Unit & Rating
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${product.unit} ${product.unitType}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6C757D),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4.5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F7F2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 12,
                              color: Color(0xFF0CA678),
                            ),
                            SizedBox(width: 2),
                            Text(
                              '4.5',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0CA678),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Price Row (Selling Price + Strikethrough MRP)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          formatCurrency(product.price, symbol: symbol),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                            color: Color(0xFF1E2229),
                          ),
                        ),
                        if (product.isDiscounted) ...[
                          const SizedBox(width: 5),
                          Text(
                            formatCurrency(product.amount, symbol: symbol),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (product.isDiscounted) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Save ${formatCurrency(product.amount - product.price, symbol: symbol)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0CA678),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _discountPercent() {
    if (product.amount <= 0 || product.price >= product.amount) return 0;
    return (((product.amount - product.price) / product.amount) * 100).round();
  }

  void _doAddToCart(BuildContext context) {
    context.read<CartCubit>().add(product, company: company);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} added to cart'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'View Cart',
          onPressed: () => context.go(AppRoutes.cart),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// High-quality aesthetic fallback when an image URL is missing or fails to load.
  Widget _fallbackImage(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFF7F6), Color(0xFFF8F9FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEA),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFF5247).withValues(alpha: 0.15),
                  width: 1.5,
                ),
              ),
              child: Icon(
                _iconFor(product.categoryId),
                size: 32,
                color: const Color(0xFFFF5247),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFECEEF1)),
              ),
              child: const Text(
                'Marketplace',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6C757D),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String categoryId) {
    switch (categoryId) {
      case 'cat_veg':
        return Icons.eco_rounded;
      case 'cat_fruit':
        return Icons.apple_rounded;
      case 'cat_dairy':
        return Icons.water_drop_rounded;
      case 'cat_phone':
        return Icons.smartphone_rounded;
      case 'cat_audio':
        return Icons.headphones_rounded;
      case 'cat_wear':
        return Icons.watch_rounded;
      default:
        return Icons.shopping_bag_rounded;
    }
  }
}
