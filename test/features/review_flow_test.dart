import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/domain/employee_roles.dart';
import 'package:myshop/core/models/order.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/core/models/review.dart';
import 'package:myshop/features/admin/reviews/admin_reviews_screen.dart';
import 'package:myshop/features/reviews/widgets/product_reviews_list.dart';

Order _order({String user = 'u1', String shop = 'c_shop'}) => Order(
  id: '',
  userId: user,
  companyId: shop,
  customerName: 'Asha Patel',
  customerPhone: '9876543210',
  items: const [
    OrderItem(productId: 'p1', name: 'Teak Shelf', qty: 1, unitPrice: 10),
  ],
);

Review _review(Order o, {String product = 'p1', int rating = 4}) => Review(
  id: '',
  orderId: o.id,
  userId: o.userId,
  userName: 'Asha',
  companyId: o.companyId,
  productId: product,
  productName: 'Teak Shelf',
  rating: rating,
  message: 'Sturdy',
);

Future<Order> _deliver(MockAppRepository repo, Order o) async {
  final placed = await repo.placeOrder(o);
  for (final s in [
    OrderStatus.confirmed,
    OrderStatus.packing,
    OrderStatus.ready,
    OrderStatus.onTheWay,
    OrderStatus.delivered,
  ]) {
    await repo.updateOrderStatus(placed.id, s, companyId: placed.companyId);
  }
  return placed;
}

void main() {
  late MockAppRepository repo;
  setUp(() => repo = MockAppRepository());

  group('the review completes the order', () {
    test('a delivered order is completed by its first review', () async {
      final o = await _deliver(repo, _order());
      expect((await repo.order(o.id))!.isDelivered, isTrue);

      await repo.submitReview(_review(o));

      final stored = (await repo.order(o.id))!;
      expect(stored.orderStatus, OrderStatus.completed);
      expect(stored.reviewId, '${o.id}_p1');
      expect(stored.statusHistory.last.status, OrderStatus.completed);
    });

    test('editing or a second review leaves the order completed', () async {
      final o = await _deliver(repo, _order());
      await repo.submitReview(_review(o));
      await repo.submitReview(_review(o, rating: 5));
      await repo.submitReview(_review(o, product: 'p2'));
      expect((await repo.order(o.id))!.orderStatus, OrderStatus.completed);
      expect(
        await repo.orderReviews(o.id, companyId: o.companyId),
        hasLength(2),
        reason: 'one review per product, never duplicated',
      );
    });

    test('an order that is not delivered yet cannot be reviewed', () async {
      final o = await repo.placeOrder(_order());
      await repo.updateOrderStatus(o.id, OrderStatus.confirmed);
      expect(() => repo.submitReview(_review(o)), throwsStateError);
      expect(await repo.orderReviews(o.id, companyId: o.companyId), isEmpty);
    });

    test('only the customer of the order can review it', () async {
      final o = await _deliver(repo, _order());
      final stranger = Review(
        id: '',
        orderId: o.id,
        userId: 'someone-else',
        companyId: o.companyId,
        productId: 'p1',
        rating: 5,
      );
      expect(() => repo.submitReview(stranger), throwsStateError);
      expect((await repo.order(o.id))!.isDelivered, isTrue);
    });

    test('nobody can complete a delivered order with a button', () {
      for (final perms in [
        const OrderPermissions.admin(),
        OrderPermissions.employee(
          EmployeeAccess(EmployeeRole.manager.fullPermissions),
        ),
      ]) {
        expect(
          perms.canMove(OrderStatus.delivered, OrderStatus.completed),
          isFalse,
        );
      }
    });
  });

  group('review details for the admin', () {
    test('joins the customer phone, order and product to a review', () async {
      final o = await _deliver(repo, _order());
      await repo.submitReview(_review(o));
      final reviews = await repo.reviews(o.companyId).first;
      final orders = await repo.orders(companyId: o.companyId).first;
      const product = Product(
        id: 'p1',
        companyId: 'c_shop',
        categoryId: 'c',
        name: 'Teak Shelf',
        details: 'Solid teak',
      );

      final d = joinReviewDetails(reviews, orders, [product]).single;
      expect(d.customerName, 'Asha Patel');
      expect(d.customerPhone, '9876543210');
      expect(d.orderRef, o.reference);
      expect(d.productName, 'Teak Shelf');
      expect(d.product?.details, 'Solid teak');
      expect(d.matches('9876543210'), isTrue, reason: 'search by mobile');
      expect(
        d.matches(o.id.toLowerCase()),
        isTrue,
        reason: 'search by order id',
      );
      expect(d.matches('nonexistent'), isFalse);
    });

    test('a review whose order is gone still lists, without a phone', () {
      const r = Review(
        id: 'x',
        orderId: 'gone',
        userId: 'u',
        userName: 'Asha',
        companyId: 'c_shop',
        rating: 3,
      );
      final d = joinReviewDetails([r], const [], const []).single;
      expect(d.customerName, 'Asha');
      expect(d.customerPhone, isEmpty);
    });

    test('the admin only gets their own shop\'s reviews', () async {
      final mine = await _deliver(repo, _order(shop: 'c_shop'));
      final other = await _deliver(repo, _order(shop: 'c_other'));
      await repo.submitReview(_review(mine));
      await repo.submitReview(_review(other));
      final list = await repo.reviews('c_shop').first;
      expect(list.map((r) => r.companyId).toSet(), {'c_shop'});
    });
  });

  group('product review list', () {
    test('keeps one product, hides hidden reviews from shoppers', () {
      const a = Review(
        id: '1',
        orderId: 'o',
        userId: 'u',
        companyId: 'c',
        productId: 'p1',
        rating: 5,
      );
      const b = Review(
        id: '2',
        orderId: 'o',
        userId: 'u',
        companyId: 'c',
        productId: 'p2',
        rating: 5,
      );
      const hidden = Review(
        id: '3',
        orderId: 'o',
        userId: 'u',
        companyId: 'c',
        productId: 'p1',
        rating: 1,
        isVisible: false,
      );
      final all = [a, b, hidden];
      expect(ProductReviewsList.forProduct(all, 'p1'), [a]);
      expect(ProductReviewsList.forProduct(all, 'p1', includeHidden: true), [
        a,
        hidden,
      ]);
    });
  });
}
