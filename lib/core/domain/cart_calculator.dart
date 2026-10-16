import 'package:myshop/core/models/product.dart';

import '../models/cart_item.dart';
import 'order_pricing.dart' show roundMoney;

/// Per-line money and measurement maths for one cart row.
class CartLineCalc {
  final String cartItemId;
  final double itemTotal;
  final double itemMrpTotal;
  final double itemDiscount;

  /// `variant.unitValue × quantity` in the variant's own unit (0 when the
  /// line carries no measurable unit).
  final double totalQuantityInUnit;

  const CartLineCalc({
    required this.cartItemId,
    required this.itemTotal,
    required this.itemMrpTotal,
    required this.itemDiscount,
    required this.totalQuantityInUnit,
  });

  @override
  String toString() =>
      'CartLineCalc($cartItemId, total: $itemTotal, mrp: $itemMrpTotal, '
      'discount: $itemDiscount, qty: $totalQuantityInUnit)';
}

/// Totals for a whole cart or one shop's block.
class CartSummary {
  final double subtotal;
  final double totalMrp;
  final double totalDiscount;
  final double deliveryCharge;
  final double grandTotal;
  final int totalItems;

  const CartSummary({
    required this.subtotal,
    required this.totalMrp,
    required this.totalDiscount,
    required this.deliveryCharge,
    required this.grandTotal,
    required this.totalItems,
  });

  @override
  String toString() =>
      'CartSummary(subtotal: $subtotal, mrp: $totalMrp, discount: '
      '$totalDiscount, delivery: $deliveryCharge, total: $grandTotal)';
}

/// Single source of truth for cart maths — used by the cart, checkout and
/// direct-order screens so every screen shows the same numbers.
///
/// All money is rounded to paise (2 decimals) so floating point noise can
/// never leak into a receipt.
class CartCalculator {
  const CartCalculator();

  /// Maths for one cart line.
  ///
  ///   itemTotal    = variant.price × quantity
  ///   itemMrpTotal = variant.mrp × quantity
  ///   itemDiscount = itemMrpTotal − itemTotal
  ///   totalQuantityInUnit = variant.unitValue × quantity
  CartLineCalc line(CartItem item) {
    final qty = item.qty < 0 ? 0 : item.qty;
    final itemTotal = roundMoney(item.effectivePrice * qty);
    final itemMrpTotal = roundMoney(item.effectiveMrp * qty);
    final discount = itemMrpTotal - itemTotal;
    return CartLineCalc(
      cartItemId: item.cartKey,
      itemTotal: itemTotal,
      itemMrpTotal: itemMrpTotal,
      itemDiscount: discount > 0 ? roundMoney(discount) : 0,
      totalQuantityInUnit: item.totalQuantityInUnit,
    );
  }

  /// Totals for [items] (one shop or the whole cart).
  ///
  ///   subtotal       = Σ itemTotal
  ///   totalMrp       = Σ itemMrpTotal
  ///   totalDiscount  = totalMrp − subtotal
  ///   grandTotal     = subtotal + deliveryCharge
  CartSummary summary(List<CartItem> items, {double deliveryCharge = 0}) {
    var subtotal = 0.0;
    var totalMrp = 0.0;
    var count = 0;
    for (final item in items) {
      final calc = line(item);
      subtotal += calc.itemTotal;
      totalMrp += calc.itemMrpTotal;
      count += item.qty < 0 ? 0 : item.qty;
    }
    subtotal = roundMoney(subtotal);
    totalMrp = roundMoney(totalMrp);
    final discount = totalMrp - subtotal;
    final delivery = roundMoney(deliveryCharge < 0 ? 0 : deliveryCharge);
    return CartSummary(
      subtotal: subtotal,
      totalMrp: totalMrp,
      totalDiscount: discount > 0 ? roundMoney(discount) : 0,
      deliveryCharge: delivery,
      grandTotal: roundMoney(subtotal + delivery),
      totalItems: count,
    );
  }

  /// Σ `variant.unitValue × quantity` over [items] in [unitType]'s measure.
  ///
  /// Lines sold in other units are ignored so "2 × 500g + 1 × 250g" answers
  /// 1250 g instead of mixing pieces into the weight.
  double totalMeasuredAmount(List<CartItem> items, String unitType) {
    final target = _normalizeUnit(unitType);
    var total = 0.0;
    for (final item in items) {
      final lineUnit = item.variant?.unitType ?? item.product.unitType;
      if (_normalizeUnit(lineUnit) != target) continue;
      total += item.totalQuantityInUnit;
    }
    return total;
  }

  static String _normalizeUnit(String unitType) {
    final t = unitType.trim().toLowerCase();
    if (t == 'gram' || t == 'grams' || t == 'gm' || t == 'g' || t == 'kg' || t == 'kgs' || t == 'kilogram') {
      return 'g';
    }
    if (t == 'ml' || t == 'millilitre' || t == 'milliliters') return 'ml';
    if (t == 'l' || t == 'litre' || t == 'liters') return 'l';
    return t;
  }

  /// "≥1000g → kg, ≥1000ml → l" display conversion, e.g. 1500g -> "1.5 kg".
  static String formatMeasured(double amount, String unitType) =>
      CartUnit.format(amount, unitType);
}
