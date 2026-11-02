import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/core/models/review.dart';
import 'package:myshop/features/checkout/cart/cart_cubit.dart';
import 'package:myshop/features/checkout/cart/wishlist_cubit.dart';
import 'package:myshop/features/product/details/product_details_screen.dart';

import '../helpers/test_harness.dart';

/// The product page shows the product's real rating (it used to show a fixed
/// "4.5 / 120+ ratings & reviews" for every product).
void main() {
  late MockAppRepository repo;

  setUp(() async {
    TestHarness.setupPlatformChannels();
    repo = TestHarness.useMockRepository();
    TestHarness.signIn(TestHarness.shopper);
    await repo.saveProduct(
      const Product(
        id: 'p_chair',
        companyId: 'c_organic',
        name: 'Cane Dining Chair',
        amount: 4999,
        discountAmt: 3999,
        stockQty: 12,
        images: ['https://example.com/chair.jpg'],
      ),
    );
  });

  tearDown(() => TestHarness.signOut());

  Future<void> review(String order, int rating, {String product = 'p_chair'}) =>
      repo.submitReview(
        Review(
          id: '',
          orderId: order,
          userId: 'u_$order',
          userName: 'Shopper $order',
          companyId: 'c_organic',
          productId: product,
          productName: 'Cane Dining Chair',
          rating: rating,
        ),
      );

  Future<void> open(WidgetTester tester) => pumpTestApp(
    tester,
    const ProductDetailsScreen(productId: 'p_chair'),
    user: TestHarness.shopper,
    cartCubit: CartCubit(),
    wishlistCubit: WishlistCubit(),
  );

  String text(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data!;

  testWidgets('a product with no reviews says so', (tester) async {
    await open(tester);
    expect(find.byKey(const Key('product-no-reviews')), findsOneWidget);
    expect(find.text('No reviews yet'), findsOneWidget);
    expect(find.byKey(const Key('product-rating-row')), findsNothing);
  });

  testWidgets('shows the average and the number of reviews', (tester) async {
    await review('o1', 5);
    await review('o2', 4);
    await open(tester);

    expect(text(tester, 'product-rating-average'), '4.5');
    expect(text(tester, 'product-rating-count'), '2 ratings & reviews');
    expect(find.byKey(const Key('product-no-reviews')), findsNothing);
  });

  testWidgets('one review reads as singular', (tester) async {
    await review('o1', 3);
    await open(tester);
    expect(text(tester, 'product-rating-average'), '3.0');
    expect(text(tester, 'product-rating-count'), '1 rating & review');
  });

  testWidgets('a review the shop hid is not counted', (tester) async {
    await review('o1', 5);
    await review('o2', 1);
    await repo.setReviewVisibility('o2_p_chair', false);
    await open(tester);
    expect(text(tester, 'product-rating-average'), '5.0');
    expect(text(tester, 'product-rating-count'), '1 rating & review');
  });

  testWidgets('another product\'s reviews are not mixed in', (tester) async {
    await review('o1', 5);
    await review('o2', 1, product: 'p_other');
    await open(tester);
    expect(text(tester, 'product-rating-average'), '5.0');
  });

  testWidgets('the old fixed rating is gone', (tester) async {
    await open(tester);
    expect(find.text('120+ ratings & reviews'), findsNothing);
    // With no reviews there is no made-up average for this product.
    expect(find.byKey(const Key('product-rating-average')), findsNothing);
  });

  testWidgets('a review written after a purchase appears on the page', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('No reviews yet'), findsOneWidget);

    await review('o9', 4);
    await open(tester); // reopen the page
    expect(text(tester, 'product-rating-average'), '4.0');
  });

  testWidgets('shows in Gujarati too', (tester) async {
    await review('o1', 5);
    await pumpTestApp(
      tester,
      Builder(
        builder: (context) => Localizations.override(
          context: context,
          locale: const Locale('gu'),
          child: const ProductDetailsScreen(productId: 'p_chair'),
        ),
      ),
      user: TestHarness.shopper,
      cartCubit: CartCubit(),
      wishlistCubit: WishlistCubit(),
    );
    expect(text(tester, 'product-rating-count'), '1 રેટિંગ અને સમીક્ષા');
  });
}
