import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/models/cart_item.dart';
import 'package:myshop/core/models/order.dart';
import 'package:myshop/core/models/product.dart';

/// U1 — the cart line freezes the SELECTED variant's snapshot.
///
/// label / price / mrp / unitValue / unitType are read from the variant that
/// was added to the cart and must never fall back to the product defaults.
void main() {
  const rice = Product(
    id: 'p_rice',
    companyId: 'c_organic',
    categoryId: 'cat_grains',
    name: 'Premium Basmati Rice',
    type: 'weight_based',
    unit: 1,
    unitType: 'kg',
    amount: 550,
    discountAmt: 500,
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
      ProductVariant(
        sku: 'RICE-1KG',
        title: '1kg',
        unitValue: 1000,
        unitType: 'grams',
        priceOverride: 500,
        mrpOverride: 550,
        stockQty: 10,
      ),
    ],
  );

  ProductVariant variantOf(String sku) =>
      rice.variants.firstWhere((v) => v.sku == sku);

  group('VariantSnapshot.fromVariant', () {
    test('freezes the variant own price / MRP / unit / stock', () {
      final snap = VariantSnapshot.fromVariant(rice, variantOf('RICE-500'));

      expect(snap.variantId, 'RICE-500');
      expect(snap.label, '500g');
      expect(snap.price, 300);
      expect(snap.mrp, 350);
      expect(snap.unitValue, 500);
      expect(snap.unitType, 'grams');
      expect(snap.stock, 3);
    });

    test('never reads the product defaults', () {
      final snap = VariantSnapshot.fromVariant(rice, variantOf('RICE-250'));

      // Product default is 1 kg @ ₹500 — none of it leaks into the snapshot.
      expect(snap.unitValue, 250);
      expect(snap.unitType, 'grams');
      expect(snap.price, 90);
      expect(snap.mrp, 110);
    });

    test('legacy variants without a unit fall back to parsing the label', () {
      const legacy = Product(
        id: 'p_old',
        companyId: 'c_organic',
        categoryId: 'cat_x',
        name: 'Old Sugar',
        unit: 5,
        unitType: 'kg',
        amount: 300,
        variants: [
          ProductVariant(sku: 'S-500', title: '500g', priceOverride: 45),
        ],
      );
      final snap = VariantSnapshot.fromVariant(legacy, legacy.variants.first);

      expect(snap.unitValue, 500, reason: 'parsed out of "500g"');
      expect(snap.unitType, 'g');
      expect(snap.price, 45);
    });

    test('a MRP below the selling price is clamped up', () {
      const odd = Product(
        id: 'p_odd',
        companyId: 'c_organic',
        categoryId: 'cat_x',
        name: 'Odd',
        amount: 100,
        variants: [
          ProductVariant(
            sku: 'O-1',
            title: 'One',
            priceOverride: 80,
            mrpOverride: 60,
          ),
        ],
      );
      final snap = VariantSnapshot.fromVariant(odd, odd.variants.first);
      expect(
        snap.mrp,
        80,
        reason: 'never strike a price below the selling price',
      );
    });
  });

  group('CartItem.fromSelection', () {
    test('cartKey is one row per variant', () {
      final a = CartItem.fromSelection(
        companyId: 'c_organic',
        companyName: 'GreenLeaf',
        product: rice,
        selectedVariant: variantOf('RICE-500'),
      );
      final b = CartItem.fromSelection(
        companyId: 'c_organic',
        companyName: 'GreenLeaf',
        product: rice,
        selectedVariant: variantOf('RICE-1KG'),
      );

      expect(a.cartKey, 'p_rice_RICE-500');
      expect(b.cartKey, 'p_rice_RICE-1KG');
      expect(a.cartKey, isNot(b.cartKey));
    });

    test('the 500g line shows "₹300 / 500g"-style unit data', () {
      final item = CartItem.fromSelection(
        companyId: 'c_organic',
        companyName: 'GreenLeaf',
        product: rice,
        selectedVariant: variantOf('RICE-500'),
        qty: 1,
      );

      expect(item.variantLabel, '500g');
      expect(item.effectivePrice, 300);
      expect(item.effectiveMrp, 350);
      expect(item.lineTotal, 300);
      expect(item.lineMrpTotal, 350);
      expect(item.lineDiscount, 50);
      expect(item.priceUnitLabel, '500g');
      expect(item.unitPriceLine, '/ 500g');
      expect(item.stepperUnitLabel, '× 500g');
    });

    test('totals convert packs into readable units', () {
      final two = CartItem.fromSelection(
        companyId: 'c_organic',
        companyName: 'GreenLeaf',
        product: rice,
        selectedVariant: variantOf('RICE-500'),
        qty: 2,
      );
      expect(two.totalQuantityInUnit, 1000);
      expect(two.totalUnitLabel, '1 kg', reason: '1000 g shows as 1 kg');

      final twoKg = CartItem.fromSelection(
        companyId: 'c_organic',
        companyName: 'GreenLeaf',
        product: rice,
        selectedVariant: variantOf('RICE-1KG'),
        qty: 2,
      );
      expect(twoKg.totalQuantityInUnit, 2000);
      expect(twoKg.totalUnitLabel, '2 kg');

      final oneSmall = CartItem.fromSelection(
        companyId: 'c_organic',
        companyName: 'GreenLeaf',
        product: rice,
        selectedVariant: variantOf('RICE-250'),
      );
      expect(
        oneSmall.totalUnitLabel,
        '250 g',
        reason: 'under 1000 g stays in g',
      );
    });

    test('no selection resolves to the default variant (1kg), never the '
        'product-level pack', () {
      expect(rice.defaultVariantIndex, 2);

      final item = CartItem.fromSelection(
        companyId: 'c_organic',
        companyName: 'GreenLeaf',
        product: rice,
      );

      expect(item.variant?.variantId, 'RICE-1KG');
      expect(item.variantLabel, '1kg');
      expect(item.effectivePrice, 500);
    });

    test('variant-less products snapshot the product pack', () {
      const plain = Product(
        id: 'p_milk',
        companyId: 'c_organic',
        categoryId: 'cat_dairy',
        name: 'Milk',
        unit: 1,
        unitType: 'L',
        amount: 68,
      );
      final item = CartItem.fromSelection(
        companyId: 'c_organic',
        companyName: 'GreenLeaf',
        product: plain,
      );

      expect(item.variantLabel, '');
      expect(item.effectivePrice, 68);
      expect(item.unitPriceLine, 'each', reason: 'plain counts price per item');
      expect(item.stepperUnitLabel, '', reason: 'no unit chip for counts');
    });

    test('stock caps maxQty and reports the warning label', () {
      final limited = CartItem.fromSelection(
        companyId: 'c_organic',
        companyName: 'GreenLeaf',
        product: rice,
        selectedVariant: variantOf('RICE-500'), // stock 3
      );
      expect(limited.maxQty, 3);
      expect(limited.stockWarningLabel(), 'Only 3 left');

      final plenty = CartItem.fromSelection(
        companyId: 'c_organic',
        companyName: 'GreenLeaf',
        product: rice,
        selectedVariant: variantOf('RICE-250'), // stock 20
      );
      expect(plenty.stockWarningLabel(), isNull, reason: 'no chip when plenty');
    });
  });

  group('CartItem.fromMap — frozen snapshots survive storage', () {
    test('reads the variant map back without the product', () {
      final item = CartItem.fromMap({
        'companyId': 'c_organic',
        'companyName': 'GreenLeaf',
        'productId': 'p_rice',
        'productName': 'Premium Basmati Rice',
        'qty': 2,
        'variant': {
          'variantId': 'RICE-500',
          'label': '500g',
          'unitValue': 500,
          'unitType': 'grams',
          'price': 300,
          'mrp': 350,
          'stock': 3,
        },
      });

      expect(item.variantLabel, '500g');
      expect(item.effectivePrice, 300);
      expect(item.effectiveMrp, 350);
      expect(item.unitValue, 500);
      expect(item.unitType, 'grams');
      expect(item.variantId, 'RICE-500');
    });
  });

  group('OrderItem snapshot labels', () {
    test('history and admin show "500g × 2"', () {
      const item = OrderItem(
        productId: 'p_rice',
        qty: 2,
        unitPrice: 300,
        name: 'Premium Basmati Rice',
        variantSku: 'RICE-500',
        variantTitle: '500g',
        variantLabel: '500g',
        unitValue: 500,
        unitType: 'grams',
        mrp: 350,
      );

      expect(item.variantQtyLabel, '500g × 2');
      expect(item.itemTotal, 600);
      expect(item.itemMrpTotal, 700);
      expect(item.displayVariantLabel, '500g');
    });

    test('variant-less items show just the quantity', () {
      const item = OrderItem(
        productId: 'p_milk',
        qty: 3,
        unitPrice: 68,
        name: 'Milk',
      );
      expect(item.variantQtyLabel, '× 3');
    });
  });
}
