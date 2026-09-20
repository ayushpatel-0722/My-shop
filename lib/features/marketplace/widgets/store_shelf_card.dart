import 'package:flutter/material.dart';

import '../../../core/models/company.dart';
import '../../../core/models/product.dart';
import '../../../core/utils/formatters.dart';

/// The one product card used by the company storefront: category shelves,
/// the trending rail and the "All Products" grid all render it, so a store
/// page keeps a single visual language.
///
/// Image + discount badge + quick-add button + name + price, following the
/// app's card style (12–16 px radius, soft shadow, coral accents).
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

    return SizedBox(
      width: width,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E6EC)),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.04),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image + discount badge + sold-out veil.
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1.15,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(14),
                      ),
                      child: hasImage
                          ? Image.network(
                              product.images.first.trim(),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _fallback(),
                            )
                          : _fallback(),
                    ),
                  ),
                  if (discountPercent > 0)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5.5,
                          vertical: 2.5,
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
                          ),
                        ),
                      ),
                    ),
                  if (soldOut)
                    Positioned.fill(
                      child: Container(
                        color: Colors.white.withValues(alpha: 0.55),
                        alignment: Alignment.center,
                        child: const Text(
                          'Out of stock',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB3261E),
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              // Name + price row with quick-add.
              Padding(
                padding: const EdgeInsets.all(8.5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${product.unit == product.unit.roundToDouble() ? product.unit.toInt() : product.unit} ${product.unitType}',
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF6C757D),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E2229),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formatCurrency(product.price, symbol: symbol),
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E2229),
                                ),
                              ),
                              if (product.isDiscounted)
                                Text(
                                  formatCurrency(product.amount, symbol: symbol),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF94A3B8),
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
                            padding: const EdgeInsets.all(5.5),
                            decoration: BoxDecoration(
                              color: soldOut
                                  ? const Color(0xFFCBD5E1)
                                  : const Color(0xFFB3261E),
                              borderRadius: BorderRadius.circular(6),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallback() => Container(
    color: const Color(0xFFF8F9FA),
    child: Center(
      child: Icon(
        Icons.shopping_bag_outlined,
        size: 32,
        color: Colors.grey.shade400,
      ),
    ),
  );
}
