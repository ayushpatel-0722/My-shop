import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/domain/cart_calculator.dart';
import 'package:myshop/core/models/cart_item.dart';
import 'package:myshop/core/models/product.dart';

/// U1 — CartCalculator is the single source of truth for cart / checkout /
/// direct-order maths. Money is paise-safe (2 decimals) and unit totals come
/// from the frozen variant snapshots.
void main() {
  const calc = CartCalculator();

  const rice = Product(
    id: 'p_rice',
    companyId: 'c_organic',
    categoryId: 'cat_grains',
    name: 'Premium Basmati Rice',
    type: 'weight_based',
    unit: 1,
    unitType: 'kg',
    amount: 550,
    stockQty: 40,
    variants: [
      ProductVariant(
        sku: 'RICE-250',
        title: '250g',
        unitValue: 250,
        unitType: 'grams',
        priceOverride: 90,
        mrpOverride: 110,
        stockQty: 20,
      ),
      ProductVariant(
        sku: 'RICE-500',
        title: '500g',
        unitValue: 500,
        unitType: 'grams',
        priceOverride: 300,
        mrpOverride: 350,
        stockQty: 3,
      ),
    ],
  );

  const milk = Product(
    id: 'p_milk',
    companyId: 'c_organic',
    categoryId: 'cat_dairy',
    name: 'Milk',
    unit: 1,
    unitType: 'L',
    amount: 68,
    stockQty: 200,
  );

  CartItem rice500({int qty = 1}) => CartItem.fromSelection(
    companyId: 'c_organic',
    companyName: 'GreenLeaf',
    product: rice,
    selectedVariant: rice.variants[1],
    qty: qty,
  );

  CartItem rice250({int qty = 1}) => CartItem.fromSelection(
    companyId: 'c_organic',
    companyName: 'GreenLeaf',
    product: rice,
    selectedVariant: rice.variants[0],
    qty: qty,
  );

  group('line', () {
    test('itemTotal = variant price × qty', () {
      final l = calc.line(rice500(qty: 2));
      expect(l.itemTotal, 600);
      expect(l.itemMrpTotal, 700);
      expect(l.itemDiscount, 100);
      expect(l.totalQuantityInUnit, 1000, reason: '2 × 500 g');
    });

    test('money maths is paise-safe (2 decimals)', () {
      const odd = Product(
        id: 'p_odd',
        companyId: 'c_organic',
        categoryId: 'cat_x',
        name: 'Odd Price',
        amount: 33.335,
        stockQty: 9,
      );
      final item = CartItem.fromSelection(
        companyId: 'c_organic',
        companyName: 'GreenLeaf',
        product: odd,
        qty: 3,
      );
      // 3 × 33.335 = 100.005 -> rounded to 100.01 (paise).
      expect(calc.line(item).itemTotal, 100.01);
    });

    test('a negative quantity is clamped to zero', () {
      // Raw construction: the calculator itself guards against bad data.
      const bad = CartItem(
        companyId: 'c_organic',
        companyName: 'GreenLeaf',
        product: milk,
        qty: -2,
      );
      final l = calc.line(bad);
      expect(l.itemTotal, 0);
    });
  });

  group('summary', () {
    test('aggregates per-variant MRP and discount across rows', () {
      final s = calc.summary([rice250(), rice500()], deliveryCharge: 30);

      expect(s.subtotal, 390); // 90 + 300
      expect(s.totalMrp, 460); // 110 + 350
      expect(s.totalDiscount, 70); // 20 + 50
      expect(s.deliveryCharge, 30);
      expect(s.grandTotal, 420); // 390 + 30
      expect(s.totalItems, 2);
    });

    test('self pickup charges no delivery', () {
      final s = calc.summary([rice500()], deliveryCharge: 0);
      expect(s.deliveryCharge, 0);
      expect(s.grandTotal, 300);
    });

    test('a negative delivery charge cannot go below zero', () {
      final s = calc.summary([rice500()], deliveryCharge: -5);
      expect(s.deliveryCharge, 0);
      expect(s.grandTotal, 300);
    });

    test('quantity sums pack counts, not measurements', () {
      final s = calc.summary([rice500(qty: 2), rice250(qty: 3)]);
      expect(s.totalItems, 5, reason: '2 packs + 3 packs');
    });
  });

  group('totalMeasuredAmount', () {
    test('mixes weights but never pieces', () {
      final items = [
        rice500(qty: 2), // 1000 g
        rice250(qty: 1), // 250 g
        CartItem.fromSelection(
          companyId: 'c_organic',
          companyName: 'GreenLeaf',
          product: milk, // 1 L — different measure
        ),
      ];

      expect(calc.totalMeasuredAmount(items, 'grams'), 1250);
      expect(calc.totalMeasuredAmount(items, 'g'), 1250);
      expect(calc.totalMeasuredAmount(items, 'L'), 1, reason: 'milk only');
      expect(calc.totalMeasuredAmount(items, 'pieces'), 0);
    });

    test('kg and g requests normalise to the same measure', () {
      expect(calc.totalMeasuredAmount([rice500()], 'kg'), 500);
      expect(calc.totalMeasuredAmount([rice500()], 'grams'), 500);
    });
  });
}
