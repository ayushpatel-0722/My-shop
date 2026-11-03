import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/features/auth/widgets/auth_bottom_sheet.dart';
import 'package:myshop/features/checkout/cart/wishlist_cubit.dart';
import 'package:myshop/features/marketplace/widgets/product_card.dart';

import '../helpers/test_harness.dart';

/// The heart on a product card: like / unlike, login for guests, and the
/// confirmation shown only when a 26th favourite would replace the oldest.
void main() {
  late MockAppRepository mock;
  late WishlistCubit wishlist;

  Product product(int i) => Product(
    id: 'p$i',
    companyId: 'c1',
    categoryId: 'cat',
    name: 'Product $i',
    amount: 10,
    stockQty: 5,
  );

  setUp(() {
    TestHarness.setupPlatformChannels();
    mock = TestHarness.useMockRepository();
    TestHarness.signIn(TestHarness.shopper);
    wishlist = WishlistCubit()..bindUser(TestHarness.shopper.id);
  });

  tearDown(() async {
    await wishlist.close();
    TestHarness.signOut();
  });

  Future<void> pumpCard(
    WidgetTester tester, {
    required Product shown,
    bool guest = false,
  }) => pumpTestApp(
    tester,
    Scaffold(
      body: Center(
        child: SizedBox(width: 220, child: ProductCard(product: shown)),
      ),
    ),
    user: guest ? null : TestHarness.shopper,
    wishlistCubit: wishlist,
  );

  /// Saving runs on real event-loop turns, which pumping alone does not give.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  final outline = find.byIcon(Icons.favorite_border_rounded);
  final filled = find.byIcon(Icons.favorite_rounded);
  final dialog = find.byKey(const Key('favorite-limit-dialog'));

  Future<void> likeMany(WidgetTester tester, int n) async {
    await tester.runAsync(() async {
      for (var i = 0; i < n; i++) {
        await wishlist.like(product(i));
      }
    });
  }

  testWidgets('tapping the heart likes, tapping again unlikes', (tester) async {
    await pumpCard(tester, shown: product(1));
    expect(outline, findsOneWidget);

    await tester.tap(outline);
    await settle(tester);
    expect(filled, findsOneWidget);
    expect(wishlist.state.contains('p1'), isTrue);
    expect((await mock.favorites('u_1').first).single.productId, 'p1');

    await tester.tap(filled);
    await settle(tester);
    expect(outline, findsOneWidget);
    expect(wishlist.state.contains('p1'), isFalse);
    expect(await mock.favorites('u_1').first, isEmpty);
  });

  testWidgets('the first 25 likes never show the dialog', (tester) async {
    await likeMany(tester, 24);
    await pumpCard(tester, shown: product(24));
    await tester.tap(outline);
    await settle(tester);
    expect(dialog, findsNothing);
    expect(wishlist.state.count, 25);
  });

  testWidgets('the 26th shows the dialog; cancel changes nothing', (
    tester,
  ) async {
    await likeMany(tester, 25);
    await pumpCard(tester, shown: product(25));

    await tester.tap(outline);
    await settle(tester);
    expect(dialog, findsOneWidget);
    expect(find.textContaining('25'), findsWidgets);

    await tester.tap(find.byKey(const Key('favorite-limit-cancel')));
    await settle(tester);
    expect(dialog, findsNothing);
    expect(wishlist.state.count, 25);
    expect(wishlist.state.contains('p25'), isFalse);
    expect(wishlist.state.contains('p0'), isTrue);
    expect(outline, findsOneWidget);
  });

  testWidgets('confirming removes the oldest and likes the new product', (
    tester,
  ) async {
    await likeMany(tester, 25);
    await pumpCard(tester, shown: product(25));

    await tester.tap(outline);
    await settle(tester);
    await tester.tap(find.byKey(const Key('favorite-limit-confirm')));
    await settle(tester);

    expect(dialog, findsNothing);
    expect(wishlist.state.count, 25);
    expect(wishlist.state.contains('p0'), isFalse);
    expect(wishlist.state.contains('p25'), isTrue);
    expect(filled, findsOneWidget);
    final saved = await mock.favorites('u_1').first;
    expect(saved.first.productId, 'p1');
    expect(saved.last.productId, 'p25');
  });

  testWidgets('no dialog for a product that is already liked', (tester) async {
    await likeMany(tester, 25);
    await pumpCard(tester, shown: product(3));
    expect(filled, findsOneWidget);

    await tester.tap(filled); // unlike: allowed even when full
    await settle(tester);
    expect(dialog, findsNothing);
    expect(wishlist.state.contains('p3'), isFalse);
    expect(wishlist.state.count, 24);
  });

  testWidgets('a removed favourite can be added again', (tester) async {
    await pumpCard(tester, shown: product(1));
    await tester.tap(outline);
    await settle(tester);
    await tester.tap(filled);
    await settle(tester);
    await tester.tap(outline);
    await settle(tester);
    expect(wishlist.state.entries.map((e) => e.productId), ['p1']);
  });

  testWidgets('rapid taps leave exactly one favourite', (tester) async {
    await pumpCard(tester, shown: product(1));
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(Icons.favorite_border_rounded).first);
      await tester.pump();
    }
    await settle(tester);
    expect(
      wishlist.state.entries.where((e) => e.productId == 'p1').length,
      lessThanOrEqualTo(1),
    );
  });

  testWidgets('a guest is sent to login and nothing is saved', (tester) async {
    TestHarness.signOut();
    wishlist.bindUser(null);
    await pumpCard(tester, shown: product(1), guest: true);

    await tester.tap(outline);
    await settle(tester);

    expect(find.byType(AuthBottomSheet), findsOneWidget);
    expect(wishlist.state.count, 0);
    expect(await mock.favorites('u_1').first, isEmpty);
  });

  testWidgets('clearing the account empties the hearts on screen', (
    tester,
  ) async {
    await likeMany(tester, 1);
    await pumpCard(tester, shown: product(0));
    expect(filled, findsOneWidget);

    wishlist.bindUser(null);
    await tester.pumpAndSettle();
    expect(outline, findsOneWidget);
    expect(filled, findsNothing);
  });
}
