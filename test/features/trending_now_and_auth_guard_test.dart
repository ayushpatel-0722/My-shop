import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/company.dart';
import 'package:myshop/core/models/home_trending_item.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/core/utils/auth_guard.dart';
import 'package:myshop/features/account/account_screen.dart';
import 'package:myshop/features/auth/auth_cubit.dart';
import 'package:myshop/features/marketplace/home/home_screen.dart';
import 'package:myshop/features/marketplace/widgets/marketplace_bottom_nav.dart';
import 'package:myshop/features/marketplace/widgets/section_header.dart';

import '../helpers/test_harness.dart';

void main() {
  late MockAppRepository repo;

  setUp(() {
    TestHarness.setupPlatformChannels();
    repo = TestHarness.useMockRepository();
  });

  group('Trending Now Vertical List on Home Screen', () {
    testWidgets(
      'renders vertical list with all active products and NO See All button',
      (tester) async {
        // Seed shop and trending products
        const shop = Company(
          id: 'shop_masala',
          name: 'Masala Mart',
          slug: 'masala-mart',
        );
        await repo.createCompany(shop);

        const prod1 = Product(
          id: 'prod_turmeric',
          companyId: 'shop_masala',
          name: 'Organic Turmeric Powder',
          amount: 100,
          discountAmt: 80,
          unit: 250,
          unitType: 'g',
          isUnlimitedStock: true,
          images: ['https://example.com/turmeric.jpg'],
        );

        const prod2 = Product(
          id: 'prod_cardamom',
          companyId: 'shop_masala',
          name: 'Green Cardamom Premium',
          amount: 300,
          discountAmt: 250,
          unit: 100,
          unitType: 'g',
          isUnlimitedStock: true,
          images: ['https://example.com/cardamom.jpg'],
          variants: [
            ProductVariant(id: 'v1', title: '50g', priceOverride: 130),
            ProductVariant(id: 'v2', title: '100g', priceOverride: 250),
          ],
        );

        await repo.saveProduct(prod1);
        await repo.saveProduct(prod2);

        await repo.saveHomeTrendingItem(
          const HomeTrendingItem(
            id: 'trend_1',
            shopId: 'shop_masala',
            productId: 'prod_turmeric',
            itemType: 'product',
            displayOrder: 0,
            isActive: true,
          ),
        );
        await repo.saveHomeTrendingItem(
          const HomeTrendingItem(
            id: 'trend_2',
            shopId: 'shop_masala',
            productId: 'prod_cardamom',
            itemType: 'product',
            displayOrder: 1,
            isActive: true,
          ),
        );

        await pumpTestApp(
          tester,
          const HomeScreen(shopId: 'shop_masala'),
          user: TestHarness.shopper,
          size: const Size(375, 667),
        );
        await tester.pumpAndSettle();

        // 1. Trending Now header is present
        final trendingHeader = find.ancestor(
          of: find.text('Trending Now 🔥'),
          matching: find.byType(SectionHeader),
        );
        expect(trendingHeader, findsOneWidget);

        // 2. "See All" button is COMPLETELY REMOVED from Trending Now
        expect(
          find.descendant(of: trendingHeader, matching: find.text('See All')),
          findsNothing,
        );

        // 3. Both products are rendered vertically in TrendingVerticalProductCard
        expect(find.byType(TrendingVerticalProductCard), findsNWidgets(2));
        expect(find.text('Organic Turmeric Powder'), findsOneWidget);
        expect(find.text('Green Cardamom Premium'), findsOneWidget);

        // 4. Product 1 details: discounted (20% OFF, Save ₹20), unit, ADD button
        expect(
          find.descendant(
            of: find.byType(TrendingVerticalProductCard).first,
            matching: find.text('20% OFF'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(TrendingVerticalProductCard).first,
            matching: find.text('Save ₹20'),
          ),
          findsOneWidget,
        );
        expect(find.text('250 g'), findsOneWidget);
        expect(find.text('ADD'), findsOneWidget);

        // 5. Product 2 details: has variants -> "2 Options" and "Select Variant" button
        expect(find.text('2 Options'), findsOneWidget);
        expect(find.text('Select Variant'), findsOneWidget);

        await tester.pump(const Duration(seconds: 3));
      },
    );

    testWidgets('displays every active item without truncation cap', (
      tester,
    ) async {
      const shop = Company(
        id: 'shop_1',
        name: 'Spice Store',
        slug: 'spice-store',
      );
      await repo.createCompany(shop);

      for (int i = 0; i < 15; i++) {
        final p = Product(
          id: 'prod_$i',
          companyId: 'shop_1',
          name: 'Spice Item $i',
          amount: 50,
          discountAmt: 45,
          isUnlimitedStock: true,
          images: ['https://example.com/$i.jpg'],
        );
        await repo.saveProduct(p);

        await repo.saveHomeTrendingItem(
          HomeTrendingItem(
            id: 't_$i',
            shopId: 'shop_1',
            productId: 'prod_$i',
            itemType: 'product',
            displayOrder: i,
            isActive: true,
          ),
        );
      }

      await pumpTestApp(
        tester,
        const HomeScreen(shopId: 'shop_1'),
        user: TestHarness.shopper,
        size: const Size(375, 667),
      );
      await tester.pumpAndSettle();

      // All 15 products must be rendered
      expect(find.byType(TrendingVerticalProductCard), findsNWidgets(15));
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('filters trending products when shop switching occurs', (
      tester,
    ) async {
      const shopA = Company(
        id: 'shop_a',
        name: 'Shop Alpha',
        slug: 'shop-alpha',
      );
      const shopB = Company(id: 'shop_b', name: 'Shop Beta', slug: 'shop-beta');
      await repo.createCompany(shopA);
      await repo.createCompany(shopB);

      const prodA = Product(
        id: 'p_a',
        companyId: 'shop_a',
        name: 'Alpha Turmeric',
        amount: 50,
        discountAmt: 40,
        isUnlimitedStock: true,
      );
      const prodB = Product(
        id: 'p_b',
        companyId: 'shop_b',
        name: 'Beta Saffron',
        amount: 500,
        discountAmt: 450,
        isUnlimitedStock: true,
      );
      await repo.saveProduct(prodA);
      await repo.saveProduct(prodB);

      await repo.saveHomeTrendingItem(
        const HomeTrendingItem(
          id: 't_a',
          shopId: 'shop_a',
          productId: 'p_a',
          itemType: 'product',
          displayOrder: 0,
          isActive: true,
        ),
      );
      await repo.saveHomeTrendingItem(
        const HomeTrendingItem(
          id: 't_b',
          shopId: 'shop_b',
          productId: 'p_b',
          itemType: 'product',
          displayOrder: 0,
          isActive: true,
        ),
      );

      // Launch home screen with shop_a
      await pumpTestApp(
        tester,
        const HomeScreen(shopId: 'shop_a'),
        user: TestHarness.shopper,
      );
      await tester.pumpAndSettle();

      expect(find.text('Alpha Turmeric'), findsOneWidget);
      expect(find.text('Beta Saffron'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('tapping product card opens product details screen', (
      tester,
    ) async {
      const shop = Company(
        id: 'shop_masala',
        name: 'Masala Mart',
        slug: 'masala-mart',
      );
      await repo.createCompany(shop);

      const prod = Product(
        id: 'p_details_test',
        companyId: 'shop_masala',
        name: 'Royal Cumin Seeds',
        amount: 80,
        discountAmt: 70,
        isUnlimitedStock: true,
      );
      await repo.saveProduct(prod);

      await repo.saveHomeTrendingItem(
        const HomeTrendingItem(
          id: 't_details',
          shopId: 'shop_masala',
          productId: 'p_details_test',
          itemType: 'product',
          isActive: true,
        ),
      );

      await pumpTestApp(
        tester,
        const HomeScreen(shopId: 'shop_masala'),
        user: TestHarness.shopper,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Royal Cumin Seeds'));
      await tester.pumpAndSettle();

      expect(find.text('Product p_details_test'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('Login Protection for Saved Address and My Orders', () {
    testWidgets(
      'guest tapping Saved Address is prompted with "Please log in to manage your saved addresses."',
      (tester) async {
        await pumpTestApp(
          tester,
          const AccountScreen(),
          authCubit: AuthCubit(), // Unauthenticated guest
        );
        await tester.pumpAndSettle();

        // Find Saved Addresses tile
        final savedAddressTile = find.widgetWithText(
          ListTile,
          'Saved Addresses',
        );
        expect(savedAddressTile, findsOneWidget);

        await tester.tap(savedAddressTile);
        await tester.pumpAndSettle();

        // Message should be displayed
        expect(
          find.text('Please log in to manage your saved addresses.'),
          findsWidgets,
        );
      },
    );

    testWidgets(
      'authenticated user tapping Saved Address opens address manager without login prompt',
      (tester) async {
        await pumpTestApp(
          tester,
          const AccountScreen(),
          user: TestHarness.shopperWithAddresses,
        );
        await tester.pumpAndSettle();

        final savedAddressTile = find.widgetWithText(
          ListTile,
          'Saved Addresses',
        );
        expect(savedAddressTile, findsOneWidget);

        await tester.tap(savedAddressTile);
        await tester.pumpAndSettle();

        // No login prompt is shown
        expect(
          find.text('Please log in to manage your saved addresses.'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'guest tapping My Orders is prompted with "Please log in to view your orders."',
      (tester) async {
        await pumpTestApp(
          tester,
          const AccountScreen(),
          authCubit: AuthCubit(), // Unauthenticated guest
        );
        await tester.pumpAndSettle();

        final myOrdersTile = find.widgetWithText(ListTile, 'My Orders');
        expect(myOrdersTile, findsOneWidget);

        await tester.tap(myOrdersTile);
        await tester.pumpAndSettle();

        // Message should be displayed
        expect(find.text('Please log in to view your orders.'), findsWidgets);
      },
    );

    testWidgets(
      'authenticated user tapping My Orders navigates directly to orders',
      (tester) async {
        await pumpTestApp(
          tester,
          const AccountScreen(),
          user: TestHarness.shopper,
        );
        await tester.pumpAndSettle();

        final myOrdersTile = find.widgetWithText(ListTile, 'My Orders');
        expect(myOrdersTile, findsOneWidget);

        await tester.tap(myOrdersTile);
        await tester.pumpAndSettle();

        // Navigates directly to Orders screen
        expect(find.text('Orders screen'), findsOneWidget);
        expect(find.text('Please log in to view your orders.'), findsNothing);
      },
    );

    testWidgets(
      'guest tapping bottom nav Orders tab is prompted with "Please log in to view your orders."',
      (tester) async {
        await pumpTestApp(
          tester,
          const Scaffold(
            bottomNavigationBar: MarketplaceBottomNav(currentIndex: 0),
          ),
          authCubit: AuthCubit(),
        );
        await tester.pumpAndSettle();

        // Tap Orders in navigation bar
        await tester.tap(find.text('Orders'));
        await tester.pumpAndSettle();

        expect(find.text('Please log in to view your orders.'), findsWidgets);
      },
    );

    testWidgets(
      'AuthGuard executes onAuthenticated immediately when user is already logged in',
      (tester) async {
        bool callbackExecuted = false;

        await pumpTestApp(
          tester,
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  AuthGuard.runWithAuth(
                    context,
                    message: 'Please log in to proceed.',
                    onAuthenticated: () {
                      callbackExecuted = true;
                    },
                  );
                },
                child: const Text('Guarded Action'),
              );
            },
          ),
          user: TestHarness.shopper,
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Guarded Action'));
        await tester.pumpAndSettle();

        expect(callbackExecuted, isTrue);
        expect(find.text('Please log in to proceed.'), findsNothing);
      },
    );
  });
}
