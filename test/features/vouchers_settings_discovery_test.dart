import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myshop/app/routes/app_router.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/category.dart';
import 'package:myshop/core/models/order.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/core/models/voucher.dart';
import 'package:myshop/features/account/account_screen.dart';
import 'package:myshop/features/account/liked_products_screen.dart';
import 'package:myshop/features/account/vouchers_screen.dart';
import 'package:myshop/features/checkout/cart/wishlist_cubit.dart';
import 'package:myshop/features/marketplace/home/home_screen.dart';
import 'package:myshop/features/marketplace/widgets/product_card.dart';
import 'package:myshop/features/product/details/product_details_screen.dart';

import '../helpers/test_harness.dart';

/// Voucher cards say which shop and what they apply to; Settings' three cards
/// show real counts and open the right screens; a product page ends with
/// more-from-category / recommended rows and a two-per-row Trending grid.
void main() {
  late MockAppRepository repo;
  late WishlistCubit wishlist;

  setUp(() async {
    TestHarness.setupPlatformChannels();
    repo = TestHarness.useMockRepository();
    TestHarness.signIn(TestHarness.shopper);
    wishlist = WishlistCubit()..bindUser(TestHarness.shopper.id);
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

  Future<void> open(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(390, 900),
  }) async {
    final original = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('overflowed')) return;
      original?.call(d);
    };
    addTearDown(() => FlutterError.onError = original);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    Widget scoped(Widget w) =>
        BlocProvider<WishlistCubit>.value(value: wishlist, child: w);
    await tester.pumpWidget(
      buildTestApp(
        child,
        user: TestHarness.shopper,
        wishlistCubit: wishlist,
        size: size,
        extraRoutes: [
          GoRoute(
            path: AppRoutes.favorites,
            builder: (_, _) => scoped(const LikedProductsScreen()),
          ),
          GoRoute(
            path: AppRoutes.vouchers,
            builder: (_, _) => scoped(const VouchersScreen()),
          ),
          GoRoute(
            path: AppRoutes.orders,
            builder: (_, _) => const Scaffold(body: Text('ORDERS TAB')),
          ),
        ],
      ),
    );
    await settle(tester);
  }

  Future<void> addVouchers() async {
    // Start from none: the mock repository comes with some of its own.
    for (final old in await repo.vouchers('').first) {
      await repo.deleteVoucher(old.id, companyId: old.companyId);
    }
    await repo.saveVoucher(
      Voucher(
        id: 'v_all',
        companyId: 'c_organic',
        code: 'ALLSHOP10',
        discountType: VoucherType.percentage,
        discountValue: 10,
        expiryDate: DateTime.now().add(const Duration(days: 30)),
      ),
    );
    await repo.saveCategory(
      const Category(id: 'cat_spice', companyId: 'c_organic', name: 'Spices'),
    );
    await repo.saveVoucher(
      Voucher(
        id: 'v_cat',
        companyId: 'c_organic',
        code: 'SPICE50',
        discountValue: 50,
        appliesTo: VoucherScope.specificCategory,
        categoryIds: const ['cat_spice'],
        expiryDate: DateTime.now().add(const Duration(days: 30)),
      ),
    );
    await repo.saveVoucher(
      Voucher(
        id: 'v_prod',
        companyId: 'c_techtronics',
        code: 'PHONE5',
        discountValue: 5,
        appliesTo: VoucherScope.specificProduct,
        productIds: const ['p_phone'],
        expiryDate: DateTime.now().add(const Duration(days: 30)),
      ),
    );
  }

  group('voucher cards', () {
    testWidgets(
      'Home cards list the shop and what it applies to, in a column',
      (tester) async {
        await addVouchers();
        await open(tester, const HomeScreen());

        String text(String key) =>
            tester.widget<Text>(find.byKey(Key(key))).data!;

        expect(text('voucher-shop-v_all'), 'GreenLeaf Organics');
        expect(text('voucher-target-v_all'), 'Applies to: All products');
        expect(text('voucher-shop-v_cat'), 'GreenLeaf Organics');
        expect(text('voucher-target-v_cat'), 'Applies to: Spices');

        // One under the other, left-aligned, not squeezed onto one line.
        final shop = tester.getTopLeft(
          find.byKey(const Key('voucher-shop-v_all')),
        );
        final target = tester.getTopLeft(
          find.byKey(const Key('voucher-target-v_all')),
        );
        expect(target.dy, greaterThan(shop.dy));
        expect((target.dx - shop.dx).abs(), lessThan(1));
      },
    );

    testWidgets('a product voucher on Home names the product', (tester) async {
      await addVouchers();
      await repo.saveProduct(
        const Product(
          id: 'p_phone',
          companyId: 'c_techtronics',
          categoryId: 'x',
          name: 'Nova X5 Smartphone',
          amount: 100,
          stockQty: 3,
        ),
      );
      await open(tester, const HomeScreen());
      // The rail scrolls sideways: bring the third card into view.
      await tester.drag(
        find.byKey(const Key('voucher-target-v_all')),
        const Offset(-700, 0),
      );
      await settle(tester);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('voucher-target-v_prod')))
            .data,
        'Applies to: Nova X5 Smartphone',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('voucher-shop-v_prod'))).data,
        'TechTronics Hub',
      );
    });

    testWidgets('a product voucher names the product', (tester) async {
      await addVouchers();
      await repo.saveProduct(
        const Product(
          id: 'p_phone',
          companyId: 'c_techtronics',
          categoryId: 'x',
          name: 'Nova X5 Smartphone',
          amount: 100,
          stockQty: 3,
        ),
      );
      await open(tester, const VouchersScreen());
      final text = tester.widget<Text>(
        find.byKey(const Key('voucher-target-v_prod')),
      );
      expect(text.data, endsWith('· Nova X5 Smartphone'));
    });
  });

  group('Vouchers screen', () {
    testWidgets('lists the usable vouchers with their conditions', (
      tester,
    ) async {
      await addVouchers();
      await open(tester, const VouchersScreen());
      expect(find.byKey(const Key('voucher-tile-v_all')), findsOneWidget);
      expect(find.byKey(const Key('voucher-tile-v_cat')), findsOneWidget);
      expect(find.text('ALLSHOP10'), findsOneWidget);
      expect(find.textContaining('Valid till'), findsWidgets);
    });

    testWidgets('an expired or paused voucher is not offered', (tester) async {
      await addVouchers();
      await repo.saveVoucher(
        Voucher(
          id: 'v_old',
          companyId: 'c_organic',
          code: 'OLD1',
          expiryDate: DateTime.now().subtract(const Duration(days: 1)),
        ),
      );
      await repo.saveVoucher(
        const Voucher(
          id: 'v_off',
          companyId: 'c_organic',
          code: 'OFF1',
          isActive: false,
        ),
      );
      await open(tester, const VouchersScreen());
      expect(find.byKey(const Key('voucher-tile-v_old')), findsNothing);
      expect(find.byKey(const Key('voucher-tile-v_off')), findsNothing);
    });

    testWidgets('copying a code says so', (tester) async {
      await addVouchers();
      await open(tester, const VouchersScreen());
      await tester.tap(find.byKey(const Key('voucher-copy-v_all')));
      await settle(tester);
      expect(find.textContaining('ALLSHOP10'), findsWidgets);
    });
  });

  group('Settings cards', () {
    Future<void> placeOrder(String userId) => repo.placeOrder(
      Order(
        id: '',
        userId: userId,
        companyId: 'c_organic',
        companyName: 'GreenLeaf Organics',
        items: const [
          OrderItem(productId: 'p1', qty: 1, unitPrice: 50, name: 'Honey'),
        ],
        subtotal: 50,
        totalAmount: 80,
        address: 'A',
        pincode: '380001',
      ),
    );

    String valueOf(WidgetTester tester, String card) => tester
        .widget<Text>(
          find
              .descendant(
                of: find.byKey(Key(card)),
                matching: find.byType(Text),
              )
              .first,
        )
        .data!;

    testWidgets('show the real counts', (tester) async {
      await addVouchers();
      await placeOrder('u_1');
      await placeOrder('u_1');
      await placeOrder('someone_else');
      await tester.runAsync(
        () => wishlist.like(
          const Product(id: 'z1', companyId: 'c_organic', name: 'Z'),
        ),
      );
      await open(tester, const AccountScreen());
      expect(valueOf(tester, 'stat-orders'), '2', reason: 'only my own orders');
      expect(valueOf(tester, 'stat-vouchers'), '3');
      expect(valueOf(tester, 'stat-saved'), '1');
    });

    testWidgets('Orders card opens the Orders tab', (tester) async {
      await open(tester, const AccountScreen());
      await tester.tap(find.byKey(const Key('stat-orders')));
      await settle(tester);
      expect(find.text('ORDERS TAB'), findsOneWidget);
    });

    testWidgets('Vouchers card opens the vouchers list', (tester) async {
      await addVouchers();
      await open(tester, const AccountScreen());
      await tester.tap(find.byKey(const Key('stat-vouchers')));
      await settle(tester);
      expect(find.byType(VouchersScreen), findsOneWidget);
      expect(find.byKey(const Key('voucher-tile-v_all')), findsOneWidget);
    });

    testWidgets('Saved card opens the liked products', (tester) async {
      await open(tester, const AccountScreen());
      await tester.tap(find.byKey(const Key('stat-saved')));
      await settle(tester);
      expect(find.byType(LikedProductsScreen), findsOneWidget);
    });

    testWidgets('counts follow changes (a new like, a new order)', (
      tester,
    ) async {
      await open(tester, const AccountScreen());
      expect(valueOf(tester, 'stat-orders'), '0');
      await placeOrder('u_1');
      await tester.runAsync(
        () => wishlist.like(
          const Product(id: 'z2', companyId: 'c_organic', name: 'Z'),
        ),
      );
      await settle(tester);
      expect(valueOf(tester, 'stat-orders'), '1');
      expect(valueOf(tester, 'stat-saved'), '1');
    });
  });

  group('product page: what to look at next', () {
    Product item(int i, {String cat = 'cat_x'}) => Product(
      id: 'd$i',
      companyId: 'c_organic',
      categoryId: cat,
      name: 'Discover $i',
      amount: 100 + i.toDouble(),
      stockQty: 5,
      images: const ['https://example.com/p.jpg'],
    );

    Future<void> seed(int n) async {
      for (var i = 0; i < n; i++) {
        await repo.saveProduct(item(i));
      }
    }

    Future<void> scrollTo(WidgetTester tester, Finder f) async {
      for (var i = 0; i < 14 && f.evaluate().isEmpty; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.ensureVisible(f);
      await tester.pump(const Duration(milliseconds: 200));
    }

    testWidgets('has the three sections, in order, under the product', (
      tester,
    ) async {
      await seed(14);
      await open(tester, const ProductDetailsScreen(productId: 'd0'));
      await scrollTo(tester, find.byKey(const Key('discovery-trending')));
      final cat = tester
          .getTopLeft(find.byKey(const Key('discovery-category')))
          .dy;
      final rec = tester
          .getTopLeft(find.byKey(const Key('discovery-recommended')))
          .dy;
      final trend = tester
          .getTopLeft(find.byKey(const Key('discovery-trending')))
          .dy;
      expect(cat < rec && rec < trend, isTrue);
      expect(find.text('More from this Category'), findsOneWidget);
      expect(find.text('Recommended for you'), findsOneWidget);
      expect(find.text('Trending Now 🔥'), findsOneWidget);
    });

    testWidgets('"more from this category" and "recommended" scroll sideways', (
      tester,
    ) async {
      await seed(14);
      await open(tester, const ProductDetailsScreen(productId: 'd0'));
      await scrollTo(tester, find.byKey(const Key('discovery-trending')));
      for (final key in ['discovery-category', 'discovery-recommended']) {
        final list = find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byType(ListView),
        );
        expect(list, findsOneWidget, reason: key);
        expect(
          tester.widget<ListView>(list).scrollDirection,
          Axis.horizontal,
          reason: key,
        );
      }
    });

    testWidgets('Trending is a grid with two products per row on a phone', (
      tester,
    ) async {
      await seed(14);
      await open(tester, const ProductDetailsScreen(productId: 'd0'));
      await scrollTo(tester, find.byKey(const Key('discovery-trending')));
      final grid = tester.widget<GridView>(
        find.descendant(
          of: find.byKey(const Key('discovery-trending')),
          matching: find.byType(GridView),
        ),
      );
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 2);
    });

    testWidgets('the product being viewed is in none of them', (tester) async {
      await seed(14);
      await open(tester, const ProductDetailsScreen(productId: 'd0'));
      await scrollTo(tester, find.byKey(const Key('discovery-trending')));
      for (final key in [
        'discovery-category',
        'discovery-recommended',
        'discovery-trending',
      ]) {
        final cards = tester.widgetList<ProductCard>(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(ProductCard),
          ),
        );
        expect(cards, isNotEmpty, reason: key);
        expect(cards.any((c) => c.product.id == 'd0'), isFalse, reason: key);
      }
    });

    testWidgets('Trending shows a page, then more on "Show more"', (
      tester,
    ) async {
      await seed(30);
      await open(tester, const ProductDetailsScreen(productId: 'd0'));
      await scrollTo(tester, find.byKey(const Key('discovery-trending')));
      int inGrid() => find
          .descendant(
            of: find.byKey(const Key('discovery-trending')),
            matching: find.byType(ProductCard),
          )
          .evaluate()
          .length;
      final first = inGrid();
      expect(first, lessThanOrEqualTo(10));
      final more = find.byKey(const Key('discovery-trending-more'));
      await scrollTo(tester, more);
      await tester.tap(more);
      await tester.pump(const Duration(milliseconds: 300));
      expect(inGrid(), greaterThan(first));
    });
  });
}
