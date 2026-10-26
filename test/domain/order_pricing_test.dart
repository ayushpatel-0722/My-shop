import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/domain/order_pricing.dart';
import 'package:myshop/core/domain/voucher_evaluator.dart';
import 'package:myshop/core/models/cart_item.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/core/models/voucher.dart';

CartItem line(
  String id, {
  double price = 100,
  int qty = 1,
  String categoryId = 'cat_veg',
}) => CartItem(
  companyId: 'c_organic',
  companyName: 'GreenLeaf Organics',
  product: Product(
    id: id,
    companyId: 'c_organic',
    categoryId: categoryId,
    name: 'Product $id',
    amount: price,
  ),
  qty: qty,
);

Voucher v({
  String type = VoucherType.percentage,
  double value = 10,
  double minOrder = 0,
  DateTime? expiry,
}) => Voucher(
  id: 'v_1',
  companyId: 'c_organic',
  code: 'SAVE10',
  discountType: type,
  discountValue: value,
  expiryDate: expiry ?? DateTime(2030, 1, 1),
  minOrderAmt: minOrder,
);

final context = VoucherContext(now: DateTime(2026, 6, 1), userId: 'u_1');

void main() {
  const pricer = OrderPricer();

  group('OrderPricer — without a voucher', () {
    test('adds the delivery charge to the subtotal', () {
      final bill = pricer.price(
        companyId: 'c_organic',
        items: [line('p1', price: 100, qty: 3)],
        deliveryCharge: 40,
        context: context,
      );

      expect(bill.subtotal, 300);
      expect(bill.discount, 0);
      expect(bill.deliveryCharge, 40);
      expect(bill.total, 340);
      expect(bill.itemCount, 3);
      expect(bill.hasVoucher, isFalse);
    });

    test('self pickup pays no delivery charge', () {
      final bill = pricer.price(
        companyId: 'c_organic',
        items: [line('p1')],
        deliveryCharge: 40,
        deliveryRequired: false,
        context: context,
      );

      expect(bill.deliveryCharge, 0);
      expect(bill.total, 100);
    });

    test('an empty cart costs nothing', () {
      final bill = pricer.price(
        companyId: 'c_organic',
        items: const <CartItem>[],
        deliveryCharge: 30,
        context: context,
      );

      expect(bill.subtotal, 0);
      expect(bill.total, 30);
      expect(bill.itemCount, 0);
    });
  });

  group('OrderPricer — with a voucher', () {
    test('applies a percentage discount and keeps the delivery charge', () {
      final bill = pricer.price(
        companyId: 'c_organic',
        items: [line('p1', price: 200, qty: 2)],
        voucher: v(value: 10),
        deliveryCharge: 30,
        context: context,
      );

      expect(bill.subtotal, 400);
      expect(bill.discount, 40);
      expect(bill.deliveryCharge, 30);
      expect(bill.total, 390);
      expect(bill.hasVoucher, isTrue);
    });

    test('free shipping zeroes only the delivery line', () {
      final bill = pricer.price(
        companyId: 'c_organic',
        items: [line('p1', price: 200)],
        voucher: v(type: VoucherType.freeShipping),
        deliveryCharge: 45,
        context: context,
      );

      expect(bill.discount, 0);
      expect(bill.deliveryCharge, 0);
      expect(bill.total, 200);
      expect(bill.totalSavings, 45);
    });

    test('an invalid voucher silently contributes nothing', () {
      final expired = v(expiry: DateTime(2020, 1, 1));
      final bill = pricer.price(
        companyId: 'c_organic',
        items: [line('p1', price: 200)],
        voucher: expired,
        deliveryCharge: 20,
        context: context,
      );

      expect(
        bill.voucher,
        isNull,
        reason: 'rejected voucher must not be stored',
      );
      expect(bill.discount, 0);
      expect(bill.deliveryCharge, 20);
      expect(bill.total, 220);
    });

    test('a voucher that does not apply to the cart is ignored', () {
      final scoped = v().copyWith(
        appliesTo: VoucherScope.specificProduct,
        productIds: ['p_other'],
      );
      final bill = pricer.price(
        companyId: 'c_organic',
        items: [line('p1', price: 200)],
        voucher: scoped,
        context: context,
      );

      expect(bill.discount, 0);
      expect(bill.voucher, isNull);
      expect(bill.total, 200);
    });

    test('the total never goes negative', () {
      final bill = pricer.price(
        companyId: 'c_organic',
        items: [line('p1', price: 50)],
        voucher: v(type: VoucherType.fixedAmount, value: 999),
        context: context,
      );

      expect(bill.discount, 50, reason: 'discount is clamped to the subtotal');
      expect(bill.total, 0);
      expect(bill.total, greaterThanOrEqualTo(0));
    });

    test('money is rounded to paise', () {
      final bill = pricer.price(
        companyId: 'c_organic',
        items: [line('p1', price: 33.33, qty: 3)],
        voucher: v(value: 33),
        deliveryCharge: 12.34,
        context: context,
      );

      expect(bill.subtotal, 99.99);
      expect(bill.deliveryCharge, 12.34);
      expect(bill.total, closeTo(99.99 - 32.9967 + 12.34, 0.01));
    });
  });

  group('OrderBill — snapshot & serialisation', () {
    test('lines freeze the product name, image and unit price', () {
      final bill = pricer.price(
        companyId: 'c_organic',
        companyName: 'GreenLeaf Organics',
        items: [line('p1', price: 120, qty: 2)],
        deliveryCharge: 10,
        context: context,
      );

      expect(bill.lines.single.productId, 'p1');
      expect(bill.lines.single.name, 'Product p1');
      expect(bill.lines.single.unitPrice, 120);
      expect(bill.lines.single.qty, 2);
      expect(bill.lines.single.lineTotal, 240);
      expect(bill.companyName, 'GreenLeaf Organics');
    });

    test('toMap carries every money field', () {
      final bill = pricer.price(
        companyId: 'c_organic',
        items: [line('p1', price: 100)],
        voucher: v(value: 10),
        deliveryCharge: 25,
        context: context,
      );

      final map = bill.toMap();
      expect(map['subtotal'], 100);
      expect(map['discount'], 10);
      expect(map['deliveryCharge'], 25);
      expect(map['total'], 115);
      expect(map['voucherCode'], 'SAVE10');
      expect(map['lines'], hasLength(1));
    });
  });

  test('roundMoney trims to two decimals', () {
    expect(roundMoney(1.2345), 1.23);
    expect(roundMoney(10.0), 10.0);
    expect(roundMoney(0), 0);
    expect(roundMoney(99.999), 100.0);
  });
}
