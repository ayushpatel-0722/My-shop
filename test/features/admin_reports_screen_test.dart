import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/order.dart';
import 'package:myshop/features/admin/reports/admin_reports_screen.dart';

import '../helpers/test_harness.dart';

void main() {
  late MockAppRepository repo;

  setUp(() {
    TestHarness.setupPlatformChannels();
    repo = TestHarness.bootServiceLocator();
    TestHarness.signIn(TestHarness.admin);
  });

  tearDown(() => TestHarness.signOut());

  testWidgets('renders AdminReportsScreen with header, filters, and cards', (
    tester,
  ) async {
    final now = DateTime.now();
    await repo.placeOrder(
      Order(
        id: 'rep_order_1',
        userId: 'u_1',
        customerName: 'Test Buyer',
        customerPhone: '9876543210',
        companyId: TestHarness.admin.companyId,
        companyName: 'Organic Valley',
        items: const [
          OrderItem(
            productId: 'p_1',
            name: 'Organic Honey',
            qty: 2,
            unitPrice: 250.0,
          ),
        ],
        subtotal: 500.0,
        discountAmount: 0.0,
        deliveryCharge: 0.0,
        totalAmount: 500.0,
        orderStatus: OrderStatus.completed,
        paymentStatus: PaymentStatus.done,
        createdAt: now,
      ),
    );

    await pumpTestApp(tester, const AdminReportsScreen());
    await tester.pumpAndSettle();

    // Verify Title & Subtitle
    expect(find.text('Business & Sales Reports'), findsOneWidget);
    expect(find.text('Download Reports'), findsOneWidget);

    // Verify Filter Chips exist
    expect(find.text('Last 7 Days'), findsOneWidget);
    expect(find.text('Last 30 Days'), findsOneWidget);
    expect(find.text('Previous Month'), findsOneWidget);

    // Verify 4 Summary Metric Cards
    expect(find.text('Total Orders'), findsOneWidget);
    expect(find.text('Total Order Value'), findsOneWidget);
    expect(find.text('Actual Revenue'), findsOneWidget);
    expect(find.text('Completed / Cancelled'), findsOneWidget);

    // Verify Download Options
    expect(find.text('Orders Report (Excel)'), findsOneWidget);
    expect(find.text('Orders Report (CSV)'), findsOneWidget);
    expect(find.text('Summary Report (PDF)'), findsOneWidget);

    // Verify order rendered in breakdown list
    await tester.scrollUntilVisible(
      find.text('Test Buyer'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Test Buyer'), findsOneWidget);
  });

  testWidgets('switching date preset filters updates active banner', (
    tester,
  ) async {
    await pumpTestApp(tester, const AdminReportsScreen());
    await tester.pumpAndSettle();

    // Initial preset is Last 30 Days
    expect(find.text('Active Filter: Last 30 Days'), findsOneWidget);

    // Tap on Last 7 Days
    await tester.tap(find.text('Last 7 Days'));
    await tester.pumpAndSettle();

    expect(find.text('Active Filter: Last 7 Days'), findsOneWidget);
  });
}
