import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myshop/app/routes/app_router.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/cart_item.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/core/models/product_addon.dart';
import 'package:myshop/features/admin/products/widgets/addons_editor.dart';
import 'package:myshop/features/checkout/cart/cart_cubit.dart';
import 'package:myshop/features/product/details/product_details_screen.dart';
import 'package:myshop/features/product/widgets/add_on_sheet.dart';

import '../helpers/test_harness.dart';

/// Product add-ons from both sides: the admin editor and the shopper's
/// bottom sheet, plus the product page wiring (sheet only when add-ons exist).
void main() {
  late MockAppRepository repo;

  setUp(() {
    TestHarness.setupPlatformChannels();
    repo = TestHarness.useMockRepository();
    TestHarness.signIn(TestHarness.shopper);
  });

  tearDown(() => TestHarness.signOut());

  const delivery = ProductAddOn(
    id: 'ao_delivery',
    title: 'Delivery to floor',
    description: 'Carried up to your floor',
    amount: 500,
    imageUrl: 'https://example.com/delivery.png',
  );
  const assembly = ProductAddOn(
    id: 'ao_assembly',
    title: 'Assembly',
    amount: 1000,
    discountAmt: 800,
  );
  const retired = ProductAddOn(
    id: 'ao_old',
    title: 'Retired service',
    amount: 300,
    isActive: false,
  );

  Product bed({
    List<ProductAddOn> addOns = const [delivery, assembly, retired],
    String selection = AddOnSelectionType.checkbox,
    String id = 'p_bed',
  }) => Product(
    id: id,
    companyId: 'c_organic',
    categoryId: 'cat_x',
    name: 'Oak Bed',
    amount: 20000,
    discountAmt: 18000,
    stockQty: 5,
    addOns: addOns,
    addOnSelection: selection,
  );

  /// Opens the sheet through [AddOnSheet.pick] and keeps what it returns.
  Future<AddOnChoice? Function()> openSheet(
    WidgetTester tester,
    Product product, {
    AddOnAction action = AddOnAction.addToCart,
    int qty = 1,
  }) async {
    AddOnChoice? result;
    var finished = false;
    await pumpTestApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const Key('open'),
              onPressed: () async {
                result = await AddOnSheet.pick(
                  context,
                  product: product,
                  qty: qty,
                  action: action,
                );
                finished = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
      user: TestHarness.shopper,
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    return () {
      expect(finished, isTrue, reason: 'pick() should have completed');
      return result;
    };
  }

  Finder option(String id) => find.byKey(Key('addon-option-$id'));
  String finalTotal(WidgetTester tester) => (tester.widget<Text>(
    find
        .descendant(
          of: find.byKey(const Key('addon-final-total')),
          matching: find.byType(Text),
        )
        .last,
  )).data!;

  group('shop sheet', () {
    testWidgets('no sheet for a product without add-ons', (tester) async {
      final result = await openSheet(tester, bed(addOns: const []));
      expect(find.byKey(const Key('addon-sheet')), findsNothing);
      expect(result()!.addOns, isEmpty);
    });

    testWidgets('no sheet when every add-on is disabled', (tester) async {
      final result = await openSheet(tester, bed(addOns: const [retired]));
      expect(find.byKey(const Key('addon-sheet')), findsNothing);
      expect(result()!.addOns, isEmpty);
    });

    testWidgets('shows summary, add-ons and price summary; hides disabled', (
      tester,
    ) async {
      await openSheet(tester, bed());
      expect(find.byKey(const Key('addon-sheet')), findsOneWidget);
      expect(find.text('Oak Bed'), findsOneWidget);
      expect(find.byKey(const Key('addon-product-price')), findsOneWidget);
      expect(find.text('Delivery to floor'), findsOneWidget);
      expect(find.text('Carried up to your floor'), findsOneWidget);
      expect(find.text('Assembly'), findsOneWidget);
      expect(find.text('Retired service'), findsNothing);
      expect(option('ao_old'), findsNothing);
      // The discounted add-on shows its price and the struck regular price.
      expect(find.text('+₹800'), findsOneWidget);
      expect(find.text('₹1,000'), findsOneWidget);
      expect(find.text('Optional: pick any'), findsOneWidget);
      expect(find.text('Add to Cart'), findsOneWidget);
    });

    testWidgets('checkbox: several can be picked and the total follows', (
      tester,
    ) async {
      await openSheet(tester, bed());
      expect(finalTotal(tester), '₹18,000');

      await tester.tap(option('ao_delivery'));
      await tester.pump();
      expect(finalTotal(tester), '₹18,500');

      await tester.tap(option('ao_assembly'));
      await tester.pump();
      expect(finalTotal(tester), '₹19,300');
      expect(find.byKey(const Key('addon-total-row')), findsOneWidget);
      expect(find.text('+₹1,300'), findsOneWidget);

      await tester.tap(option('ao_delivery'));
      await tester.pump();
      expect(finalTotal(tester), '₹18,800');

      await tester.tap(option('ao_assembly'));
      await tester.pump();
      expect(finalTotal(tester), '₹18,000');
      expect(find.byKey(const Key('addon-total-row')), findsNothing);
    });

    testWidgets('radio: only one at a time', (tester) async {
      await openSheet(tester, bed(selection: AddOnSelectionType.radio));
      expect(find.text('Optional: pick one'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(2));

      await tester.tap(option('ao_delivery'));
      await tester.pump();
      expect(finalTotal(tester), '₹18,500');
      await tester.tap(option('ao_assembly'));
      await tester.pump();
      expect(finalTotal(tester), '₹18,800');
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);

      await tester.tap(option('ao_assembly'));
      await tester.pump();
      expect(finalTotal(tester), '₹18,000');
    });

    testWidgets('quantity multiplies product and add-ons', (tester) async {
      await openSheet(tester, bed());
      await tester.tap(option('ao_assembly'));
      await tester.tap(find.byKey(const Key('addon-qty-plus')));
      await tester.pump();
      expect(finalTotal(tester), '₹37,600'); // 2 × (18000 + 800)
    });

    testWidgets('confirming returns the picked add-ons and quantity', (
      tester,
    ) async {
      final result = await openSheet(tester, bed(), qty: 2);
      await tester.tap(option('ao_delivery'));
      await tester.tap(option('ao_assembly'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('addon-confirm')));
      await tester.pumpAndSettle();

      final choice = result()!;
      expect(choice.qty, 2);
      expect(choice.addOns.map((a) => a.addOnId), [
        'ao_delivery',
        'ao_assembly',
      ]);
      expect(choice.addOns.last.price, 800);
      expect(find.byKey(const Key('addon-sheet')), findsNothing);
    });

    testWidgets('confirming with nothing ticked adds the plain product', (
      tester,
    ) async {
      final result = await openSheet(tester, bed());
      await tester.tap(find.byKey(const Key('addon-confirm')));
      await tester.pumpAndSettle();
      expect(result()!.addOns, isEmpty);
    });

    testWidgets('dismissing the sheet returns nothing', (tester) async {
      final result = await openSheet(tester, bed());
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(result(), isNull);
    });

    testWidgets('the buy flow labels the action Continue to buy', (
      tester,
    ) async {
      await openSheet(tester, bed(), action: AddOnAction.buyNow);
      expect(find.text('Continue to buy'), findsOneWidget);
      expect(find.text('Add to Cart'), findsNothing);
    });

    testWidgets('an add-on without an image renders fine', (tester) async {
      await openSheet(tester, bed(addOns: const [assembly]));
      expect(find.text('Assembly'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a free add-on says Free', (tester) async {
      await openSheet(
        tester,
        bed(
          addOns: const [
            ProductAddOn(id: 'ao_pick', title: 'Store pickup', amount: 0),
          ],
        ),
      );
      expect(find.text('Free'), findsOneWidget);
    });
  });

  group('admin editor', () {
    Future<void> pumpEditor(
      WidgetTester tester, {
      List<ProductAddOn> initial = const [],
      String selection = AddOnSelectionType.checkbox,
      void Function(String)? onSelection,
    }) async {
      var current = List<ProductAddOn>.of(initial);
      var sel = selection;
      late StateSetter rebuild;
      await pumpTestApp(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return AddOnsEditor(
                  addOns: current,
                  selectionType: sel,
                  onChanged: (l) => rebuild(() => current = l),
                  onSelectionChanged: (v) {
                    onSelection?.call(v);
                    rebuild(() => sel = v);
                  },
                );
              },
            ),
          ),
        ),
        user: TestHarness.admin,
      );
    }

    testWidgets('empty state and checkbox is the default selection', (
      tester,
    ) async {
      await pumpEditor(tester);
      expect(find.byKey(const Key('addons-empty')), findsOneWidget);
      final seg = tester.widget<SegmentedButton<String>>(
        find.byKey(const Key('addon-selection-type')),
      );
      expect(seg.selected, {AddOnSelectionType.checkbox});
    });

    testWidgets('adds an add-on through the dialog', (tester) async {
      await pumpEditor(tester);
      await tester.tap(find.byKey(const Key('addon-add-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('addon-title-field')),
        'Assembly',
      );
      await tester.enterText(
        find.byKey(const Key('addon-description-field')),
        'By our team',
      );
      await tester.enterText(
        find.byKey(const Key('addon-price-field')),
        '1000',
      );
      await tester.enterText(
        find.byKey(const Key('addon-discount-field')),
        '800',
      );
      await tester.tap(find.byKey(const Key('addon-save-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('addons-empty')), findsNothing);
      expect(find.text('Assembly'), findsOneWidget);
      expect(find.text('₹800'), findsOneWidget);
      expect(find.text('₹1,000'), findsOneWidget);
    });

    testWidgets('the dialog validates title, price, discount and image', (
      tester,
    ) async {
      await pumpEditor(tester);
      await tester.tap(find.byKey(const Key('addon-add-button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('addon-save-button')));
      await tester.pumpAndSettle();
      expect(find.text('Enter a title for the add-on.'), findsOneWidget);
      expect(find.text('Enter a valid price (0 or more).'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('addon-title-field')), 'X');
      await tester.enterText(find.byKey(const Key('addon-price-field')), '100');
      await tester.enterText(
        find.byKey(const Key('addon-discount-field')),
        '100',
      );
      await tester.enterText(
        find.byKey(const Key('addon-image-field')),
        'not-a-url',
      );
      await tester.tap(find.byKey(const Key('addon-save-button')));
      await tester.pumpAndSettle();
      expect(
        find.text('The discounted price must be lower than the price.'),
        findsOneWidget,
      );
      expect(find.text('Image must be an http or https link.'), findsOneWidget);
      // Nothing was saved: the dialog is still open.
      expect(find.byKey(const Key('addon-save-button')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('addon-price-field')), '-5');
      await tester.tap(find.byKey(const Key('addon-save-button')));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid price (0 or more).'), findsOneWidget);
    });

    testWidgets('edit, disable and remove existing add-ons', (tester) async {
      await pumpEditor(tester, initial: const [delivery, assembly]);
      expect(find.byKey(const Key('addon-tile-ao_delivery')), findsOneWidget);

      await tester.tap(find.byKey(const Key('addon-active-ao_delivery')));
      await tester.pumpAndSettle();
      expect(find.text('Disabled'), findsOneWidget);

      await tester.tap(find.byKey(const Key('addon-edit-ao_assembly')));
      await tester.pumpAndSettle();
      // The dialog loads what was saved.
      expect(find.widgetWithText(TextFormField, 'Assembly'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('addon-title-field')),
        'Full assembly',
      );
      await tester.tap(find.byKey(const Key('addon-save-button')));
      await tester.pumpAndSettle();
      expect(find.text('Full assembly'), findsOneWidget);

      await tester.tap(find.byKey(const Key('addon-remove-ao_delivery')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('addon-tile-ao_delivery')), findsNothing);
      expect(find.byKey(const Key('addon-tile-ao_assembly')), findsOneWidget);
    });

    testWidgets('a duplicate title is refused', (tester) async {
      await pumpEditor(tester, initial: const [assembly]);
      await tester.tap(find.byKey(const Key('addon-add-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('addon-title-field')),
        'assembly',
      );
      await tester.enterText(find.byKey(const Key('addon-price-field')), '10');
      await tester.tap(find.byKey(const Key('addon-save-button')));
      await tester.pumpAndSettle();
      expect(find.text('Two add-ons have the same title.'), findsOneWidget);
    });

    testWidgets('switching to radio reports the new selection type', (
      tester,
    ) async {
      String? seen;
      await pumpEditor(tester, onSelection: (v) => seen = v);
      await tester.tap(find.text('Radio: only one'));
      await tester.pumpAndSettle();
      expect(seen, AddOnSelectionType.radio);
      final seg = tester.widget<SegmentedButton<String>>(
        find.byKey(const Key('addon-selection-type')),
      );
      expect(seg.selected, {AddOnSelectionType.radio});
    });
  });

  group('product page', () {
    Future<CartCubit> openDetails(WidgetTester tester, Product p) async {
      await repo.saveProduct(p);
      final cart = CartCubit();
      await pumpTestApp(
        tester,
        ProductDetailsScreen(productId: p.id),
        user: TestHarness.shopper,
        cartCubit: cart,
      );
      await tester.pumpAndSettle();
      return cart;
    }

    testWidgets('Add to Cart opens the sheet and adds the chosen add-ons', (
      tester,
    ) async {
      final cart = await openDetails(tester, bed());
      final btn = find.byKey(const Key('desktop-add-to-cart-btn'));
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('addon-sheet')), findsOneWidget);
      expect(cart.state.items, isEmpty, reason: 'nothing is added yet');

      await tester.tap(option('ao_assembly'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('addon-confirm')));
      await tester.pumpAndSettle();

      final line = cart.state.items.single;
      expect(line.addOns.map((a) => a.addOnId), ['ao_assembly']);
      expect(line.lineTotal, 18800);
    });

    testWidgets('dismissing the sheet adds nothing', (tester) async {
      final cart = await openDetails(tester, bed());
      final btn = find.byKey(const Key('desktop-add-to-cart-btn'));
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(cart.state.items, isEmpty);
    });

    testWidgets('Buy Now asks for add-ons, then opens checkout with them', (
      tester,
    ) async {
      final p = bed();
      await repo.saveProduct(p);
      final cart = CartCubit();
      tester.view.physicalSize = const Size(1600, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      // Stand-in checkout route: shows what the product page handed over.
      await tester.pumpWidget(
        buildTestApp(
          ProductDetailsScreen(productId: p.id),
          user: TestHarness.shopper,
          cartCubit: cart,
          size: const Size(1600, 2400),
          extraRoutes: [
            GoRoute(
              path: AppRoutes.checkout,
              builder: (context, state) {
                final item = state.extra as CartItem;
                return Scaffold(
                  body: Text(
                    'DIRECT ${item.qty} '
                    '${item.addOns.map((a) => a.title).join('+')} '
                    '${item.lineTotal}',
                  ),
                );
              },
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final btn = find.byKey(const Key('desktop-buy-now-btn'));
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();
      expect(find.text('Continue to buy'), findsOneWidget);

      await tester.tap(option('ao_assembly'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('addon-confirm')));
      await tester.pumpAndSettle();

      expect(find.text('DIRECT 1 Assembly 18800.0'), findsOneWidget);
      expect(cart.state.items, isEmpty, reason: 'Buy Now skips the cart');
    });

    testWidgets('a product without add-ons adds straight away', (tester) async {
      final cart = await openDetails(tester, bed(addOns: const []));
      final btn = find.byKey(const Key('desktop-add-to-cart-btn'));
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('addon-sheet')), findsNothing);
      expect(cart.state.items.single.addOns, isEmpty);
      expect(cart.state.items.single.lineTotal, 18000);
    });

    testWidgets('the same product with different add-ons makes two rows', (
      tester,
    ) async {
      final cart = await openDetails(tester, bed());
      final btn = find.byKey(const Key('desktop-add-to-cart-btn'));
      await tester.ensureVisible(btn);

      await tester.tap(btn);
      await tester.pumpAndSettle();
      await tester.tap(option('ao_delivery'));
      await tester.tap(find.byKey(const Key('addon-confirm')));
      await tester.pumpAndSettle();

      await tester.tap(btn);
      await tester.pumpAndSettle();
      await tester.tap(option('ao_assembly'));
      await tester.tap(find.byKey(const Key('addon-confirm')));
      await tester.pumpAndSettle();

      expect(cart.state.items.length, 2);
      expect(cart.state.totalAmount, 18500 + 18800);
    });
  });
}
