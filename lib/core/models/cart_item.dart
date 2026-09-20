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
  String get cartKey => variant != null && variant!.sku.isNotEmpty
      ? '${product.id}_${variant!.sku}'
      : product.id;

  String get displayName => variant != null && variant!.title.isNotEmpty
      ? '${product.name} (${variant!.title})'
      : product.name;

  String get variantLabel => variant != null && variant!.title.isNotEmpty
      ? variant!.title
      : (variant != null && variant!.attributes.isNotEmpty
            ? variant!.attributes.values.join(' / ')
            : '');

  CartItem copyWith({int? qty, ProductVariant? variant}) => CartItem(
    companyId: companyId,
    companyName: companyName,
    product: product,
    variant: variant ?? this.variant,
    qty: qty ?? this.qty,
  );
}
