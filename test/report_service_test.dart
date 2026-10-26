import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/models/order.dart';
import 'package:myshop/core/services/report_service.dart';

void main() {
  group('ReportService', () {
    late ReportService service;
    late List<Order> testOrders;

    setUp(() {
      service = ReportService();
      testOrders = [
        Order(
          id: 'ord_101',
          userId: 'u_1',
          customerName: 'Aarav Patel',
          customerPhone: '9876543210',
          companyId: 'comp_1',
          companyName: 'Masala Mart',
          items: const [
            OrderItem(
              productId: 'p_1',
              name: 'Garam Masala',
              qty: 2,
              unitPrice: 150.0,
            ),
            OrderItem(
              productId: 'p_2',
              name: 'Turmeric Powder',
              qty: 1,
              unitPrice: 90.0,
            ),
          ],
          subtotal: 390.0,
          discountAmount: 40.0,
          deliveryCharge: 30.0,
          totalAmount: 380.0,
          orderStatus: OrderStatus.completed,
          paymentStatus: PaymentStatus.done,
          paymentMethod: 'UPI',
          createdAt: DateTime(2026, 10, 15, 11, 20),
        ),
        Order(
          id: 'ord_102',
          userId: 'u_2',
          customerName: 'Priya Sharma',
          customerPhone: '9876543211',
          companyId: 'comp_1',
          companyName: 'Masala Mart',
          items: const [
            OrderItem(
              productId: 'p_3',
              name: 'Red Chilli Powder',
              qty: 1,
              unitPrice: 120.0,
            ),
          ],
          subtotal: 120.0,
          discountAmount: 0.0,
          deliveryCharge: 30.0,
          totalAmount: 150.0,
          orderStatus: OrderStatus.cancelled,
          paymentStatus: PaymentStatus.pending,
          paymentMethod: 'COD',
          createdAt: DateTime(2026, 10, 16, 14, 10),
        ),
      ];
    });

    test(
      'buildOrderReportExcel generates non-empty bytes and removes Sheet1',
      () {
        final bytes = service.buildOrderReportExcel(
          testOrders,
          'Orders Report',
          companyName: 'Masala Mart',
          dateRangeLabel: '12 Oct 2026 – 18 Oct 2026',
        );
        expect(bytes.isNotEmpty, isTrue);
      },
    );

    test('buildOrderReportCsv formats valid RFC-4180 CSV rows', () {
      final bytes = service.buildOrderReportCsv(
        testOrders,
        title: 'Orders Report',
        companyName: 'Masala Mart',
        dateRangeLabel: '12 Oct 2026 – 18 Oct 2026',
      );
      expect(bytes.isNotEmpty, isTrue);

      final csvString = String.fromCharCodes(bytes);
      expect(csvString, contains('Order ID,Date & Time,Customer Name'));
      expect(csvString, contains('ord_101'));
      expect(csvString, contains('Aarav Patel'));
      expect(csvString, contains('ord_102'));
      expect(csvString, contains('Priya Sharma'));
    });

    test('buildOrdersReportPdf generates PDF document successfully', () async {
      final bytes = await service.buildOrdersReportPdf(
        orders: testOrders,
        companyName: 'Masala Mart',
        dateRangeLabel: '12 Oct 2026 – 18 Oct 2026',
      );
      expect(bytes.isNotEmpty, isTrue);
      // PDF documents start with '%PDF-'
      final header = String.fromCharCodes(bytes.take(5));
      expect(header, equals('%PDF-'));
    });
  });
}
