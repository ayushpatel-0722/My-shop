import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/domain/validators.dart';
import 'package:myshop/core/models/category.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/core/models/voucher.dart';

void main() {
  group('ProductValidator', () {
    const validator = ProductValidator();

    Product base({
      String name = 'Honey',
      double amount = 250,
      double discount = 0,
      int stock = 10,
      bool unlimited = false,
      String categoryId = 'cat_1',
      double unit = 1,
      String type = ProductType.quantityBased,
      String unitType = 'pieces',
    }) => Product(
      id: 'p1',
      companyId: 'c1',
      categoryId: categoryId,
      name: name,
      amount: amount,
      discountAmt: discount,
      stockQty: stock,
      isUnlimitedStock: unlimited,
      unit: unit,
      type: type,
      unitType: unitType,
    );

    test('accepts a valid product', () {
      expect(validator.validate(base()).isValid, isTrue);
    });

    test('requires a name', () {
      final result = validator.validate(base(name: '   '));
      expect(result.errorFor('name'), isNotNull);
      expect(result.isValid, isFalse);
    });

    test('rejects a one character name', () {
      expect(validator.validate(base(name: 'H')).errorFor('name'), isNotNull);
    });

    test('requires a positive MRP', () {
      expect(validator.validate(base(amount: 0)).errorFor('amount'), isNotNull);
      expect(
        validator.validate(base(amount: -5)).errorFor('amount'),
        isNotNull,
      );
    });

    test('selling price must stay below the MRP', () {
      expect(
        validator
            .validate(base(amount: 100, discount: 100))
            .errorFor('discountAmt'),
        isNotNull,
      );
      expect(
        validator
            .validate(base(amount: 100, discount: 120))
            .errorFor('discountAmt'),
        isNotNull,
      );
      expect(
        validator.validate(base(amount: 100, discount: 0)).isValid,
        isTrue,
        reason: '0 means "no discount"',
      );
    });

    test('rejects negative discount and negative stock', () {
      expect(
        validator.validate(base(discount: -1)).errorFor('discountAmt'),
        isNotNull,
      );
      expect(
        validator.validate(base(stock: -3)).errorFor('stockQty'),
        isNotNull,
      );
    });

    test('unlimited stock may report zero on hand', () {
      expect(
        validator.validate(base(stock: 0, unlimited: true)).isValid,
        isTrue,
      );
    });

    test('category is optional and requires a positive unit', () {
      expect(
        validator.validate(base(categoryId: '')).errorFor('categoryId'),
        isNull,
      );
      expect(validator.validate(base(unit: 0)).errorFor('unit'), isNotNull);
    });

    test('weight based products need a unit type', () {
      final result = validator.validate(
        base(type: ProductType.weightBased, unitType: ''),
      );
      expect(result.errorFor('unitType'), isNotNull);
    });
  });

  group('CategoryValidator', () {
    const validator = CategoryValidator();

    final existing = <Category>[
      const Category(id: 'c1', name: 'Groceries', companyId: 'comp_1'),
      const Category(id: 'c2', name: 'Electronics', companyId: 'comp_1'),
      const Category(id: 'c3', name: 'Groceries', companyId: 'comp_2'),
    ];

    test('accepts a fresh name', () {
      expect(
        validator
            .validate(
              name: 'Fresh Produce',
              existing: existing,
              companyId: 'comp_1',
            )
            .isValid,
        isTrue,
      );
    });

    test('rejects an empty name', () {
      expect(
        validator.validate(name: ' ', existing: existing).errorFor('name'),
        isNotNull,
      );
    });

    test('rejects a duplicate name inside the same company', () {
      expect(
        validator
            .validate(
              name: 'groceries',
              existing: existing,
              companyId: 'comp_1',
            )
            .errorFor('name'),
        isNotNull,
      );
      expect(
        validator
            .validate(
              name: '  GROCERIES  ',
              existing: existing,
              companyId: 'comp_1',
            )
            .errorFor('name'),
        isNotNull,
      );
    });

    test('allows the same name in a different company', () {
      expect(
        validator
            .validate(
              name: 'Groceries',
              existing: existing,
              companyId: 'comp_9',
            )
            .isValid,
        isTrue,
      );
    });

    test('editing a category does not flag its own name', () {
      expect(
        validator
            .validate(
              name: 'Groceries',
              existing: existing,
              companyId: 'comp_1',
              selfId: 'c1',
            )
            .isValid,
        isTrue,
      );
    });

    test('a category cannot be its own parent', () {
      final result = validator.validate(
        name: 'Groceries',
        existing: existing,
        companyId: 'comp_1',
        selfId: 'c1',
        parentId: 'c1',
      );
      expect(result.errorFor('parentId'), isNotNull);
    });
  });

  group('VoucherValidator', () {
    const validator = VoucherValidator();
    final now = DateTime(2026, 6, 1);
    final future = DateTime(2026, 12, 31);

    ValidationResult check({
      String code = 'SAVE20',
      String type = VoucherType.percentage,
      double value = 20,
      double minOrder = 0,
      int perUser = 1,
      int maxUses = 100,
      String scope = VoucherScope.allCategories,
      List<String> productIds = const [],
      List<String> categoryIds = const [],
      List<String> existing = const [],
      DateTime? expiry,
    }) => validator.validate(
      code: code,
      discountType: type,
      discountValue: value,
      minOrderAmt: minOrder,
      perUserLimit: perUser,
      maxUses: maxUses,
      appliesTo: scope,
      productIds: productIds,
      categoryIds: categoryIds,
      existingCodes: existing,
      expiryDate: expiry,
      now: now,
    );

    test('accepts a sensible voucher', () {
      expect(check().isValid, isTrue);
    });

    test('code rules: required, length, characters, duplicates', () {
      expect(check(code: '').errorFor('code'), isNotNull);
      expect(check(code: 'AB').errorFor('code'), isNotNull);
      expect(check(code: 'SAVE-20!').errorFor('code'), isNotNull);
      expect(
        check(code: 'save20', existing: ['SAVE20']).errorFor('code'),
        isNotNull,
      );
      expect(check(code: ' save 20 ').isValid, isTrue, reason: 'normalised');
    });

    test('percentage must be between 0 and 100', () {
      expect(check(value: 0).errorFor('discountValue'), isNotNull);
      expect(check(value: 101).errorFor('discountValue'), isNotNull);
      expect(check(value: 100).isValid, isTrue);
    });

    test('fixed amount must be positive', () {
      expect(
        check(
          type: VoucherType.fixedAmount,
          value: 0,
        ).errorFor('discountValue'),
        isNotNull,
      );
    });

    test('free shipping needs no value', () {
      expect(check(type: VoucherType.freeShipping, value: 0).isValid, isTrue);
    });

    test('minimum order cannot be negative or pointless', () {
      expect(check(minOrder: -1).errorFor('minOrderAmt'), isNotNull);
      expect(
        check(
          type: VoucherType.fixedAmount,
          value: 100,
          minOrder: 50,
        ).errorFor('minOrderAmt'),
        isNotNull,
        reason: 'a 100 off on a 50 minimum would zero the order',
      );
    });

    test('usage limits must be sane', () {
      expect(check(perUser: 0).errorFor('perUserLimit'), isNotNull);
      expect(check(maxUses: 0).errorFor('maxUses'), isNotNull);
      expect(check(perUser: 5, maxUses: 2).errorFor('maxUses'), isNotNull);
    });

    test('expiry must be in the future', () {
      expect(
        check(expiry: DateTime(2020, 1, 1)).errorFor('expiryDate'),
        isNotNull,
      );
      expect(check(expiry: future).isValid, isTrue);
      expect(
        check(expiry: null).isValid,
        isTrue,
        reason: 'no expiry is allowed',
      );
    });

    test('scoped vouchers must pick at least one target', () {
      expect(
        check(scope: VoucherScope.specificProduct).errorFor('productIds'),
        isNotNull,
      );
      expect(
        check(scope: VoucherScope.specificCategory).errorFor('categoryIds'),
        isNotNull,
      );
      expect(
        check(scope: VoucherScope.specificProduct, productIds: ['p1']).isValid,
        isTrue,
      );
      expect(
        check(
          scope: VoucherScope.specificCategory,
          categoryIds: ['c1'],
        ).isValid,
        isTrue,
      );
    });

    test('results are empty when valid', () {
      final result = check();
      expect(result.hasErrors, isFalse);
      expect(result.errorFor('code'), isNull);
    });
  });
}
