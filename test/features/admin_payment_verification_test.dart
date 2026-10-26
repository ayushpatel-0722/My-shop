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

  group('Order Payment Model & Helpers', () {
    test('PaymentMethod helpers validate and display correctly', () {
      expect(PaymentMethod.isValid('cash'), isTrue);
      expect(PaymentMethod.isValid('upi'), isTrue);
      expect(PaymentMethod.isValid('invalid'), isFalse);

      expect(PaymentMethod.isCash('cash'), isTrue);
      expect(PaymentMethod.isCash('CASH'), isTrue);
      expect(PaymentMethod.isCash(''), isFalse);

      expect(PaymentMethod.isUpi('upi'), isTrue);
      expect(PaymentMethod.isUpi('UPI'), isTrue);
      expect(PaymentMethod.isUpi(''), isFalse);

      expect(PaymentMethod.displayName('cash'), 'Cash');
      expect(PaymentMethod.displayName('upi'), 'UPI');
      expect(PaymentMethod.displayName(''), 'Not recorded');
    });

    test('PaymentStatus helpers display correctly', () {
      expect(PaymentStatus.displayName('pending'), 'Pending');
      expect(PaymentStatus.displayName('done'), 'Paid');
      expect(PaymentStatus.displayName('failed'), 'Failed');
    });

    test('Order serializes and deserializes payment fields accurately', () {
      final now = DateTime.now();
      final order = Order(
        id: 'ord_test_1',
        userId: 'user_1',
        companyId: 'c_organic',
        companyName: 'GreenLeaf Organics',
        items: const [
          OrderItem(
            productId: 'p_1',
            name: 'Organic Spices',
            unitPrice: 150,
            qty: 1,
          ),
        ],
        subtotal: 150,
        deliveryCharge: 0,
        totalAmount: 150,
        address: '123 Test Lane',
        pincode: '380001',
        paymentMethod: PaymentMethod.upi,
        paymentStatus: PaymentStatus.done,
        transactionRef: 'UTR987654321',
        amountPaid: 150,
        paidAt: now,
        paymentVerifiedBy: 'Store Admin',
        paymentVerifiedAt: now,
      );

      final map = order.toMap();
      expect(map['paymentMethod'], PaymentMethod.upi);
      expect(map['paymentStatus'], PaymentStatus.done);
      expect(map['transactionRef'], 'UTR987654321');
      expect(map['amountPaid'], 150);
      expect(map['paymentVerifiedBy'], 'Store Admin');
      expect(map['paidAt'], isNotNull);
      expect(map['paymentVerifiedAt'], isNotNull);

      final reconstructed = Order.fromMap('ord_test_1', map);
      expect(reconstructed.paymentMethod, PaymentMethod.upi);
      expect(reconstructed.paymentStatus, PaymentStatus.done);
      expect(reconstructed.isUpi, isTrue);
      expect(reconstructed.isPaid, isTrue);
      expect(reconstructed.transactionRef, 'UTR987654321');
      expect(reconstructed.paymentVerifiedBy, 'Store Admin');
    });
  });

  group('Repository Payment Verification Workflow', () {
    test(
      'Cash payment verification selects Cash, updates status, and records audit history',
      () async {
        // Customer places order without selecting Cash or UPI
        final order = await repo.placeOrder(
          Order(
            id: '',
            userId: 'user_1',
            companyId: 'c_organic',
            companyName: 'GreenLeaf Organics',
            customerName: 'Rahul Sharma',
            items: const [
              OrderItem(
                productId: 'p_1',
                name: 'Cardamom',
                unitPrice: 200,
                qty: 1,
              ),
            ],
            subtotal: 200,
            deliveryCharge: 20,
            totalAmount: 220,
            address: '45 Road',
            pincode: '380001',
            paymentMethod: '', // Customer has not chosen Cash/UPI
            paymentStatus: PaymentStatus.pending,
            orderStatus: OrderStatus.pending,
          ),
        );

        expect(order.isPaymentPending, isTrue);
        expect(order.isPaid, isFalse);
        expect(order.paymentMethod, '');
        expect(order.paymentMethodDisplay, 'Not recorded');

        // Admin verifies payment and selects Cash
        await repo.verifyPayment(
          orderId: order.id,
          companyId: order.companyId,
          paymentStatus: PaymentStatus.done,
          paymentMethod: PaymentMethod.cash,
          verifiedBy: 'Store Admin (Rahul)',
          amountPaid: 220,
        );

        final updated = (await repo.order(order.id, companyId: 'c_organic'))!;

        expect(updated.isPaid, isTrue);
        expect(updated.paymentStatus, PaymentStatus.done);
        expect(updated.paymentMethod, PaymentMethod.cash);
        expect(updated.isCash, isTrue);
        expect(updated.paymentMethodDisplay, 'Cash');
        expect(updated.paidAt, isNotNull);
        expect(updated.paymentVerifiedAt, isNotNull);
        expect(updated.paymentVerifiedBy, 'Store Admin (Rahul)');
        expect(updated.amountPaid, 220);
        expect(
          updated.orderStatus,
          OrderStatus.pending,
        ); // Preserves independent order status

        // Audit trail in statusHistory
        expect(
          updated.statusHistory.any(
            (entry) => entry.note.contains('Payment of ₹220 verified (Cash)'),
          ),
          isTrue,
        );
      },
    );

    test(
      'UPI payment verification selects UPI, records UTR, and preserves idempotency',
      () async {
        // Customer places order without selecting payment method
        final order = await repo.placeOrder(
          Order(
            id: '',
            userId: 'user_2',
            companyId: 'c_organic',
            companyName: 'GreenLeaf Organics',
            customerName: 'Priya Patel',
            items: const [
              OrderItem(
                productId: 'p_2',
                name: 'Turmeric',
                unitPrice: 100,
                qty: 2,
              ),
            ],
            subtotal: 200,
            deliveryCharge: 0,
            totalAmount: 200,
            address: '77 Cross',
            pincode: '380001',
            paymentMethod: '',
            paymentStatus: PaymentStatus.pending,
            orderStatus: OrderStatus.confirmed,
          ),
        );

        // Admin confirms payment selecting UPI with UTR
        await repo.verifyPayment(
          orderId: order.id,
          companyId: order.companyId,
          paymentStatus: PaymentStatus.done,
          paymentMethod: PaymentMethod.upi,
          verifiedBy: 'Store Manager',
          transactionRef: 'UPI_VERIFIED_BANK_REF_999',
          amountPaid: 200,
        );

        final verifiedOrder = (await repo.order(
          order.id,
          companyId: 'c_organic',
        ))!;

        expect(verifiedOrder.isPaid, isTrue);
        expect(verifiedOrder.paymentMethod, PaymentMethod.upi);
        expect(verifiedOrder.isUpi, isTrue);
        expect(verifiedOrder.transactionRef, 'UPI_VERIFIED_BANK_REF_999');
        expect(verifiedOrder.paymentVerifiedBy, 'Store Manager');
        final originalVerifiedAt = verifiedOrder.paymentVerifiedAt;

        // Idempotency: verify again shouldn't re-execute or overwrite
        await repo.verifyPayment(
          orderId: order.id,
          companyId: order.companyId,
          paymentStatus: PaymentStatus.done,
          paymentMethod: PaymentMethod
              .cash, // Different method ignored on already-paid order
          verifiedBy: 'Another Person',
        );

        final reChecked = (await repo.order(order.id, companyId: 'c_organic'))!;
        expect(reChecked.paymentMethod, PaymentMethod.upi);
        expect(reChecked.paymentVerifiedBy, 'Store Manager');
        expect(reChecked.paymentVerifiedAt, originalVerifiedAt);
      },
    );
  });

  group('Admin Orders Screen UI Payment Workflow', () {
    testWidgets(
      'unpaid order shows Not recorded and opens dialog to select Cash',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());
        addTearDown(() => tester.view.resetDevicePixelRatio());

        final order = await repo.placeOrder(
          Order(
            id: '',
            userId: 'u_flow_1',
            companyId: 'c_organic',
            companyName: 'GreenLeaf Organics',
            customerName: 'Aarav Mehta',
            items: const [
              OrderItem(
                productId: 'p_1',
                name: 'Ginger',
                unitPrice: 150,
                qty: 1,
              ),
            ],
            subtotal: 150,
            deliveryCharge: 0,
            totalAmount: 150,
            address: 'Street X',
            pincode: '380001',
            paymentMethod: '', // Customer did not pick method
            paymentStatus: PaymentStatus.pending,
          ),
        );

        await pumpTestApp(tester, const AdminOrdersScreen());

        // Initial state: Not recorded
        expect(
          find.descendant(
            of: find.byKey(Key('order-card-${order.id}')),
            matching: find.text('Payment: Not recorded'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(Key('order-verify-payment-${order.id}')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(Key('order-card-${order.id}')),
            matching: find.text('Confirm Payment'),
          ),
          findsOneWidget,
        );

        // Tap Confirm Payment
        await tester.tap(find.byKey(Key('order-verify-payment-${order.id}')));
        await tester.pumpAndSettle();

        // Dialog opens
        expect(find.text('Confirm Payment Received'), findsWidgets);
        expect(find.text('Select Payment Method'), findsOneWidget);

        // Select Cash
        final cashOption = find.byKey(const Key('payment-method-cash-option'));
        expect(cashOption, findsOneWidget);
        await tester.tap(cashOption);
        await tester.pumpAndSettle();

        // Tap Confirm button
        final confirmBtn = find.byKey(const Key('confirm-payment-action-btn'));
        expect(confirmBtn, findsOneWidget);
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        // Order card updates to Cash and Paid
        expect(
          find.descendant(
            of: find.byKey(Key('order-card-${order.id}')),
            matching: find.text('Payment: Cash'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(Key('order-card-${order.id}')),
            matching: find.text('Status: PAID'),
          ),
          findsOneWidget,
        );
        // Confirm payment button is now hidden
        expect(
          find.byKey(Key('order-verify-payment-${order.id}')),
          findsNothing,
        );

        // Verify repository updated
        final updated = (await repo.order(order.id, companyId: 'c_organic'))!;
        expect(updated.isPaid, isTrue);
        expect(updated.paymentMethod, PaymentMethod.cash);
      },
    );

    testWidgets('admin can select UPI in dialog and enter UTR', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      final order = await repo.placeOrder(
        Order(
          id: '',
          userId: 'u_flow_2',
          companyId: 'c_organic',
          companyName: 'GreenLeaf Organics',
          customerName: 'Meera Sen',
          items: const [
            OrderItem(productId: 'p_2', name: 'Cumin', unitPrice: 250, qty: 1),
          ],
          subtotal: 250,
          deliveryCharge: 0,
          totalAmount: 250,
          address: 'Street Y',
          pincode: '380001',
          paymentMethod: '',
          paymentStatus: PaymentStatus.pending,
        ),
      );

      await pumpTestApp(tester, const AdminOrdersScreen());

      // Open dialog
      await tester.tap(find.byKey(Key('order-verify-payment-${order.id}')));
      await tester.pumpAndSettle();

      // Select UPI
      final upiOption = find.byKey(const Key('payment-method-upi-option'));
      expect(upiOption, findsOneWidget);
      await tester.tap(upiOption);
      await tester.pumpAndSettle();

      // UPI reference field appears
      final utrField = find.byKey(const Key('dialog-upi-ref-field'));
      expect(utrField, findsOneWidget);
      await tester.enterText(utrField, 'BANK_UTR_889900');
      await tester.pumpAndSettle();

      // Tap Confirm
      final confirmBtn = find.byKey(const Key('confirm-payment-action-btn'));
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Card updates to UPI and Paid
      expect(
        find.descendant(
          of: find.byKey(Key('order-card-${order.id}')),
          matching: find.text('Payment: UPI'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(Key('order-card-${order.id}')),
          matching: find.text('Status: PAID'),
        ),
        findsOneWidget,
      );

      // Verify repository updated
      final updated = (await repo.order(order.id, companyId: 'c_organic'))!;
      expect(updated.isPaid, isTrue);
      expect(updated.paymentMethod, PaymentMethod.upi);
      expect(updated.transactionRef, 'BANK_UTR_889900');
    });
  });
}
