import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/domain/voucher_evaluator.dart';
import 'package:myshop/core/models/cart_item.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/core/models/voucher.dart';

CartItem line(
  String productId, {
  String categoryId = 'cat_veg',
  double price = 100,
  int qty = 1,
}) => CartItem(
  companyId: 'c_organic',
  companyName: 'GreenLeaf Organics',
  product: Product(
    id: productId,
    companyId: 'c_organic',
    categoryId: categoryId,
    name: 'Product $productId',
    amount: price,
  ),
  qty: qty,
);

Voucher voucher({
  String id = 'v_1',
  String code = 'SAVE20',
  String type = VoucherType.percentage,
  String scope = VoucherScope.allCategories,
  double value = 20,
  double minOrder = 0,
  int perUser = 1,
  int maxUses = 100,
  DateTime? expiry,
  bool firstTimeOnly = false,
  bool active = true,
  List<String> productIds = const [],
  List<String> categoryIds = const [],
  List<String> usedOrders = const [],
  Map<String, int> usageByUser = const {},
}) => Voucher(
  id: id,
  companyId: 'c_organic',
  code: code,
  discountType: type,
  discountValue: value,
  appliesTo: scope,
  productIds: productIds,
  categoryIds: categoryIds,
  perUserLimit: perUser,
  maxUses: maxUses,
  expiryDate: expiry,
  minOrderAmt: minOrder,
  firstTimeOnly: firstTimeOnly,
  isActive: active,
  usedOrderIds: usedOrders,
  usageByUser: usageByUser,
);

final now = DateTime(2026, 6, 1, 12);
final future = DateTime(2026, 12, 31, 23, 59, 59);
final past = DateTime(2020, 1, 1);

VoucherContext context({String userId = 'u_1', int previousOrders = 0}) =>
    VoucherContext(
      now: now,
      userId: userId,
      previousOrderCount: previousOrders,
    );

