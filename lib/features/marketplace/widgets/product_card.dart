import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myshop/app/l10n/app_localizations.dart';
import 'package:myshop/core/services/auth_session.dart';
import 'package:myshop/features/auth/widgets/auth_bottom_sheet.dart';

import '../../../core/models/company.dart';
import '../../../core/models/product.dart';
import '../../../core/utils/cart_notification.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../core/widgets/app_product_image.dart';
import '../../checkout/cart/cart_cubit.dart';
import '../../checkout/cart/wishlist_cubit.dart';

/// Product card styled to match the Vibrant Marketplace design system.
///
/// Features:
/// - Resilient image loading with graceful fallback when image is missing/broken.
/// - Top-left discount badge (% OFF).
/// - Floating circular Coral Red '+' add-to-cart action button.
/// - Royal Blue brand name badge, bold product title, and Emerald rating pill.
/// - Formatted pricing with strikethrough MRP and savings highlight.
/// - Desktop hover lift, shadow, and responsive typography scaling.
class ProductCard extends StatefulWidget {
  final Product product;
  final Company? company;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;
  final double? width;
  final bool showBrand;

  const ProductCard({
    super.key,
    required this.product,
    this.company,
    this.onTap,
    this.onAddToCart,
    this.width,
    this.showBrand = true,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final company = widget.company;
    final symbol = company?.currencySymbol ?? '₹';
    final soldOut = !product.isInStock;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = context.isDesktop;

    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;

    final Widget card = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        if (isDesktop && mounted) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (isDesktop && mounted) setState(() => _isHovered = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(
          0,
          (_isHovered && isDesktop) ? -3.0 : 0.0,
          0,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (_isHovered && isDesktop)
                ? const Color(0xFFFF5247).withValues(alpha: 0.45)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E6EC)),
            width: 1,
          ),
          boxShadow: (_isHovered && isDesktop)
              ? [
                  const BoxShadow(
                    color: Color.fromRGBO(30, 34, 41, 0.12),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ]
              : const [
                  BoxShadow(
                    color: Color.fromRGBO(30, 34, 41, 0.03),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image with Overlays (Discount Tag, Out of Stock, & Floating Add Button)
              AspectRatio(
                aspectRatio: isDesktop ? 1.15 : 1.24,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Product Image or Resilient Fallback
                    AppProductImage.product(
                      product: product,
                      fit: BoxFit.cover,
                      fallback: _fallbackImage(context),
                    ),

                    // Discount Badge (Top Left)
                    if (product.isDiscounted && !soldOut)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 8 : 7,
                            vertical: isDesktop ? 4 : 3.5,
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
                            AppLocalizations.of(
                              context,
                            ).off2('${_discountPercent()}'),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: context.discountLabelSize,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),

                    // Wishlist / Favorite Button (Top Right)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _buildWishlistButton(context, isDark, isDesktop),
                    ),

                    // Sold out veil
                    if (soldOut)
                      Positioned.fill(
                        child: Container(
                          color: (isDark ? Colors.black : Colors.white)
                              .withValues(alpha: 0.65),
                          alignment: Alignment.center,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFB3261E),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              AppLocalizations.of(context).outOfStock,
                              style: TextStyle(
                                fontSize: isDesktop ? 10.5 : 9.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Floating '+' Add to Cart Button (Bottom Right)
                    if (!soldOut)
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
                              if (widget.onAddToCart != null) {
                                widget.onAddToCart!();
                              } else if (AuthSession.currentUser == null) {
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
                            child: Padding(
                              padding: EdgeInsets.all(isDesktop ? 8.5 : 7.5),
                              child: Icon(
                                Icons.add,
                                color: Colors.white,
                                size: isDesktop ? 22 : 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Product Details
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isDesktop ? 12 : 10,
                  isDesktop ? 8 : 6,
                  isDesktop ? 12 : 10,
                  isDesktop ? 10 : 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Brand / Company Name (Royal Blue)
                    if (widget.showBrand &&
                        company != null &&
                        company.name.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          company.name.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isDesktop ? 10.5 : 9.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF3D38D9),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),

                    // Product Title
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: context.productNameSize,
                        color: onSurface,
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
                            style: TextStyle(
                              fontSize: context.supportingTextSize,
                              color: onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 6.0 : 4.5,
                            vertical: isDesktop ? 3.0 : 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F7F2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star_rounded,
                                size: isDesktop ? 14 : 12,
                                color: const Color(0xFF0CA678),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '4.5',
                                style: TextStyle(
                                  fontSize: context.smallMetadataSize,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0CA678),
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
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: context.productPriceSize,
                              color: onSurface,
                            ),
                          ),
                          if (product.isDiscounted) ...[
                            const SizedBox(width: 5),
                            Text(
                              formatCurrency(product.amount, symbol: symbol),
                              style: TextStyle(
                                fontSize: context.originalPriceSize,
                                color: const Color(0xFF94A3B8),
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
                        AppLocalizations.of(context).save2(
                          formatCurrency(
                            product.amount - product.price,
                            symbol: symbol,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isDesktop ? 11 : 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0CA678),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.width != null) {
      return SizedBox(width: widget.width, child: card);
    }
    return card;
  }

  int _discountPercent() {
    final product = widget.product;
    if (product.amount <= 0 || product.price >= product.amount) return 0;
    return (((product.amount - product.price) / product.amount) * 100).round();
  }

  void _doAddToCart(BuildContext context) {
    context.read<CartCubit>().add(widget.product, company: widget.company);
    showAddToCartNotification(context, productName: widget.product.name);
  }

  Widget _buildWishlistButton(
    BuildContext context,
    bool isDark,
    bool isDesktop,
  ) {
    WishlistCubit? wishlistCubit;
    try {
      wishlistCubit = context.watch<WishlistCubit>();
    } catch (_) {}
    final inWishlist =
        wishlistCubit?.state.contains(widget.product.id) ?? false;

    return Material(
      color: (isDark ? const Color(0xFF1E293B) : Colors.white).withValues(
        alpha: 0.9,
      ),
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          if (wishlistCubit != null) {
            wishlistCubit.toggle(widget.product);
          }
        },
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? 6.5 : 5.5),
          child: Icon(
            inWishlist ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: inWishlist
                ? const Color(0xFFFF5247)
                : (isDark ? Colors.white70 : const Color(0xFF64748B)),
            size: isDesktop ? 18 : 16,
          ),
        ),
      ),
    );
  }

  /// High-quality aesthetic fallback when an image URL is missing or fails to load.
  Widget _fallbackImage(BuildContext context) {
    final product = widget.product;
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
              child: Text(
                AppLocalizations.of(context).marketplace,
                style: const TextStyle(
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
