import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/app/l10n/app_localizations.dart';
import 'package:myshop/app/theme/app_theme.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/app_user.dart';
import 'package:myshop/core/models/home_trending_item.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/core/services/auth_session.dart';
import 'package:myshop/core/services/service_locator.dart';
import 'package:myshop/core/models/company.dart';
import 'package:myshop/core/widgets/app_product_image.dart';
import 'package:myshop/features/admin/home_config/admin_trending_now_screen.dart';
import 'package:myshop/features/admin/products/admin_add_product_screen.dart';
import 'package:myshop/features/marketplace/widgets/product_card.dart';

void main() {
  late MockAppRepository mockRepo;

  setUp(() {
    mockRepo = MockAppRepository();
    ServiceLocator.instance.repository = mockRepo;
  });

  group('Product Trending Now Synchronization - Repository Unit Tests', () {
    test('1 & 4. Adding product to Trending Now and removing it', () async {
      const shopId = 'store_alpha';
      const productId = 'prod_101';

      await mockRepo.saveHomeTrendingItem(
        const HomeTrendingItem(
          id: '${shopId}_product_$productId',
          shopId: shopId,
          itemType: 'product',
          productId: productId,
          productName: 'Organic Apples',
          displayOrder: 0,
        ),
      );

      expect(
        await mockRepo.isProductInTrendingNow(
          shopId: shopId,
          productId: productId,
        ),
        isTrue,
      );

      final removedCount = await mockRepo.removeProductFromTrendingNow(
        shopId: shopId,
        productId: productId,
      );

      expect(removedCount, 1);
      expect(
        await mockRepo.isProductInTrendingNow(
          shopId: shopId,
          productId: productId,
        ),
        isFalse,
      );
    });

    test(
      '7 & 8. Removes only target product; preserves other products, categories, and other shops',
      () async {
        const shopA = 'store_alpha';
        const shopB = 'store_beta';
        const prod1 = 'prod_1';
        const prod2 = 'prod_2';
        const cat1 = 'cat_1';

        // Setup Shop A items
        await mockRepo.saveHomeTrendingItem(
          const HomeTrendingItem(
            id: '${shopA}_product_$prod1',
            shopId: shopA,
            itemType: 'product',
            productId: prod1,
            productName: 'Product 1 (Shop A)',
            displayOrder: 0,
          ),
        );
        await mockRepo.saveHomeTrendingItem(
          const HomeTrendingItem(
            id: '${shopA}_product_$prod2',
            shopId: shopA,
            itemType: 'product',
            productId: prod2,
            productName: 'Product 2 (Shop A)',
            displayOrder: 1,
          ),
        );
        await mockRepo.saveHomeTrendingItem(
          const HomeTrendingItem(
            id: '${shopA}_category_$cat1',
            shopId: shopA,
            itemType: 'category',
            categoryId: cat1,
            categoryName: 'Category 1 (Shop A)',
            displayOrder: 2,
          ),
        );

        // Setup Shop B items with same prod1 id
        await mockRepo.saveHomeTrendingItem(
          const HomeTrendingItem(
            id: '${shopB}_product_$prod1',
            shopId: shopB,
            itemType: 'product',
            productId: prod1,
            productName: 'Product 1 (Shop B)',
            displayOrder: 0,
          ),
        );

        // Remove prod1 from shopA only
        final removed = await mockRepo.removeProductFromTrendingNow(
          shopId: shopA,
          productId: prod1,
        );
        expect(removed, 1);

        // Verify Shop A: prod1 is removed, but prod2 and cat1 remain!
        final shopAEntries = await mockRepo
            .homeTrendingNow(shopId: shopA)
            .first;
        expect(shopAEntries.any((e) => e.productId == prod1), isFalse);
        expect(shopAEntries.any((e) => e.productId == prod2), isTrue);
        expect(shopAEntries.any((e) => e.categoryId == cat1), isTrue);

        // Verify Shop B: prod1 is untouched!
        final shopBEntries = await mockRepo
            .homeTrendingNow(shopId: shopB)
            .first;
        expect(shopBEntries.any((e) => e.productId == prod1), isTrue);
      },
    );

    test('Repeated cleanup calls are safe and idempotent', () async {
      const shopId = 'store_alpha';
      const productId = 'prod_safe';

      await mockRepo.saveHomeTrendingItem(
        const HomeTrendingItem(
          id: 'item_1',
          shopId: shopId,
          itemType: 'product',
          productId: productId,
        ),
      );

      expect(
        await mockRepo.removeProductFromTrendingNow(
          shopId: shopId,
          productId: productId,
        ),
        1,
      );
      // Repeated call with no matching entry returns 0 without crashing
      expect(
        await mockRepo.removeProductFromTrendingNow(
          shopId: shopId,
          productId: productId,
        ),
        0,
      );
      expect(
        await mockRepo.removeProductFromTrendingNow(
          shopId: shopId,
          productId: productId,
        ),
        0,
      );
    });

    test(
      '10. Deleting or saving a product does not delete unrelated products',
      () async {
        const shopId = 'store_alpha';
        const prodA = Product(
          id: 'p_a',
          companyId: shopId,
          name: 'Product A',
          amount: 50,
        );
        const prodB = Product(
          id: 'p_b',
          companyId: shopId,
          name: 'Product B',
          amount: 80,
        );

        await mockRepo.saveProduct(prodA);
        await mockRepo.saveProduct(prodB);

        // Both are in trending
        await mockRepo.saveHomeTrendingItem(
          const HomeTrendingItem(
            id: 'trend_a',
            shopId: shopId,
            itemType: 'product',
            productId: 'p_a',
          ),
        );
        await mockRepo.saveHomeTrendingItem(
          const HomeTrendingItem(
            id: 'trend_b',
            shopId: shopId,
            itemType: 'product',
            productId: 'p_b',
          ),
        );

        // Delete Product A
        await mockRepo.deleteProduct('p_a', companyId: shopId);

        // Trending A is automatically removed
        expect(
          await mockRepo.isProductInTrendingNow(
            shopId: shopId,
            productId: 'p_a',
          ),
          isFalse,
        );
        // Trending B is preserved
        expect(
          await mockRepo.isProductInTrendingNow(
            shopId: shopId,
            productId: 'p_b',
          ),
          isTrue,
        );
        // Product B remains in product catalog
        final products = await mockRepo.products(companyId: shopId).first;
        expect(products.any((p) => p.id == 'p_b'), isTrue);
      },
    );
  });

  group('Admin Product Edit Automatically Removes from Trending Now - Widget Tests', () {
    testWidgets(
      '2, 3, 5, 6, 10: Editing product as admin updates catalog and automatically removes entry from Trending Now',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        const shopId = 'store_farm';
        const productId = 'prod_mango';

        AuthSession.currentUser = AppUser(
          id: 'admin_1',
          companyId: shopId,
          companyName: 'Farm Fresh Store',
          name: 'Farm Admin',
          email: 'admin@farm.com',
          role: 'admin',
        );

        // Seed product
        const initialProduct = Product(
          id: productId,
          companyId: shopId,
          name: 'Alphonso Mango 1kg',
          amount: 500,
          stockQty: 25,
          unit: 1,
          unitType: 'kg',
          sku: 'SKU-MANGO-01',
          images: ['https://example.com/mango.png'],
        );
        await mockRepo.saveProduct(initialProduct);

        // Also seed an unrelated product
        const unrelatedProduct = Product(
          id: 'prod_banana',
          companyId: shopId,
          name: 'Robusta Banana 1 dozen',
          amount: 60,
          stockQty: 50,
          images: ['https://example.com/banana.png'],
        );
        await mockRepo.saveProduct(unrelatedProduct);

        // Add both to Trending Now
        await mockRepo.saveHomeTrendingItem(
          const HomeTrendingItem(
            id: 'trend_mango',
            shopId: shopId,
            itemType: 'product',
            productId: productId,
            productName: 'Alphonso Mango 1kg',
            imageUrl: 'https://example.com/mango.png',
            displayOrder: 0,
          ),
        );
        await mockRepo.saveHomeTrendingItem(
          const HomeTrendingItem(
            id: 'trend_banana',
            shopId: shopId,
            itemType: 'product',
            productId: 'prod_banana',
            productName: 'Robusta Banana 1 dozen',
            imageUrl: 'https://example.com/banana.png',
            displayOrder: 1,
          ),
        );

        // Verify initial state: both are in Trending Now
        expect(
          await mockRepo.isProductInTrendingNow(
            shopId: shopId,
            productId: productId,
          ),
          isTrue,
        );
        expect(
          await mockRepo.isProductInTrendingNow(
            shopId: shopId,
            productId: 'prod_banana',
          ),
          isTrue,
        );

        // Pump AdminAddProductScreen in edit mode for prod_mango
        await tester.pumpWidget(
          MaterialApp(
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: AppTheme.light(),
            home: const AdminAddProductScreen(product: initialProduct),
          ),
        );
        await tester.pumpAndSettle();

        // Check that initial product name is loaded
        expect(find.text('Alphonso Mango 1kg'), findsWidgets);

        // Edit the product name
        final titleField = find.widgetWithText(
          TextFormField,
          'Product Title *',
        );
        await tester.enterText(
          titleField,
          'Premium Organic Alphonso Mango 1kg',
        );
        await tester.pumpAndSettle();

        // Tap "Update Product"
        final updateBtn = find.text('Update Product');
        await tester.ensureVisible(updateBtn);
        await tester.pumpAndSettle();
        await tester.tap(updateBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Verify 10: Product remains available in normal catalog with updated name!
        final updatedProduct = await mockRepo.product(productId);
        expect(updatedProduct, isNotNull);
        expect(updatedProduct!.name, 'Premium Organic Alphonso Mango 1kg');

        // Verify 4, 5, 6: Its Trending Now entry is automatically removed!
        expect(
          await mockRepo.isProductInTrendingNow(
            shopId: shopId,
            productId: productId,
          ),
          isFalse,
        );

        // Verify 7: Unrelated product remains in Trending Now!
        expect(
          await mockRepo.isProductInTrendingNow(
            shopId: shopId,
            productId: 'prod_banana',
          ),
          isTrue,
        );
      },
    );

    testWidgets(
      'Verify images display properly and editing product removes it from Home Trending Now',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        const shopId = 'store_organic';
        const shop = Company(
          id: shopId,
          slug: 'organic-life-store',
          name: 'Organic Life Store',
        );
        await mockRepo.createCompany(shop);

        AuthSession.currentUser = AppUser(
          id: 'admin_1',
          companyId: shopId,
          companyName: 'Organic Life Store',
          name: 'Store Manager',
          email: 'manager@organic.com',
          role: 'admin',
        );

        const mangoProduct = Product(
          id: 'prod_mango_special',
          companyId: shopId,
          name: 'Devgad Alphonso Mango',
          amount: 650,
          stockQty: 30,
          images: ['https://example.com/mango.png'],
        );
        const appleProduct = Product(
          id: 'prod_apple_special',
          companyId: shopId,
          name: 'Shimla Royal Apple',
          amount: 220,
          stockQty: 50,
          images: ['https://example.com/apple.png'],
        );

        await mockRepo.saveProduct(mangoProduct);
        await mockRepo.saveProduct(appleProduct);

        // Add both to Trending Now
        await mockRepo.saveHomeTrendingItem(
          const HomeTrendingItem(
            id: 'trend_mango_special',
            shopId: shopId,
            itemType: 'product',
            productId: 'prod_mango_special',
            productName: 'Devgad Alphonso Mango',
            imageUrl: 'https://example.com/mango.png',
            displayOrder: 0,
          ),
        );
        await mockRepo.saveHomeTrendingItem(
          const HomeTrendingItem(
            id: 'trend_apple_special',
            shopId: shopId,
            itemType: 'product',
            productId: 'prod_apple_special',
            productName: 'Shimla Royal Apple',
            imageUrl: 'https://example.com/apple.png',
            displayOrder: 1,
          ),
        );

        // 1. Verify Image Display in Customer-facing ProductCard
        await tester.pumpWidget(
          MaterialApp(
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: AppTheme.light(),
            home: Scaffold(body: ProductCard(product: mangoProduct)),
          ),
        );
        await tester.pumpAndSettle();

        // Check ProductCard renders title and AppProductImage with correct image URL
        expect(find.text('Devgad Alphonso Mango'), findsOneWidget);
        final customerImageFinder = find.byType(AppProductImage);
        expect(customerImageFinder, findsOneWidget);
        final customerAppProductImage = tester.widget<AppProductImage>(
          customerImageFinder,
        );
        expect(customerAppProductImage.url, 'https://example.com/mango.png');

        // 2. Verify Image Display in AdminTrendingNowScreen
        await tester.pumpWidget(
          MaterialApp(
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: AppTheme.light(),
            home: const AdminTrendingNowScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // Both products are present in Trending Now
        expect(find.text('Devgad Alphonso Mango'), findsOneWidget);
        expect(find.text('Shimla Royal Apple'), findsOneWidget);

        // 3. Edit product as Admin via AdminAddProductScreen
        await tester.pumpWidget(
          MaterialApp(
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: AppTheme.light(),
            home: const AdminAddProductScreen(product: mangoProduct),
          ),
        );
        await tester.pumpAndSettle();

        final titleField = find.widgetWithText(
          TextFormField,
          'Product Title *',
        );
        await tester.enterText(titleField, 'Devgad Alphonso Mango Extra Sweet');
        await tester.pumpAndSettle();

        final updateBtn = find.text('Update Product');
        await tester.ensureVisible(updateBtn);
        await tester.pumpAndSettle();
        await tester.tap(updateBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // 4. Verify product is removed from Trending Now in repository
        expect(
          await mockRepo.isProductInTrendingNow(
            shopId: shopId,
            productId: 'prod_mango_special',
          ),
          isFalse,
        );

        // 5. Verify catalog product remains intact and updated
        final updatedCatalog = await mockRepo.product('prod_mango_special');
        expect(updatedCatalog, isNotNull);
        expect(updatedCatalog!.name, 'Devgad Alphonso Mango Extra Sweet');

        // 6. Verify unrelated product remains in Trending Now
        expect(
          await mockRepo.isProductInTrendingNow(
            shopId: shopId,
            productId: 'prod_apple_special',
          ),
          isTrue,
        );

        // 7. Verify Admin Trending Now screen reflects the removal
        await tester.pumpWidget(
          MaterialApp(
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: AppTheme.light(),
            home: const AdminTrendingNowScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // The edited product is NO LONGER in Trending Now
        expect(find.text('Devgad Alphonso Mango'), findsNothing);
        expect(find.text('Devgad Alphonso Mango Extra Sweet'), findsNothing);

        // The unedited apple product is STILL in Trending Now with its image intact
        expect(find.text('Shimla Royal Apple'), findsOneWidget);
      },
    );
  });
}
