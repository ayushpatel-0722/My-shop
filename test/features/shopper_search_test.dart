import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/category.dart';
import 'package:myshop/core/models/company.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/features/product/search/search_screen.dart';

import '../helpers/test_harness.dart';

void main() {
  late MockAppRepository repo;

  final company1 = const Company(
    id: 'c_spices',
    name: 'Spice King',
    slug: 'spice-king',
    companyPassword: 'pass',
  );

  final company2 = const Company(
    id: 'c_organic',
    name: 'GreenLeaf Organics',
    slug: 'greenleaf-organics',
    companyPassword: 'pass',
  );

  final categorySpices = const Category(
    id: 'cat_spices',
    name: 'Spices',
    companyId: 'c_spices',
  );

  final categoryVeg = const Category(
    id: 'cat_veg',
    name: 'Vegetables',
    companyId: 'c_organic',
  );

  final prodTurmeric = const Product(
    id: 'prod_turmeric',
    companyId: 'c_spices',
    categoryId: 'cat_spices',
    name: 'Turmeric Powder 500g',
    amount: 150.0,
    discountAmt: 130.0,
    stockQty: 50,
  );

  final prodChilli = const Product(
    id: 'prod_chilli',
    companyId: 'c_spices',
    categoryId: 'cat_spices',
    name: 'Red Chilli Powder 250g',
    amount: 120.0,
    discountAmt: 110.0,
    stockQty: 0, // Out of stock
  );

  final prodTomato = const Product(
    id: 'prod_tomato',
    companyId: 'c_organic',
    categoryId: 'cat_veg',
    name: 'Organic Tomatoes 1kg',
    amount: 60.0,
    discountAmt: 50.0,
    stockQty: 25,
  );

  setUp(() async {
    TestHarness.setupPlatformChannels();
    repo = TestHarness.useMockRepository();

    await repo.createCompany(company1);
    await repo.createCompany(company2);
    await repo.saveCategory(categorySpices);
    await repo.saveCategory(categoryVeg);
    await repo.saveProduct(prodTurmeric);
    await repo.saveProduct(prodChilli);
    await repo.saveProduct(prodTomato);
  });

  group('Shopper Search Screen', () {
    testWidgets(
      'shows discovery view with popular search chips when query is empty',
      (tester) async {
        await pumpTestApp(tester, const SearchScreen());
        await tester.pumpAndSettle();

        expect(find.text('Popular Searches'), findsOneWidget);
        expect(find.text('Vegetables'), findsOneWidget);
        expect(find.text('Spices'), findsOneWidget);
        expect(find.text('Browse All Products'), findsOneWidget);
        expect(find.text('Turmeric Powder 500g'), findsOneWidget);
        expect(find.text('Organic Tomatoes 1kg'), findsOneWidget);
      },
    );

    testWidgets('typing a keyword filters products in real-time', (
      tester,
    ) async {
      await pumpTestApp(tester, const SearchScreen());
      await tester.pumpAndSettle();

      final searchField = find.byKey(const Key('search-input-field'));
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'Turmeric');
      await tester.pumpAndSettle();

      expect(find.text('Turmeric Powder 500g'), findsOneWidget);
      expect(find.text('Organic Tomatoes 1kg'), findsNothing);
      expect(find.text('Red Chilli Powder 250g'), findsNothing);
    });

    testWidgets(
      'searching by category keyword matches products in that category',
      (tester) async {
        await pumpTestApp(tester, const SearchScreen());
        await tester.pumpAndSettle();

        final searchField = find.byKey(const Key('search-input-field'));
        await tester.enterText(searchField, 'Spices');
        await tester.pumpAndSettle();

        expect(find.text('Turmeric Powder 500g'), findsOneWidget);
        expect(find.text('Red Chilli Powder 250g'), findsOneWidget);
        expect(find.text('Organic Tomatoes 1kg'), findsNothing);
      },
    );

    testWidgets('tapping a popular search tag executes search immediately', (
      tester,
    ) async {
      await pumpTestApp(tester, const SearchScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Vegetables'));
      await tester.pumpAndSettle();

      expect(find.text('Organic Tomatoes 1kg'), findsOneWidget);
      expect(find.text('Turmeric Powder 500g'), findsNothing);
    });

    testWidgets('in-stock toggle hides sold out products in search results', (
      tester,
    ) async {
      await pumpTestApp(tester, const SearchScreen(initialQuery: 'Powder'));
      await tester.pumpAndSettle();

      expect(find.text('Turmeric Powder 500g'), findsOneWidget);
      expect(find.text('Red Chilli Powder 250g'), findsOneWidget);

      // Toggle In Stock filter
      await tester.tap(find.text('In Stock'));
      await tester.pumpAndSettle();

      expect(find.text('Turmeric Powder 500g'), findsOneWidget);
      expect(find.text('Red Chilli Powder 250g'), findsNothing);
    });

    testWidgets(
      'store-scoped search restricts results and allows clearing scope',
      (tester) async {
        await pumpTestApp(
          tester,
          const SearchScreen(companyId: 'c_spices', companyName: 'Spice King'),
        );
        await tester.pumpAndSettle();

        // Scoped banner is shown
        expect(find.textContaining('Searching in Spice King'), findsOneWidget);

        // Only Spice King products appear
        expect(find.text('Turmeric Powder 500g'), findsOneWidget);
        expect(find.text('Organic Tomatoes 1kg'), findsNothing);

        // Tapping "Search all stores" clears store scope
        await tester.tap(find.text('Search all stores'));
        await tester.pumpAndSettle();

        // Now all products across all stores are visible
        expect(find.text('Turmeric Powder 500g'), findsOneWidget);
        expect(find.text('Organic Tomatoes 1kg'), findsOneWidget);
      },
    );

    testWidgets(
      'empty search results show clear search button which resets query',
      (tester) async {
        await pumpTestApp(
          tester,
          const SearchScreen(initialQuery: 'NonExistentProduct123'),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('No products found for "NonExistentProduct123"'),
          findsOneWidget,
        );

        // Tap Clear Search
        await tester.tap(find.text('Clear Search'));
        await tester.pumpAndSettle();

        // Resets to discovery view
        expect(find.text('Popular Searches'), findsOneWidget);
      },
    );

    testWidgets(
      'desktop web view renders desktop search header and breadcrumbs',
      (tester) async {
        await pumpTestApp(
          tester,
          const SearchScreen(initialQuery: 'Tomatoes'),
          size: const Size(1280, 800),
        );
        await tester.pumpAndSettle();

        // Desktop breadcrumbs rendered
        expect(find.text('Home'), findsWidgets);
        expect(find.text('Search: "Tomatoes"'), findsOneWidget);
        expect(find.text('Organic Tomatoes 1kg'), findsOneWidget);
      },
    );
  });
}
