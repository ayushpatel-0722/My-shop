import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/app_user.dart';
import 'package:myshop/core/models/cart_item.dart';
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
    TestHarness.signIn(TestHarness.shopperWithAddresses);
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

  Future<void> openCheckout(WidgetTester tester, {AppUser? user}) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await pumpTestApp(
      tester,
      const CheckoutScreen(),
      user: user ?? TestHarness.shopperWithAddresses,
      cartCubit: cart,
    );
    await tester.pumpAndSettle();
  }

  /// Selects the saved home address (12 Market Street, pincode 380001).
  /// The checkout reads saved addresses from the profile — the default one
  /// is pre-selected, the tap makes the test explicit about which is used.
  Future<void> useSavedAddress(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('address-card-addr_home')));
    await tester.tap(find.byKey(const Key('address-card-addr_home')));
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
    await useSavedAddress(tester);

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
    await useSavedAddress(tester);
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
    await useSavedAddress(tester);

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
    await useSavedAddress(tester);

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
    await useSavedAddress(tester);

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
    await useSavedAddress(tester);

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
    await useSavedAddress(tester);

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
    await useSavedAddress(tester);

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
    await useSavedAddress(tester);

    await tester.enterText(
      find.byKey(const Key('checkout-voucher-field-c_organic')),
      'OLDSCHOOL',
    );
    await tester.tap(find.byKey(const Key('checkout-apply-c_organic')));
    await tester.pumpAndSettle();

    expect(find.text('This voucher has expired.'), findsOneWidget);
  });

  testWidgets('a saved delivery address is required before ordering', (
    tester,
  ) async {
    // A profile without saved addresses cannot order with home delivery.
    TestHarness.signIn(TestHarness.shopper);
    cart.add(
      tomatoes,
      companyId: 'c_organic',
      companyName: 'GreenLeaf Organics',
      qty: 1,
    );

    await openCheckout(tester, user: TestHarness.shopper);

    // The empty state offers adding the first address.
    expect(find.byKey(const Key('empty-address-state')), findsOneWidget);
    expect(find.byKey(const Key('add-address-empty')), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('checkout-place-order-button')),
    );
    await tester.tap(find.byKey(const Key('checkout-place-order-button')));
    await tester.pumpAndSettle();

    expect(find.text('Please select a delivery address.'), findsOneWidget);
    expect(await repo.orders(userId: TestHarness.shopper.id).first, isEmpty);
    TestHarness.signIn(TestHarness.shopperWithAddresses);
  });

  testWidgets('placing an order reduces the stock', (tester) async {
    cart.add(
      tomatoes,
      companyId: 'c_organic',
      companyName: 'GreenLeaf Organics',
      qty: 5,
    );

    await openCheckout(tester);
    await useSavedAddress(tester);
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
    await useSavedAddress(tester);

    await tester.enterText(
      find.byKey(const Key('checkout-voucher-field-c_organic')),
      '  fresh20  ',
    );
    await tester.tap(find.byKey(const Key('checkout-apply-c_organic')));
    await tester.pumpAndSettle();

    expect(find.text('Voucher applied'), findsOneWidget);
  });

  testWidgets(
    'directItems checkout supports direct buy now without touching cart',
    (tester) async {
      // Leave something in the general cart
      cart.add(
        tomatoes,
        companyId: 'c_organic',
        companyName: 'GreenLeaf Organics',
        qty: 1,
      );

      // Open checkout with directItems (e.g. buying a phone directly)
      final directItem = CartItem(
        companyId: 'c_techtronics',
        companyName: 'TechTronics Hub',
        product: phone,
        qty: 1,
      );

      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await pumpTestApp(
        tester,
        CheckoutScreen(directItems: [directItem]),
        user: TestHarness.shopperWithAddresses,
        cartCubit: cart,
      );
      await useSavedAddress(tester);

      // Only the direct buy store should be shown
      expect(
        find.byKey(const Key('checkout-store-card-c_techtronics')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('checkout-store-card-c_organic')),
        findsNothing,
      );

      await tester.ensureVisible(
        find.byKey(const Key('checkout-place-order-button')),
      );
      await tester.tap(find.byKey(const Key('checkout-place-order-button')));
      await tester.pumpAndSettle();

      final orders = await repo.orders(userId: TestHarness.shopper.id).first;
      expect(orders.length, 1);
      expect(orders.first.companyId, 'c_techtronics');
      expect(orders.first.items.first.name, 'Nova X5 Smartphone');

      // General cart should remain intact!
      expect(cart.state.items.length, 1);
      expect(cart.state.items.first.product.id, 'p_tomato');
    },
  );
  testWidgets('an incomplete profile blocks the order with guidance', (
    tester,
  ) async {
    final noName = TestHarness.shopperWithAddresses.copyWith(name: '');
    TestHarness.signIn(noName);
    cart.add(
      tomatoes,
      companyId: 'c_organic',
      companyName: 'GreenLeaf Organics',
      qty: 1,
    );

    await openCheckout(tester, user: noName);
    expect(find.byKey(const Key('customer-profile-warning')), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('checkout-place-order-button')),
    );
    await tester.tap(find.byKey(const Key('checkout-place-order-button')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text(
          'Please complete your profile (name & mobile) before placing an order.',
        ),
      ),
      findsOneWidget,
    );
    expect(await repo.orders(userId: noName.id).first, isEmpty);
    TestHarness.signIn(TestHarness.shopperWithAddresses);
  });

  testWidgets('self-pickup orders carry a pickup shop and no delivery '
      'address', (tester) async {
    cart.add(
      tomatoes,
      companyId: 'c_organic',
      companyName: 'GreenLeaf Organics',
      qty: 1,
    );

    await openCheckout(tester);
    await useSavedAddress(tester);

    await tester.tap(find.text('Self pickup'));
    await tester.pumpAndSettle();

    // The pickup card replaces the shared address block for this shop.
    expect(find.byKey(const Key('pickup-shop-card')), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('checkout-place-order-button')),
    );
    await tester.tap(find.byKey(const Key('checkout-place-order-button')));
    await tester.pumpAndSettle();

    final order =
        (await repo.orders(userId: TestHarness.shopper.id).first).single;
    expect(order.deliveryType, DeliveryType.selfPickup);
    expect(order.address, isEmpty, reason: 'no delivery address on pickup');
    expect(order.pickupShop, isNotNull);
    expect(order.pickupShop!.name, 'GreenLeaf Organics');
    expect(order.customerName, 'Asha Shopper');
    expect(order.customerPhone, '9876543210');
    expect(order.orderStatus, OrderStatus.pending);
    expect(order.paymentStatus, PaymentStatus.pending);
  });

  testWidgets('home-delivery orders snapshot the customer and the address', (
    tester,
  ) async {
    cart.add(
      tomatoes,
      companyId: 'c_organic',
      companyName: 'GreenLeaf Organics',
      qty: 1,
    );

    await openCheckout(tester);
    await useSavedAddress(tester);

    await tester.ensureVisible(
      find.byKey(const Key('checkout-place-order-button')),
    );
    await tester.tap(find.byKey(const Key('checkout-place-order-button')));
    await tester.pumpAndSettle();

    final order =
        (await repo.orders(userId: TestHarness.shopper.id).first).single;
    expect(order.deliveryType, DeliveryType.homeDelivery);
    expect(
      order.address,
      TestHarness.homeAddress.formattedAddress,
      reason: 'address snapshot',
    );
    expect(order.pincode, '380001');
    expect(order.pickupShop, isNull);
    expect(order.customerName, 'Asha Shopper');
  });
}
