import 'package:flutter/material.dart';

import '../../../core/models/company.dart';
import '../../../core/models/product.dart';
import '../../../core/utils/formatters.dart';

/// The product card used across the company storefront: category shelves,
/// trending shelf and the "All Products" grid.
class StoreShelfCard extends StatelessWidget {
  final Product product;
  final Company company;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;

  /// Fixed width for horizontal shelves; null lets a grid cell size it.
  final double? width;

  const StoreShelfCard({
    super.key,
    required this.product,
    required this.company,
    this.onTap,
    this.onAddToCart,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final symbol = company.currencySymbol;
    final hasImage =
        product.images.isNotEmpty && product.images.first.trim().isNotEmpty;
    final discountPercent = product.discountPercent.round();
    final soldOut = !product.isInStock;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: width,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Image container with discount tag & stock overlay
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1.1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF8FAFC),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(11),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(11),
                        ),
                        child: hasImage
                            ? Image.network(
                                product.images.first.trim(),
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => _fallback(isDark),
                              )
                            : _fallback(isDark),
                      ),
                    ),
                  ),

                  // Discount tag
                  if (discountPercent > 0)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB3261E),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$discountPercent% OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),

                  // Sold out veil
                  if (soldOut)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.black : Colors.white)
                              .withValues(alpha: 0.65),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(11),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFB3261E),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Out of stock',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              // 2. Info area (Unit, Title, Price, Add Button)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(9, 7, 9, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Unit measurement
                      Text(
                        '${product.unit == product.unit.roundToDouble() ? product.unit.toInt() : product.unit} ${product.unitType}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 2),

                      // Product Title
                      Expanded(
                        child: Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1F2937),
                            height: 1.25,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Price & Quick Add Button Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  formatCurrency(product.price, symbol: symbol),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF111827),
                                  ),
                                ),
                                if (product.isDiscounted)
                                  Text(
                                    formatCurrency(
                                      product.amount,
                                      symbol: symbol,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF9CA3AF),
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: soldOut ? null : onAddToCart,
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: soldOut
                                    ? (isDark
                                          ? const Color(0xFF475569)
                                          : const Color(0xFFCBD5E1))
                                    : const Color(0xFFB3261E),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: soldOut
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: const Color(
                                            0xFFB3261E,
                                          ).withValues(alpha: 0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                              ),
                              child: const Icon(
                                Icons.add,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallback(bool isDark) => Container(
    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
    child: Center(
      child: Icon(
        Icons.shopping_bag_outlined,
        size: 28,
        color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
      ),
    ),
  );
}
