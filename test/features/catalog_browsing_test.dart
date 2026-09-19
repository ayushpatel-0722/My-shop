import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/category.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/features/marketplace/categories/categories_screen.dart';
import 'package:myshop/features/marketplace/category_view/category_view_screen.dart';

import '../helpers/test_harness.dart';

void main() {
  late MockAppRepository repo;

  setUp(() {
    TestHarness.setupPlatformChannels();
    repo = TestHarness.useMockRepository();
  });

  group('Store front categories', () {
    testWidgets('shows top level categories only', (tester) async {
      await repo.saveCategory(
        const Category(id: 'cat_root', name: 'Root', companyId: 'c_organic'),
      );
      await repo.saveCategory(
        const Category(
          id: 'cat_child',
          name: 'Child',
          companyId: 'c_organic',
          parentId: 'cat_root',
        ),
      );

      await pumpTestApp(tester, const CategoriesScreen());

      expect(find.text('Root'), findsOneWidget);
      expect(
        find.text('Child'),
        findsNothing,
        reason: 'sub-categories are reached through their parent',
      );
    });

    testWidgets('shows real store data instead of invented ratings',
        (tester) async {
      await pumpTestApp(tester, const CategoriesScreen());

      expect(find.text('GreenLeaf Organics'), findsWidgets);
      expect(
        find.text('4.8'),
        findsNothing,
        reason: 'ratings used to be hard-coded per row',
      );
      expect(
        find.text('Up to 40% OFF'),
        findsNothing,
        reason: 'fake offers must not be shown',
      );
    });
  });

  group('Category view', () {
    testWidgets('lists the products filed under the category', (tester) async {
      await pumpTestApp(
        tester,
        const CategoryViewScreen(categoryId: 'cat_veg', categoryName: 'Vegetables'),
      );

      expect(find.text('Fresh Tomatoes'), findsOneWidget);
      expect(find.text('Baby Spinach'), findsOneWidget);
      expect(find.text('Nova X5 Smartphone'), findsNothing);
      expect(find.textContaining('2 products'), findsOneWidget);
    });

    testWidgets('includes the products of sub-categories', (tester) async {
      await repo.saveCategory(
        const Category(id: 'cat_all', name: 'All', companyId: 'c_organic'),
      );
      await repo.saveCategory(
        const Category(
          id: 'cat_veg',
          name: 'Vegetables',
          companyId: 'c_organic',
          parentId: 'cat_all',
        ),
      );

      await pumpTestApp(
        tester,
        const CategoryViewScreen(categoryId: 'cat_all', categoryName: 'All'),
      );

      expect(
        find.text('Fresh Tomatoes'),
        findsOneWidget,
        reason: 'the child category\'s products belong to the parent too',
      );
    });

    testWidgets('an empty category is distinguished from a loading one',
        (tester) async {
      await pumpTestApp(
        tester,
        const CategoryViewScreen(categoryId: 'cat_empty', categoryName: 'Empty'),
      );

      expect(find.text('No products in this category'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('the in-stock switch hides sold out products', (tester) async {
      await repo.saveProduct(
        const Product(
          id: 'p_sold',
          companyId: 'c_organic',
          categoryId: 'cat_veg',
          name: 'Sold Out Spinach',
          amount: 30,
          stockQty: 0,
        ),
      );

      await pumpTestApp(
        tester,
        const CategoryViewScreen(categoryId: 'cat_veg', categoryName: 'Vegetables'),
      );
      expect(find.text('Sold Out Spinach'), findsOneWidget);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(find.text('Sold Out Spinach'), findsNothing);
      expect(find.text('Fresh Tomatoes'), findsOneWidget);
    });

    testWidgets('sorting by price reorders the grid', (tester) async {
      await pumpTestApp(
        tester,
        const CategoryViewScreen(categoryId: 'cat_veg', categoryName: 'Vegetables'),
      );

      await tester.tap(find.byType(DropdownButton<ProductSort>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Price (low to high)').last);
      await tester.pumpAndSettle();

      // Baby Spinach (40) is cheaper than Fresh Tomatoes (48).
      final spinach = tester.getTopLeft(find.text('Baby Spinach'));
      final tomatoes = tester.getTopLeft(find.text('Fresh Tomatoes'));
      expect(spinach.dy, lessThanOrEqualTo(tomatoes.dy));
    });
  });
}
