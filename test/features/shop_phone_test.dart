import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/order.dart';
import 'package:myshop/core/widgets/shop_phone.dart';
import 'package:myshop/features/checkout/tracking/order_tracking_screen.dart';
import 'package:myshop/features/marketplace/company_store/company_store_screen.dart';

import '../helpers/test_harness.dart';

const _phone = '+91 98765 43210';

void main() {
  late MockAppRepository repo;

  setUp(() {
    TestHarness.setupPlatformChannels();
    repo = TestHarness.useMockRepository();
    TestHarness.signIn(TestHarness.shopper);
  });

  tearDown(() => TestHarness.signOut());

  Future<void> setShopPhone(String phone) async {
    final company = (await repo.company('c_organic'))!;
    await repo.updateCompanyDetails(company.copyWith(phone: phone));
  }

  group('dialableNumber', () {
    test('keeps digits and a leading +', () {
      expect(dialableNumber('+91 98765-43210'), '+919876543210');
      expect(dialableNumber('(079) 2345 6789'), '07923456789');
      expect(dialableNumber('  98765 43210 '), '9876543210');
      expect(dialableNumber(''), '');
    });
  });

  group('ShopContactCard', () {
    Future<void> pump(
      WidgetTester tester, {
      String companyId = 'c_organic',
      String fallback = '',
    }) => pumpTestApp(
      tester,
      Scaffold(
        body: ShopContactCard(companyId: companyId, fallbackPhone: fallback),
      ),
      user: TestHarness.shopper,
    );

    testWidgets('shows the phone number the shop admin entered', (
      tester,
    ) async {
      await setShopPhone(_phone);
      await pump(tester);
      expect(find.byKey(const Key('shop-contact-card')), findsOneWidget);
      expect(find.text('Contact the shop'), findsOneWidget);
      expect(find.text(_phone), findsOneWidget);
      expect(find.byKey(const Key('shop-call-button')), findsOneWidget);
    });

    testWidgets('shows nothing when the shop has no number', (tester) async {
      await pump(tester);
      expect(find.byKey(const Key('shop-contact-card')), findsNothing);
    });

    testWidgets('uses the fallback number only if the shop has none', (
      tester,
    ) async {
      await pump(tester, fallback: '0281 000 111');
      expect(find.text('0281 000 111'), findsOneWidget);
    });

    testWidgets('the shop\'s own number wins over the fallback', (
      tester,
    ) async {
      await setShopPhone(_phone);
      await pump(tester, fallback: '0281 000 111');
      expect(find.text(_phone), findsOneWidget);
      expect(find.text('0281 000 111'), findsNothing);
    });

    testWidgets('an unknown shop falls back instead of failing', (
      tester,
    ) async {
      await pump(tester, companyId: 'no_such_shop', fallback: '0281 000 111');
      expect(find.text('0281 000 111'), findsOneWidget);
    });

    testWidgets('where calling is not possible the number is copied', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await setShopPhone(_phone);
      await pump(tester);

      await tester.tap(find.byKey(const Key('shop-call-button')));
      // The platform call completes asynchronously.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Phone number copied'), findsOneWidget);
      expect(copied, _phone);
    });
  });

  group('shop page', () {
    Future<void> pumpStore(WidgetTester tester) => pumpTestApp(
      tester,
      const CompanyStoreScreen(slug: 'greenleaf-organics'),
      user: TestHarness.shopper,
      size: const Size(430, 6000),
    );

    testWidgets('shows the phone the admin added', (tester) async {
      await setShopPhone(_phone);
      await pumpStore(tester);
      expect(
        tester.widget<Text>(find.byKey(const Key('store-phone-number'))).data,
        _phone,
      );
      expect(find.text('Call shop'), findsOneWidget);
    });

    testWidgets('shows no phone row when none was added', (tester) async {
      await pumpStore(tester);
      expect(find.byKey(const Key('store-phone-row')), findsNothing);
    });
  });

  group('order tracking', () {
    Future<Order> place({
      String status = OrderStatus.completed,
      PickupShop? pickup,
    }) => repo.placeOrder(
      Order(
        id: '',
        userId: TestHarness.shopper.id,
        companyId: 'c_organic',
        companyName: 'GreenLeaf Organics',
        orderStatus: status,
        deliveryType: pickup == null ? 'home_delivery' : 'self_pickup',
        pickupShop: pickup,
        items: const [
          OrderItem(
            productId: 'p_tomato',
            qty: 1,
            unitPrice: 40,
            name: 'Fresh Tomatoes',
          ),
        ],
        subtotal: 40,
        totalAmount: 40,
        address: '12 Market Street',
      ),
    );

    Future<void> open(WidgetTester tester, Order order, {Size? size}) =>
        pumpTestApp(
          tester,
          OrderTrackingScreen(orderId: order.id, companyId: order.companyId),
          user: TestHarness.shopper,
          size: size ?? const Size(1200, 3000),
        );

    for (final entry in {
      'desktop': const Size(1200, 3000),
      'mobile': const Size(430, 3000),
    }.entries) {
      testWidgets('${entry.key}: shows the shop phone to call', (tester) async {
        await setShopPhone(_phone);
        final order = await place();
        await open(tester, order, size: entry.value);

        expect(find.byKey(const Key('shop-contact-card')), findsOneWidget);
        expect(find.text(_phone), findsOneWidget);
      });
    }

    testWidgets('no contact card when the shop has no number', (tester) async {
      final order = await place();
      await open(tester, order);
      expect(find.byKey(const Key('shop-contact-card')), findsNothing);
    });

    testWidgets('a pickup order falls back to the number saved on it', (
      tester,
    ) async {
      final order = await place(
        pickup: const PickupShop(
          name: 'GreenLeaf Organics',
          address: 'Market Road',
          phone: '0281 222 333',
        ),
      );
      await open(tester, order);
      expect(find.text('0281 222 333'), findsOneWidget);
    });

    testWidgets('a completed order offers the item reviews', (tester) async {
      final order = await place();
      await open(tester, order);
      expect(find.byKey(const Key('order-review-section')), findsOneWidget);
      expect(find.byKey(const Key('review-write-p_tomato')), findsOneWidget);
    });

    testWidgets('an order still in progress does not', (tester) async {
      final order = await place(status: OrderStatus.packing);
      await open(tester, order);
      expect(find.byKey(const Key('order-review-section')), findsNothing);
    });
  });
}
