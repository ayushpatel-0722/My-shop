import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/domain/category_lookup.dart';
import 'package:myshop/core/models/category.dart';

Category _cat(String id, String shop, {String icon = ''}) =>
    Category(id: id, name: '$shop-$id', companyId: shop, iconUrl: icon);

void main() {
  test('the same category id in two shops resolves to the right shop', () {
    final all = [
      _cat('spices', 'other', icon: 'https://x/other.png'),
      _cat('spices', 'woodnest', icon: 'https://x/wood.png'),
    ];
    expect(
      findShopCategory(all, 'woodnest', 'spices')?.iconUrl,
      'https://x/wood.png',
    );
    expect(
      findShopCategory(all, 'other', 'spices')?.iconUrl,
      'https://x/other.png',
    );
  });

  test('another shop\'s category is never returned for this shop', () {
    final all = [_cat('spices', 'other')];
    expect(findShopCategory(all, 'woodnest', 'spices'), isNull);
  });

  test('categories without a shop still match (older data)', () {
    final all = [_cat('spices', '')];
    expect(findShopCategory(all, 'woodnest', 'spices'), isNotNull);
  });
}
