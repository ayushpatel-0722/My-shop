import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/order.dart';
import 'package:myshop/core/models/review.dart';
import 'package:myshop/features/auth/auth_cubit.dart';
import 'package:myshop/features/checkout/cart/cart_cubit.dart';
import 'package:myshop/features/checkout/tracking/order_tracking_screen.dart';
import 'package:myshop/features/checkout/tracking/orders_screen.dart';

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
  }) => repo.placeOrder(
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
    await pumpTestApp(tester, const OrdersScreen(), authCubit: AuthCubit());

    expect(find.text('Sign In to View Orders'), findsOneWidget);
  });

  testWidgets('a shopper with no orders sees the empty state', (tester) async {
    await pumpTestApp(tester, const OrdersScreen(), user: TestHarness.shopper);

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

    await pumpTestApp(tester, const OrdersScreen(), user: TestHarness.shopper);

    expect(find.byKey(Key('order-card-${mine.id}')), findsOneWidget);
    expect(find.text('Order ${mine.reference}'), findsOneWidget);
    expect(find.text('₹280'), findsOneWidget, reason: '250 + 30 delivery');
  });

  testWidgets('the status filter narrows the list', (tester) async {
    final pending = await placeOrder(status: OrderStatus.pending);
    final delivered = await placeOrder(status: OrderStatus.completed);

    await pumpTestApp(tester, const OrdersScreen(), user: TestHarness.shopper);

    await tester.tap(find.text('Completed (1)'));
    await tester.pumpAndSettle();

    expect(find.byKey(Key('order-card-${delivered.id}')), findsOneWidget);
    expect(find.byKey(Key('order-card-${pending.id}')), findsNothing);
  });

  testWidgets('a cancelled order is visible and labelled', (tester) async {
    final order = await placeOrder();
    await repo.cancelOrder(order.id);

    await pumpTestApp(tester, const OrdersScreen(), user: TestHarness.shopper);

    await tester.tap(find.text('Cancelled (1)'));
    await tester.pumpAndSettle();

    expect(find.byKey(Key('order-card-${order.id}')), findsOneWidget);
    expect(find.text('Cancelled'), findsWidgets);
    // Reorder stays available whatever the status.
    expect(find.byKey(Key('reorder-${order.id}')), findsOneWidget);
  });

  testWidgets('tapping an order opens its tracking screen', (tester) async {
    final order = await placeOrder();

    await pumpTestApp(tester, const OrdersScreen(), user: TestHarness.shopper);

    await tester.tap(find.byKey(Key('order-card-${order.id}')));
    await tester.pumpAndSettle();

    expect(find.text('Order ${order.id}'), findsOneWidget);
  });

  testWidgets('the tracking screen shows the bill and allows cancelling', (
    tester,
  ) async {
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

  testWidgets('a dispatched order cannot be cancelled by the shopper', (
    tester,
  ) async {
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

  group('order card detail', () {
    testWidgets('shows the store, payment chip and a progress bar', (
      tester,
    ) async {
      final order = await placeOrder();

      await pumpTestApp(
        tester,
        const OrdersScreen(),
        user: TestHarness.shopper,
      );

      final card = find.byKey(Key('order-card-${order.id}'));
      expect(
        find.descendant(of: card, matching: find.text('GreenLeaf Organics')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('Pay on delivery')),
        findsOneWidget,
      );

      final bar = tester.widget<LinearProgressIndicator>(
        find.descendant(
          of: card,
          matching: find.byKey(Key('order-progress-${order.id}')),
        ),
      );
      expect(bar.value, closeTo(1 / 7, 0.001), reason: 'pending = stage 1/7');
    });

    testWidgets('the progress bar fills as the order advances', (tester) async {
      final order = await placeOrder();
      await repo.updateOrderStatus(order.id, OrderStatus.confirmed);
      await repo.updateOrderStatus(order.id, OrderStatus.packing);

      await pumpTestApp(
        tester,
        const OrdersScreen(),
        user: TestHarness.shopper,
      );

      final bar = tester.widget<LinearProgressIndicator>(
        find.byKey(Key('order-progress-${order.id}')),
      );
      expect(bar.value, closeTo(3 / 7, 0.001), reason: 'packing = stage 3/7');
    });

    testWidgets('a paid order shows the Paid chip', (tester) async {
      final order = await placeOrder();
      await repo.togglePaymentStatus(order.id);

      await pumpTestApp(
        tester,
        const OrdersScreen(),
        user: TestHarness.shopper,
      );

      expect(find.text('Paid'), findsOneWidget);
      expect(find.text('Pay on delivery'), findsNothing);
    });

    testWidgets('moving orders get an ETA from the store\'s handling time', (
      tester,
    ) async {
      final order = await placeOrder();
      await repo.updateOrderStatus(order.id, OrderStatus.confirmed);
      await repo.updateOrderStatus(order.id, OrderStatus.packing);

      await pumpTestApp(
        tester,
        const OrdersScreen(),
        user: TestHarness.shopper,
      );

      expect(find.byKey(Key('order-eta-${order.id}')), findsOneWidget);
      expect(find.textContaining('Arriving by'), findsOneWidget);
    });

    testWidgets('pickup orders get a ready-for-pickup ETA', (tester) async {
      final order = await repo.placeOrder(
        Order(
          id: '',
          userId: TestHarness.shopper.id,
          companyId: 'c_organic',
          companyName: 'GreenLeaf Organics',
          deliveryType: DeliveryType.selfPickup,
          items: const [
            OrderItem(productId: 'p_milk', qty: 1, unitPrice: 68, name: 'Milk'),
          ],
          subtotal: 68,
          totalAmount: 68,
        ),
      );
      await repo.updateOrderStatus(order.id, OrderStatus.confirmed);
      await repo.updateOrderStatus(order.id, OrderStatus.packing);

      await pumpTestApp(
        tester,
        const OrdersScreen(),
        user: TestHarness.shopper,
      );

      expect(find.textContaining('Ready for pickup by'), findsOneWidget);
    });

    testWidgets('the item preview shows thumbnails and a "+N more" chip', (
      tester,
    ) async {
      final order = await repo.placeOrder(
        Order(
          id: '',
          userId: TestHarness.shopper.id,
          companyId: 'c_organic',
          companyName: 'GreenLeaf Organics',
          items: const [
            OrderItem(productId: 'p_tomato', qty: 1, unitPrice: 48, name: 'A'),
            OrderItem(productId: 'p_spinach', qty: 1, unitPrice: 40, name: 'B'),
            OrderItem(productId: 'p_milk', qty: 1, unitPrice: 68, name: 'C'),
            OrderItem(productId: 'p_apple', qty: 1, unitPrice: 150, name: 'D'),
            OrderItem(productId: 'p_curd', qty: 1, unitPrice: 60, name: 'E'),
          ],
          subtotal: 366,
          totalAmount: 366,
        ),
      );

      await pumpTestApp(
        tester,
        const OrdersScreen(),
        user: TestHarness.shopper,
      );

      expect(find.text('+2 more'), findsOneWidget);
      expect(find.byKey(Key('order-card-${order.id}')), findsOneWidget);
    });

    testWidgets('reorder adds the same lines back to the cart', (tester) async {
      final cart = CartCubit();
      final order = await repo.placeOrder(
        Order(
          id: '',
          userId: TestHarness.shopper.id,
          companyId: 'c_organic',
          companyName: 'GreenLeaf Organics',
          items: const [
            OrderItem(productId: 'p_tomato', qty: 2, unitPrice: 48, name: 'A'),
            OrderItem(productId: 'p_milk', qty: 1, unitPrice: 68, name: 'B'),
          ],
          subtotal: 164,
          totalAmount: 164,
        ),
      );

      await pumpTestApp(
        tester,
        const OrdersScreen(),
        user: TestHarness.shopper,
        cartCubit: cart,
      );

      await tester.tap(find.byKey(Key('reorder-${order.id}')));
      await tester.pumpAndSettle();

      expect(cart.state.items.length, 2);
      final tomato = cart.state.items.firstWhere(
        (e) => e.product.id == 'p_tomato',
      );
      expect(tomato.qty, 2);
      expect(find.text('2 items added to cart'), findsOneWidget);
    });

    testWidgets('reorder restores the variant that was bought', (tester) async {
      final cart = CartCubit();
      final order = await repo.placeOrder(
        Order(
          id: '',
          userId: TestHarness.shopper.id,
          companyId: 'c_techtronics',
          companyName: 'TechTronics Hub',
          items: const [
            OrderItem(
              productId: 'p_phone',
              qty: 1,
              unitPrice: 24999,
              name: 'Nova X5',
              variantSku: 'NOVA-X5-BLK',
              variantTitle: 'Black',
            ),
          ],
          subtotal: 24999,
          totalAmount: 24999,
        ),
      );

      await pumpTestApp(
        tester,
        const OrdersScreen(),
        user: TestHarness.shopper,
        cartCubit: cart,
      );

      await tester.tap(find.byKey(Key('reorder-${order.id}')));
      await tester.pumpAndSettle();

      final line = cart.state.items.single;
      expect(line.product.id, 'p_phone');
      expect(line.variant?.variantId, 'NOVA-X5-BLK');
    });

    testWidgets('Rate your items lists the products and opens their review', (
      tester,
    ) async {
      final order = await placeOrder(status: OrderStatus.completed);

      await pumpTestApp(
        tester,
        const OrdersScreen(),
        user: TestHarness.shopper,
      );

      await tester.tap(find.byKey(Key('rate-items-${order.id}')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('order-review-section')), findsOneWidget);
      expect(find.byKey(const Key('review-item-p_tomato')), findsOneWidget);
      expect(find.text('Fresh Tomatoes'), findsWidgets);

      await tester.tap(find.byKey(const Key('review-write-p_tomato')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Leave review ${order.id}'), findsOneWidget);
      expect(find.textContaining('product=p_tomato'), findsOneWidget);
    });

    testWidgets('a reviewed product shows its stars and Edit review', (
      tester,
    ) async {
      final order = await placeOrder(status: OrderStatus.completed);
      await repo.submitReview(
        Review(
          id: '',
          orderId: order.id,
          userId: TestHarness.shopper.id,
          companyId: 'c_organic',
          productId: 'p_tomato',
          productName: 'Fresh Tomatoes',
          rating: 4,
        ),
      );

      await pumpTestApp(
        tester,
        const OrdersScreen(),
        user: TestHarness.shopper,
      );
      await tester.tap(find.byKey(Key('rate-items-${order.id}')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('review-write-p_tomato')), findsNothing);
      expect(find.byKey(const Key('review-edit-p_tomato')), findsOneWidget);
      final stars = find.descendant(
        of: find.byKey(const Key('review-stars-p_tomato')),
        matching: find.byIcon(Icons.star),
      );
      expect(stars, findsNWidgets(4), reason: 'a 4-star review');
    });

    testWidgets('orders that are not completed cannot be reviewed', (
      tester,
    ) async {
      final order = await placeOrder(status: OrderStatus.packing);

      await pumpTestApp(
        tester,
        const OrdersScreen(),
        user: TestHarness.shopper,
      );

      expect(find.byKey(Key('rate-items-${order.id}')), findsNothing);
    });
  });
}
