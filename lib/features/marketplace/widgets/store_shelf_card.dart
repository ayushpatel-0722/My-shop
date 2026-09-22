import 'package:flutter/material.dart';

import '../../../core/models/company.dart';
import '../../../core/models/product.dart';
import 'product_card.dart';

/// The product card used across the company storefront: category shelves,
/// trending shelf and the "All Products" grid.
///
/// Delegates to the unified [ProductCard] for 100% consistent styling,
/// height, width, badges, and behavior across the entire app.
class StoreShelfCard extends StatelessWidget {
  final Product product;
  final Company company;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;
  final double? width;
  final bool showBrand;

  const StoreShelfCard({
    super.key,
    required this.product,
    required this.company,
    this.onTap,
    this.onAddToCart,
    this.width,
    this.showBrand = false,
  });

  @override
  Widget build(BuildContext context) {
    return ProductCard(
      product: product,
      company: company,
      onTap: onTap,
      onAddToCart: onAddToCart,
      width: width,
      showBrand: showBrand,
    );
  }
}
