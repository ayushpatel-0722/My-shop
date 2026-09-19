import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/domain/order_status.dart';
import 'package:myshop/core/domain/voucher_evaluator.dart';
import 'package:myshop/core/models/order.dart';
import 'package:myshop/core/models/voucher.dart';

Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 1));

Order order({
  String id = '',
  String userId = 'u1',
  String companyId = 'c_organic',
  String companyName = 'GreenLeaf Organics',
  List<OrderItem>? items,
  double? subtotal,
  double discount = 0,
  double delivery = 0,
  double? total,
  String? voucherId,
  String voucherCode = '',
}) {
  final lines = items ??
      const [OrderItem(productId: 'p_tomato', qty: 2, unitPrice: 60, name: 'Tomatoes')];
  return Order(
    id: id,
    userId: userId,
    companyId: companyId,
    companyName: companyName,
    items: lines,
    subtotal: subtotal,
    discountAmount: discount,
    deliveryCharge: delivery,
    totalAmount: total,
    voucherId: voucherId,
    voucherCode: voucherCode,
    address: '12 Market Street',
    pincode: '380001',
  );
}

void main() {
  late MockAppRepository repo;

  setUp(() {
    repo = MockAppRepository();
  });

  group('placeOrder', () {
    test('assigns an id and a creation timestamp', () async {
      final placed = await repo.placeOrder(order());

      expect(placed.id, isNotEmpty);
      expect(placed.createdAt, isNotNull);
      expect(placed.orderStatus, OrderStatus.pending);
      expect(placed.paymentStatus, PaymentStatus.pending);
    });

    test('derives the total from the items when the caller omits it', () async {
      final placed = await repo.placeOrder(order());

      expect(placed.subtotal, 120);
      expect(placed.totalAmount, 120);
      expect(placed.isBalanced, isTrue);
    });

    test('keeps the full bill (discount + delivery) on the stored order', () async {
      final placed = await repo.placeOrder(
        order(subtotal: 500, discount: 75, delivery: 30, total: 455),
      );

      expect(placed.subtotal, 500);
      expect(placed.discountAmount, 75);
      expect(placed.deliveryCharge, 30);
      expect(placed.totalAmount, 455);
      expect(placed.isBalanced, isTrue);
    });

    test('rejects an order without a company or without items', () async {
      expect(
        () => repo.placeOrder(order(companyId: '')),
        throwsArgumentError,
      );
      expect(
        () => repo.placeOrder(order(items: const <OrderItem>[])),
        throwsArgumentError,
      );
    });

    test('decrements the stock of the ordered products', () async {
      final before = (await repo.product('p_tomato'))!;
      await repo.placeOrder(
        order(items: const [
          OrderItem(productId: 'p_tomato', qty: 5, unitPrice: 60, name: 'Tomatoes'),
        ]),
      );
      final after = (await repo.product('p_tomato'))!;

      expect(after.stockQty, before.stockQty - 5);
    });

    test('stock never drops below zero', () async {
      await repo.placeOrder(
        order(items: const [
          OrderItem(productId: 'p_tomato', qty: 99999, unitPrice: 60, name: 'Tomatoes'),
        ]),
      );
      expect((await repo.product('p_tomato'))!.stockQty, 0);
    });
  });

  group('placeOrder — voucher bookkeeping', () {
    test('records the redemption against the voucher', () async {
      await repo.saveVoucher(
        Voucher(
          id: 'v_once',
          companyId: 'c_organic',
          code: 'ONCE',
          discountType: VoucherType.fixedAmount,
          discountValue: 50,
          maxUses: 1,
          perUserLimit: 1,
          expiryDate: DateTime.now().add(const Duration(days: 10)),
        ),
      );

      final placed = await repo.placeOrder(
        order(voucherId: 'v_once', voucherCode: 'ONCE', discount: 50, subtotal: 200, total: 150),
      );

      final voucher = (await repo.voucherByCode('c_organic', 'ONCE'))!;
      expect(voucher.usageCount, 1);
      expect(voucher.usedOrderIds, contains(placed.id));
      expect(voucher.usageFor('u1'), 1);
    });

    test('a single-use voucher cannot be honoured twice', () async {
      await repo.saveVoucher(
        Voucher(
          id: 'v_single',
          companyId: 'c_organic',
          code: 'SINGLE',
          discountType: VoucherType.fixedAmount,
          discountValue: 50,
          maxUses: 1,
          perUserLimit: 1,
          expiryDate: DateTime.now().add(const Duration(days: 10)),
        ),
      );

      await repo.placeOrder(
        order(voucherId: 'v_single', voucherCode: 'SINGLE', subtotal: 200, discount: 50, total: 150),
      );

      // The evaluator is what checkout asks before accepting the code again.
      final voucher = (await repo.voucherByCode('c_organic', 'SINGLE'))!;
      final evaluation = const VoucherEvaluator().evaluate(
        voucher: voucher,
        items: const [],
        context: VoucherContext(now: DateTime.now(), userId: 'u2'),
      );
      expect(evaluation.isAccepted, isFalse);
      expect(evaluation.reason, VoucherRejection.usageLimitReached);
    });

    test('an unknown voucher id does not break the order', () async {
      final placed = await repo.placeOrder(order(voucherId: 'does-not-exist'));
      expect(placed.id, isNotEmpty);
    });
  });

  group('order status', () {
    test('follows the whole happy path', () async {
      final placed = await repo.placeOrder(order());

      await repo.updateOrderStatus(placed.id, OrderStatus.confirmed);
      await repo.updateOrderStatus(placed.id, OrderStatus.packing);
      await repo.updateOrderStatus(placed.id, OrderStatus.ready);
      await repo.updateOrderStatus(placed.id, OrderStatus.onTheWay);
      await repo.updateOrderStatus(placed.id, OrderStatus.completed);

      final stored = (await repo.order(placed.id))!;
      expect(stored.orderStatus, OrderStatus.completed);
      expect(stored.isOpen, isFalse);
    });

    test('refuses an illegal transition', () async {
      final placed = await repo.placeOrder(order());

      expect(
        () => repo.updateOrderStatus(placed.id, OrderStatus.completed),
        throwsArgumentError,
      );
      expect((await repo.order(placed.id))!.orderStatus, OrderStatus.pending);
    });

    test('refuses to move a completed order', () async {
      final placed = await repo.placeOrder(order());
      await repo.updateOrderStatus(placed.id, OrderStatus.confirmed);
      await repo.updateOrderStatus(placed.id, OrderStatus.packing);
      await repo.updateOrderStatus(placed.id, OrderStatus.ready);
      await repo.updateOrderStatus(placed.id, OrderStatus.onTheWay);
      await repo.updateOrderStatus(placed.id, OrderStatus.completed);

      expect(
        () => repo.updateOrderStatus(placed.id, OrderStatus.packing),
        throwsArgumentError,
      );
    });

    test('cancelOrder stamps cancelledAt', () async {
      final placed = await repo.placeOrder(order());
      await repo.updateOrderStatus(placed.id, OrderStatus.confirmed);
      await repo.cancelOrder(placed.id);

      final stored = (await repo.order(placed.id))!;
      expect(stored.isCancelled, isTrue);
      expect(stored.cancelledAt, isNotNull);
    });

    test('a dispatched order can no longer be cancelled', () async {
      final placed = await repo.placeOrder(order());
      await repo.updateOrderStatus(placed.id, OrderStatus.confirmed);
      await repo.updateOrderStatus(placed.id, OrderStatus.packing);
      await repo.updateOrderStatus(placed.id, OrderStatus.ready);
      await repo.updateOrderStatus(placed.id, OrderStatus.onTheWay);

      expect(() => repo.cancelOrder(placed.id), throwsArgumentError);
    });

    test('togglePaymentStatus flips between pending and done', () async {
      final placed = await repo.placeOrder(order());
      expect((await repo.order(placed.id))!.isPaid, isFalse);

      await repo.togglePaymentStatus(placed.id);
      expect((await repo.order(placed.id))!.isPaid, isTrue);

      await repo.togglePaymentStatus(placed.id);
      expect((await repo.order(placed.id))!.isPaid, isFalse);
    });
  });

  group('reading orders', () {
    test('orders() is scoped by user and by company', () async {
      await repo.placeOrder(order(userId: 'u1', companyId: 'c_organic'));
      await repo.placeOrder(order(userId: 'u2', companyId: 'c_organic'));
      await repo.placeOrder(order(userId: 'u3', companyId: 'c_techtronics'));

      final forUser = await repo.orders(userId: 'u1').first;
      expect(forUser.every((o) => o.userId == 'u1'), isTrue);
      expect(forUser, hasLength(1));

      final forCompany = await repo.orders(companyId: 'c_organic').first;
      expect(forCompany, hasLength(2));

      final everything = await repo.orders().first;
      expect(everything, hasLength(3));
    });

    test('orders() is sorted newest first', () async {
      final first = await repo.placeOrder(order(userId: 'u1'));
      await tick();
      final second = await repo.placeOrder(order(userId: 'u1'));

      final list = await repo.orders(userId: 'u1').first;
      expect(list.first.id, second.id);
      expect(list.last.id, first.id);
    });

    test('watchOrder emits the order and follows updates', () async {
      final placed = await repo.placeOrder(order());
      final seen = <Order?>[];
      final sub = repo.watchOrder(placed.id).listen(seen.add);
      await tick();

      await repo.updateOrderStatus(placed.id, OrderStatus.confirmed);
      await tick();

      expect(seen.length, greaterThanOrEqualTo(2));
      expect(seen.last?.orderStatus, OrderStatus.confirmed);
      await sub.cancel();
    });

    test('watchOrder emits null for an unknown id', () async {
      final seen = <Order?>[];
      final sub = repo.watchOrder('nope').listen(seen.add);
      await tick();
      expect(seen.last, isNull);
      await sub.cancel();
    });
  });
}
