import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/models/voucher.dart';

Voucher base({
  String id = 'v1',
  String code = 'SAVE20',
  String type = VoucherType.percentage,
  double value = 20,
  DateTime? expiry,
  int maxUses = 100,
  int perUser = 1,
  bool active = true,
  List<String> usedOrders = const [],
  Map<String, int> usageByUser = const {},
}) => Voucher(
  id: id,
  companyId: 'c_organic',
  code: code,
  discountType: type,
  discountValue: value,
  expiryDate: expiry,
  maxUses: maxUses,
  perUserLimit: perUser,
  isActive: active,
  usedOrderIds: usedOrders,
  usageByUser: usageByUser,
);

void main() {
  group('Voucher — code normalisation', () {
    test('trims, removes whitespace and upper-cases', () {
      expect(Voucher.normalizeCode('  save 20 '), 'SAVE20');
      expect(base(code: 'fresh20').normalizedCode, 'FRESH20');
    });

    test('parsing normalises the stored code too', () {
      final voucher = Voucher.fromMap('v1', {'code': 'fresh20'});
      expect(voucher.code, 'FRESH20');
    });
  });

  group('Voucher — parsing resilience', () {
    test('sanitises an unknown discount type and scope', () {
      final voucher = Voucher.fromMap('v1', {
        'discountType': 'flat',
        'appliesTo': 'whatever',
      });
      expect(voucher.discountType, VoucherType.fixedAmount);
      expect(voucher.appliesTo, VoucherScope.allCategories);
    });

    test('accepts numbers as strings and drops junk list entries', () {
      final voucher = Voucher.fromMap('v1', {
        'discountValue': '15',
        'maxUses': '7',
        'minOrderAmt': '199.5',
        'productIds': ['p1', null, '', 'p2'],
        'usageByUser': {'u1': 2, 'u2': '1'},
      });
      expect(voucher.discountValue, 15);
      expect(voucher.maxUses, 7);
      expect(voucher.minOrderAmt, 199.5);
      expect(voucher.productIds, ['p1', 'p2']);
      expect(voucher.usageFor('u1'), 2);
      expect(voucher.usageFor('u2'), 1);
    });

    test('legacy documents without isActive default to enabled', () {
      expect(Voucher.fromMap('v1', {'code': 'OLD'}).isActive, isTrue);
      expect(
        Voucher.fromMap('v1', {'code': 'OLD', 'isActive': false}).isActive,
        isFalse,
      );
    });

    test('a missing document does not throw', () {
      final voucher = Voucher.fromMap('v1', const <String, dynamic>{});
      expect(voucher.code, '');
      expect(voucher.discountValue, 0);
      expect(voucher.expiryDate, isNull);
      expect(voucher.usedOrderIds, isEmpty);
    });

    test('toMap contains the denormalised fields used by queries', () {
      final map = base(usedOrders: ['o1']).toMap();
      expect(map['code'], 'SAVE20');
      expect(map['codeUpper'], 'SAVE20');
      expect(map['usageCount'], 1);
      expect(map['companyId'], 'c_organic');
    });
  });

  group('Voucher — discount maths', () {
    test('percentage of the eligible subtotal', () {
      expect(base(value: 25).computeDiscount(200), 50);
      expect(base(value: 10).computeDiscount(0), 0);
    });

    test('a percentage above 100 is clamped', () {
      expect(base(value: 250).computeDiscount(100), 100);
    });

    test('fixed amount is clamped to the subtotal', () {
      expect(
        base(type: VoucherType.fixedAmount, value: 500).computeDiscount(120),
        120,
      );
      expect(
        base(type: VoucherType.fixedAmount, value: 30).computeDiscount(120),
        30,
      );
    });

    test('free shipping never discounts items', () {
      expect(base(type: VoucherType.freeShipping).computeDiscount(100), 0);
    });

    test('never returns a negative discount', () {
      expect(
        base(type: VoucherType.fixedAmount, value: -50).computeDiscount(100),
        0,
      );
      expect(base(value: -10).computeDiscount(100), 0);
    });
  });

  group('Voucher — lifecycle', () {
    final now = DateTime(2026, 6, 1, 12);

    test('expiry is evaluated against the supplied clock', () {
      expect(base(expiry: DateTime(2026, 5, 31)).isExpiredAt(now), isTrue);
      expect(base(expiry: DateTime(2026, 6, 2)).isExpiredAt(now), isFalse);
      expect(base().isExpiredAt(now), isFalse, reason: 'no expiry');
    });

    test('isLiveAt combines the enabled flag and the expiry', () {
      expect(base(active: false).isLiveAt(now), isFalse);
      expect(base(expiry: DateTime(2020)).isLiveAt(now), isFalse);
      expect(base().isLiveAt(now), isTrue);
    });

    test('usage counters', () {
      final voucher = base(maxUses: 3, perUser: 2, usedOrders: ['o1', 'o2']);
      expect(voucher.usageCount, 2);
      expect(voucher.usesRemaining, 1);
      expect(voucher.isExhausted, isFalse);

      final used = voucher.registerUsage(orderId: 'o3', userId: 'u1');
      expect(used.usageCount, 3);
      expect(used.isExhausted, isTrue);
      expect(used.usesRemaining, 0);
    });

    test('registerUsage is idempotent per order', () {
      final voucher = base();
      final once = voucher.registerUsage(orderId: 'o1', userId: 'u1');
      final twice = once.registerUsage(orderId: 'o1', userId: 'u1');

      expect(twice.usageCount, 1);
      expect(twice.usageFor('u1'), 1);
    });

    test('per-user usage is tracked separately', () {
      final voucher = base(perUser: 2)
          .registerUsage(orderId: 'o1', userId: 'u1')
          .registerUsage(orderId: 'o2', userId: 'u1')
          .registerUsage(orderId: 'o3', userId: 'u2');

      expect(voucher.usageFor('u1'), 2);
      expect(voucher.usageFor('u2'), 1);
      expect(voucher.usesRemainingFor('u1'), 0);
      expect(voucher.usesRemainingFor('u2'), 1);
    });

    test('unlimited caps report -1 remaining', () {
      final unlimited = base(maxUses: 0, perUser: 0);
      expect(unlimited.usesRemaining, -1);
      expect(unlimited.usesRemainingFor('u1'), -1);
    });

    test('registerUsage does not mutate the original', () {
      final voucher = base();
      voucher.registerUsage(orderId: 'o1', userId: 'u1');
      expect(voucher.usageCount, 0);
    });
  });

  group('Voucher — presentation', () {
    test('discount labels', () {
      expect(base(value: 20).discountLabel, '20% OFF');
      expect(base(value: 20.5).discountLabel, '20.50% OFF');
      expect(
        base(type: VoucherType.fixedAmount, value: 150).discountLabel,
        '₹150 OFF',
      );
      expect(
        base(type: VoucherType.freeShipping).discountLabel,
        'FREE DELIVERY',
      );
    });

    test('scope and type labels', () {
      expect(
        VoucherScope.label(VoucherScope.specificProduct),
        'Specific products',
      );
      expect(VoucherScope.label('nonsense'), 'All categories');
      expect(VoucherType.label(VoucherType.percentage), 'Percentage');
    });

    test('copyWith can clear the expiry date', () {
      final voucher = base(expiry: DateTime(2030));
      expect(voucher.copyWith(clearExpiryDate: true).expiryDate, isNull);
      expect(voucher.expiryDate, isNotNull);
    });

    test('equality is id + code based', () {
      expect(base(), base());
      expect(base(id: 'v2'), isNot(base()));
    });
  });
}
