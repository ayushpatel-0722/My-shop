import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myshop/app/routes/app_router.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/features/account/account_screen.dart';
import 'package:myshop/features/account/liked_products_screen.dart';
import 'package:myshop/features/checkout/cart/wishlist_cubit.dart';
import 'package:myshop/features/product/details/product_details_screen.dart';

import '../helpers/test_harness.dart';

/// The like button on the (mobile) product page, the Liked products entries in
/// Settings, and the list they open.
void main() {
  late MockAppRepository repo;
  late WishlistCubit wishlist;

  Product product(int i) => Product(
    id: 'lp$i',
    companyId: 'c_organic',
    categoryId: 'cat_x',
    name: 'Liked Item $i',
    amount: 200 + i.toDouble(),
    discountAmt: 150 + i.toDouble(),
    stockQty: 9,
    images: const ['https://example.com/p.jpg'],
  );

  setUp(() async {
    TestHarness.setupPlatformChannels();
    repo = TestHarness.useMockRepository();
    TestHarness.signIn(TestHarness.shopper);
    wishlist = WishlistCubit()..bindUser(TestHarness.shopper.id);
    for (var i = 0; i < 3; i++) {
      await repo.saveProduct(product(i));
    }
  });

  tearDown(() async {
    await wishlist.close();
    TestHarness.signOut();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> like(WidgetTester tester, int i) async {
    await tester.runAsync(() => wishlist.like(product(i)));
  }

  Future<void> open(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(390, 900),
  }) async {
    // The test font is wider than a real one and overflows a few tight rows;
    // that is not what these tests are about.
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      buildTestApp(
        child,
        user: TestHarness.shopper,
        wishlistCubit: wishlist,
        size: size,
        extraRoutes: [
          GoRoute(
            path: AppRoutes.favorites,
            // In the real app the providers sit above the router; here the
            // extra route is outside them, so give it the list explicitly.
            builder: (_, _) => BlocProvider<WishlistCubit>.value(
              value: wishlist,
              child: const LikedProductsScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.product,
            builder: (_, s) =>
                Scaffold(body: Text('PRODUCT PAGE ${s.pathParameters['id']}')),
          ),
        ],
      ),
    );
    await settle(tester);
  }

  group('mobile product page', () {
    testWidgets('shows a like button in the top bar', (tester) async {
      await open(tester, const ProductDetailsScreen(productId: 'lp0'));
      expect(find.byKey(const Key('favorite-button-lp0')), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border_rounded), findsWidgets);
    });

    testWidgets('tapping it likes, tapping again unlikes', (tester) async {
      await open(tester, const ProductDetailsScreen(productId: 'lp0'));
      await tester.tap(find.byKey(const Key('favorite-button-lp0')));
      await settle(tester);
      expect(wishlist.state.contains('lp0'), isTrue);
      expect(find.byIcon(Icons.favorite_rounded), findsWidgets);

      await tester.tap(find.byKey(const Key('favorite-button-lp0')));
      await settle(tester);
      expect(wishlist.state.contains('lp0'), isFalse);
    });

    testWidgets('an already liked product opens with a filled heart', (
      tester,
    ) async {
      await like(tester, 0);
      await open(tester, const ProductDetailsScreen(productId: 'lp0'));
      expect(find.byIcon(Icons.favorite_rounded), findsWidgets);
    });
  });

  group('Settings', () {
    testWidgets('has a Liked products entry that opens the list', (
      tester,
    ) async {
      await like(tester, 1);
      await open(tester, const AccountScreen());
      final tile = find.byKey(const Key('account-liked-products'));
      await tester.ensureVisible(tile);
      expect(find.text('Liked products'), findsOneWidget);
      await tester.tap(tile);
      await settle(tester);
      expect(find.byType(LikedProductsScreen), findsOneWidget);
      expect(find.text('Liked Item 1'), findsOneWidget);
    });

    testWidgets('the Saved card shows how many, and opens the list too', (
      tester,
    ) async {
      await like(tester, 0);
      await like(tester, 1);
      await open(tester, const AccountScreen());
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      await tester.tap(find.text('Saved'));
      await settle(tester);
      expect(find.byType(LikedProductsScreen), findsOneWidget);
    });
  });

  group('Liked products list', () {
    testWidgets('empty: says so', (tester) async {
      await open(tester, const LikedProductsScreen());
      expect(find.byKey(const Key('liked-empty')), findsOneWidget);
      expect(find.text('You have not liked any products yet.'), findsOneWidget);
    });

    testWidgets('lists every liked product, newest first', (tester) async {
      await like(tester, 0);
      await like(tester, 2);
      await like(tester, 1);
      await open(tester, const LikedProductsScreen());
      expect(find.byKey(const Key('liked-row-lp0')), findsOneWidget);
      expect(find.byKey(const Key('liked-row-lp1')), findsOneWidget);
      expect(find.byKey(const Key('liked-row-lp2')), findsOneWidget);
      final y1 = tester.getTopLeft(find.byKey(const Key('liked-row-lp1'))).dy;
      final y2 = tester.getTopLeft(find.byKey(const Key('liked-row-lp2'))).dy;
      final y0 = tester.getTopLeft(find.byKey(const Key('liked-row-lp0'))).dy;
      expect(y1 < y2 && y2 < y0, isTrue, reason: 'last liked is on top');
      expect(find.text('₹151'), findsOneWidget); // price of Liked Item 1
    });

    testWidgets('unliking from the list removes the row', (tester) async {
      await like(tester, 0);
      await like(tester, 1);
      await open(tester, const LikedProductsScreen());
      await tester.tap(find.byKey(const Key('favorite-button-lp0')));
      await settle(tester);
      expect(find.byKey(const Key('liked-row-lp0')), findsNothing);
      expect(find.byKey(const Key('liked-row-lp1')), findsOneWidget);
      expect(wishlist.state.contains('lp0'), isFalse);
    });

    testWidgets('tapping a product opens it', (tester) async {
      await like(tester, 2);
      await open(tester, const LikedProductsScreen());
      await tester.tap(find.byKey(const Key('liked-row-lp2')));
      await settle(tester);
      expect(find.text('PRODUCT PAGE lp2'), findsOneWidget);
    });

    testWidgets('a product the shop removed is flagged and can be dropped', (
      tester,
    ) async {
      await like(tester, 0);
      await tester.runAsync(
        () => repo.deleteProduct('lp0', companyId: 'c_organic'),
      );
      await open(tester, const LikedProductsScreen());
      expect(find.byKey(const Key('liked-row-gone-lp0')), findsOneWidget);
      expect(find.text('No longer available'), findsOneWidget);
      await tester.tap(find.byTooltip('Remove from liked'));
      await settle(tester);
      expect(find.byKey(const Key('liked-row-gone-lp0')), findsNothing);
      expect(wishlist.state.contains('lp0'), isFalse);
    });

    testWidgets('a new like appears without reopening', (tester) async {
      await open(tester, const LikedProductsScreen());
      expect(find.byKey(const Key('liked-empty')), findsOneWidget);
      await like(tester, 1);
      await settle(tester);
      expect(find.byKey(const Key('liked-row-lp1')), findsOneWidget);
    });
  });
}
