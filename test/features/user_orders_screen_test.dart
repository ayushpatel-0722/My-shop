import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/order.dart';
import 'package:myshop/features/auth/auth_cubit.dart';
import 'package:myshop/features/checkout/tracking/orders_screen.dart';
import 'package:myshop/features/checkout/tracking/order_tracking_screen.dart';

import '../helpers/test_harness.dart';

void main() {
  late MockAppRepository repo;

  setUp(() {
    TestHarness.setupPlatformChannels();
    repo = TestHarness.useMockRepository();
  });

  Future<Order> placeOrder({
    String status = OrderStatus.pending,
    double total = 250,
    String name = 'Fresh Tomatoes',
  }) =>
      repo.placeOrder(
        Order(
          id: '',
          userId: TestHarness.shopper.id,
          companyId: 'c_organic',
          companyName: 'GreenLeaf Organics',
          items: [
            OrderItem(
              productId: 'p_tomato',
              qty: 2,
              unitPrice: total / 2,
              name: name,
            ),
          ],
          subtotal: total,
          deliveryCharge: 30,
          totalAmount: total + 30,
          address: '12 Market Street',
          pincode: '380001',
          orderStatus: status,
        ),
      );

  testWidgets('guests are asked to sign in', (tester) async {
    await pumpTestApp(
      tester,
      const OrdersScreen(),
      authCubit: AuthCubit(),
    );

    expect(find.text('Sign In to View Orders'), findsOneWidget);
  });

  testWidgets('a shopper with no orders sees the empty state', (tester) async {
    await pumpTestApp(
      tester,
      const OrdersScreen(),
      user: TestHarness.shopper,
    );

    expect(find.text('No Orders Yet'), findsOneWidget);
  });

  testWidgets('lists the shopper\'s own orders only', (tester) async {
    final mine = await placeOrder();
    await repo.placeOrder(
      Order(
        id: '',
        userId: 'somebody_else',
        companyId: 'c_organic',
        companyName: 'GreenLeaf Organics',
        items: const [
          OrderItem(productId: 'p_milk', qty: 1, unitPrice: 40, name: 'Milk'),
        ],
        subtotal: 40,
        totalAmount: 40,
      ),
    );

    await pumpTestApp(
      tester,
      const OrdersScreen(),
      user: TestHarness.shopper,
    );

    expect(find.byKey(Key('order-card-${mine.id}')), findsOneWidget);
    expect(find.text('Order ${mine.reference}'), findsOneWidget);
    expect(find.text('₹280'), findsOneWidget, reason: '250 + 30 delivery');
  });

  testWidgets('the status filter narrows the list', (tester) async {
    final pending = await placeOrder(status: OrderStatus.pending);
    final delivered = await placeOrder(status: OrderStatus.completed);

    await pumpTestApp(
      tester,
      const OrdersScreen(),
      user: TestHarness.shopper,
    );

    await tester.tap(find.text('Completed (1)'));
    await tester.pumpAndSettle();

    expect(find.byKey(Key('order-card-${delivered.id}')), findsOneWidget);
    expect(find.byKey(Key('order-card-${pending.id}')), findsNothing);
  });

  testWidgets('a cancelled order is visible and labelled', (tester) async {
    final order = await placeOrder();
    await repo.cancelOrder(order.id);

    await pumpTestApp(
      tester,
      const OrdersScreen(),
      user: TestHarness.shopper,
    );

    await tester.tap(find.text('Cancelled (1)'));
    await tester.pumpAndSettle();

    expect(find.byKey(Key('order-card-${order.id}')), findsOneWidget);
    expect(find.text('Cancelled'), findsWidgets);
  });

  testWidgets('tapping an order opens its tracking screen', (tester) async {
    final order = await placeOrder();

    await pumpTestApp(
      tester,
      const OrdersScreen(),
      user: TestHarness.shopper,
    );

    await tester.tap(find.byKey(Key('order-card-${order.id}')));
    await tester.pumpAndSettle();

    expect(find.text('Order ${order.id}'), findsOneWidget);
  });

  testWidgets('the tracking screen shows the bill and allows cancelling',
      (tester) async {
    final order = await repo.placeOrder(
      Order(
        id: '',
        userId: TestHarness.shopper.id,
        companyId: 'c_organic',
        companyName: 'GreenLeaf Organics',
        items: const [
          OrderItem(productId: 'p_milk', qty: 2, unitPrice: 68, name: 'Milk'),
        ],
        subtotal: 136,
        discountAmount: 20,
        deliveryCharge: 30,
        totalAmount: 146,
        voucherCode: 'FRESH20',
        address: '12 Market Street',
        pincode: '380001',
      ),
    );

    await pumpTestApp(
      tester,
      OrderTrackingScreen(orderId: order.id),
      user: TestHarness.shopper,
    );

    expect(find.text('Subtotal'), findsOneWidget);
    expect(find.textContaining('Discount (FRESH20)'), findsOneWidget);
    expect(find.text('Delivery charge'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('₹146'), findsOneWidget);
    expect(
      find.text('₹136'),
      findsWidgets,
      reason: 'the subtotal row and the line total both read 136',
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel this order?'), findsOneWidget);

    await tester.tap(find.text('Yes, cancel'));
    await tester.pumpAndSettle();

    expect((await repo.order(order.id))!.isCancelled, isTrue);
  });

  testWidgets('a dispatched order cannot be cancelled by the shopper',
      (tester) async {
    final order = await placeOrder();
    await repo.updateOrderStatus(order.id, OrderStatus.confirmed);
    await repo.updateOrderStatus(order.id, OrderStatus.packing);
    await repo.updateOrderStatus(order.id, OrderStatus.ready);
    await repo.updateOrderStatus(order.id, OrderStatus.onTheWay);

    await pumpTestApp(
      tester,
      OrderTrackingScreen(orderId: order.id),
      user: TestHarness.shopper,
    );

    expect(find.text('Cancel'), findsNothing);
  });

  testWidgets('an unknown order id shows a friendly message', (tester) async {
    await pumpTestApp(
      tester,
      const OrderTrackingScreen(orderId: 'does-not-exist'),
      user: TestHarness.shopper,
    );

    expect(find.text('This order is no longer available.'), findsOneWidget);
  });
}
