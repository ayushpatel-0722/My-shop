import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/category.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/features/admin/categories/admin_categories_screen.dart';

import '../helpers/test_harness.dart';

void main() {
  late MockAppRepository repo;

  setUp(() {
    TestHarness.setupPlatformChannels();
    repo = TestHarness.useMockRepository();
    TestHarness.signIn(TestHarness.admin);
  });

  tearDown(() => TestHarness.signOut());

  testWidgets('lists categories with a copyable id badge', (tester) async {
    await repo.saveCategory(
      const Category(
        id: 'cat_beverages',
        companyId: 'c_organic',
        name: 'Beverages',
        type: 'Drinks',
        productList: ['p_101'],
      ),
    );

    await pumpTestApp(tester, const AdminCategoriesScreen());

    expect(find.text('Beverages'), findsOneWidget);
    expect(find.text('ID: cat_beverages'), findsOneWidget);

    await tester.tap(find.byKey(const Key('category-id-cat_beverages')));
    await tester.pumpAndSettle();
    expect(
      find.text('Category ID copied to clipboard: cat_beverages'),
      findsOneWidget,
    );
  });

  testWidgets('renders nested categories as a tree', (tester) async {
    await repo.saveCategory(
      const Category(id: 'cat_root', name: 'Root', companyId: 'c_organic'),
    );
    await repo.saveCategory(
      const Category(
        id: 'cat_kid',
        name: 'Kid',
        companyId: 'c_organic',
        parentId: 'cat_root',
      ),
    );
    await repo.saveCategory(
      const Category(
        id: 'cat_grandkid',
        name: 'GrandKid',
        companyId: 'c_organic',
        parentId: 'cat_kid',
      ),
    );

    await pumpTestApp(tester, const AdminCategoriesScreen());

    expect(find.byKey(const Key('category-tile-cat_root')), findsOneWidget);
    expect(find.byKey(const Key('category-tile-cat_kid')), findsOneWidget);
    expect(find.byKey(const Key('category-tile-cat_grandkid')), findsOneWidget);

    // The child shows where it sits in the hierarchy.
    expect(find.text('Under: Root'), findsOneWidget);
    expect(find.text('Under: Root / Kid'), findsOneWidget);
  });

  testWidgets('collapsing a parent hides its children', (tester) async {
    await repo.saveCategory(
      const Category(id: 'cat_root', name: 'Root', companyId: 'c_organic'),
    );
    await repo.saveCategory(
      const Category(
        id: 'cat_kid',
        name: 'Kid',
        companyId: 'c_organic',
        parentId: 'cat_root',
      ),
    );

    await pumpTestApp(tester, const AdminCategoriesScreen());
    expect(find.byKey(const Key('category-tile-cat_kid')), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('category-tile-cat_root')),
        matching: find.byIcon(Icons.keyboard_arrow_down),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('category-tile-cat_kid')), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('category-tile-cat_root')),
        matching: find.byIcon(Icons.keyboard_arrow_right),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('category-tile-cat_kid')), findsOneWidget);
  });

  testWidgets('product counts include sub-categories', (tester) async {
    await repo.saveCategory(
      const Category(
        id: 'cat_root',
        name: 'Root',
        companyId: 'c_organic',
        productList: ['p_1'],
      ),
    );
    await repo.saveCategory(
      const Category(
        id: 'cat_kid',
        name: 'Kid',
        companyId: 'c_organic',
        parentId: 'cat_root',
        productList: ['p_2', 'p_3'],
      ),
    );

    await pumpTestApp(tester, const AdminCategoriesScreen());

    expect(
      find.descendant(
        of: find.byKey(const Key('category-tile-cat_root')),
        matching: find.text('3 products'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('hides categories belonging to another store', (tester) async {
    await repo.saveCategory(
      const Category(
        id: 'cat_theirs',
        name: 'Theirs',
        companyId: 'c_techtronics',
      ),
    );
    await pumpTestApp(tester, const AdminCategoriesScreen());

    expect(find.byKey(const Key('category-tile-cat_theirs')), findsNothing);
  });

  testWidgets('search flattens the tree and matches names', (tester) async {
    await repo.saveCategory(
      const Category(id: 'cat_a', name: 'Alpha', companyId: 'c_organic'),
    );
    await repo.saveCategory(
      const Category(
        id: 'cat_b',
        name: 'Beta',
        companyId: 'c_organic',
        parentId: 'cat_a',
      ),
    );

    await pumpTestApp(tester, const AdminCategoriesScreen());
    await tester.enterText(
      find.byKey(const Key('category-search-field')),
      'beta',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('category-tile-cat_b')), findsOneWidget);
    expect(find.byKey(const Key('category-tile-cat_a')), findsNothing);
  });

  testWidgets('deleting warns about children and re-parents them', (
    tester,
  ) async {
    await repo.saveCategory(
      const Category(id: 'cat_root', name: 'Root', companyId: 'c_organic'),
    );
    await repo.saveCategory(
      const Category(
        id: 'cat_kid',
        name: 'Kid',
        companyId: 'c_organic',
        parentId: 'cat_root',
        productList: ['p_move'],
      ),
    );
    await repo.saveProduct(
      const Product(
        id: 'p_move',
        companyId: 'c_organic',
        categoryId: 'cat_kid',
        name: 'Mover',
      ),
    );

    await pumpTestApp(tester, const AdminCategoriesScreen());

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('category-tile-cat_kid')),
        matching: find.byIcon(Icons.delete_outline),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Delete Category'), findsOneWidget);
    expect(
      find.textContaining('1 assigned product will move to "Root"'),
      findsOneWidget,
    );

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(await repo.category('cat_kid', companyId: 'c_organic'), isNull);
    expect(
      (await repo.product('p_move'))!.categoryId,
      'cat_root',
      reason: 'the product falls back to the parent category',
    );
  });

  testWidgets('an unmatched search shows the empty filter state', (
    tester,
  ) async {
    await pumpTestApp(tester, const AdminCategoriesScreen());

    await tester.enterText(
      find.byKey(const Key('category-search-field')),
      'zzzz',
    );
    await tester.pumpAndSettle();

    expect(find.text('No categories match this search'), findsOneWidget);
  });
}
