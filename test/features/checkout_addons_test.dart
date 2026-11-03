import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/domain/addon_rules.dart';
import 'package:myshop/core/models/cart_item.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/core/models/product_addon.dart';
import 'package:myshop/features/checkout/cart/cart_cubit.dart';
import 'package:myshop/features/checkout/cart/cart_screen.dart';
import 'package:myshop/features/checkout/payment/checkout_screen.dart';

import '../helpers/test_harness.dart';

/// Add-ons through the cart, checkout and the placed order: shown, priced,
/// re-checked against the live catalogue, and stored on the order.
void main() {
  late MockAppRepository repo;
  late CartCubit cart;

  setUp(() {
    TestHarness.setupPlatformChannels();
    repo = TestHarness.bootServiceLocator();
    TestHarness.signIn(TestHarness.shopperWithAddresses);
    cart = CartCubit();
  });

  tearDown(() => TestHarness.signOut());

  const delivery = ProductAddOn(
    id: 'ao_delivery',
    title: 'Delivery to floor',
    amount: 500,
  );
  const assembly = ProductAddOn(
    id: 'ao_assembly',
    title: 'Assembly',
    amount: 1000,
    discountAmt: 800,
  );

  const table = Product(
    id: 'p_table',
    companyId: 'c_organic',
    categoryId: 'cat_x',
    name: 'Oak Table',
    amount: 5000,
    discountAmt: 4500,
    stockQty: 20,
    addOns: [delivery, assembly],
  );

  void addLine(Product p, List<String> ids, {int qty = 1}) => cart.add(
    p,
    companyId: 'c_organic',
    companyName: 'GreenLeaf Organics',
    qty: qty,
    addOns: AddOnRules.resolve(p, ids),
  );

  Future<void> openCheckout(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await pumpTestApp(
      tester,
      const CheckoutScreen(),
      user: TestHarness.shopperWithAddresses,
      cartCubit: cart,
    );
    await tester.pumpAndSettle();
    // Re-validation reads the catalogue through async streams.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> placeOrder(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('address-card-addr_home')));
    await tester.tap(find.byKey(const Key('address-card-addr_home')));
    await tester.pumpAndSettle();
    final btn = find.byKey(const Key('checkout-place-order-button'));
    await tester.ensureVisible(btn);
    await tester.tap(btn);
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('cart shows the add-ons and the line total includes them', (
    tester,
  ) async {
    await repo.saveProduct(table);
    addLine(table, ['ao_delivery', 'ao_assembly'], qty: 2);

    await pumpTestApp(
      tester,
      const CartScreen(),
      user: TestHarness.shopperWithAddresses,
      cartCubit: cart,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('addon-lines')), findsOneWidget);
    expect(find.textContaining('Delivery to floor'), findsOneWidget);
    expect(find.textContaining('Assembly'), findsOneWidget);
    // 2 × (4500 + 500 + 800)
    expect(find.text('₹11,600'), findsWidgets);
  });

  testWidgets('cart reopened from storage still shows its add-ons', (
    tester,
  ) async {
    await repo.saveProduct(table);
    addLine(table, ['ao_assembly']);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    final reopened = CartCubit();
    await tester.runAsync(reopened.loadFromStorage);
    expect(reopened.state.items.single.addOns.single.title, 'Assembly');
    expect(reopened.state.items.single.lineTotal, 5300);
    await reopened.close();
  });

  testWidgets('the order stores the add-ons and the right amounts', (
    tester,
  ) async {
    await repo.saveProduct(table);
    addLine(table, ['ao_delivery', 'ao_assembly'], qty: 2);

    await openCheckout(tester);
    expect(find.byKey(const Key('addon-lines')), findsOneWidget);
    await placeOrder(tester);

    final order =
        (await repo.orders(userId: TestHarness.shopper.id).first).single;
    final item = order.items.single;
    expect(item.qty, 2);
    expect(item.addOns.map((a) => a.addOnId), ['ao_delivery', 'ao_assembly']);
    expect(item.addOns.map((a) => a.price), [500, 800]);
    expect(item.unitPrice, 5800, reason: 'product + add-ons per unit');
    expect(item.baseUnitPrice, 4500);
    expect(order.subtotal, 11600);
    expect(order.deliveryCharge, 30);
    expect(order.totalAmount, 11630);
    expect(order.isBalanced, isTrue);
    expect(cart.state.items, isEmpty);
  });

  testWidgets('a product without add-ons is ordered exactly as before', (
    tester,
  ) async {
    const plain = Product(
      id: 'p_plain',
      companyId: 'c_organic',
      categoryId: 'cat_x',
      name: 'Plain Stool',
      amount: 900,
      stockQty: 20,
    );
    await repo.saveProduct(plain);
    cart.add(plain, companyId: 'c_organic', companyName: 'G', qty: 2);

    await openCheckout(tester);
    expect(find.byKey(const Key('addon-lines')), findsNothing);
    await placeOrder(tester);

    final order =
        (await repo.orders(userId: TestHarness.shopper.id).first).single;
    expect(order.items.single.addOns, isEmpty);
    expect(order.subtotal, 1800);
  });

  testWidgets('an add-on disabled since it was added is dropped at checkout', (
    tester,
  ) async {
    await repo.saveProduct(table);
    addLine(table, ['ao_delivery', 'ao_assembly']);
    // The shop disables "Delivery to floor" after the shopper added it.
    await repo.saveProduct(
      table.copyWith(addOns: [delivery.copyWith(isActive: false), assembly]),
    );

    await openCheckout(tester);
    expect(
      find.textContaining('Delivery to floor is no longer available'),
      findsOneWidget,
    );
    expect(cart.state.items.single.addOns.map((a) => a.addOnId), [
      'ao_assembly',
    ]);

    await placeOrder(tester);
    final order =
        (await repo.orders(userId: TestHarness.shopper.id).first).single;
    expect(order.items.single.addOns.map((a) => a.addOnId), ['ao_assembly']);
    expect(order.subtotal, 5300, reason: '4500 + 800, no delivery add-on');
  });

  testWidgets('a changed add-on price is re-priced at checkout', (
    tester,
  ) async {
    await repo.saveProduct(table);
    addLine(table, ['ao_assembly']);
    await repo.saveProduct(
      table.copyWith(addOns: [delivery, assembly.copyWith(discountAmt: 600)]),
    );

    await openCheckout(tester);
    expect(find.textContaining('Add-on prices changed'), findsOneWidget);
    await placeOrder(tester);

    final order =
        (await repo.orders(userId: TestHarness.shopper.id).first).single;
    expect(order.items.single.addOns.single.price, 600);
    expect(order.subtotal, 5100);
  });

  testWidgets('direct buy carries the add-ons into checkout', (tester) async {
    await repo.saveProduct(table);
    final direct = CartItem.fromSelection(
      companyId: 'c_organic',
      companyName: 'GreenLeaf Organics',
      product: table,
      qty: 1,
      addOns: AddOnRules.resolve(table, ['ao_delivery']),
    );
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await pumpTestApp(
      tester,
      CheckoutScreen(directItems: [direct]),
      user: TestHarness.shopperWithAddresses,
      cartCubit: cart,
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Delivery to floor'), findsOneWidget);
    await placeOrder(tester);

    final order =
        (await repo.orders(userId: TestHarness.shopper.id).first).single;
    expect(order.items.single.addOns.single.addOnId, 'ao_delivery');
    expect(order.subtotal, 5000);
    expect(cart.state.items, isEmpty, reason: 'the cart was never touched');
  });
}
