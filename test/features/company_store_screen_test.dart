import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/order.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/features/checkout/cart/cart_cubit.dart';
import 'package:myshop/features/marketplace/company_store/company_store_screen.dart';

import '../helpers/test_harness.dart';

void main() {
  late MockAppRepository repo;

  setUp(() {
    TestHarness.setupPlatformChannels();
    repo = TestHarness.useMockRepository();
  });

  Future<void> pumpStore(
    WidgetTester tester, {
    CartCubit? cartCubit,
    String slug = 'greenleaf-organics',
  }) => pumpTestApp(
    tester,
    CompanyStoreScreen(slug: slug),
    user: TestHarness.shopper,
    cartCubit: cartCubit,
    // Tall frame so every shelf, trending and the grid are all built by
    // the lazy ListView in one frame.
    size: const Size(430, 6000),
  );

  testWidgets('shop details: logo, verified badge, rating, followers, pill', (
    tester,
  ) async {
    await pumpStore(tester);

    expect(find.byKey(const Key('store-logo')), findsOneWidget);
    expect(find.byKey(const Key('verified-badge')), findsOneWidget);
    expect(find.byKey(const Key('open-closed-pill')), findsOneWidget);

    // Real review data: one seeded 5-star review for GreenLeaf.
    expect(find.text('5.0'), findsOneWidget);
    expect(find.textContaining('1 review'), findsOneWidget);

    // Follower count comes from the company record.
    expect(find.text('128 followers'), findsOneWidget);
  });

  testWidgets('an unverified store shows no verified badge', (tester) async {
    await pumpStore(tester, slug: 'techtronics-hub');

    expect(find.byKey(const Key('verified-badge')), findsNothing);
    expect(find.text('42 followers'), findsOneWidget);
  });

  testWidgets('the offer carousel promotes this store\'s own vouchers', (
    tester,
  ) async {
    await pumpStore(tester);

    expect(find.byKey(const Key('store-banner-carousel')), findsOneWidget);
    expect(find.text('SPECIAL OFFER'), findsOneWidget);
    expect(find.textContaining('Use Code: FRESH20'), findsOneWidget);
  });

  testWidgets('one shelf per category, each with a See All link', (
    tester,
  ) async {
    await pumpStore(tester);

    // GreenLeaf sells in exactly these three categories.
    expect(find.byKey(const Key('store-shelf-cat_veg')), findsOneWidget);
    expect(find.byKey(const Key('store-shelf-cat_fruit')), findsOneWidget);
    expect(find.byKey(const Key('store-shelf-cat_dairy')), findsOneWidget);
    expect(
      find.byKey(const Key('store-shelf-cat_phone')),
      findsNothing,
      reason: 'another store\'s category must not get a shelf here',
    );

    for (final id in ['cat_veg', 'cat_fruit', 'cat_dairy']) {
      expect(find.byKey(Key('shelf-see-all-$id')), findsOneWidget);
    }

    // The shelf headers carry the category names.
    expect(find.text('Vegetables'), findsOneWidget);
    expect(find.text('Fruits'), findsOneWidget);
    expect(find.text('Dairy & Eggs'), findsOneWidget);
  });

  testWidgets('shelves with few products stay shelves', (tester) async {
    // Fruit has exactly two products — it must not collapse into All Products.
    await pumpStore(tester);

    final fruitShelf = find.byKey(const Key('store-shelf-cat_fruit'));
    expect(
      find.descendant(of: fruitShelf, matching: find.text('Himalayan Apples')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: fruitShelf, matching: find.text('Robusta Bananas')),
      findsOneWidget,
    );
  });

  testWidgets('See All opens the category explorer scoped to this store', (
    tester,
  ) async {
    await pumpStore(tester);

    await tester.tap(find.byKey(const Key('shelf-see-all-cat_veg')));
    await tester.pumpAndSettle();

    expect(find.text('Category cat_veg'), findsOneWidget);
  });

  testWidgets('trending shelf renders with the fire icon', (tester) async {
    await pumpStore(tester);

    expect(find.byKey(const Key('trending-shelf')), findsOneWidget);
    expect(find.text('Trending Now'), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
  });

  testWidgets('trending is driven by this store\'s order velocity', (
    tester,
  ) async {
    // Milk bought three times, tomatoes once.
    for (var i = 0; i < 3; i++) {
      await repo.placeOrder(
        Order(
          id: '',
          userId: 'u_$i',
          companyId: 'c_organic',
          companyName: 'GreenLeaf Organics',
          items: const [
            OrderItem(
              productId: 'p_milk',
              qty: 2,
              unitPrice: 68,
              name: 'Organic Cow Milk',
            ),
          ],
        ),
      );
    }
    await repo.placeOrder(
      Order(
        id: '',
        userId: 'u_milk_2',
        companyId: 'c_organic',
        companyName: 'GreenLeaf Organics',
        items: const [
          OrderItem(
            productId: 'p_tomato',
            qty: 1,
            unitPrice: 48,
            name: 'Fresh Tomatoes',
          ),
        ],
      ),
    );

    await pumpStore(tester);

    final trending = find.byKey(const Key('trending-shelf'));
    expect(
      find.descendant(of: trending, matching: find.text('Organic Cow Milk')),
      findsOneWidget,
      reason: 'the most-ordered product leads the rail',
    );
    // Orders from *this* store only: no TechTronics products on the rail.
    expect(
      find.descendant(of: trending, matching: find.text('Nova X5 Smartphone')),
      findsNothing,
    );
  });

  testWidgets('all products grid with Price / Rating / In-Stock pills', (
    tester,
  ) async {
    await pumpStore(tester);

    expect(find.text('All Products (5)'), findsOneWidget);
    expect(find.byKey(const Key('all-products-grid')), findsOneWidget);
    expect(find.byKey(const Key('filter-pill-price')), findsOneWidget);
    expect(find.byKey(const Key('filter-pill-rating')), findsOneWidget);
    expect(find.byKey(const Key('filter-pill-instock')), findsOneWidget);
  });

  testWidgets('the in-stock pill hides sold-out products', (tester) async {
    await repo.saveProduct(
      const Product(
        id: 'p_sold',
        companyId: 'c_organic',
        categoryId: 'cat_veg',
        name: 'Sold Out Kale',
        amount: 40,
        stockQty: 0,
      ),
    );

    await pumpStore(tester);
    final grid = find.byKey(const Key('all-products-grid'));
    expect(find.text('All Products (6)'), findsOneWidget);
    expect(
      find.descendant(of: grid, matching: find.text('Sold Out Kale')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('filter-pill-instock')));
    await tester.pumpAndSettle();

    expect(find.text('All Products (5)'), findsOneWidget);
    expect(
      find.descendant(of: grid, matching: find.text('Sold Out Kale')),
      findsNothing,
    );
    // Shelves keep showing sold-out items (with an "Out of stock" veil).
    expect(find.text('Sold Out Kale'), findsOneWidget);
  });

  testWidgets('the price pill cycles ascending then descending', (
    tester,
  ) async {
    await pumpStore(tester);

    expect(find.text('Price'), findsOneWidget);

    await tester.tap(find.byKey(const Key('filter-pill-price')));
    await tester.pumpAndSettle();
    expect(find.text('Price ↑'), findsOneWidget);

    await tester.tap(find.byKey(const Key('filter-pill-price')));
    await tester.pumpAndSettle();
    expect(find.text('Price ↓'), findsOneWidget);
  });

  testWidgets('the follow button toggles and bumps the follower count', (
    tester,
  ) async {
    await pumpStore(tester);

    expect(find.text('+ Follow'), findsOneWidget);

    await tester.tap(find.byKey(const Key('follow-button')));
    await tester.pumpAndSettle();

    expect(find.text('✓ Following'), findsOneWidget);
    expect(find.text('129 followers'), findsOneWidget);
  });

  testWidgets('the app-bar search is scoped to this store', (tester) async {
    await pumpStore(tester);

    await tester.tap(find.byIcon(Icons.search).first);
    await tester.pumpAndSettle();

    expect(find.text('Search companyId=c_organic'), findsOneWidget);
  });

  testWidgets('the rating row opens the reviews screen', (tester) async {
    await pumpStore(tester);

    await tester.tap(find.byKey(const Key('store-rating-row')));
    await tester.pumpAndSettle();
    expect(find.text('Reviews c_organic'), findsOneWidget);
  });

  testWidgets('the app-bar reviews icon opens the reviews screen', (
    tester,
  ) async {
    await pumpStore(tester);

    await tester.tap(find.byIcon(Icons.rate_review_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Reviews c_organic'), findsOneWidget);
  });

  testWidgets('quick-add puts the product in the cart and badges the icon', (
    tester,
  ) async {
    final cart = CartCubit();
    await pumpStore(tester, cartCubit: cart);

    final vegShelf = find.byKey(const Key('store-shelf-cat_veg'));
    await tester.tap(
      find.descendant(of: vegShelf, matching: find.byIcon(Icons.add)).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Fresh Tomatoes added to cart'), findsOneWidget);
    expect(cart.state.items.single.product.id, 'p_tomato');
    expect(cart.state.items.single.qty, 1);
  });

  testWidgets(
    'product grid columns scale up with screen width keeping card width <= 250',
    (tester) async {
      // Test on tablet/wide viewport (width 1000)
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await pumpStore(tester);

      final gridFinder = find.byKey(const Key('all-products-grid'));
      expect(gridFinder, findsOneWidget);

      final gridWidget = tester.widget<GridView>(gridFinder);
      final delegate =
          gridWidget.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

      // Available width is 1000 - 32 = 968.
      // ((968 + 12) / (250 + 12)).ceil() = ceil(980 / 262) = 4 columns.
      expect(delegate.crossAxisCount, 4);

      final cardWidth = (968 - (4 - 1) * 12) / 4;
      expect(cardWidth, lessThanOrEqualTo(250.0));
    },
  );
}
