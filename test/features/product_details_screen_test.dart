import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/features/checkout/cart/cart_cubit.dart';
import 'package:myshop/features/checkout/cart/wishlist_cubit.dart';
import 'package:myshop/features/product/details/product_details_screen.dart';

import '../helpers/test_harness.dart';

/// U2 — Product Details layout.
///
/// image carousel → name → price (selling, MRP strike, discount%) → stock
/// label → SKU → Select Variant → qty → Highlights → All Details → bottom
/// bar. Highlights / All Details are collapsible accordions (collapsed by
/// default, several may stay open, empty blocks are hidden).
void main() {
  late MockAppRepository repo;

  setUp(() {
    TestHarness.setupPlatformChannels();
    repo = TestHarness.useMockRepository();
    TestHarness.signIn(TestHarness.shopper);
  });

  tearDown(() => TestHarness.signOut());

  const variantProduct = Product(
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
    sku: 'RICE-BASE',
    images: ['https://example.com/rice.jpg'],
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
        stockQty: 2,
      ),
      ProductVariant(
        sku: 'RICE-1KG',
        title: '1kg',
        unitValue: 1000,
        unitType: 'grams',
        priceOverride: 500,
        mrpOverride: 550,
        stockQty: 0,
      ),
    ],
    highlights: [
      HighlightItem(title: 'Grain', value: 'Basmati', order: 0),
      HighlightItem(title: 'Aging', value: '2 years', order: 1),
    ],
    allDetails: [
      DetailSection(
        title: 'Description',
        type: DetailSectionType.text,
        text:
            'Long grain aromatic rice. Sourced from the foothills and aged '
            'to perfection for a fluffy texture and a fragrant aroma that '
            'pairs beautifully with curries, biryani and pulao. This is a '
            'long paragraph used to exercise the Read more affordance of '
            'the expandable text widget on the details page.',
        order: 0,
      ),
      DetailSection(
        title: 'Specifications',
        type: DetailSectionType.keyValue,
        items: [
          DetailItem(title: 'Shelf Life', value: '12 Months'),
          DetailItem(title: 'Storage', value: 'Cool & dry place'),
        ],
        order: 1,
      ),
      DetailSection(
        title: 'Country of Origin',
        type: DetailSectionType.text,
        text: 'India',
        order: 2,
      ),
    ],
  );

  Future<void> pumpDetails(WidgetTester tester, String productId) =>
      pumpTestApp(
        tester,
        ProductDetailsScreen(productId: productId),
        user: TestHarness.shopper,
        cartCubit: CartCubit(),
        wishlistCubit: WishlistCubit(),
      );

  testWidgets('layout stacks name, price, stock, SKU, variants, then content', (
    tester,
  ) async {
    await repo.saveProduct(variantProduct);
    await pumpDetails(tester, 'p_rice');

    double yOf(Finder f) => tester.getTopLeft(f).dy;

    final name = find.text('Premium Basmati Rice');
    final price = find.byKey(const Key('product-price'));
    final stock = find.byKey(const Key('stock-label'));
    final sku = find.byKey(const Key('product-sku'));
    final variants = find.text('Select Variant');
    final highlights = find.byKey(const Key('collapsible-toggle-Highlights'));

    expect(name, findsOneWidget);
    expect(price, findsOneWidget);
    expect(stock, findsOneWidget);
    expect(sku, findsOneWidget);
    expect(variants, findsOneWidget);

    await tester.ensureVisible(highlights);
    await tester.pumpAndSettle();

    expect(yOf(name), lessThan(yOf(price)), reason: 'name above price');
    expect(yOf(price), lessThan(yOf(stock)), reason: 'price above stock label');
    expect(yOf(stock), lessThan(yOf(sku)), reason: 'stock above SKU');
    expect(yOf(sku), lessThan(yOf(variants)), reason: 'SKU above Select Variant');
    expect(
      yOf(variants),
      lessThan(yOf(find.byKey(const Key('collapsible-toggle-Highlights')))),
      reason: 'variants above Highlights',
    );
  });

  testWidgets('price row shows selling, MRP strike and discount %', (
    tester,
  ) async {
    await repo.saveProduct(variantProduct);
    await pumpDetails(tester, 'p_rice');

    // Default variant is 1 kg (matches the product pack): ₹500 from ₹550.
    expect(
      find.descendant(
        of: find.byKey(const Key('product-price')),
        matching: find.text('₹500'),
      ),
      findsOneWidget,
    );
    expect(find.text('₹550'), findsOneWidget, reason: 'MRP strikethrough');
    expect(find.text('9% OFF'), findsOneWidget);
  });

  testWidgets('stock label reflects the selected variant', (tester) async {
    await repo.saveProduct(variantProduct);
    await pumpDetails(tester, 'p_rice');

    // 1 kg pack is out of stock (stockQty 0) and preselected.
    expect(find.text('Out of Stock'), findsWidgets);
    final outOfStock = find.descendant(
      of: find.byKey(const Key('stock-label')),
      matching: find.text('Out of Stock'),
    );
    expect(outOfStock, findsOneWidget);

    // 500g has only 2 left -> orange-style low-stock wording.
    await tester.tap(find.byKey(const Key('variant-chip-1')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('stock-label')),
        matching: find.text('Only 2 left'),
      ),
      findsOneWidget,
    );

    // 250g is comfortably in stock.
    await tester.tap(find.byKey(const Key('variant-chip-0')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('stock-label')),
        matching: find.text('In Stock'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('variant change updates price and SKU live', (tester) async {
    await repo.saveProduct(variantProduct);
    await pumpDetails(tester, 'p_rice');

    expect(find.text('SKU: RICE-1KG'), findsOneWidget);
    expect(find.text('₹500'), findsWidgets);

    await tester.tap(find.byKey(const Key('variant-chip-1'))); // 500g
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('product-sku')),
        matching: find.text('SKU: RICE-500'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('product-price')),
        matching: find.text('₹300'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('out-of-stock variants disable Add to Cart and Buy Now', (
    tester,
  ) async {
    await repo.saveProduct(variantProduct);
    await pumpDetails(tester, 'p_rice');

    // The preselected 1 kg variant is out of stock.
    final addBtn = find.widgetWithText(OutlinedButton, 'Out of Stock');
    final buyBtn = find.widgetWithText(FilledButton, 'Buy Now');
    expect(addBtn, findsOneWidget, reason: 'label flips to Out of Stock');
    expect(
      tester.widget<OutlinedButton>(addBtn).onPressed,
      isNull,
      reason: 'Add to Cart disabled',
    );
    expect(
      tester.widget<FilledButton>(buyBtn).onPressed,
      isNull,
      reason: 'Buy Now disabled',
    );

    // Picking an in-stock variant re-enables both.
    await tester.tap(find.byKey(const Key('variant-chip-0')));
    await tester.pumpAndSettle();

    final liveAdd = find.widgetWithText(OutlinedButton, 'Add to Cart');
    expect(liveAdd, findsOneWidget);
    expect(tester.widget<OutlinedButton>(liveAdd).onPressed, isNotNull);
    expect(tester.widget<FilledButton>(buyBtn).onPressed, isNotNull);
  });

  testWidgets('highlights and details accordions start collapsed and stack', (
    tester,
  ) async {
    await repo.saveProduct(variantProduct);
    await pumpDetails(tester, 'p_rice');

    final highlightsToggle = find.byKey(const Key('collapsible-toggle-Highlights'));
    await tester.ensureVisible(highlightsToggle);
    await tester.pumpAndSettle();

    // Collapsed: the rows are not built yet.
    expect(find.text('Basmati'), findsNothing);

    await tester.tap(highlightsToggle);
    await tester.pumpAndSettle();
    expect(find.text('Basmati'), findsOneWidget);
    expect(find.text('Aging'), findsOneWidget);

    // Multiple sections can stay open together.
    final descToggle = find.byKey(const Key('collapsible-toggle-Description'));
    await tester.ensureVisible(descToggle);
    await tester.tap(descToggle);
    await tester.pumpAndSettle();

    expect(find.text('Basmati'), findsOneWidget, reason: 'highlights still open');
    expect(find.text('India'), findsNothing, reason: 'third section capped at 2');
  });

  testWidgets('keyValue sections render a table, text sections use Read more', (
    tester,
  ) async {
    await repo.saveProduct(variantProduct);
    await pumpDetails(tester, 'p_rice');

    final descToggle = find.byKey(const Key('collapsible-toggle-Description'));
    await tester.ensureVisible(descToggle);
    await tester.tap(descToggle);
    await tester.pumpAndSettle();

    // Long paragraph exposes the Read more affordance.
    expect(find.byKey(const Key('expandable-read-more')), findsOneWidget);
    await tester.tap(find.byKey(const Key('expandable-read-more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('expandable-read-less')), findsOneWidget);

    final specsToggle = find.byKey(
      const Key('collapsible-toggle-Specifications'),
    );
    await tester.ensureVisible(specsToggle);
    await tester.tap(specsToggle);
    await tester.pumpAndSettle();

    expect(find.text('Shelf Life'), findsOneWidget);
    expect(find.text('12 Months'), findsOneWidget);
    expect(find.text('Storage'), findsOneWidget);
    expect(find.text('Cool & dry place'), findsOneWidget);
  });

  testWidgets('more than two detail sections collapse behind View more', (
    tester,
  ) async {
    await repo.saveProduct(variantProduct);
    await pumpDetails(tester, 'p_rice');

    final viewMore = find.byKey(const Key('view-more-details'));
    await tester.ensureVisible(viewMore);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('collapsible-toggle-Description')), findsOneWidget);
    expect(
      find.byKey(const Key('collapsible-toggle-Specifications')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('collapsible-toggle-Country of Origin')),
      findsNothing,
    );

    await tester.tap(viewMore);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('collapsible-toggle-Country of Origin')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('view-less-details')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('collapsible-toggle-Country of Origin')),
      findsNothing,
    );
  });

  testWidgets('legacy description and highlights strings still render', (
    tester,
  ) async {
    await repo.saveProduct(
      const Product(
        id: 'p_legacy',
        companyId: 'c_organic',
        categoryId: 'cat_x',
        name: 'Legacy Jam',
        amount: 120,
        details: 'Handmade strawberry jam in a glass jar.',
        subDetails: 'No preservatives\nSmall batches',
      ),
    );
    await pumpDetails(tester, 'p_legacy');

    final highlightsToggle = find.byKey(const Key('collapsible-toggle-Highlights'));
    await tester.ensureVisible(highlightsToggle);
    await tester.tap(highlightsToggle);
    await tester.pumpAndSettle();

    expect(find.text('No preservatives\nSmall batches'), findsOneWidget);

    final descToggle = find.byKey(const Key('collapsible-toggle-Description'));
    await tester.ensureVisible(descToggle);
    await tester.tap(descToggle);
    await tester.pumpAndSettle();

    expect(
      find.text('Handmade strawberry jam in a glass jar.'),
      findsOneWidget,
    );
  });

  testWidgets('a bare product with missing fields does not crash', (
    tester,
  ) async {
    await repo.saveProduct(
      const Product(
        id: 'p_bare',
        companyId: 'c_organic',
        categoryId: 'cat_x',
        name: 'Bare Product',
      ),
    );
    await pumpDetails(tester, 'p_bare');

    expect(find.text('Bare Product'), findsOneWidget);
    expect(find.text('Highlights'), findsNothing, reason: 'empty blocks hidden');
    expect(find.text('Description'), findsNothing);
  });

  testWidgets('Add to Cart carries the selected variant snapshot', (
    tester,
  ) async {
    await repo.saveProduct(variantProduct);
    final cart = CartCubit();
    await pumpTestApp(
      tester,
      const ProductDetailsScreen(productId: 'p_rice'),
      user: TestHarness.shopper,
      cartCubit: cart,
      wishlistCubit: WishlistCubit(),
    );

    await tester.tap(find.byKey(const Key('variant-chip-1'))); // 500g
    await tester.pumpAndSettle();

    final addBtn = find.widgetWithText(OutlinedButton, 'Add to Cart');
    await tester.ensureVisible(addBtn);
    await tester.tap(addBtn);
    await tester.pumpAndSettle();

    expect(find.text('Premium Basmati Rice (500g) added to cart'), findsOneWidget);
    expect(cart.state.items.single.variant?.variantId, 'RICE-500');
    expect(cart.state.items.single.effectivePrice, 300);
  });
}
