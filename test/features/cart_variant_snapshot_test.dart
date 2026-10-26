import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/domain/cart_calculator.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/features/checkout/cart/cart_cubit.dart';
import 'package:myshop/features/checkout/cart/cart_screen.dart';
import 'package:myshop/features/checkout/cart/wishlist_cubit.dart';
import 'package:myshop/features/checkout/payment/checkout_screen.dart';

import '../helpers/test_harness.dart';

/// U1 — Cart variant snapshot.
///
/// A cart line freezes the variant that was actually selected (label, price,
/// MRP, unitValue, unitType). Adding the 500g variant of a 250g/500g/1kg
/// product shows "₹300 / 500g" everywhere — never the product default (1kg).
void main() {
  late MockAppRepository repo;
  late CartCubit cart;
  late WishlistCubit wishlist;

  setUp(() {
    TestHarness.setupPlatformChannels();
    repo = TestHarness.bootServiceLocator();
    TestHarness.signIn(TestHarness.shopperWithAddresses);
    cart = CartCubit();
    wishlist = WishlistCubit();
  });

  tearDown(() => TestHarness.signOut());

  // Three packs of one product; the 1 kg pack is the default (product unit).
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

  Future<void> pumpCart(WidgetTester tester) => pumpTestApp(
    tester,
    const CartScreen(),
    user: TestHarness.shopperWithAddresses,
    cartCubit: cart,
    wishlistCubit: wishlist,
  );

  testWidgets('1. adding 500g shows ₹300 / 500g — never the product default', (
    tester,
  ) async {
    cart.add(rice, variant: variantOf('RICE-500'), companyId: 'c_organic');

    await pumpCart(tester);

    // The row carries the 500g snapshot: price per pack, unit chip, label.
    expect(find.text('₹300 / 500g'), findsOneWidget);
    expect(find.text('× 500g'), findsOneWidget);
    expect(find.text('500g'), findsWidgets);

    // The product default (1 kg @ ₹500) must never leak into the row.
    expect(find.text('₹500 / 1kg'), findsNothing);
    expect(find.text('₹500'), findsNothing);
    expect(find.text('× 1kg'), findsNothing);
    expect(find.text('1 kg'), findsNothing);
  });

  testWidgets('2. + steps to qty 2: ₹600 and Total: 1 kg', (tester) async {
    cart.add(rice, variant: variantOf('RICE-500'), companyId: 'c_organic');

    await pumpCart(tester);

    await tester.tap(find.byKey(const Key('stepper-plus-p_rice_RICE-500')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('stepper-qty-p_rice_RICE-500')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('line-total-p_rice_RICE-500')),
        matching: find.text('₹600'),
      ),
      findsOneWidget,
    );
    // 2 × 500 g = 1000 g -> converted for readability.
    expect(find.text('Total: 1 kg'), findsOneWidget);
  });

  testWidgets('3. 1kg is a separate row from 500g', (tester) async {
    cart.add(rice, variant: variantOf('RICE-500'), companyId: 'c_organic');
    cart.add(rice, variant: variantOf('RICE-1KG'), companyId: 'c_organic');

    await pumpCart(tester);

    expect(find.byKey(const Key('cart-line-p_rice_RICE-500')), findsOneWidget);
    expect(find.byKey(const Key('cart-line-p_rice_RICE-1KG')), findsOneWidget);
    expect(find.text('₹300 / 500g'), findsOneWidget);
    expect(find.text('₹500 / 1kg'), findsOneWidget);
    expect(cart.state.items.length, 2);
  });

  testWidgets('4. re-adding the same variant merges into one row', (
    tester,
  ) async {
    cart.add(rice, variant: variantOf('RICE-500'), companyId: 'c_organic');
    cart.add(
      rice,
      variant: variantOf('RICE-500'),
      companyId: 'c_organic',
      qty: 2,
    );

    await pumpCart(tester);

    expect(cart.state.items.length, 1, reason: 'same variant merges');
    expect(cart.state.items.single.qty, 3);
    expect(find.byKey(const Key('cart-line-p_rice_RICE-500')), findsOneWidget);
  });

  testWidgets('5. no selection falls back to the default variant (1kg)', (
    tester,
  ) async {
    // What "Add to Cart" does without an explicit selection: the details
    // screen preselects the default variant (1 kg of a 1 kg product).
    expect(rice.defaultVariantIndex, 2, reason: 'the 1kg pack is the default');

    cart.add(rice, companyId: 'c_organic');

    await pumpCart(tester);

    expect(find.text('₹500 / 1kg'), findsOneWidget);
    expect(find.text('× 1kg'), findsOneWidget);
    expect(find.text('₹300 / 500g'), findsNothing);
    expect(cart.state.items.single.variant?.variantId, 'RICE-1KG');
  });

  testWidgets('6. MRP and discount stay per-variant across rows', (
    tester,
  ) async {
    cart.add(rice, variant: variantOf('RICE-250'), companyId: 'c_organic');
    cart.add(rice, variant: variantOf('RICE-500'), companyId: 'c_organic');

    await pumpCart(tester);

    // Each row strikes its own MRP next to its own price.
    expect(find.text('₹110'), findsOneWidget); // 250g MRP
    expect(find.text('₹350'), findsOneWidget); // 500g MRP
    expect(find.text('₹90'), findsOneWidget); // 250g price (line total)
    expect(find.text('₹300'), findsOneWidget); // 500g price (line total)

    // CartCalculator agrees: discounts are computed from the snapshots.
    const calc = CartCalculator();
    final summary = calc.summary(cart.state.items, deliveryCharge: 30);
    expect(summary.totalMrp, 460); // 110 + 350
    expect(summary.subtotal, 390); // 90 + 300
    expect(summary.totalDiscount, 70); // 20 + 50
    expect(summary.grandTotal, 420);

    final line500 = calc.line(cart.state.items.last);
    expect(line500.itemTotal, 300);
    expect(line500.itemMrpTotal, 350);
    expect(line500.itemDiscount, 50);
    expect(line500.totalQuantityInUnit, 500);
  });

  testWidgets('7. checkout and the order snapshot keep "500g × 2"', (
    tester,
  ) async {
    await repo.saveProduct(rice); // checkout revalidates against the repo
    cart.add(
      rice,
      variant: variantOf('RICE-500'),
      companyId: 'c_organic',
      companyName: 'GreenLeaf Organics',
      qty: 2,
    );

    await pumpTestApp(
      tester,
      const CheckoutScreen(),
      user: TestHarness.shopperWithAddresses,
      cartCubit: cart,
    );

    // The checkout item row shows the variant and quantity snapshot.
    expect(find.text('500g × 2'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('checkout-place-order-button')),
    );
    await tester.tap(find.byKey(const Key('checkout-place-order-button')));
    await tester.pumpAndSettle();

    final order =
        (await repo.orders(userId: TestHarness.shopper.id).first).single;
    final item = order.items.single;
    expect(item.productId, 'p_rice');
    expect(item.variantSku, 'RICE-500');
    expect(item.variantLabel, '500g');
    expect(item.variantQtyLabel, '500g × 2', reason: 'history/admin wording');
    expect(item.unitValue, 500);
    expect(item.unitType, 'grams');
    expect(item.unitPrice, 300);
    expect(item.mrp, 350);
    expect(item.qty, 2);
    expect(item.itemTotal, 600);
  });

  testWidgets('8. stock caps the stepper at the available quantity', (
    tester,
  ) async {
    // RICE-500 has only 3 left.
    cart.add(
      rice,
      variant: variantOf('RICE-500'),
      companyId: 'c_organic',
      qty: 3,
    );

    await pumpCart(tester);

    expect(find.text('Only 3 left'), findsOneWidget);
    expect(cart.state.items.single.qty, 3);

    await tester.tap(
      find.byKey(const Key('stepper-plus-p_rice_RICE-500')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(
      cart.state.items.single.qty,
      3,
      reason: 'stock blocks the increment',
    );
  });
}
