import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/features/checkout/cart/cart_cubit.dart';
import 'package:myshop/features/checkout/cart/cart_screen.dart';
import 'package:myshop/features/checkout/cart/wishlist_cubit.dart';

import '../helpers/test_harness.dart';

void main() {
  late MockAppRepository repo;
  late CartCubit cart;
  late WishlistCubit wishlist;

  setUp(() {
    TestHarness.setupPlatformChannels();
    repo = TestHarness.useMockRepository();
    cart = CartCubit();
    wishlist = WishlistCubit();
  });

  /// All seeded products, straight from the repository the screen reads.
  Future<List<Product>> allProducts() => repo.products().first;

  /// Seeds the cart with one line per rule the card implements.
  Future<void> seedCart() async {
    final products = await allProducts();
    Product byId(String id) => products.firstWhere((p) => p.id == id);
    cart.add(byId('p_tomato'), companyId: 'c_organic'); // weight based
    cart.add(byId('p_milk'), companyId: 'c_organic'); // quantity based
    cart.add(byId('p_curd'), companyId: 'c_organic'); // only 3 left
  }

  /// The Dismissible card that contains [name].
  Finder rowOf(String name) =>
      find.ancestor(of: find.text(name), matching: find.byType(Dismissible));

  testWidgets('an empty cart invites shopping', (tester) async {
    await pumpTestApp(tester, const CartScreen(), user: TestHarness.shopper);

    expect(find.text('Your cart is empty'), findsOneWidget);
  });

  testWidgets('weight-based lines step in the real unit', (tester) async {
    await seedCart();
    await pumpTestApp(
      tester,
      const CartScreen(),
      user: TestHarness.shopper,
      cartCubit: cart,
      wishlistCubit: wishlist,
    );

    // One 500 g step at qty 1 shows count '1' and variant info in item details.
    expect(find.byKey(const Key('stepper-qty-p_tomato')), findsOneWidget);
    expect(find.byKey(const Key('stepper-unit-p_tomato')), findsNothing);

    // … and "Total: 1 kg" after a single increment (2 × 500 g).
    await tester.tap(
      find.descendant(
        of: rowOf('Fresh Tomatoes'),
        matching: find.byIcon(Icons.add),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Total: 1 kg'), findsOneWidget);
    expect(find.byKey(const Key('stepper-unit-p_tomato')), findsNothing);
  });

  testWidgets('quantity-based lines step in plain counts', (tester) async {
    await seedCart();
    await pumpTestApp(
      tester,
      const CartScreen(),
      user: TestHarness.shopper,
      cartCubit: cart,
      wishlistCubit: wishlist,
    );

    // Milk shows a count, not a weight.
    expect(
      find.descendant(
        of: rowOf('Organic Cow Milk'),
        matching: find.byKey(const Key('stepper-qty-p_milk')),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('stepper-unit-p_milk')), findsNothing);
  });

  testWidgets('the line subtotal updates live with the stepper', (
    tester,
  ) async {
    await seedCart();
    await pumpTestApp(
      tester,
      const CartScreen(),
      user: TestHarness.shopper,
      cartCubit: cart,
      wishlistCubit: wishlist,
    );

    // Tomatoes: ₹48 / 500 g step (from the pack snapshot).
    expect(find.text('₹48 / 500 g'), findsOneWidget);
    expect(find.text('₹48'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: rowOf('Fresh Tomatoes'),
        matching: find.byIcon(Icons.add),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('₹96'), findsOneWidget);
  });

  testWidgets('an amber stock warning appears only when stock is low', (
    tester,
  ) async {
    await seedCart();
    await pumpTestApp(
      tester,
      const CartScreen(),
      user: TestHarness.shopper,
      cartCubit: cart,
      wishlistCubit: wishlist,
    );

    // Curd has 3 left -> chip. Milk (200) and tomatoes (120) -> no chip.
    expect(find.text('Only 3 left'), findsOneWidget);
    expect(find.textContaining('Only 120'), findsNothing);
    expect(find.textContaining('Only 200'), findsNothing);
  });

  testWidgets('the small × removes exactly one line', (tester) async {
    await seedCart();
    await pumpTestApp(
      tester,
      const CartScreen(),
      user: TestHarness.shopper,
      cartCubit: cart,
      wishlistCubit: wishlist,
    );

    await tester.tap(
      find.descendant(
        of: rowOf('Set Curd (Dahi)'),
        matching: find.byIcon(Icons.close),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Set Curd (Dahi)'), findsNothing);
    expect(cart.state.items.length, 2);
  });

  testWidgets('swiping left removes the line and offers the wishlist', (
    tester,
  ) async {
    await seedCart();
    await pumpTestApp(
      tester,
      const CartScreen(),
      user: TestHarness.shopper,
      cartCubit: cart,
      wishlistCubit: wishlist,
    );

    await tester.drag(rowOf('Set Curd (Dahi)'), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text('Set Curd (Dahi)'), findsNothing);
    expect(
      cart.state.items.map((e) => e.product.id),
      isNot(contains('p_curd')),
    );

    // The snackbar offers the alternative to deleting outright.
    expect(find.text('MOVE TO WISHLIST'), findsOneWidget);
    await tester.tap(find.text('MOVE TO WISHLIST'));
    await tester.pumpAndSettle();

    expect(wishlist.state.contains('p_curd'), isTrue);
    expect(find.text('Set Curd (Dahi) saved to your wishlist'), findsOneWidget);
  });

  testWidgets('swiping reveals a red Remove action', (tester) async {
    await seedCart();
    await pumpTestApp(
      tester,
      const CartScreen(),
      user: TestHarness.shopper,
      cartCubit: cart,
      wishlistCubit: wishlist,
    );

    // Reveal the background without completing the dismiss gesture.
    final rect = tester.getRect(rowOf('Organic Cow Milk'));
    final gesture = await tester.startGesture(
      Offset(rect.right - 40, rect.center.dy),
    );
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-170, 0));
    await tester.pump();

    expect(find.text('Remove'), findsOneWidget);
    expect(find.text('Move to Wishlist?'), findsOneWidget);

    await gesture.moveBy(const Offset(200, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(cart.state.items.length, 3, reason: 'the swipe was cancelled');
  });

  testWidgets('variants keep their own line and subtext', (tester) async {
    final products = await allProducts();
    final phone = products.firstWhere((p) => p.id == 'p_phone');
    final black = phone.variants.first;

    cart.add(
      phone,
      variant: black,
      companyId: 'c_techtronics',
      companyName: 'TechTronics Hub',
    );

    await pumpTestApp(
      tester,
      const CartScreen(),
      user: TestHarness.shopper,
      cartCubit: cart,
      wishlistCubit: wishlist,
    );

    expect(find.text('Nova X5 Smartphone'), findsOneWidget);
    // Variant subtext is shown under the name.
    expect(find.text(black.title), findsOneWidget);
  });

  testWidgets('out-of-stock lines cannot be incremented', (tester) async {
    await repo.saveProduct(
      const Product(
        id: 'p_gone',
        companyId: 'c_organic',
        categoryId: 'cat_veg',
        name: 'Sold Out Kale',
        amount: 40,
        stockQty: 0,
      ),
    );
    final products = await allProducts();
    cart.add(
      products.firstWhere((p) => p.id == 'p_gone'),
      companyId: 'c_organic',
    );

    await pumpTestApp(
      tester,
      const CartScreen(),
      user: TestHarness.shopper,
      cartCubit: cart,
      wishlistCubit: wishlist,
    );

    expect(find.text('Out of stock'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: rowOf('Sold Out Kale'),
        matching: find.byIcon(Icons.add),
      ),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(cart.state.items.first.qty, 1);
  });
}
