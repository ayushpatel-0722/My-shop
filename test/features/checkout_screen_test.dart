import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/order.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/core/models/voucher.dart';
import 'package:myshop/features/checkout/cart/cart_cubit.dart';
import 'package:myshop/features/checkout/payment/checkout_screen.dart';

import '../helpers/test_harness.dart';

void main() {
  late MockAppRepository repo;
  late CartCubit cart;

  setUp(() {
    TestHarness.setupPlatformChannels();
    repo = TestHarness.bootServiceLocator();
    TestHarness.signIn(TestHarness.shopper);
    cart = CartCubit();
  });

  tearDown(() => TestHarness.signOut());

  const tomatoes = Product(
    id: 'p_tomato',
    companyId: 'c_organic',
    categoryId: 'cat_veg',
    name: 'Fresh Tomatoes',
    amount: 60,
    discountAmt: 48,
    stockQty: 120,
  );

  const milk = Product(
    id: 'p_milk',
    companyId: 'c_organic',
    categoryId: 'cat_dairy',
    name: 'Organic Cow Milk',
    amount: 68,
    stockQty: 200,
  );

  const phone = Product(
    id: 'p_phone',
    companyId: 'c_techtronics',
    categoryId: 'cat_phone',
    name: 'Nova X5 Smartphone',
    amount: 24999,
    stockQty: 25,
  );

  Future<void> openCheckout(WidgetTester tester) => pumpTestApp(
    tester,
    const CheckoutScreen(),
    user: TestHarness.shopper,
    cartCubit: cart,
  );

  Future<void> enterAddressAndPincode(
    WidgetTester tester, {
    String address = '12 Market Street',
    String pincode = '380001',
  }) async {
    await tester.enterText(
      find.byKey(const Key('checkout-address-field')),
      address,
    );
    await tester.enterText(
      find.byKey(const Key('checkout-pincode-field')),
      pincode,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an empty cart never reaches the checkout form', (tester) async {
    await openCheckout(tester);
    expect(find.text('Your cart is empty'), findsOneWidget);
  });

  testWidgets('places one order per store of a multi-store cart', (
    tester,
  ) async {
    cart.add(
      tomatoes,
      companyId: 'c_organic',
      companyName: 'GreenLeaf Organics',
      qty: 2,
    );
    cart.add(
      phone,
      companyId: 'c_techtronics',
      companyName: 'TechTronics Hub',
      qty: 1,
    );

    await openCheckout(tester);
    await enterAddressAndPincode(tester);

    expect(
      find.byKey(const Key('checkout-store-card-c_organic')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('checkout-store-card-c_techtronics')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const Key('checkout-place-order-button')),
    );
    await tester.tap(find.byKey(const Key('checkout-place-order-button')));
    await tester.pumpAndSettle();

    final orders = await repo.orders(userId: TestHarness.shopper.id).first;
    expect(orders.length, 2, reason: 'every store gets its own order');
    expect(orders.map((o) => o.companyId).toSet(), {
      'c_organic',
      'c_techtronics',
    });
    expect(cart.state.items, isEmpty, reason: 'the cart is emptied on success');
  });

  testWidgets('stores the full bill on the order', (tester) async {
    cart.add(
      tomatoes,
      companyId: 'c_organic',
      companyName: 'GreenLeaf Organics',
      qty: 2,
    ); // 96

    await openCheckout(tester);
    await enterAddressAndPincode(tester);
    await tester.ensureVisible(
      find.byKey(const Key('checkout-place-order-button')),
    );
    await tester.tap(find.byKey(const Key('checkout-place-order-button')));
    await tester.pumpAndSettle();

    final order =
        (await repo.orders(userId: TestHarness.shopper.id).first).single;
    expect(order.subtotal, 96, reason: '2 × 48');
    expect(order.deliveryCharge, 30, reason: 'pincode 380001 costs 30');
    expect(order.discountAmount, 0);
    expect(order.totalAmount, 126, reason: 'subtotal + delivery');
    expect(order.isBalanced, isTrue);
    expect(order.items.single.name, 'Fresh Tomatoes', reason: 'name snapshot');
    expect(order.items.single.unitPrice, 48);
    expect(order.deliveryType, DeliveryType.homeDelivery);
  });

  testWidgets('self pickup is not charged for delivery', (tester) async {
    cart.add(
      tomatoes,
      companyId: 'c_organic',
      companyName: 'GreenLeaf Organics',
      qty: 1,
    );

    await openCheckout(tester);
    await enterAddressAndPincode(tester);

    await tester.tap(find.text('Self pickup'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('checkout-place-order-button')),
    );
    await tester.tap(find.byKey(const Key('checkout-place-order-button')));
    await tester.pumpAndSettle();

    final order =
        (await repo.orders(userId: TestHarness.shopper.id).first).single;
    expect(order.deliveryCharge, 0);
    expect(order.totalAmount, 48);
    expect(order.isSelfPickup, isTrue);
  });

  testWidgets('a valid voucher reduces the total and is recorded', (
    tester,
  ) async {
    // 2 × 250 = 500 (>= the 100 minimum of FRESH20).
    await repo.saveProduct(milk.copyWith(amount: 250, discountAmt: 0));
    cart.add(
      milk.copyWith(amount: 250, discountAmt: 0),
      companyId: 'c_organic',
      companyName: 'GreenLeaf Organics',
      qty: 2,
    );

    await openCheckout(tester);
    await enterAddressAndPincode(tester);

    await tester.enterText(
      find.byKey(const Key('checkout-voucher-field-c_organic')),
      'fresh20',
    );
    await tester.tap(find.byKey(const Key('checkout-apply-c_organic')));
    await tester.pumpAndSettle();

    // 20% of 500 = 100 discount.
    expect(find.text('₹500'), findsWidgets);
    expect(find.text('− ₹100'), findsWidgets);

    await tester.ensureVisible(
      find.byKey(const Key('checkout-place-order-button')),
    );
    await tester.tap(find.byKey(const Key('checkout-place-order-button')));
    await tester.pumpAndSettle();

    final order =
        (await repo.orders(userId: TestHarness.shopper.id).first).single;
    expect(order.discountAmount, 100);
    expect(order.voucherCode, 'FRESH20');
    expect(order.totalAmount, 430, reason: '500 - 100 + 30 delivery');
    expect(order.isBalanced, isTrue);

    final voucher = (await repo.voucherByCode('c_organic', 'FRESH20'))!;
    expect(voucher.usageCount, 1);
    expect(voucher.usageFor(TestHarness.shopper.id), 1);
  });

  testWidgets('an unknown code is refused with an explanation', (tester) async {
    cart.add(
      tomatoes,
      companyId: 'c_organic',
      companyName: 'GreenLeaf Organics',
      qty: 2,
    );

    await openCheckout(tester);
    await enterAddressAndPincode(tester);

    await tester.enterText(
      find.byKey(const Key('checkout-voucher-field-c_organic')),
      'NOSUCHCODE',
    );
    await tester.tap(find.byKey(const Key('checkout-apply-c_organic')));
    await tester.pumpAndSettle();

    expect(find.text('Invalid code'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('checkout-place-order-button')),
    );
    await tester.tap(find.byKey(const Key('checkout-place-order-button')));
    await tester.pumpAndSettle();

    final order =
        (await repo.orders(userId: TestHarness.shopper.id).first).single;
    expect(order.discountAmount, 0);
    expect(order.voucherCode, isEmpty);
  });

  testWidgets('a voucher below the minimum order is refused', (tester) async {
    // Cart total 48, FRESH20 needs 100.
    cart.add(
      tomatoes,
      companyId: 'c_organic',
      companyName: 'GreenLeaf Organics',
      qty: 1,
    );

    await openCheckout(tester);
    await enterAddressAndPincode(tester);

    await tester.enterText(
      find.byKey(const Key('checkout-voucher-field-c_organic')),
      'FRESH20',
    );
    await tester.tap(find.byKey(const Key('checkout-apply-c_organic')));
    await tester.pumpAndSettle();

    expect(
      find.text('Add a few more items to use this voucher.'),
      findsOneWidget,
    );
  });

  testWidgets('another store\'s code cannot be used here', (tester) async {
    cart.add(
      phone,
      companyId: 'c_techtronics',
      companyName: 'TechTronics Hub',
      qty: 1,
    );

    await openCheckout(tester);
    await enterAddressAndPincode(tester);

    await tester.enterText(
      find.byKey(const Key('checkout-voucher-field-c_techtronics')),
      'FRESH20',
    );
    await tester.tap(find.byKey(const Key('checkout-apply-c_techtronics')));
    await tester.pumpAndSettle();

    expect(find.text('Invalid code'), findsOneWidget);
  });

  testWidgets('a free shipping voucher waives the delivery fee only', (
    tester,
  ) async {
    cart.add(
      milk,
      companyId: 'c_organic',
      companyName: 'GreenLeaf Organics',
      qty: 1,
    ); // 68

    await openCheckout(tester);
    await enterAddressAndPincode(tester);

    await tester.enterText(
      find.byKey(const Key('checkout-voucher-field-c_organic')),
      'FREESHIP',
    );
    await tester.tap(find.byKey(const Key('checkout-apply-c_organic')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('checkout-place-order-button')),
    );
    await tester.tap(find.byKey(const Key('checkout-place-order-button')));
    await tester.pumpAndSettle();

    final order =
        (await repo.orders(userId: TestHarness.shopper.id).first).single;
    expect(order.discountAmount, 0);
    expect(order.deliveryCharge, 0);
    expect(order.totalAmount, 68);
  });

  testWidgets('an expired voucher is refused', (tester) async {
    await repo.saveVoucher(
      Voucher(
        id: 'v_old',
        companyId: 'c_organic',
        code: 'OLDSCHOOL',
        discountType: VoucherType.fixedAmount,
        discountValue: 100,
        expiryDate: DateTime.now().subtract(const Duration(days: 1)),
      ),
    );
    cart.add(
      milk,
      companyId: 'c_organic',
      companyName: 'GreenLeaf Organics',
      qty: 1,
    );

    await openCheckout(tester);
    await enterAddressAndPincode(tester);

    await tester.enterText(
      find.byKey(const Key('checkout-voucher-field-c_organic')),
      'OLDSCHOOL',
    );
    await tester.tap(find.byKey(const Key('checkout-apply-c_organic')));
    await tester.pumpAndSettle();

    expect(find.text('This voucher has expired.'), findsOneWidget);
  });

  testWidgets('the address and pincode are validated before ordering', (
    tester,
  ) async {
    cart.add(
      tomatoes,
      companyId: 'c_organic',
      companyName: 'GreenLeaf Organics',
      qty: 1,
    );

    await openCheckout(tester);
    await tester.ensureVisible(
      find.byKey(const Key('checkout-place-order-button')),
    );
    await tester.tap(find.byKey(const Key('checkout-place-order-button')));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a delivery address.'), findsOneWidget);
    expect(await repo.orders(userId: TestHarness.shopper.id).first, isEmpty);

    await tester.enterText(
      find.byKey(const Key('checkout-address-field')),
      '12 Market Street',
    );
    await tester.enterText(
      find.byKey(const Key('checkout-pincode-field')),
      '38',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('checkout-place-order-button')),
    );
    await tester.tap(find.byKey(const Key('checkout-place-order-button')));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid pincode.'), findsOneWidget);
    expect(await repo.orders(userId: TestHarness.shopper.id).first, isEmpty);
  });

  testWidgets('placing an order reduces the stock', (tester) async {
    cart.add(
      tomatoes,
      companyId: 'c_organic',
      companyName: 'GreenLeaf Organics',
      qty: 5,
    );

    await openCheckout(tester);
    await enterAddressAndPincode(tester);
    await tester.ensureVisible(
      find.byKey(const Key('checkout-place-order-button')),
    );
    await tester.tap(find.byKey(const Key('checkout-place-order-button')));
    await tester.pumpAndSettle();

    expect((await repo.product('p_tomato'))!.stockQty, 115);
  });

  testWidgets('a lowercase code is accepted', (tester) async {
    await repo.saveProduct(milk.copyWith(amount: 250, discountAmt: 0));
    cart.add(
      milk.copyWith(amount: 250, discountAmt: 0),
      companyId: 'c_organic',
      companyName: 'GreenLeaf Organics',
      qty: 2,
    );

    await openCheckout(tester);
    await enterAddressAndPincode(tester);

    await tester.enterText(
      find.byKey(const Key('checkout-voucher-field-c_organic')),
      '  fresh20  ',
    );
    await tester.tap(find.byKey(const Key('checkout-apply-c_organic')));
    await tester.pumpAndSettle();

    expect(find.text('Voucher applied'), findsOneWidget);
  });
}
