import 'product.dart';

/// Cart line item (client-side, grouped by company at checkout).
class CartItem {
  final String companyId;
  final String companyName;
  final Product product;
  final ProductVariant? variant;
  final int qty;

  const CartItem({
    required this.companyId,
    required this.companyName,
    required this.product,
    this.variant,
    this.qty = 1,
  });

  /// Effective unit price taking variant price override into account.
  double get effectivePrice => (variant != null && variant!.priceOverride > 0)
      ? variant!.priceOverride
      : product.price;

  double get lineTotal => effectivePrice * qty;

  /// Unique identifier key for cart grouping and item management.
  String get cartKey {
    if (variant != null) {
      if (variant!.sku.isNotEmpty) return '${product.id}_${variant!.sku}';
      if (variant!.title.isNotEmpty) return '${product.id}_${variant!.title}';
      if (variant!.size.isNotEmpty || variant!.color.isNotEmpty) {
        return '${product.id}_${variant!.size}_${variant!.color}';
      }
    }
    return product.id;
  }

  String get displayName => variant != null && variant!.title.isNotEmpty
      ? '${product.name} (${variant!.title})'
      : product.name;

  String get variantLabel => variant != null && variant!.title.isNotEmpty
      ? variant!.title
      : (variant != null && variant!.attributes.isNotEmpty
            ? variant!.attributes.values.join(' / ')
            : '');

  /// Subtitle under the product name: the chosen variant when there is one,
  /// otherwise the pack size ("500 g", "1 piece").
  String get subLabel {
    if (variantLabel.isNotEmpty) return variantLabel;
    if (product.type == ProductType.weightBased && product.unit > 0) {
      return CartItem.formatAmount(product.unit, product.unitType);
    }
    return '${product.unit == product.unit.roundToDouble() ? product.unit.toInt() : product.unit} ${product.unitType}';
  }

  // ------------------------------------------------------------ Stock rules --

  /// Stock really remaining for this line (null when stock is untracked).
  int? get trackedStock {
    if (variant != null) {
      return variant!.isUnlimitedStock ? null : variant!.stockQty;
    }
    return product.isUnlimitedStock ? null : product.stockQty;
  }

  bool get isInStock => trackedStock == null || trackedStock! > 0;

  /// Largest quantity the stepper may reach (99 when stock is untracked).
  int get maxQty => trackedStock == null ? 99 : trackedStock!.clamp(1, 99);

  /// Amber chip text shown next to the stepper when stock is running out.
  ///
  /// Null while there is plenty left (or stock is not tracked) so the chip
  /// only appears "when relevant" instead of shouting on every row.
  String? stockWarningLabel({int threshold = 5}) {
    final left = trackedStock;
    if (left == null || left <= 0 || left > threshold) return null;
    return 'Only $left left';
  }

  // ----------------------------------------------------------- Stepper UI ---

  /// Middle label of the "–  x  +" stepper, in the product's real unit.
  ///
  /// Weight-based products step in their actual unit ("500 g", "1 kg"),
  /// quantity-based ones show a plain count.
  String get stepperLabel {
    if (product.type == ProductType.weightBased && product.unit > 0) {
      return CartItem.formatAmount(product.unit * qty, product.unitType);
    }
    return '$qty';
  }

  /// "500 grams" -> "500 g"; "1500 grams" -> "1.5 kg"; "2 pieces" -> "2 pieces".
  static String formatAmount(double amount, String unitType) {
    final unit = unitType.trim().toLowerCase();
    var value = amount;
    var suffix = unitType.isEmpty ? 'unit' : unitType;

    if (unit == 'grams' || unit == 'gram' || unit == 'g' || unit == 'gm') {
      if (amount >= 1000) {
        value = amount / 1000;
        suffix = 'kg';
      } else {
        suffix = 'g';
      }
    } else if (unit == 'ml' || unit == 'millilitre' || unit == 'milliliters') {
      if (amount >= 1000) {
        value = amount / 1000;
        suffix = 'L';
      } else {
        suffix = 'ml';
      }
    }

    final rounded = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
    return '$rounded $suffix';
  }

  CartItem copyWith({int? qty, ProductVariant? variant}) => CartItem(
    companyId: companyId,
    companyName: companyName,
    product: product,
    variant: variant ?? this.variant,
    qty: qty ?? this.qty,
  );
}
