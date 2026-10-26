import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/models/category.dart';
import 'package:myshop/core/models/company.dart';
import 'package:myshop/core/models/home_trending_item.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/features/admin/home_config/admin_trending_now_screen.dart';

import '../helpers/test_harness.dart';

void main() {
  setUp(() {
    TestHarness.setupPlatformChannels();
  });

  tearDown(() {
    TestHarness.signOut();
  });

  group('AdminTrendingNowScreen Responsive Layout & Overflow Tests', () {
    const shop = Company(
      id: 'c_organic',
      slug: 'greenleaf-organics',
      name: 'GreenLeaf Organics',
    );

    const longNamedProduct = Product(
      id: 'prod_long_1',
      companyId: 'c_organic',
      categoryId: 'cat_spices',
      name: 'Everest Royal Traditional Pure Garam Masala Powder 250g Pack',
      amount: 199.50,
      stockQty: 45,
      sku: 'EV-GM-250',
      images: ['https://example.com/masala.png'],
    );

    const normalProduct = Product(
      id: 'prod_2',
      companyId: 'c_organic',
      categoryId: 'cat_spices',
      name: 'Organic Turmeric Powder',
      amount: 85.00,
      stockQty: 120,
      sku: 'OTP-100',
      images: [],
    );

    const spicesCat = Category(
      id: 'cat_spices',
      companyId: 'c_organic',
      name: 'Spices & Condiments',
      details: 'Freshly ground spices and whole condiments',
    );

    testWidgets(
      'renders on narrow mobile screen (360x740) without any overflow',
      (tester) async {
        final repo = TestHarness.useMockRepository();
        TestHarness.signIn(TestHarness.admin);

        await repo.createCompany(shop);
        await repo.saveCategory(spicesCat);
        await repo.saveProduct(longNamedProduct);
        await repo.saveProduct(normalProduct);

        // Add a trending item
        await repo.saveHomeTrendingItem(
          HomeTrendingItem(
            id: 'c_organic_product_prod_long_1',
            shopId: shop.id,
            shopName: shop.name,
            itemType: 'product',
            productId: longNamedProduct.id,
            productName: longNamedProduct.name,
            categoryName: 'Spices & Condiments',
            isActive: true,
            displayOrder: 0,
          ),
        );

        // Narrow screen: 360 x 740
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await pumpTestApp(
          tester,
          const AdminTrendingNowScreen(),
          user: TestHarness.admin,
          size: const Size(360, 740),
        );

        // Verify no Flutter errors
        expect(tester.takeException(), isNull);

        // Verify shop name displayed
        expect(find.text(shop.name), findsOneWidget);

        // Verify trending items counter displayed
        expect(find.text('1 Trending Item'), findsOneWidget);

        // Verify responsive action buttons exist
        expect(find.text('By Category'), findsOneWidget);
        expect(find.text('Add Products'), findsOneWidget);

        // Verify long product name is displayed
        expect(find.text(longNamedProduct.name), findsOneWidget);

        // Verify price is displayed
        expect(find.textContaining('199.5'), findsOneWidget);
      },
    );

    testWidgets(
      'renders on extra-narrow mobile screen (320x640) without overflow',
      (tester) async {
        final repo = TestHarness.useMockRepository();
        TestHarness.signIn(TestHarness.admin);

        await repo.createCompany(shop);
        await repo.saveCategory(spicesCat);
        await repo.saveProduct(longNamedProduct);

        await repo.saveHomeTrendingItem(
          HomeTrendingItem(
            id: 'c_organic_product_prod_long_1',
            shopId: shop.id,
            shopName: shop.name,
            itemType: 'product',
            productId: longNamedProduct.id,
            productName: longNamedProduct.name,
            categoryName: 'Spices & Condiments',
            isActive: true,
            displayOrder: 0,
          ),
        );

        // Extra narrow: 320 x 640
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await pumpTestApp(
          tester,
          const AdminTrendingNowScreen(),
          user: TestHarness.admin,
          size: const Size(320, 640),
        );

        expect(tester.takeException(), isNull);
        expect(find.text(longNamedProduct.name), findsOneWidget);
      },
    );

    testWidgets('tapping product card opens product details preview modal', (
      tester,
    ) async {
      final repo = TestHarness.useMockRepository();
      TestHarness.signIn(TestHarness.admin);

      await repo.createCompany(shop);
      await repo.saveCategory(spicesCat);
      await repo.saveProduct(longNamedProduct);

      await repo.saveHomeTrendingItem(
        HomeTrendingItem(
          id: 'c_organic_product_prod_long_1',
          shopId: shop.id,
          shopName: shop.name,
          itemType: 'product',
          productId: longNamedProduct.id,
          productName: longNamedProduct.name,
          categoryName: 'Spices & Condiments',
          isActive: true,
          displayOrder: 0,
        ),
      );

      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await pumpTestApp(
        tester,
        const AdminTrendingNowScreen(),
        user: TestHarness.admin,
        size: const Size(360, 740),
      );

      // Tap on the card
      await tester.tap(find.text(longNamedProduct.name));
      await tester.pumpAndSettle();

      // Verify modal opened with full details
      expect(find.text('TRENDING PRODUCT'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Remove from Trending'), findsOneWidget);
    });

    testWidgets(
      'Add Products Sheet opens and filters by search and category without overflow',
      (tester) async {
        final repo = TestHarness.useMockRepository();
        TestHarness.signIn(TestHarness.admin);

        await repo.createCompany(shop);
        await repo.saveCategory(spicesCat);
        await repo.saveProduct(longNamedProduct);
        await repo.saveProduct(normalProduct);

        // Add one existing item
        await repo.saveHomeTrendingItem(
          HomeTrendingItem(
            id: 'c_organic_product_prod_long_1',
            shopId: shop.id,
            shopName: shop.name,
            itemType: 'product',
            productId: longNamedProduct.id,
            productName: longNamedProduct.name,
            categoryName: 'Spices & Condiments',
            isActive: true,
            displayOrder: 0,
          ),
        );

        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await pumpTestApp(
          tester,
          const AdminTrendingNowScreen(),
          user: TestHarness.admin,
          size: const Size(360, 740),
        );

        // Tap Add Products button
        await tester.tap(find.text('Add Products'));
        await tester.pumpAndSettle();

        // Verify sheet opened
        expect(find.byType(TextField), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text('Add Products to Trending'),
          ),
          findsOneWidget,
        );

        // Verify products found in search sheet
        expect(find.textContaining('products found'), findsOneWidget);
        expect(find.text('Fresh Tomatoes'), findsOneWidget);

        // Test Search
        await tester.enterText(find.byType(TextField), 'Turmeric');
        await tester.pumpAndSettle();

        expect(find.text('1 products found'), findsOneWidget);
        expect(find.text(normalProduct.name), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text(longNamedProduct.name),
          ),
          findsNothing,
        );

        // Clear Search
        await tester.tap(find.byIcon(Icons.clear));
        await tester.pumpAndSettle();

        expect(find.textContaining('products found'), findsOneWidget);
      },
    );

    testWidgets('renders empty state without overflow on small screens', (
      tester,
    ) async {
      final repo = TestHarness.useMockRepository();
      TestHarness.signIn(TestHarness.admin);

      await repo.createCompany(shop);

      tester.view.physicalSize = const Size(360, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await pumpTestApp(
        tester,
        const AdminTrendingNowScreen(),
        user: TestHarness.admin,
        size: const Size(360, 600),
      );

      expect(tester.takeException(), isNull);
      expect(
        find.text('No Trending Products for ${shop.name}'),
        findsOneWidget,
      );
      expect(
        find.text('Add Products to Trending'),
        findsNWidgets(2),
      ); // Empty state button + FAB
    });

    testWidgets(
      'renders on wide desktop/tablet layout (1024x768) without regressions',
      (tester) async {
        final repo = TestHarness.useMockRepository();
        TestHarness.signIn(TestHarness.admin);

        await repo.createCompany(shop);
        await repo.saveCategory(spicesCat);
        await repo.saveProduct(longNamedProduct);

        await repo.saveHomeTrendingItem(
          HomeTrendingItem(
            id: 'c_organic_product_prod_long_1',
            shopId: shop.id,
            shopName: shop.name,
            itemType: 'product',
            productId: longNamedProduct.id,
            productName: longNamedProduct.name,
            categoryName: 'Spices & Condiments',
            isActive: true,
            displayOrder: 0,
          ),
        );

        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await pumpTestApp(
          tester,
          const AdminTrendingNowScreen(),
          user: TestHarness.admin,
          size: const Size(1024, 768),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('1 Trending Item'), findsOneWidget);
        expect(find.text('Add by Category'), findsOneWidget);
        expect(find.text('Add Products'), findsOneWidget);
      },
    );
  });
}
