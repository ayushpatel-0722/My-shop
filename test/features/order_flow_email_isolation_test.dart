import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/admin.dart';
import 'package:myshop/core/models/order.dart';
import 'package:myshop/core/services/email_service.dart';

import '../helpers/test_harness.dart';

void main() {
  late MockAppRepository mockRepo;

  setUp(() {
    TestHarness.setupPlatformChannels();
    mockRepo = TestHarness.useMockRepository();
  });

  group('Shop-Specific Admin Email Isolation Tests', () {
    test('resolves specific admin email for Coffee House vs Masala Mart', () async {
      // Seed company A (Coffee House) admin
      await mockRepo.createAdminAccount(
        const Admin(
          id: 'admin_coffee',
          companyId: 'company_coffee_house',
          name: 'Coffee Admin',
          email: 'work.ayushkumar112428@gmail.com',
        ),
        password: 'Password123!',
      );

      // Seed company B (Masala Mart) admin
      await mockRepo.createAdminAccount(
        const Admin(
          id: 'admin_masala',
          companyId: 'company_masala_mart',
          name: 'Masala Admin',
          email: 'ayushpatel112428@gmail.com',
        ),
        password: 'Password123!',
      );


      final coffeeAdminEmail = await EmailService.resolveShopAdminEmail('company_coffee_house');
      final masalaAdminEmail = await EmailService.resolveShopAdminEmail('company_masala_mart');

      expect(coffeeAdminEmail, equals('work.ayushkumar112428@gmail.com'));
      expect(masalaAdminEmail, equals('ayushpatel112428@gmail.com'));
      expect(coffeeAdminEmail, isNot(equals(masalaAdminEmail)));
    });

    test('sendOrderPlacedEmail formats shop-specific order without crashing', () async {
      final order = Order(
        id: 'ord_test_12345',
        userId: 'user_shopper_1',
        customerName: 'Ayush Kumar',
        customerEmail: 'customer@test.com',
        customerPhone: '+91 9876543210',
        companyId: 'company_coffee_house',
        companyName: 'Coffee House',
        items: [
          const OrderItem(
            productId: 'p_coffee_1',
            name: 'Davidoff Café Espresso 57',
            qty: 2,
            unitPrice: 450,
            variantTitle: '200g Jar',
          ),
        ],
        subtotal: 900,
        deliveryCharge: 40,
        discountAmount: 50,
        totalAmount: 890,
        address: '101 MG Road, Sector 4',
        pincode: '380015',
        orderStatus: OrderStatus.pending,
        paymentStatus: PaymentStatus.pending,
      );

      // Should execute cleanly without throw, even if url_launcher is intercepted in tests
      final success = await EmailService.sendOrderPlacedEmail(
        order: order,
        recipientEmail: 'work.ayushkumar112428@gmail.com',
      );

      expect(success, isA<bool>());
    });

    test('Multi-shop orders are split cleanly per company', () async {
      final orderCoffee = Order(
        id: '',
        userId: 'shopper_1',
        companyId: 'company_coffee',
        companyName: 'Coffee House',
        items: [
          const OrderItem(
            productId: 'p_c1',
            qty: 1,
            unitPrice: 300,
            name: 'Roasted Beans',
          ),
        ],
        subtotal: 300,
        totalAmount: 300,
        address: 'Home',
        pincode: '123456',
      );

      final orderMasala = Order(
        id: '',
        userId: 'shopper_1',
        companyId: 'company_masala',
        companyName: 'Masala Mart',
        items: [
          const OrderItem(
            productId: 'p_m1',
            qty: 2,
            unitPrice: 150,
            name: 'Garam Masala',
          ),
        ],
        subtotal: 300,
        totalAmount: 300,
        address: 'Home',
        pincode: '123456',
      );

      final saved = await mockRepo.placeOrders([orderCoffee, orderMasala]);
      expect(saved.length, equals(2));
      expect(saved[0].companyId, equals('company_coffee'));
      expect(saved[1].companyId, equals('company_masala'));
    });
  });
}
