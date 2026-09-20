import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/category.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/features/admin/products/admin_products_screen.dart';

import '../helpers/test_harness.dart';

void main() {
  late MockAppRepository repo;

  setUp(() {
    TestHarness.setupPlatformChannels();
    repo = TestHarness.useMockRepository();
    TestHarness.signIn(TestHarness.admin);
  });

  tearDown(() => TestHarness.signOut());

  testWidgets('lists the store\'s products with an id badge', (tester) async {
    await repo.saveProduct(
      const Product(
        id: 'p_101',
        companyId: 'c_organic',
        categoryId: 'cat_1',
        name: 'Organic Honey',
        amount: 250,
        stockQty: 15,
        unitType: 'bottle',
      ),
    );

    await pumpTestApp(tester, const AdminProductsScreen());

    expect(find.text('Organic Honey'), findsOneWidget);
    expect(find.text('ID: p_101'), findsOneWidget);

    // Every row offers copy / edit / delete.
    final tile = find.byKey(const Key('product-tile-p_101'));
    expect(
      find.descendant(of: tile, matching: find.byIcon(Icons.copy_rounded)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tile, matching: find.byIcon(Icons.edit_outlined)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tile, matching: find.byIcon(Icons.delete_outline)),
      findsOneWidget,
    );
  });

  testWidgets('copies the product id to the clipboard', (tester) async {
    await repo.saveProduct(
      const Product(
        id: 'p_101',
        companyId: 'c_organic',
        categoryId: 'cat_1',
        name: 'Organic Honey',
        amount: 250,
        stockQty: 15,
      ),
    );
    await pumpTestApp(tester, const AdminProductsScreen());

    await tester.tap(find.byKey(const Key('product-id-p_101')));
    await tester.pumpAndSettle();

    expect(find.text('Product ID copied to clipboard: p_101'), findsOneWidget);
  });

  testWidgets('only shows products of the signed-in store', (tester) async {
    await pumpTestApp(tester, const AdminProductsScreen());

    expect(find.text('Fresh Tomatoes'), findsOneWidget);
    expect(
      find.text('Nova X5 Smartphone'),
      findsNothing,
      reason: 'TechTronics products must not appear',
    );
  });

  testWidgets('search filters the catalogue', (tester) async {
    await pumpTestApp(tester, const AdminProductsScreen());

    await tester.enterText(find.byKey(const Key('product-search-field')), 'tomato');
    await tester.pumpAndSettle();

    expect(find.text('Fresh Tomatoes'), findsOneWidget);
    expect(find.text('Himalayan Apples'), findsNothing);
  });

  testWidgets('an unmatched search shows the empty filter state', (tester) async {
    await pumpTestApp(tester, const AdminProductsScreen());

    await tester.enterText(find.byKey(const Key('product-search-field')), 'zzzz');
    await tester.pumpAndSettle();

    expect(find.text('No products match these filters'), findsOneWidget);
  });

  testWidgets('the sold out filter isolates out-of-stock items', (tester) async {
    await repo.saveProduct(
      const Product(
        id: 'p_soldout',
        companyId: 'c_organic',
        categoryId: 'cat_1',
        name: 'Sold Out Jam',
        amount: 120,
        stockQty: 0,
      ),
    );
    await pumpTestApp(tester, const AdminProductsScreen());

    await tester.tap(find.text('Sold out (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Sold Out Jam'), findsOneWidget);
    expect(find.text('Fresh Tomatoes'), findsNothing);
  });

  testWidgets('shows the category a product belongs to', (tester) async {
    await repo.saveCategory(
      const Category(id: 'cat_honey', name: 'Honey & Spreads', companyId: 'c_organic'),
    );
    await repo.saveProduct(
      const Product(
        id: 'p_honey',
        companyId: 'c_organic',
        categoryId: 'cat_honey',
        name: 'Wild Honey',
        amount: 300,
      ),
    );
    await pumpTestApp(tester, const AdminProductsScreen());

    expect(find.text('Honey & Spreads'), findsOneWidget);
  });

  testWidgets('deleting asks for confirmation and removes the product',
      (tester) async {
    await repo.saveProduct(
      const Product(
        id: 'p_gone',
        companyId: 'c_organic',
        categoryId: 'cat_1',
        name: 'Discontinued Tea',
        amount: 90,
      ),
    );
    await pumpTestApp(tester, const AdminProductsScreen());

    await tester.tap(find.descendant(
      of: find.byKey(const Key('product-tile-p_gone')),
      matching: find.byIcon(Icons.delete_outline),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Delete Product'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await repo.product('p_gone'), isNotNull);

    await tester.tap(find.descendant(
      of: find.byKey(const Key('product-tile-p_gone')),
      matching: find.byIcon(Icons.delete_outline),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(await repo.product('p_gone'), isNull);
  });

  testWidgets('low stock items are flagged', (tester) async {
    await repo.saveProduct(
      const Product(
        id: 'p_low',
        companyId: 'c_organic',
        categoryId: 'cat_1',
        name: 'Low Stock Oil',
        amount: 150,
        stockQty: 4,
      ),
    );
    await pumpTestApp(tester, const AdminProductsScreen());

    expect(
      find.descendant(
        of: find.byKey(const Key('product-tile-p_low')),
        matching: find.text('Low stock'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('discounted products strike through the MRP', (tester) async {
    await pumpTestApp(tester, const AdminProductsScreen());

    // Fresh Tomatoes: MRP 60, selling 48.
    expect(
      find.descendant(
        of: find.byKey(const Key('product-tile-p_tomato')),
        matching: find.text('₹48'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('product-tile-p_tomato')),
        matching: find.text('₹60'),
      ),
      findsOneWidget,
    );
  });
}
