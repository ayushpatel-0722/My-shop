import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/order.dart';
import 'package:myshop/core/models/review.dart';
import 'package:myshop/core/services/service_locator.dart';
import 'package:myshop/features/auth/auth_cubit.dart';
import 'package:myshop/features/reviews/leave_review_screen.dart';

import '../helpers/test_harness.dart';

/// A repository whose review saving can be slow or can fail, to prove the
/// screen shows progress and errors instead of silently doing nothing.
class _TestRepo extends MockAppRepository {
  int submitCalls = 0;
  int failNext = 0;
  Duration delay = Duration.zero;

  @override
  Future<void> submitReview(Review review) async {
    submitCalls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (failNext > 0) {
      failNext--;
      throw Exception('permission-denied');
    }
    return super.submitReview(review);
  }
}

void main() {
  late _TestRepo repo;

  setUp(() {
    TestHarness.setupPlatformChannels();
    repo = _TestRepo();
    ServiceLocator.instance.repository = repo;
    TestHarness.signIn(TestHarness.shopper);
  });

  tearDown(() => TestHarness.signOut());

  Future<Order> place({
    String status = OrderStatus.completed,
    String userId = '',
  }) => repo.placeOrder(
    Order(
      id: '',
      userId: userId.isEmpty ? TestHarness.shopper.id : userId,
      companyId: 'c_organic',
      companyName: 'GreenLeaf Organics',
      orderStatus: status,
      items: const [
        OrderItem(
          productId: 'p_tomato',
          qty: 2,
          unitPrice: 40,
          name: 'Fresh Tomatoes',
          variantLabel: '500 g',
          image: 'https://img.example.com/tomato.jpg',
        ),
      ],
      subtotal: 80,
      totalAmount: 80,
    ),
  );

  Future<void> open(
    WidgetTester tester,
    Order order, {
    String productId = 'p_tomato',
    int rating = 5,
    AuthCubit? authCubit,
  }) async {
    await pumpTestApp(
      tester,
      LeaveReviewScreen(
        orderId: order.id,
        orderCompanyId: order.companyId,
        productId: productId,
        initialRating: rating,
      ),
      user: authCubit == null ? TestHarness.shopper : null,
      authCubit: authCubit,
    );
  }

  Finder key(String k) => find.byKey(Key(k));

  int filledStars(WidgetTester tester) => find
      .descendant(
        of: find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith('review-star-'),
        ),
        matching: find.byIcon(Icons.star),
      )
      .evaluate()
      .length;

  testWidgets('shows the product being reviewed', (tester) async {
    final order = await place();
    await open(tester, order);

    expect(find.text('Rate this product'), findsOneWidget);
    expect(
      tester.widget<Text>(key('review-product-name')).data,
      'Fresh Tomatoes',
    );
    expect(find.text('500 g'), findsOneWidget);
    expect(key('review-submit-button'), findsOneWidget);
    expect(find.text('Submit review'), findsOneWidget);
  });

  testWidgets('Submit saves the review and tells the shopper', (tester) async {
    final order = await place();
    await open(tester, order);

    await tester.tap(key('review-star-3'));
    await tester.pump();
    expect(filledStars(tester), 3);
    await tester.enterText(key('review-message-field'), '  Fresh and juicy  ');
    await tester.tap(key('review-submit-button'));
    await tester.pumpAndSettle();

    final saved = await repo.orderReviews(order.id, companyId: 'c_organic');
    expect(saved, hasLength(1));
    expect(saved.single.productId, 'p_tomato');
    expect(saved.single.productName, 'Fresh Tomatoes');
    expect(saved.single.rating, 3);
    expect(saved.single.message, 'Fresh and juicy', reason: 'trimmed');
    expect(saved.single.userId, TestHarness.shopper.id);
    expect(find.text('Thanks for your review!'), findsOneWidget);
  });

  testWidgets('a star count passed in is preselected', (tester) async {
    final order = await place();
    await open(tester, order, rating: 4);
    expect(filledStars(tester), 4);
  });

  testWidgets('submitting without typing a message is fine', (tester) async {
    final order = await place();
    await open(tester, order);
    await tester.tap(key('review-submit-button'));
    await tester.pumpAndSettle();
    final saved = await repo.orderReviews(order.id, companyId: 'c_organic');
    expect(saved.single.rating, 5);
    expect(saved.single.message, isEmpty);
  });

  testWidgets('while saving: spinner, locked controls, no double submit', (
    tester,
  ) async {
    repo.delay = const Duration(milliseconds: 400);
    final order = await place();
    await open(tester, order);

    await tester.tap(key('review-submit-button'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.descendant(
        of: key('review-submit-button'),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(key('review-submit-button')).onPressed,
      isNull,
    );
    expect(tester.widget<IconButton>(key('review-star-1')).onPressed, isNull);
    // A second tap while saving does nothing.
    await tester.tap(key('review-submit-button'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(repo.submitCalls, 1);
  });

  testWidgets('a failure is shown, the button comes back and a retry works', (
    tester,
  ) async {
    repo.failNext = 1;
    final order = await place();
    await open(tester, order);

    await tester.tap(key('review-submit-button'));
    await tester.pumpAndSettle();

    expect(key('review-error'), findsOneWidget);
    expect(
      tester.widget<Text>(key('review-error')).data,
      contains('Could not submit your review'),
    );
    expect(
      tester.widget<Text>(key('review-error')).data,
      contains('permission-denied'),
    );
    expect(
      tester.widget<FilledButton>(key('review-submit-button')).onPressed,
      isNotNull,
      reason: 'the shopper can try again',
    );
    expect(await repo.orderReviews(order.id, companyId: 'c_organic'), isEmpty);

    await tester.tap(key('review-submit-button'));
    await tester.pumpAndSettle();
    expect(repo.submitCalls, 2);
    expect(
      await repo.orderReviews(order.id, companyId: 'c_organic'),
      hasLength(1),
    );
    expect(find.text('Thanks for your review!'), findsOneWidget);
  });

  testWidgets('submitting never modifies the order', (tester) async {
    final order = await place();
    await open(tester, order);
    await tester.tap(key('review-submit-button'));
    await tester.pumpAndSettle();
    expect((await repo.order(order.id))!.reviewId, isNull);
  });

  group('editing an existing review', () {
    Future<void> seedReview(Order order) => repo.submitReview(
      Review(
        id: '',
        orderId: order.id,
        userId: TestHarness.shopper.id,
        companyId: 'c_organic',
        productId: 'p_tomato',
        productName: 'Fresh Tomatoes',
        rating: 2,
        message: 'A bit soft',
      ),
    );

    testWidgets('opens pre-filled and says it is an edit', (tester) async {
      final order = await place();
      await seedReview(order);
      await open(tester, order);

      expect(find.text('Edit your review'), findsOneWidget);
      expect(find.text('Update review'), findsOneWidget);
      expect(filledStars(tester), 2);
      expect(find.text('A bit soft'), findsOneWidget);
    });

    testWidgets('updating changes the one review, not adds another', (
      tester,
    ) async {
      final order = await place();
      await seedReview(order);
      await open(tester, order);

      await tester.tap(key('review-star-5'));
      await tester.enterText(key('review-message-field'), 'Better next time');
      await tester.tap(key('review-submit-button'));
      await tester.pumpAndSettle();

      final all = await repo.orderReviews(order.id, companyId: 'c_organic');
      expect(all, hasLength(1));
      expect(all.single.rating, 5);
      expect(all.single.message, 'Better next time');
      expect(find.text('Your review was updated.'), findsOneWidget);
    });
  });

  group('who can review', () {
    Future<void> expectBlocked(WidgetTester tester, String message) async {
      expect(key('review-blocked-message'), findsOneWidget);
      expect(tester.widget<Text>(key('review-blocked-message')).data, message);
      expect(key('review-submit-button'), findsNothing);
    }

    testWidgets('not before the order is delivered', (tester) async {
      final order = await place(status: OrderStatus.packing);
      await open(tester, order);
      await expectBlocked(
        tester,
        'You can review items once your order is delivered.',
      );
    });

    testWidgets('not someone else\'s order', (tester) async {
      final order = await place(userId: 'someone_else');
      await open(tester, order);
      await expectBlocked(tester, 'This order belongs to another account.');
    });

    testWidgets('not an order that does not exist', (tester) async {
      await pumpTestApp(
        tester,
        const LeaveReviewScreen(
          orderId: 'missing',
          orderCompanyId: 'c_organic',
          productId: 'p_tomato',
        ),
        user: TestHarness.shopper,
      );
      await expectBlocked(tester, 'We could not find this order.');
    });

    testWidgets('not a product that is not in the order', (tester) async {
      final order = await place();
      await open(tester, order, productId: 'p_unknown');
      await expectBlocked(tester, 'This product is not part of that order.');
    });

    testWidgets('not when signed out', (tester) async {
      final order = await place();
      await open(tester, order, authCubit: AuthCubit());
      await expectBlocked(tester, 'Please sign in to write a review.');
    });
  });

  testWidgets('works in Hindi', (tester) async {
    final order = await place();
    await pumpTestApp(
      tester,
      Builder(
        builder: (context) => Localizations.override(
          context: context,
          locale: const Locale('hi'),
          child: LeaveReviewScreen(
            orderId: order.id,
            orderCompanyId: order.companyId,
            productId: 'p_tomato',
          ),
        ),
      ),
      user: TestHarness.shopper,
    );
    expect(find.text('इस उत्पाद को रेट करें'), findsOneWidget);
    expect(find.text('समीक्षा सबमिट करें'), findsOneWidget);
    expect(find.text('Submit review'), findsNothing);
  });
}
