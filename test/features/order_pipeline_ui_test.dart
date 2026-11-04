import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/order.dart';
import 'package:myshop/features/admin/orders/admin_order_details_screen.dart';
import 'package:myshop/features/admin/orders/admin_orders_screen.dart';
import 'package:myshop/features/admin/orders/widgets/order_filter_bar.dart';
import 'package:myshop/features/employee/order_queue/employee_order_queue_screen.dart';

import '../helpers/test_harness.dart';

/// Order pipeline layout: filters, clear, sizes, and text-only buttons.
void main() {
  late MockAppRepository repo;

  setUp(() {
    TestHarness.setupPlatformChannels();
    repo = TestHarness.useMockRepository();
    TestHarness.signIn(TestHarness.admin);
  });
  tearDown(TestHarness.signOut);

  Future<Order> place(String status, {String name = 'Asha'}) async {
    final o = await repo.placeOrder(
      Order(
        id: '',
        userId: 'u1',
        companyId: 'c_organic',
        companyName: 'GreenLeaf Organics',
        customerName: name,
        items: const [
          OrderItem(productId: 'p1', qty: 2, unitPrice: 60, name: 'Tomatoes'),
          OrderItem(productId: 'p2', qty: 1, unitPrice: 40, name: 'Milk'),
        ],
        subtotal: 160,
        totalAmount: 160,
        address: '12 Market Street',
        pincode: '380001',
      ),
    );
    if (status != OrderStatus.pending) {
      await repo.updateOrderStatus(o.id, status, companyId: 'c_organic');
    }
    return o;
  }

  group('orderInDateRange', () {
    final range = DateTimeRange(
      start: DateTime(2026, 11, 1),
      end: DateTime(2026, 11, 3),
    );
    test('includes both end days and excludes outside', () {
      expect(orderInDateRange(DateTime(2026, 11, 1, 0, 0), range), isTrue);
      expect(orderInDateRange(DateTime(2026, 11, 3, 23, 59), range), isTrue);
      expect(orderInDateRange(DateTime(2026, 10, 31, 23, 59), range), isFalse);
      expect(orderInDateRange(DateTime(2026, 11, 4), range), isFalse);
    });
    test(
      'no range matches everything; a missing date never matches a range',
      () {
        expect(orderInDateRange(null, null), isTrue);
        expect(orderInDateRange(null, range), isFalse);
      },
    );
  });

  testWidgets('Clear resets search and status together', (tester) async {
    final tomato = await place(OrderStatus.pending, name: 'Asha');
    final confirmed = await place(OrderStatus.confirmed, name: 'Bina');
    await pumpTestApp(tester, const AdminOrdersScreen());

    final clear = find.byKey(const Key('order-filter-clear'));
    expect(tester.widget<TextButton>(clear).onPressed, isNull);

    await tester.tap(find.text('Confirmed (1)'));
    await tester.enterText(find.byKey(const Key('order-search-field')), 'Bina');
    await tester.pumpAndSettle();
    expect(find.byKey(Key('order-card-${tomato.id}')), findsNothing);
    expect(find.byKey(Key('order-card-${confirmed.id}')), findsOneWidget);
    expect(tester.widget<TextButton>(clear).onPressed, isNotNull);

    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(find.byKey(Key('order-card-${tomato.id}')), findsOneWidget);
    expect(find.byKey(Key('order-card-${confirmed.id}')), findsOneWidget);
    expect(tester.widget<TextButton>(clear).onPressed, isNull);
  });

  testWidgets('the date button opens the range picker', (tester) async {
    await place(OrderStatus.pending);
    await pumpTestApp(tester, const AdminOrdersScreen());
    await tester.tap(find.byKey(const Key('order-filter-date')));
    await tester.pumpAndSettle();
    expect(find.text('Select date range'), findsOneWidget);
  });

  testWidgets('order actions show text only, no arrow icons', (tester) async {
    await place(OrderStatus.pending);
    await place(OrderStatus.confirmed);
    await pumpTestApp(tester, const AdminOrdersScreen());
    for (final icon in [
      Icons.arrow_forward,
      Icons.arrow_forward_ios,
      Icons.arrow_right,
      Icons.arrow_right_alt,
      Icons.chevron_right,
      Icons.keyboard_arrow_right,
    ]) {
      expect(find.byIcon(icon), findsNothing, reason: '$icon');
    }
    expect(find.widgetWithText(FilledButton, 'Confirm'), findsWidgets);
    expect(find.widgetWithText(OutlinedButton, 'View Details'), findsWidgets);
  });

  testWidgets('"Advance to" on the details page has no arrow', (tester) async {
    final o = await place(OrderStatus.confirmed);
    await pumpTestApp(tester, AdminOrderDetailsScreen(orderId: o.id));
    await tester.pumpAndSettle();
    expect(find.textContaining('Advance to'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward), findsNothing);
  });

  const sizes = <String, Size>{
    'small phone': Size(320, 640),
    'phone': Size(390, 844),
    'large phone': Size(430, 932),
    'small browser': Size(800, 700),
    'desktop': Size(1440, 900),
    'large desktop': Size(1920, 1080),
  };
  for (final e in sizes.entries) {
    testWidgets('admin pipeline fits a ${e.key}', (tester) async {
      tester.view.physicalSize = e.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await place(OrderStatus.pending);
      await place(OrderStatus.confirmed);
      await place(OrderStatus.cancelled);
      await pumpTestApp(tester, const AdminOrdersScreen(), size: e.value);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('employee queue fits a ${e.key}', (tester) async {
      tester.view.physicalSize = e.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      TestHarness.signIn(TestHarness.employee);
      await place(OrderStatus.confirmed);
      await pumpTestApp(
        tester,
        const EmployeeOrderQueueScreen(),
        user: TestHarness.employee,
        size: e.value,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
