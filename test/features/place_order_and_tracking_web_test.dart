import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/app/routes/app_router.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/order.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/features/checkout/cart/cart_cubit.dart';
import 'package:myshop/features/checkout/payment/checkout_screen.dart';
import 'package:myshop/features/checkout/tracking/order_tracking_screen.dart';
import 'package:myshop/features/checkout/tracking/orders_screen.dart';

import '../helpers/test_harness.dart';

void main() {
  late MockAppRepository repo;
  late CartCubit cart;

  setUp(() {
    TestHarness.setupPlatformChannels();
    repo = TestHarness.bootServiceLocator();
    TestHarness.signIn(TestHarness.shopperWithAddresses);
    cart = CartCubit();
  });

  tearDown(() => TestHarness.signOut());

  const sampleProduct = Product(
    id: 'p_pepper',
    companyId: 'c_organic',
    categoryId: 'cat_spices',
    name: 'Organic Black Pepper',
    amount: 120,
    discountAmt: 100,
    stockQty: 50,
  );

  testWidgets(
    'Place Order desktop layout displays 2-column layout with Order Summary and Trust Badges',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await repo.saveProduct(sampleProduct);

      cart.add(
        sampleProduct,
        companyId: 'c_organic',
        companyName: 'GreenLeaf Organics',
        qty: 2,
      );

      // Desktop test: width 1280
      await pumpTestApp(
        tester,
        const CheckoutScreen(),
        user: TestHarness.shopperWithAddresses,
        cartCubit: cart,
        size: const Size(1280, 1000),
      );
      expect(find.text('Order Summary'), findsOneWidget);
      expect(find.text('100% Safe & Secure Checkout'), findsOneWidget);
      expect(find.text('Trackable Direct Store Delivery'), findsOneWidget);
      expect(find.text('Verified Quality Products'), findsOneWidget);
      expect(
        find.byKey(const Key('checkout-place-order-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('checkout-store-card-c_organic')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'OrderTrackingScreen displays rich details on desktop without blank screen',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Place an order in repo
      final orders = await repo.placeOrders([
        Order(
          id: 'ord_test_web_001',
          userId: TestHarness.shopper.id,
          customerName: TestHarness.shopper.name,
          customerEmail: TestHarness.shopper.email,
          companyId: 'c_organic',
          companyName: 'GreenLeaf Organics',
          items: [
            const OrderItem(
              productId: 'p_pepper',
              qty: 2,
              unitPrice: 100,
              name: 'Organic Black Pepper',
            ),
          ],
          subtotal: 200,
          discountAmount: 0,
          deliveryCharge: 30,
          totalAmount: 230,
          address: '12 Market Street, Ahmedabad',
          pincode: '380001',
          orderStatus: OrderStatus.pending,
          createdAt: DateTime.now(),
        ),
      ]);
      final placedOrder = orders.first;

      await pumpTestApp(
        tester,
        OrderTrackingScreen(
          orderId: placedOrder.id,
          companyId: placedOrder.companyId,
        ),
        user: TestHarness.shopper,
      );
      await tester.pumpAndSettle();

      // Verify tracking screen has loaded correctly
      expect(
        find.textContaining('Order #${placedOrder.reference}'),
        findsWidgets,
      );
      expect(
        find.text('Tracking Timeline'),
        findsNothing,
      ); // Timeline uses stepper or icons
      expect(find.text('Ordered Items (1)'), findsOneWidget);
      expect(find.text('Organic Black Pepper'), findsOneWidget);
      expect(find.text('Delivery Details'), findsOneWidget);
      expect(find.textContaining('12 Market Street'), findsOneWidget);
      expect(find.text('Store / Vendor'), findsOneWidget);
      expect(find.textContaining('GreenLeaf Organics'), findsWidgets);
      expect(find.text('Subtotal'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('₹230'), findsOneWidget);
      expect(find.text('Continue Shopping'), findsOneWidget);
      expect(find.text('View All Orders'), findsOneWidget);
    },
  );

  testWidgets(
    'AppRoutes.orderPath incorporates companyId query parameter properly',
    (tester) async {
      final pathWithCompany = AppRoutes.orderPath(
        'ord_123',
        companyId: 'comp_456',
      );
      expect(pathWithCompany, '/order/ord_123?companyId=comp_456');

      final pathWithoutCompany = AppRoutes.orderPath('ord_123');
      expect(pathWithoutCompany, '/order/ord_123');
    },
  );

  testWidgets('Place Order mobile layout is preserved on compact screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await repo.saveProduct(sampleProduct);

    cart.add(
      sampleProduct,
      companyId: 'c_organic',
      companyName: 'GreenLeaf Organics',
      qty: 1,
    );

    await pumpTestApp(
      tester,
      const CheckoutScreen(),
      user: TestHarness.shopperWithAddresses,
      cartCubit: cart,
      size: const Size(400, 1600),
    );
    await tester.pumpAndSettle();

    // Verify mobile checkout elements
    expect(
      find.byKey(const Key('checkout-place-order-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('checkout-store-card-c_organic')),
      findsOneWidget,
    );
    // Desktop breadcrumbs and trust badges are desktop-only
    expect(find.text('100% Safe & Secure Checkout'), findsNothing);
  });

  testWidgets(
    'OrdersScreen desktop layout displays enhanced card with order metadata bar and actions',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final order = await repo.placeOrder(
        Order(
          id: 'ord_desktop_web_001',
          userId: TestHarness.shopper.id,
          customerName: TestHarness.shopper.name,
          customerEmail: TestHarness.shopper.email,
          companyId: 'c_organic',
          companyName: 'GreenLeaf Organics',
          items: const [
            OrderItem(
              productId: 'p_pepper',
              qty: 2,
              unitPrice: 100,
              name: 'Organic Black Pepper',
              variantLabel: '100g',
            ),
          ],
          subtotal: 200,
          deliveryCharge: 30,
          totalAmount: 230,
          orderStatus: OrderStatus.confirmed,
        ),
      );

      await pumpTestApp(
        tester,
        const OrdersScreen(),
        user: TestHarness.shopper,
        size: const Size(1280, 1000),
      );
      await tester.pumpAndSettle();

      // Check card presence
      expect(find.byKey(Key('order-card-${order.id}')), findsOneWidget);

      // Check Desktop Header Bar metadata labels
      expect(find.text('ORDER PLACED'), findsOneWidget);
      expect(find.text('TOTAL'), findsOneWidget);
      expect(find.text('STORE'), findsOneWidget);

      // Check order details
      expect(find.text('GreenLeaf Organics'), findsWidgets);
      expect(find.text('Organic Black Pepper'), findsOneWidget);
      expect(find.text('Qty: 2'), findsOneWidget);

      // Check desktop action column
      expect(find.byKey(Key('reorder-${order.id}')), findsOneWidget);
      expect(find.text('Track order'), findsOneWidget);
    },
  );
}