void main() {
  const evaluator = VoucherEvaluator();

  group('VoucherEvaluator — happy paths', () {
    test('no voucher means no discount (and no crash)', () {
      final result = evaluator.evaluate(
        items: [line('p1')],
        context: context(),
      );

      expect(result.isAccepted, isFalse);
      expect(result.reason, VoucherRejection.none);
      expect(result.discount, 0);
      expect(result.cartSubtotal, 100);
    });

    test('percentage voucher discounts the eligible subtotal', () {
      final result = evaluator.evaluate(
        voucher: voucher(value: 20, expiry: future),
        items: [line('p1', price: 100, qty: 2)],
        context: context(),
      );

      expect(result.isAccepted, isTrue);
      expect(result.cartSubtotal, 200);
      expect(result.eligibleSubtotal, 200);
      expect(result.discount, 40);
      expect(result.matchedItemCount, 1);
    });

    test('fixed amount voucher is clamped to the eligible subtotal', () {
      final result = evaluator.evaluate(
        voucher: voucher(
          type: VoucherType.fixedAmount,
          value: 500,
          expiry: future,
        ),
        items: [line('p1', price: 120)],
        context: context(),
      );

      expect(result.isAccepted, isTrue);
      expect(result.discount, 120, reason: 'discount must not exceed subtotal');
    });

    test('free shipping waives the delivery charge only', () {
      final result = evaluator.evaluate(
        voucher: voucher(type: VoucherType.freeShipping, expiry: future),
        items: [line('p1')],
        context: context(),
        deliveryCharge: 40,
      );

      expect(result.isAccepted, isTrue);
      expect(result.discount, 0);
      expect(result.deliveryDiscount, 40);
      expect(result.totalSavings, 40);
    });

    test('evaluation message is user friendly when accepted', () {
      final result = evaluator.evaluate(
        voucher: voucher(expiry: future),
        items: [line('p1')],
        context: context(),
      );
      expect(result.message, 'Voucher applied.');
    });
  });

  group('VoucherEvaluator — scope', () {
    test('specific product voucher only discounts matching lines', () {
      final scoped = voucher(
        scope: VoucherScope.specificProduct,
        productIds: ['p2'],
        value: 50,
        expiry: future,
      );
      final result = evaluator.evaluate(
        voucher: scoped,
        items: [line('p1', price: 100), line('p2', price: 200)],
        context: context(),
      );

      expect(result.isAccepted, isTrue);
      expect(result.cartSubtotal, 300);
      expect(result.eligibleSubtotal, 200);
      expect(result.discount, 100, reason: '50% of the 200 eligible');
      expect(result.matchedItemCount, 1);
    });

    test('specific product voucher with no match is rejected', () {
      final result = evaluator.evaluate(
        voucher: voucher(
          scope: VoucherScope.specificProduct,
          productIds: ['p_other'],
          expiry: future,
        ),
        items: [line('p1')],
        context: context(),
      );

      expect(result.isAccepted, isFalse);
      expect(result.reason, VoucherRejection.scopeMismatch);
    });

    test('specific category voucher matches by product category', () {
      final result = evaluator.evaluate(
        voucher: voucher(
          scope: VoucherScope.specificCategory,
          categoryIds: ['cat_veg'],
          value: 10,
          expiry: future,
        ),
        items: [
          line('p1', categoryId: 'cat_veg', price: 100),
          line('p2', categoryId: 'cat_fruit', price: 500),
        ],
        context: context(),
      );

      expect(result.isAccepted, isTrue);
      expect(result.eligibleSubtotal, 100);
      expect(result.discount, 10);
    });

    test('empty cart is rejected instead of dividing by zero', () {
      final result = evaluator.evaluate(
        voucher: voucher(expiry: future),
        items: const <CartItem>[],
        context: context(),
      );

      expect(result.isAccepted, isFalse);
      expect(result.reason, VoucherRejection.scopeMismatch);
      expect(result.discount, 0);
    });

    test('eligibleSubtotalFor reuses the same scope rules', () {
      final scoped = voucher(
        scope: VoucherScope.specificCategory,
        categoryIds: ['cat_fruit'],
        expiry: future,
      );
      expect(
        evaluator.eligibleSubtotalFor(scoped, [
          line('p1', categoryId: 'cat_veg', price: 10),
          line('p2', categoryId: 'cat_fruit', price: 25),
        ]),
        25,
      );
    });
  });

  group('VoucherEvaluator — rejections', () {
    test('expired voucher', () {
      final result = evaluator.evaluate(
        voucher: voucher(expiry: past),
        items: [line('p1')],
        context: context(),
      );
      expect(result.reason, VoucherRejection.expired);
      expect(result.discount, 0);
    });

    test('paused (inactive) voucher', () {
      final result = evaluator.evaluate(
        voucher: voucher(expiry: future, active: false),
        items: [line('p1')],
        context: context(),
      );
      expect(result.reason, VoucherRejection.inactive);
    });

    test('minimum order amount not met', () {
      final result = evaluator.evaluate(
        voucher: voucher(minOrder: 500, expiry: future),
        items: [line('p1', price: 100)],
        context: context(),
      );
      expect(result.reason, VoucherRejection.minOrderNotMet);
    });

    test('minimum order amount met', () {
      final result = evaluator.evaluate(
        voucher: voucher(minOrder: 500, expiry: future),
        items: [line('p1', price: 500)],
        context: context(),
      );
      expect(result.isAccepted, isTrue);
    });

    test('per-user limit already reached', () {
      final result = evaluator.evaluate(
        voucher: voucher(perUser: 1, expiry: future, usageByUser: {'u_1': 1}),
        items: [line('p1')],
        context: context(userId: 'u_1'),
      );
      expect(result.reason, VoucherRejection.perUserLimitReached);
    });

    test('a different shopper is unaffected by another user\'s usage', () {
      final result = evaluator.evaluate(
        voucher: voucher(perUser: 1, expiry: future, usageByUser: {'u_1': 1}),
        items: [line('p1')],
        context: context(userId: 'u_2'),
      );
      expect(result.isAccepted, isTrue);
    });

    test('global redemption cap reached', () {
      final result = evaluator.evaluate(
        voucher: voucher(
          maxUses: 2,
          expiry: future,
          usedOrders: ['o_1', 'o_2'],
        ),
        items: [line('p1')],
        context: context(),
      );
      expect(result.reason, VoucherRejection.usageLimitReached);
    });

    test('first-time-only voucher is refused to returning shoppers', () {
      final result = evaluator.evaluate(
        voucher: voucher(firstTimeOnly: true, expiry: future),
        items: [line('p1')],
        context: context(previousOrders: 1),
      );
      expect(result.reason, VoucherRejection.firstTimeOnly);
    });

    test('first-time-only voucher works for a first order', () {
      final result = evaluator.evaluate(
        voucher: voucher(firstTimeOnly: true, expiry: future),
        items: [line('p1')],
        context: context(previousOrders: 0),
      );
      expect(result.isAccepted, isTrue);
    });

    test('rejections never produce a discount', () {
      final rejections = <Voucher>[
        voucher(expiry: past),
        voucher(active: false),
        voucher(minOrder: 1000),
        voucher(maxUses: 1, usedOrders: ['o_1']),
        voucher(perUser: 1, usageByUser: {'u_1': 1}),
        voucher(firstTimeOnly: true),
      ];
      for (final v in rejections) {
        final result = evaluator.evaluate(
          voucher: v,
          items: [line('p1', price: 100)],
          context: context(previousOrders: 3),
        );
        expect(result.discount, 0, reason: '${v.code} must not discount');
        expect(result.totalSavings, 0);
      }
    });
  });

  group('VoucherEvaluator — usableVouchers', () {
    test('filters out expired, paused, exhausted and out-of-scope codes', () {
      final vouchers = <Voucher>[
        voucher(id: 'v_ok', expiry: future),
        voucher(id: 'v_old', code: 'OLD', expiry: past),
        voucher(id: 'v_pause', code: 'PAUSED', expiry: future, active: false),
        voucher(
          id: 'v_done',
          code: 'DONE',
          expiry: future,
          maxUses: 1,
          usedOrders: ['o_1'],
        ),
        voucher(
          id: 'v_scope',
          code: 'SCOPED',
          expiry: future,
          scope: VoucherScope.specificProduct,
          productIds: ['nope'],
        ),
      ];

      final usable = evaluator.usableVouchers(
        vouchers,
        items: [line('p1')],
        context: context(),
      );

      expect(usable.map((v) => v.code), ['SAVE20']);
    });
  });
}
