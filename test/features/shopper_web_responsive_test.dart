import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/app/l10n/app_localizations.dart';
import 'package:myshop/app/theme/app_theme.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/company.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/features/checkout/cart/cart_cubit.dart';
import 'package:myshop/features/checkout/cart/wishlist_cubit.dart';
import 'package:myshop/features/marketplace/home/home_screen.dart';
import 'package:myshop/features/marketplace/widgets/marketplace_bottom_nav.dart';
import 'package:myshop/features/marketplace/widgets/product_card.dart';
import 'package:myshop/features/marketplace/widgets/section_header.dart';
import 'package:myshop/features/marketplace/widgets/web_header.dart';
import 'package:myshop/features/product/details/product_details_screen.dart';

import '../helpers/test_harness.dart';

void main() {
  late MockAppRepository mockRepo;
  late CartCubit cartCubit;
  late WishlistCubit wishlistCubit;

  const testProduct = Product(
    id: 'prod_spice_01',
    companyId: 'company_1',
    name: 'Turmeric Powder 500g',
    amount: 180.0,
    discountAmt: 150.0,
    unit: 500,
    unitType: 'g',
    stockQty: 50,
    images: ['https://example.com/turmeric.jpg'],
  );

  const testCompany = Company(
    id: 'company_1',
    name: 'Masala Mart',
    slug: 'masala-mart',
    currency: 'INR',
  );

  setUp(() {
    TestHarness.setupPlatformChannels();
    mockRepo = TestHarness.useMockRepository();
    TestHarness.signIn(TestHarness.shopper);
    cartCubit = CartCubit();
    wishlistCubit = WishlistCubit();
  });

  tearDown(() {
    cartCubit.close();
    wishlistCubit.close();
    TestHarness.signOut();
  });

  Widget buildTestWidget({required Widget child, ThemeData? theme}) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<CartCubit>.value(value: cartCubit),
        BlocProvider<WishlistCubit>.value(value: wishlistCubit),
      ],
      child: MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: theme ?? AppTheme.light(),
        home: Scaffold(body: child),
      ),
    );
  }

  group('Shopper Responsive Design Tokens', () {
    testWidgets('SectionHeader adapts typography between Desktop and Mobile', (
      tester,
    ) async {
      // 1. Desktop Viewport (1280x800)
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestWidget(
          child: const SectionHeader(
            title: 'Featured Products',
            subtitle: 'Handpicked spices for you',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final desktopTitle = tester.widget<Text>(find.text('Featured Products'));
      expect(desktopTitle.style?.fontSize, equals(26.0));

      final desktopSubtitle = tester.widget<Text>(
        find.text('Handpicked spices for you'),
      );
      expect(desktopSubtitle.style?.fontSize, equals(13.5));

      // 2. Mobile Viewport (375x667)
      tester.view.physicalSize = const Size(375, 667);
      await tester.pumpWidget(
        buildTestWidget(
          child: const SectionHeader(
            title: 'Featured Products',
            subtitle: 'Handpicked spices for you',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final mobileTitle = tester.widget<Text>(find.text('Featured Products'));
      expect(mobileTitle.style?.fontSize, equals(18.0));

      final mobileSubtitle = tester.widget<Text>(
        find.text('Handpicked spices for you'),
      );
      expect(mobileSubtitle.style?.fontSize, equals(12.0));
    });

    testWidgets(
      'ProductCard scales font sizes on Desktop web while preserving Mobile',
      (tester) async {
        // 1. Desktop Viewport (1280x800)
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          buildTestWidget(
            child: const SizedBox(
              width: 300,
              child: ProductCard(product: testProduct, company: testCompany),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final desktopName = tester.widget<Text>(
          find.text('Turmeric Powder 500g'),
        );
        expect(desktopName.style?.fontSize, equals(18.0));

        final desktopPrice = tester.widget<Text>(find.text('₹150'));
        expect(desktopPrice.style?.fontSize, equals(22.0));

        final desktopUnit = tester.widget<Text>(find.text('500.0 g'));
        expect(desktopUnit.style?.fontSize, equals(14.0));

        // 2. Mobile Viewport (375x667)
        tester.view.physicalSize = const Size(375, 667);
        await tester.pumpWidget(
          buildTestWidget(
            child: const SizedBox(
              width: 180,
              child: ProductCard(product: testProduct, company: testCompany),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final mobileName = tester.widget<Text>(
          find.text('Turmeric Powder 500g'),
        );
        expect(mobileName.style?.fontSize, equals(14.0));

        final mobilePrice = tester.widget<Text>(find.text('₹150'));
        expect(mobilePrice.style?.fontSize, equals(16.0));

        final mobileUnit = tester.widget<Text>(find.text('500.0 g'));
        expect(mobileUnit.style?.fontSize, equals(12.0));
      },
    );

    testWidgets('ProductCard supports desktop mouse hover animation', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestWidget(
          child: const Center(
            child: SizedBox(
              width: 250,
              child: ProductCard(product: testProduct, company: testCompany),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      // Hover over the card
      await gesture.moveTo(tester.getCenter(find.byType(ProductCard)));
      await tester.pumpAndSettle();

      // Card is successfully rendered and interactive
      expect(find.byType(ProductCard), findsOneWidget);
    });

    testWidgets(
      'MarketplaceBottomNav stays centered and constrained on Desktop',
      (tester) async {
        tester.view.physicalSize = const Size(1600, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          buildTestWidget(child: const MarketplaceBottomNav(currentIndex: 0)),
        );
        await tester.pumpAndSettle();

        // Find the ConstrainedBox inside MarketplaceBottomNav
        final constrainedBoxes = tester.widgetList<ConstrainedBox>(
          find.descendant(
            of: find.byType(MarketplaceBottomNav),
            matching: find.byType(ConstrainedBox),
          ),
        );
        final navConstrainedBox = constrainedBoxes.firstWhere(
          (b) => b.constraints.maxWidth == 700.0,
        );
        expect(navConstrainedBox.constraints.maxWidth, equals(700.0));
      },
    );
  });

  group('ProductDetailsScreen Responsive Layout', () {
    testWidgets('Desktop view renders side-by-side 2-column layout', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await mockRepo.saveProduct(testProduct);
      await mockRepo.createCompany(testCompany);

      await tester.pumpWidget(
        buildTestWidget(child: ProductDetailsScreen(productId: testProduct.id)),
      );
      await tester.pumpAndSettle();

      // On desktop, there should be a 2-column Row inside full-width layout with WebHeader
      expect(find.text(testProduct.name), findsWidgets);
      expect(find.byType(Row), findsWidgets);
      expect(find.byType(WebHeader), findsOneWidget);

      // Verify page uses full available width without restrictive 1200 max width
      final constrainedBoxes = tester.widgetList<ConstrainedBox>(
        find.byType(ConstrainedBox),
      );
      final hasRestrictiveConstraint = constrainedBoxes.any(
        (b) => b.constraints.maxWidth == AppTheme.shopperMaxContentWidth,
      );
      expect(hasRestrictiveConstraint, isFalse);
    });

    testWidgets('Mobile view preserves single-column layout', (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await mockRepo.saveProduct(testProduct);
      await mockRepo.createCompany(testCompany);

      await tester.pumpWidget(
        buildTestWidget(child: ProductDetailsScreen(productId: testProduct.id)),
      );
      await tester.pumpAndSettle();

      expect(find.text(testProduct.name), findsWidgets);
      // On mobile, the bottom bar is present
      expect(find.text('Add to Cart'), findsOneWidget);
    });
  });

  group('HomeScreen Web Full-Width & WebHeader Layout', () {
    testWidgets(
      'Desktop view renders WebHeader with logo and hides bottom nav',
      (tester) async {
        await mockRepo.saveProduct(testProduct);
        await mockRepo.createCompany(testCompany);

        await pumpTestApp(
          tester,
          const HomeScreen(),
          user: TestHarness.shopper,
          size: const Size(1600, 900),
        );

        // On desktop, WebHeader is present
        expect(find.byType(WebHeader), findsOneWidget);

        // App brand / logo text is visible
        expect(find.text('MyShop'), findsOneWidget);

        // Desktop bottom navigation bar is hidden
        expect(find.byType(MarketplaceBottomNav), findsNothing);

        // Body uses full available width (no restrictive 1200 constraint)
        final csv = tester.widget<CustomScrollView>(
          find.byType(CustomScrollView),
        );
        expect(csv.slivers.length, equals(1)); // Only body sliver on desktop
        final s0 = csv.slivers[0] as SliverPadding;
        final adapter = s0.child as SliverToBoxAdapter;
        final bodyPadding = adapter.child as Padding;
        expect(
          bodyPadding.padding,
          equals(const EdgeInsets.symmetric(horizontal: 24)),
        );
      },
    );

    testWidgets('Mobile view preserves coral header and MarketplaceBottomNav', (
      tester,
    ) async {
      await mockRepo.saveProduct(testProduct);
      await mockRepo.createCompany(testCompany);

      await pumpTestApp(
        tester,
        const HomeScreen(),
        user: TestHarness.shopper,
        size: const Size(375, 667),
      );

      // WebHeader is hidden on mobile
      expect(find.byType(WebHeader), findsNothing);

      // Mobile MarketplaceBottomNav is displayed
      expect(find.byType(MarketplaceBottomNav), findsOneWidget);

      // Mobile coral header is present
      final csv = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView),
      );
      expect(
        csv.slivers.length,
        equals(2),
      ); // Coral header sliver + body sliver
    });

    testWidgets(
      'Trending Now renders responsive GridView with dynamic columns on Desktop',
      (tester) async {
        await mockRepo.saveProduct(testProduct);
        for (int i = 1; i <= 6; i++) {
          await mockRepo.saveProduct(
            Product(
              id: 'trend_prod_$i',
              companyId: 'company_1',
              categoryId: 'cat_spices',
              name: 'Spice Item $i',
              amount: 100.0 + i * 10,
              discountAmt: 90.0 + i * 10,
              stockQty: 20,
              images: const ['https://example.com/item.jpg'],
            ),
          );
        }
        await mockRepo.createCompany(testCompany);

        // Desktop 1280px viewport
        await pumpTestApp(
          tester,
          const HomeScreen(shopId: 'company_1'),
          user: TestHarness.shopper,
          size: const Size(1280, 900),
        );
        await tester.pumpAndSettle();

        // On desktop, Trending Now renders a GridView rather than a ListView
        expect(find.byType(GridView), findsWidgets);
        expect(find.byType(ProductCard), findsWidgets);

        // Find the grid delegates in the tree
        final gridViews = tester.widgetList<GridView>(find.byType(GridView));
        final hasResponsiveTrendingGrid = gridViews.any((g) {
          final delegate = g.gridDelegate;
          if (delegate is SliverGridDelegateWithFixedCrossAxisCount) {
            // At 1280 width (minus 48 padding = 1232 available), columns is 5
            return delegate.crossAxisCount == 5;
          }
          return false;
        });
        expect(hasResponsiveTrendingGrid, isTrue);
      },
    );

    testWidgets('ProductCard wishlist heart icon toggles favorite state', (
      tester,
    ) async {
      await mockRepo.saveProduct(testProduct);
      await mockRepo.createCompany(testCompany);

      await tester.pumpWidget(
        buildTestWidget(
          child: const SizedBox(
            width: 240,
            child: ProductCard(product: testProduct, company: testCompany),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially heart is border / unselected
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      expect(wishlistCubit.state.contains(testProduct.id), isFalse);

      // Tap favorite button
      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      await tester.pumpAndSettle();

      // Now item is in wishlist and heart is filled
      expect(wishlistCubit.state.contains(testProduct.id), isTrue);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    });
  });

  group('Product Details Related Products (Same Category)', () {
    const mainProduct = Product(
      id: 'prod_main_spice',
      companyId: 'company_1',
      categoryId: 'cat_spices',
      name: 'Organic Cumin Powder',
      amount: 150.0,
      discountAmt: 130.0,
      stockQty: 30,
      images: ['https://example.com/cumin.jpg'],
    );

    const relatedProduct1 = Product(
      id: 'prod_related_1',
      companyId: 'company_1',
      categoryId: 'cat_spices',
      name: 'Organic Coriander Powder',
      amount: 140.0,
      discountAmt: 120.0,
      stockQty: 25,
      images: ['https://example.com/coriander.jpg'],
    );

    const relatedProduct2 = Product(
      id: 'prod_related_2',
      companyId: 'company_1',
      categoryId: 'cat_spices',
      name: 'Red Chilli Powder',
      amount: 160.0,
      discountAmt: 140.0,
      stockQty: 15,
      images: ['https://example.com/chilli.jpg'],
    );

    const differentCategoryProduct = Product(
      id: 'prod_diff_cat',
      companyId: 'company_1',
      categoryId: 'cat_grains',
      name: 'Basmati Rice',
      amount: 300.0,
      stockQty: 10,
    );

    const differentShopProduct = Product(
      id: 'prod_diff_shop',
      companyId: 'company_2',
      categoryId: 'cat_spices',
      name: 'Other Shop Spice',
      amount: 110.0,
      stockQty: 10,
    );

    testWidgets(
      'renders "More from this Category" excluding current product and other shops',
      (tester) async {
        await mockRepo.saveProduct(mainProduct);
        await mockRepo.saveProduct(relatedProduct1);
        await mockRepo.saveProduct(relatedProduct2);
        await mockRepo.saveProduct(differentCategoryProduct);
        await mockRepo.saveProduct(differentShopProduct);
        await mockRepo.createCompany(testCompany);

        await pumpTestApp(
          tester,
          const ProductDetailsScreen(productId: 'prod_main_spice'),
          user: TestHarness.shopper,
          size: const Size(1280, 900),
        );
        await tester.pumpAndSettle();

        // Section header is rendered
        expect(find.text('More from this Category'), findsOneWidget);

        // Related products from the same category and shop are rendered
        expect(find.text(relatedProduct1.name), findsOneWidget);
        expect(find.text(relatedProduct2.name), findsOneWidget);

        // Different category and different shop products are excluded
        expect(find.text(differentCategoryProduct.name), findsNothing);
        expect(find.text(differentShopProduct.name), findsNothing);

        // Main product is not duplicated in the related section
        final mainProductFinders = find.text(mainProduct.name);
        expect(mainProductFinders, findsOneWidget);
      },
    );
  });
}
