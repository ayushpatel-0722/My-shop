import 'product.dart';

/// Cart line item (client-side, grouped by company at checkout).
class CartItem {
  final String companyId;
  final String companyName;
  final Product product;
  final int qty;

  const CartItem({
    required this.companyId,
    required this.companyName,
    required this.product,
    this.qty = 1,
  });

  double get lineTotal => product.price * qty;

  CartItem copyWith({int? qty}) => CartItem(
        companyId: companyId,
        companyName: companyName,
        product: product,
        qty: qty ?? this.qty,
      );
}
