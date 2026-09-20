import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/models/order.dart';

void main() {
  group('Order — money fields', () {
    final order = Order(
      id: 'o1',
      userId: 'u1',
      companyId: 'c1',
      items: const [
        OrderItem(productId: 'p1', qty: 2, unitPrice: 100, name: 'Honey'),
        OrderItem(productId: 'p2', qty: 1, unitPrice: 50, name: 'Tea'),
      ],
      discountAmount: 30,
      deliveryCharge: 25,
      totalAmount: 245,
    );

    test('subtotal defaults to the sum of the lines', () {
      expect(order.itemsTotal, 250);
      expect(order.subtotal, 250);
      expect(order.itemCount, 3);
    });

    test('the bill balances', () {
      expect(order.isBalanced, isTrue, reason: '250 - 30 + 25 = 245');
    });

    test('a mismatched total is detectable', () {
      expect(order.copyWith(totalAmount: 100).isBalanced, isFalse);
    });

    test('discount and delivery survive a round trip', () {
      final restored = Order.fromMap('o1', order.toMap());
      expect(restored.subtotal, 250);
      expect(restored.discountAmount, 30);
      expect(restored.deliveryCharge, 25);
      expect(restored.totalAmount, 245);
      expect(restored.items.length, 2);
    });

    test('negative quantities cannot inflate a total', () {
      final weird = Order(
        id: 'o2',
        userId: 'u1',
        companyId: 'c1',
        items: const [OrderItem(productId: 'p1', qty: -5, unitPrice: 100)],
      );
      expect(weird.itemCount, 0);
      expect(weird.itemsTotal, 0);
    });
  });

  group('Order — parsing resilience', () {
    test('legacy documents without billing fields still work', () {
      final order = Order.fromMap('legacy', {
        'userId': 'u1',
        'companyId': 'c1',
        'totalAmount': 500,
        'orderStatus': 'pending',
        'items': [
          {'productId': 'p1', 'qty': 2, 'unitPrice': 250, 'name': 'Honey'},
        ],
      });

      expect(order.totalAmount, 500);
      expect(order.subtotal, 500, reason: 'derived from the items');
      expect(order.discountAmount, 0);
      expect(order.deliveryCharge, 0);
    });

    test('numbers stored as strings are parsed', () {
      final order = Order.fromMap('x', {
        'totalAmount': '99.5',
        'subtotal': '120',
        'discountAmount': '20',
        'deliveryCharge': '0',
        'qty': '3',
        'items': [
          {'productId': 'p1', 'qty': '2', 'unitPrice': '60'},
        ],
      });
      expect(order.totalAmount, 99.5);
      expect(order.subtotal, 120);
      expect(order.itemsTotal, 120);
      expect(order.items.single.qty, 2);
    });

    test('garbage values fall back to defaults instead of throwing', () {
      final order = Order.fromMap('x', {
        'totalAmount': null,
        'items': 'not-a-list',
        'orderStatus': 42,
      });
      expect(order.items, isEmpty);
      expect(order.totalAmount, 0);
      expect(order.orderStatus, OrderStatus.pending);
    });

    test('an unknown status degrades to pending', () {
      final order = Order.fromMap('x', {'orderStatus': 'teleported'});
      expect(order.orderStatus, OrderStatus.pending);
    });

    test('an unknown delivery type degrades to home delivery', () {
      final order = Order.fromMap('x', {'deliveryType': 'drone'});
      expect(order.deliveryType, DeliveryType.homeDelivery);
      expect(order.isSelfPickup, isFalse);
    });

    test('empty strings are not stored as empty-string ids', () {
      final order = Order.fromMap('x', {
        'voucherId': '',
        'assignedEmployeeId': '',
        'reviewId': '',
      });
      expect(order.voucherId, isNull);
      expect(order.assignedEmployeeId, isNull);
      expect(order.reviewId, isNull);
    });
  });

  group('Order — lifecycle helpers', () {
    test('status flags', () {
      final pending = Order(id: 'o', userId: 'u', companyId: 'c');
      expect(pending.isOpen, isTrue);
      expect(pending.isPending, isTrue);

      final cancelled = pending.copyWith(orderStatus: OrderStatus.cancelled);
      expect(cancelled.isCancelled, isTrue);
      expect(cancelled.isOpen, isFalse);

      final completed = pending.copyWith(orderStatus: OrderStatus.completed);
      expect(completed.isCompleted, isTrue);
      expect(completed.isOpen, isFalse);
    });

    test('withStatus stamps cancelledAt only when cancelling', () {
      final now = DateTime(2026, 6, 1, 10);
      final order = Order(id: 'o', userId: 'u', companyId: 'c');

      final packed = order.withStatus(OrderStatus.packing, now: now);
      expect(packed.orderStatus, OrderStatus.packing);
      expect(packed.updatedAt, now);
      expect(packed.cancelledAt, isNull);

      final cancelled = packed.withStatus(OrderStatus.cancelled, now: now);
      expect(cancelled.cancelledAt, now);

      final reopened = cancelled.withStatus(OrderStatus.pending, now: now);
      expect(reopened.cancelledAt, isNull);
    });

    test('withStatus can flip the payment flag', () {
      final order = Order(id: 'o', userId: 'u', companyId: 'c');
      expect(order.isPaid, isFalse);
      expect(
        order.withStatus(OrderStatus.confirmed, paid: true).isPaid,
        isTrue,
      );
    });

    test('withStatus clears payment when cancelling', () {
      final order = Order(
        id: 'o',
        userId: 'u',
        companyId: 'c',
        paymentStatus: PaymentStatus.done,
      );
      expect(order.withStatus(OrderStatus.cancelled).isPaid, isFalse);
    });

    test('reference is safe for short and long ids', () {
      expect(Order(id: 'abc', userId: 'u', companyId: 'c').reference, '#ABC');
      expect(
        Order(id: 'abcdefghij', userId: 'u', companyId: 'c').reference,
        '#ABCDEF',
      );
      expect(Order(id: '', userId: 'u', companyId: 'c').reference, '#—');
    });

    test('copyWithItems keeps the billing fields', () {
      final order = Order(
        id: 'o',
        userId: 'u',
        companyId: 'c',
        subtotal: 100,
        discountAmount: 10,
        deliveryCharge: 5,
        totalAmount: 95,
      );
      final updated = order.copyWithItems(const [
        OrderItem(productId: 'p9', qty: 1, unitPrice: 60),
      ]);
      expect(updated.items.single.productId, 'p9');
      expect(updated.subtotal, 100, reason: 'the stored bill is preserved');
      expect(updated.totalAmount, 95);
    });
  });
}
