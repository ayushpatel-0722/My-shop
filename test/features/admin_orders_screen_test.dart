import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/order.dart';
import 'package:myshop/features/admin/orders/admin_orders_screen.dart';

import '../helpers/test_harness.dart';

void main() {
  late MockAppRepository repo;

  setUp(() {
    TestHarness.setupPlatformChannels();
    repo = TestHarness.useMockRepository();
    TestHarness.signIn(TestHarness.admin);
  });

  tearDown(() => TestHarness.signOut());

  Future<Order> placeOrder({
    String companyId = 'c_organic',
    String companyName = 'GreenLeaf Organics',
    String status = OrderStatus.pending,
    String userId = 'u1',
    List<OrderItem>? items,
  }) =>
      repo.placeOrder(
        Order(
          id: '',
          userId: userId,
          companyId: companyId,
          companyName: companyName,
          items: items ??
              const [
                OrderItem(
                  productId: 'p_tomato',
                  qty: 2,
                  unitPrice: 60,
                  name: 'Fresh Tomatoes',
                ),
              ],
          subtotal: 120,
          deliveryCharge: 30,
          totalAmount: 150,
          address: '12 Market Street',
          pincode: '380001',
          orderStatus: status,
        ),
      );

  testWidgets('shows only this store\'s orders', (tester) async {
    final mine = await placeOrder();
    final theirs = await placeOrder(
      companyId: 'c_techtronics',
      companyName: 'TechTronics Hub',
    );

    await pumpTestApp(tester, const AdminOrdersScreen());

    expect(
      find.byKey(Key('order-card-${mine.id}')),
      findsOneWidget,
    );
    expect(
      find.byKey(Key('order-card-${theirs.id}')),
      findsNothing,
      reason: 'another tenant\'s orders must not be visible',
    );
  });

  testWidgets('cancelled orders stay on the board', (tester) async {
    final order = await placeOrder();
    await repo.cancelOrder(order.id);

    await pumpTestApp(tester, const AdminOrdersScreen());

    // The cancelled column is rendered and the order is inside it.
    expect(find.text('Cancelled'), findsWidgets);
    expect(find.byKey(Key('order-card-${order.id}')), findsOneWidget);
  });

  testWidgets('advancing an order moves it to the next stage', (tester) async {
    final order = await placeOrder();

    await pumpTestApp(tester, const AdminOrdersScreen());

    await tester.tap(find.byKey(Key('order-advance-${order.id}')));
    await tester.pumpAndSettle();

    // Confirm dialog
    expect(find.text('Confirm Order'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm').last);
    await tester.pumpAndSettle();

    expect((await repo.order(order.id))!.orderStatus, OrderStatus.confirmed);
  });

  testWidgets('cancelling asks for confirmation and then cancels', (tester) async {
    final order = await placeOrder();

    await pumpTestApp(tester, const AdminOrdersScreen());

    await tester.tap(find.byKey(Key('order-cancel-${order.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Cancel this order?'), findsOneWidget);

    await tester.tap(find.text('Keep'));
    await tester.pumpAndSettle();
    expect((await repo.order(order.id))!.isCancelled, isFalse);

    await tester.tap(find.byKey(Key('order-cancel-${order.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel order'));
    await tester.pumpAndSettle();

    final stored = (await repo.order(order.id))!;
    expect(stored.isCancelled, isTrue);
    expect(stored.cancelledAt, isNotNull);
  });

  testWidgets('a completed order can neither advance nor be cancelled',
      (tester) async {
    final order = await placeOrder();
    for (final status in [
      OrderStatus.confirmed,
      OrderStatus.packing,
      OrderStatus.ready,
      OrderStatus.onTheWay,
      OrderStatus.completed,
    ]) {
      await repo.updateOrderStatus(order.id, status);
    }

    await pumpTestApp(tester, const AdminOrdersScreen());

    expect(find.byKey(Key('order-advance-${order.id}')), findsNothing);
    expect(find.byKey(Key('order-cancel-${order.id}')), findsNothing);
  });

  testWidgets('items quick preview dialog opens on tapping items button', (tester) async {
    final order = await repo.placeOrder(
      Order(
        id: '',
        userId: 'u1',
        companyId: 'c_organic',
        companyName: 'GreenLeaf Organics',
        items: const [
          OrderItem(productId: 'p_tomato', qty: 2, unitPrice: 60, name: 'Tomatoes'),
        ],
        subtotal: 120,
        discountAmount: 20,
        deliveryCharge: 30,
        totalAmount: 130,
        voucherCode: 'FRESH20',
        address: '12 Market Street',
        pincode: '380001',
      ),
    );

    await pumpTestApp(tester, const AdminOrdersScreen());

    await tester.tap(find.byKey(Key('order-items-btn-${order.id}')));
    await tester.pumpAndSettle();

    expect(find.text('Order Items (2)'), findsOneWidget);
    expect(find.text('Tomatoes'), findsOneWidget);
  });

  testWidgets('search filters the pipeline', (tester) async {
    final tomatoes = await placeOrder();
    final milk = await repo.placeOrder(
      Order(
        id: '',
        userId: 'u9',
        companyId: 'c_organic',
        companyName: 'GreenLeaf Organics',
        items: const [
          OrderItem(productId: 'p_milk', qty: 1, unitPrice: 40, name: 'Organic Cow Milk'),
        ],
        subtotal: 40,
        totalAmount: 40,
        address: '9 Park Lane',
        pincode: '400001',
      ),
    );

    await pumpTestApp(tester, const AdminOrdersScreen());
    expect(find.byKey(Key('order-card-${tomatoes.id}')), findsOneWidget);
    expect(find.byKey(Key('order-card-${milk.id}')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('order-search-field')),
      'milk',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(Key('order-card-${milk.id}')), findsOneWidget);
    expect(find.byKey(Key('order-card-${tomatoes.id}')), findsNothing);
  });

  testWidgets('an empty pipeline shows a helpful empty state', (tester) async {
    await pumpTestApp(tester, const AdminOrdersScreen());

    expect(find.text('No orders yet'), findsOneWidget);
  });

  testWidgets('status filters narrow the board', (tester) async {
    final pending = await placeOrder();
    final confirmed = await placeOrder();
    await repo.updateOrderStatus(confirmed.id, OrderStatus.confirmed);

    await pumpTestApp(tester, const AdminOrdersScreen());

    await tester.tap(find.text('Confirmed (1)'));
    await tester.pumpAndSettle();

    expect(find.byKey(Key('order-card-${pending.id}')), findsNothing);
    expect(find.byKey(Key('order-card-${confirmed.id}')), findsOneWidget);
  });
}
