import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/order.dart';
import 'package:myshop/core/models/voucher.dart';
import 'package:myshop/features/admin/orders/admin_orders_screen.dart';
import 'package:myshop/features/checkout/tracking/orders_screen.dart';
import 'package:myshop/features/checkout/tracking/order_tracking_screen.dart';

import '../helpers/test_harness.dart';

void main() {
  late MockAppRepository repo;

  setUp(() {
    TestHarness.setupPlatformChannels();
    repo = TestHarness.useMockRepository();
  });

  tearDown(() {
    TestHarness.signOut();
  });

  Future<Order> placeOrder({
    String companyId = 'c_organic',
    String companyName = 'GreenLeaf Organics',
    String status = OrderStatus.pending,
    String userId = 'u_1',
    String productId = 'p_tomato',
    int qty = 2,
    double unitPrice = 60,
    String? voucherId,
  }) => repo.placeOrder(
    Order(
      id: '',
      userId: userId,
      companyId: companyId,
      companyName: companyName,
      items: [
        OrderItem(
          productId: productId,
          qty: qty,
          unitPrice: unitPrice,
          name: 'Fresh Product',
        ),
      ],
      subtotal: qty * unitPrice,
      deliveryCharge: 30,
      totalAmount: qty * unitPrice + 30,
      address: '12 Market Street',
      pincode: '380001',
      orderStatus: status,
      voucherId: voucherId,
    ),
  );

  group('Domain & Repository Order Cancellation Rules', () {
    test('Customer can cancel pending order successfully', () async {
      final order = await placeOrder();
      expect(order.orderStatus, OrderStatus.pending);

      await repo.cancelOrder(
        order.id,
        companyId: order.companyId,
        userId: order.userId,
      );

      final updated = await repo.order(order.id);
      expect(updated, isNotNull);
      expect(updated!.orderStatus, OrderStatus.cancelled);
      expect(updated.isCancelled, isTrue);
      expect(updated.cancelledAt, isNotNull);
      expect(updated.cancellationReason, 'Cancelled by customer');
      expect(updated.statusHistory.length, greaterThanOrEqualTo(2));
      expect(updated.statusHistory.last.status, OrderStatus.cancelled);
      expect(updated.statusHistory.last.note, 'Cancelled by customer');
    });

    test(
      'Customer cannot cancel confirmed, packing, ready, or completed order',
      () async {
        final nonCancellableStatuses = [
          OrderStatus.confirmed,
          OrderStatus.packing,
          OrderStatus.ready,
          OrderStatus.onTheWay,
          OrderStatus.completed,
        ];

        for (final st in nonCancellableStatuses) {
          final order = await placeOrder(status: st);
          expect(
            () => repo.cancelOrder(
              order.id,
              companyId: order.companyId,
              userId: order.userId,
            ),
            throwsA(isA<StateError>()),
          );
        }
      },
    );

    test('Customer cannot cancel another user\'s order', () async {
      final order = await placeOrder(userId: 'user_alice');

      expect(
        () => repo.cancelOrder(
          order.id,
          companyId: order.companyId,
          userId: 'user_bob',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('Cannot cancel an already cancelled order (idempotency)', () async {
      final order = await placeOrder();
      await repo.cancelOrder(
        order.id,
        companyId: order.companyId,
        userId: order.userId,
      );

      expect(
        () => repo.cancelOrder(
          order.id,
          companyId: order.companyId,
          userId: order.userId,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'Concurrent race condition: Admin confirms before customer cancel attempt',
      () async {
        final order = await placeOrder();

        // Admin confirms the order first
        await repo.updateOrderStatus(order.id, OrderStatus.confirmed);

        // Customer tries to cancel now
        expect(
          () => repo.cancelOrder(
            order.id,
            companyId: order.companyId,
            userId: order.userId,
          ),
          throwsA(
            predicate(
              (e) =>
                  e is StateError &&
                  e.message.contains(
                    'This order has already been confirmed by the store',
                  ),
            ),
          ),
        );
      },
    );
  });

  group('Multi-Shop Order Management', () {
    test(
      'Cancelling one shop order does not affect other shop orders from same checkout',
      () async {
        // Simulate multi-shop checkout placing two separate shop orders
        final orders = await repo.placeOrders([
          Order(
            id: '',
            userId: TestHarness.shopper.id,
            companyId: 'c_organic',
            companyName: 'GreenLeaf Organics',
            items: const [
              OrderItem(
                productId: 'p_tomato',
                qty: 2,
                unitPrice: 60,
                name: 'Tomatoes',
              ),
            ],
            subtotal: 120,
            totalAmount: 150,
            address: '12 Market Street',
            pincode: '380001',
            orderStatus: OrderStatus.pending,
          ),
          Order(
            id: '',
            userId: TestHarness.shopper.id,
            companyId: 'c_techtronics',
            companyName: 'TechTronics Hub',
            items: const [
              OrderItem(
                productId: 'p_cable',
                qty: 1,
                unitPrice: 200,
                name: 'HDMI Cable',
              ),
            ],
            subtotal: 200,
            totalAmount: 230,
            address: '12 Market Street',
            pincode: '380001',
            orderStatus: OrderStatus.pending,
          ),
        ]);

        expect(orders.length, 2);
        final shopAOrder = orders[0];
        final shopBOrder = orders[1];

        expect(shopAOrder.id, isNot(equals(shopBOrder.id)));
        expect(shopAOrder.companyId, 'c_organic');
        expect(shopBOrder.companyId, 'c_techtronics');

        // Cancel Shop A order only
        await repo.cancelOrder(
          shopAOrder.id,
          companyId: shopAOrder.companyId,
          userId: TestHarness.shopper.id,
        );

        final freshA = await repo.order(shopAOrder.id);
        final freshB = await repo.order(shopBOrder.id);

        expect(freshA!.orderStatus, OrderStatus.cancelled);
        expect(freshB!.orderStatus, OrderStatus.pending);
        expect(freshB.isCancelled, isFalse);
      },
    );
  });

  group('Inventory & Voucher Restoration', () {
    test(
      'Deducted stock is restored when order is cancelled and never restored twice',
      () async {
        final initialProduct = await repo.product('p_tomato');
        expect(initialProduct, isNotNull);
        final initialStock = initialProduct!.stockQty;

        // Place order for 3 items (stock decreases by 3)
        final order = await placeOrder(productId: 'p_tomato', qty: 3);
        final afterPlaceProduct = await repo.product('p_tomato');
        expect(afterPlaceProduct!.stockQty, initialStock - 3);

        // Cancel order -> stock restored by 3
        await repo.cancelOrder(
          order.id,
          companyId: order.companyId,
          userId: order.userId,
        );

        final afterCancelProduct = await repo.product('p_tomato');
        expect(afterCancelProduct!.stockQty, initialStock);

        final cancelledOrder = await repo.order(order.id);
        expect(cancelledOrder!.stockRestored, isTrue);
      },
    );

    test('Voucher usage is released upon order cancellation', () async {
      final voucher = Voucher(
        id: 'v_cancel_test',
        companyId: 'c_organic',
        code: 'CANCELTEST',
        discountType: VoucherType.fixedAmount,
        discountValue: 20,
        maxUses: 10,
        perUserLimit: 1,
      );
      await repo.saveVoucher(voucher);

      final order = await placeOrder(voucherId: voucher.id);
      final voucherAfterUse = await repo.voucherByCode(
        'c_organic',
        'CANCELTEST',
      );
      expect(voucherAfterUse!.usageCount, 1);
      expect(voucherAfterUse.usedOrderIds.contains(order.id), isTrue);

      // Cancel order
      await repo.cancelOrder(
        order.id,
        companyId: order.companyId,
        userId: order.userId,
      );

      final voucherAfterCancel = await repo.voucherByCode(
        'c_organic',
        'CANCELTEST',
      );
      expect(voucherAfterCancel!.usageCount, 0);
      expect(voucherAfterCancel.usedOrderIds.contains(order.id), isFalse);
    });
  });

  group('Customer UI Order Cancellation', () {
    testWidgets(
      'OrdersScreen displays Cancel Order button for pending order and cancels on confirmation',
      (tester) async {
        final order = await placeOrder();

        await pumpTestApp(
          tester,
          const OrdersScreen(),
          user: TestHarness.shopper,
        );

        // Verify Cancel Order button is present
        final cancelBtnFinder = find.byKey(Key('cancel-order-${order.id}'));
        expect(cancelBtnFinder, findsOneWidget);

        // Tap Cancel Order button
        await tester.tap(cancelBtnFinder);
        await tester.pumpAndSettle();

        // Verify Confirmation Dialog
        expect(find.text('Cancel Order?'), findsOneWidget);
        expect(
          find.text('Are you sure you want to cancel this order?'),
          findsOneWidget,
        );
        expect(find.text('Keep Order'), findsOneWidget);
        expect(find.text('Yes, Cancel Order'), findsOneWidget);

        // Tap "Keep Order" first -> dialog dismissed, order still pending
        await tester.tap(find.text('Keep Order'));
        await tester.pumpAndSettle();
        expect(find.text('Cancel Order?'), findsNothing);
        expect((await repo.order(order.id))!.isCancelled, isFalse);

        // Tap Cancel Order again and confirm
        await tester.tap(cancelBtnFinder);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Yes, Cancel Order'));
        await tester.pumpAndSettle();

        // Verify success snackbar and updated status
        expect(
          find.text('Order ${order.reference} cancelled successfully.'),
          findsOneWidget,
        );
        expect((await repo.order(order.id))!.isCancelled, isTrue);
      },
    );

    testWidgets(
      'Confirmed order shows In Progress and hides Cancel button on OrdersScreen',
      (tester) async {
        final order = await placeOrder(status: OrderStatus.confirmed);

        await pumpTestApp(
          tester,
          const OrdersScreen(),
          user: TestHarness.shopper,
        );

        expect(find.byKey(Key('cancel-order-${order.id}')), findsNothing);
        expect(find.text('In Progress'), findsOneWidget);
      },
    );

    testWidgets(
      'OrderTrackingScreen shows Cancel Order button and timeline for pending order',
      (tester) async {
        final order = await placeOrder();

        await pumpTestApp(
          tester,
          OrderTrackingScreen(orderId: order.id),
          user: TestHarness.shopper,
        );

        expect(
          find.byKey(Key('tracking-cancel-order-${order.id}')),
          findsOneWidget,
        );

        // Tap cancel and confirm
        await tester.tap(find.byKey(Key('tracking-cancel-order-${order.id}')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Yes, cancel'));
        await tester.pumpAndSettle();

        final updated = await repo.order(order.id);
        expect(updated!.isCancelled, isTrue);
        expect(find.text('Order Timeline'), findsOneWidget);
        expect(find.text('Cancelled by customer'), findsOneWidget);
      },
    );
  });

  group('Admin View Integration', () {
    testWidgets(
      'Admin sees customer cancellation reason and cannot advance cancelled order',
      (tester) async {
        final order = await placeOrder();

        // Customer cancels
        await repo.cancelOrder(
          order.id,
          companyId: order.companyId,
          userId: order.userId,
        );

        TestHarness.signIn(TestHarness.admin);

        await pumpTestApp(
          tester,
          const AdminOrdersScreen(),
          user: TestHarness.admin,
        );

        // Verify cancellation reason is shown
        expect(
          find.textContaining('Cancelled: Cancelled by customer'),
          findsOneWidget,
        );

        // Confirm button must NOT be present for cancelled order
        expect(find.byKey(Key('order-advance-${order.id}')), findsNothing);
        expect(find.byKey(Key('order-cancel-${order.id}')), findsNothing);
      },
    );
  });
}
