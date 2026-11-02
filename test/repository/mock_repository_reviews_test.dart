import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/order.dart';
import 'package:myshop/core/models/review.dart';

Review review({
  String order = 'o1',
  String product = 'p1',
  int rating = 5,
  String message = '',
  String company = 'c_shop',
}) => Review(
  id: '',
  orderId: order,
  userId: 'u1',
  userName: 'Asha',
  companyId: company,
  productId: product,
  productName: 'Product $product',
  rating: rating,
  message: message,
);

void main() {
  late MockAppRepository repo;
  setUp(() => repo = MockAppRepository());

  group('submitReview', () {
    test('saves a review for a product of an order', () async {
      await repo.submitReview(review(rating: 4, message: 'Sturdy'));
      final saved = await repo.orderReviews('o1', companyId: 'c_shop');
      expect(saved, hasLength(1));
      expect(saved.single.id, 'o1_p1', reason: 'one stable id per product');
      expect(saved.single.rating, 4);
      expect(saved.single.message, 'Sturdy');
      expect(saved.single.productName, 'Product p1');
      expect(saved.single.isVisible, isTrue);
    });

    test(
      'reviewing the same product again edits it, never duplicates',
      () async {
        await repo.submitReview(review(rating: 2, message: 'Meh'));
        final first = (await repo.orderReviews(
          'o1',
          companyId: 'c_shop',
        )).single;

        await repo.submitReview(review(rating: 5, message: 'Grew on me'));
        final all = await repo.orderReviews('o1', companyId: 'c_shop');
        expect(all, hasLength(1));
        expect(all.single.rating, 5);
        expect(all.single.message, 'Grew on me');
        expect(
          all.single.createdAt,
          first.createdAt,
          reason: 'first date kept',
        );
      },
    );

    test('different products of one order get separate reviews', () async {
      await repo.submitReview(review(product: 'a', rating: 5));
      await repo.submitReview(review(product: 'b', rating: 3));
      final all = await repo.orderReviews('o1', companyId: 'c_shop');
      expect(all.map((r) => r.productId).toSet(), {'a', 'b'});
      expect(all.map((r) => r.id).toSet(), {'o1_a', 'o1_b'});
    });

    test('an order of its own is separate from another order', () async {
      await repo.submitReview(review(order: 'o1'));
      await repo.submitReview(review(order: 'o2'));
      expect(await repo.orderReviews('o1', companyId: 'c_shop'), hasLength(1));
      expect(await repo.orderReviews('o2', companyId: 'c_shop'), hasLength(1));
    });

    test('editing keeps a review the shop has hidden hidden', () async {
      await repo.submitReview(review(rating: 1, message: 'Rude message'));
      await repo.setReviewVisibility('o1_p1', false);

      await repo.submitReview(review(rating: 1, message: 'Still rude'));
      final saved = (await repo.orderReviews('o1', companyId: 'c_shop')).single;
      expect(saved.isVisible, isFalse, reason: 'a shopper cannot un-hide it');
      expect(saved.message, 'Still rude');
    });

    test(
      'does not touch the order (shoppers may only cancel orders)',
      () async {
        // The old implementation wrote reviewId onto the order, which the
        // security rules reject for shoppers, so Submit failed after saving.
        final placed = await repo.placeOrder(
          Order(
            id: '',
            userId: 'u1',
            companyId: 'c_shop',
            orderStatus: OrderStatus.completed,
            items: const [OrderItem(productId: 'p1', qty: 1, unitPrice: 10)],
            subtotal: 10,
            totalAmount: 10,
          ),
        );
        await repo.submitReview(
          review(order: placed.id, company: placed.companyId),
        );
        expect((await repo.order(placed.id))!.reviewId, isNull);
      },
    );

    test('rejects a rating outside 1-5', () async {
      expect(() => repo.submitReview(review(rating: 0)), throwsArgumentError);
      expect(() => repo.submitReview(review(rating: 6)), throwsArgumentError);
    });

    test('rejects a review without a shop or an order', () async {
      expect(() => repo.submitReview(review(company: '')), throwsArgumentError);
      expect(() => repo.submitReview(review(order: '')), throwsArgumentError);
    });
  });

  group('orderReviews / productReviews', () {
    test('only that shop\'s reviews are returned', () async {
      await repo.submitReview(review(company: 'c_a'));
      await repo.submitReview(review(company: 'c_b'));
      expect(await repo.orderReviews('o1', companyId: 'c_a'), hasLength(1));
      expect(await repo.orderReviews('o1', companyId: 'c_none'), isEmpty);
    });

    test(
      'productReviews lists a product\'s visible reviews across orders',
      () async {
        await repo.submitReview(review(order: 'o1', product: 'p1', rating: 5));
        await repo.submitReview(review(order: 'o2', product: 'p1', rating: 3));
        await repo.submitReview(review(order: 'o3', product: 'other'));
        await repo.setReviewVisibility('o2_p1', false);

        final list = await repo.productReviews('p1', companyId: 'c_shop');
        expect(list.map((r) => r.id), ['o1_p1'], reason: 'hidden one excluded');
      },
    );
  });

  group('Review model', () {
    test('round-trips the product fields', () {
      final r = Review.fromMap('x', {
        'orderId': 'o',
        'userId': 'u',
        'companyId': 'c',
        'productId': 'p',
        'productName': 'Chair',
        'rating': 4,
      });
      expect(r.productId, 'p');
      expect(r.productName, 'Chair');
      expect(r.toMap()['productId'], 'p');
      expect(r.toMap()['productName'], 'Chair');
    });

    test('an older whole-order review has no product', () {
      final r = Review.fromMap('x', {
        'orderId': 'o',
        'userId': 'u',
        'companyId': 'c',
        'rating': 5,
      });
      expect(r.productId, '');
      expect(Review.idFor(orderId: 'o'), 'o');
      expect(Review.idFor(orderId: 'o', productId: 'p'), 'o_p');
    });

    test('a rating stored as a double still loads', () {
      final r = Review.fromMap('x', {
        'orderId': 'o',
        'userId': 'u',
        'companyId': 'c',
        'rating': 4.0,
      });
      expect(r.rating, 4);
    });
  });
}
