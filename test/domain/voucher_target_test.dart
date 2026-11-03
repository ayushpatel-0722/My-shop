import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/domain/voucher_target.dart';
import 'package:myshop/core/models/voucher.dart';

void main() {
  String more(int n) => '+$n more';

  String target(
    Voucher v, {
    Map<String, String> cats = const {},
    Map<String, String> prods = const {},
    int max = 2,
  }) => VoucherTarget.appliesTo(
    v,
    categoryNames: cats,
    productNames: prods,
    allProducts: 'All products',
    selectedCategories: 'Selected categories',
    selectedProducts: 'Selected products',
    more: more,
    maxNames: max,
  );

  Voucher v({
    String scope = VoucherScope.allCategories,
    List<String> cats = const [],
    List<String> prods = const [],
  }) => Voucher(
    id: 'v',
    companyId: 'c',
    code: 'X',
    appliesTo: scope,
    categoryIds: cats,
    productIds: prods,
  );

  test('a voucher for everything says so', () {
    expect(target(v()), 'All products');
  });

  test('a category voucher names its categories', () {
    final voucher = v(scope: VoucherScope.specificCategory, cats: ['a', 'b']);
    expect(
      target(voucher, cats: {'a': 'Spices', 'b': 'Coffee'}),
      'Spices, Coffee',
    );
  });

  test('a product voucher names its products', () {
    final voucher = v(scope: VoucherScope.specificProduct, prods: ['p1']);
    expect(target(voucher, prods: {'p1': 'Oak Bed'}), 'Oak Bed');
  });

  test('more than two names are cut to "+N more"', () {
    final voucher = v(
      scope: VoucherScope.specificCategory,
      cats: ['a', 'b', 'c', 'd'],
    );
    final names = {'a': 'A', 'b': 'B', 'c': 'C', 'd': 'D'};
    expect(target(voucher, cats: names), 'A, B +2 more');
    expect(target(voucher, cats: names, max: 4), 'A, B, C, D');
  });

  test('deleted or unnamed ids are skipped, never shown as blanks', () {
    final voucher = v(
      scope: VoucherScope.specificCategory,
      cats: ['gone', 'a'],
    );
    expect(target(voucher, cats: {'a': 'Spices', 'gone': '  '}), 'Spices');
  });

  test('when no id can be named a generic phrase is used', () {
    expect(
      target(v(scope: VoucherScope.specificCategory, cats: ['x'])),
      'Selected categories',
    );
    expect(
      target(v(scope: VoucherScope.specificProduct, prods: ['x'])),
      'Selected products',
    );
  });

  test('the label joins shop and target, and copes with no shop', () {
    expect(
      VoucherTarget.label(v(), shopName: ' GreenLeaf ', target: 'Spices'),
      'GreenLeaf · Spices',
    );
    expect(VoucherTarget.label(v(), shopName: '', target: 'Spices'), 'Spices');
  });
}
