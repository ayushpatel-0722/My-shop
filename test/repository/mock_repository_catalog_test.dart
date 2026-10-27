import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/category.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/core/models/voucher.dart';

/// Drains one microtask so the broadcast streams can deliver their events.
Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 1));

void main() {
  late MockAppRepository repo;

  setUp(() {
    repo = MockAppRepository();
  });

  group('Products', () {
    test('saveProduct assigns an id when the product is new', () async {
      await repo.saveProduct(
        const Product(
          id: '',
          companyId: 'c_organic',
          categoryId: 'cat_veg',
          name: 'Mango',
        ),
      );

      final products = await repo.products(companyId: 'c_organic').first;
      final mango = products.firstWhere((p) => p.name == 'Mango');
      expect(mango.id, isNotEmpty);
    });

    test('saveProduct updates in place instead of duplicating', () async {
      const product = Product(
        id: 'p_honey',
        companyId: 'c_organic',
        categoryId: 'cat_veg',
        name: 'Honey',
        amount: 250,
      );
      await repo.saveProduct(product);
      await repo.saveProduct(
        product.copyWith(amount: 299, name: 'Honey (new crop)'),
      );

      final products = await repo.products(companyId: 'c_organic').first;
      expect(products.where((p) => p.id == 'p_honey'), hasLength(1));
      expect((await repo.product('p_honey'))!.name, 'Honey (new crop)');
    });

    test('saveProduct requires a company', () async {
      expect(
        () => repo.saveProduct(
          const Product(
            id: 'x',
            companyId: '',
            categoryId: 'cat_veg',
            name: 'Ghost',
          ),
        ),
        throwsArgumentError,
      );
    });

    test('saving a product records it in its category', () async {
      await repo.saveCategory(
        const Category(id: 'cat_test', name: 'Test', companyId: 'c_organic'),
      );
      await repo.saveProduct(
        const Product(
          id: 'p_test',
          companyId: 'c_organic',
          categoryId: 'cat_test',
          name: 'Tested',
        ),
      );

      final category = (await repo.category(
        'cat_test',
        companyId: 'c_organic',
      ))!;
      expect(category.productList, contains('p_test'));
    });

    test('deleteProduct also removes it from every category list', () async {
      await repo.saveCategory(
        const Category(
          id: 'cat_test',
          name: 'Test',
          companyId: 'c_organic',
          productList: ['p_test'],
        ),
      );
      await repo.saveProduct(
        const Product(
          id: 'p_test',
          companyId: 'c_organic',
          categoryId: 'cat_test',
          name: 'Tested',
        ),
      );

      await repo.deleteProduct('p_test', companyId: 'c_organic');

      final category = (await repo.category(
        'cat_test',
        companyId: 'c_organic',
      ))!;
      expect(category.productList, isNot(contains('p_test')));
      expect(await repo.product('p_test'), isNull);
    });

    test('deleteProduct is scoped to the owning company', () async {
      await repo.saveProduct(
        const Product(
          id: 'p_x',
          companyId: 'c_organic',
          categoryId: 'cat_veg',
          name: 'Mine',
        ),
      );
      await repo.deleteProduct('p_x', companyId: 'c_techtronics');

      expect(await repo.product('p_x'), isNotNull);
    });

    test('products() filters by company, category and search', () async {
      final organic = await repo.products(companyId: 'c_organic').first;
      expect(organic.every((p) => p.companyId == 'c_organic'), isTrue);
      expect(organic.map((p) => p.id), contains('p_tomato'));
      expect(organic.map((p) => p.id), isNot(contains('p_phone')));

      final veg = await repo.products(categoryId: 'cat_veg').first;
      expect(veg.map((p) => p.id), containsAll(['p_tomato', 'p_spinach']));
      expect(veg.map((p) => p.id), isNot(contains('p_apple')));

      final searched = await repo.products(search: 'tomato').first;
      expect(searched.map((p) => p.name), ['Fresh Tomatoes']);
    });

    test('search matches SKUs as well as names', () async {
      await repo.saveProduct(
        const Product(
          id: 'p_sku',
          companyId: 'c_organic',
          categoryId: 'cat_veg',
          name: 'Mystery Box',
          sku: 'MB-1234',
        ),
      );
      final found = await repo
          .products(companyId: 'c_organic', search: 'MB-1234')
          .first;
      expect(found.map((p) => p.id), contains('p_sku'));
    });

    test('the products stream emits again after a write', () async {
      final events = <List<Product>>[];
      final sub = repo.products(companyId: 'c_organic').listen(events.add);
      await tick();

      await repo.saveProduct(
        const Product(
          id: 'p_stream',
          companyId: 'c_organic',
          categoryId: 'cat_veg',
          name: 'Streamed',
        ),
      );
      await tick();

      expect(events.length, greaterThanOrEqualTo(2));
      expect(events.last.map((p) => p.id), contains('p_stream'));
      await sub.cancel();
    });
  });

  group('Categories', () {
    test('saveCategory upserts by id', () async {
      await repo.saveCategory(
        const Category(id: 'cat_a', name: 'A', companyId: 'c_organic'),
      );
      await repo.saveCategory(
        const Category(id: 'cat_a', name: 'A renamed', companyId: 'c_organic'),
      );

      final list = await repo.categories(companyId: 'c_organic').first;
      expect(list.where((c) => c.id == 'cat_a'), hasLength(1));
      expect(list.firstWhere((c) => c.id == 'cat_a').name, 'A renamed');
    });

    test('a category can be nested under another one', () async {
      await repo.saveCategory(
        const Category(id: 'parent', name: 'Parent', companyId: 'c_organic'),
      );
      await repo.saveCategory(
        const Category(
          id: 'child',
          name: 'Child',
          companyId: 'c_organic',
          parentId: 'parent',
        ),
      );

      final child = (await repo.category('child', companyId: 'c_organic'))!;
      expect(child.parentId, 'parent');
    });

    test('saveCategory refuses to create a hierarchy cycle', () async {
      await repo.saveCategory(
        const Category(id: 'a', name: 'A', companyId: 'c_organic'),
      );
      await repo.saveCategory(
        const Category(
          id: 'b',
          name: 'B',
          companyId: 'c_organic',
          parentId: 'a',
        ),
      );

      expect(
        () => repo.saveCategory(
          const Category(
            id: 'a',
            name: 'A',
            companyId: 'c_organic',
            parentId: 'b',
          ),
        ),
        throwsArgumentError,
      );
    });

    test('deleting a parent re-parents the children', () async {
      await repo.saveCategory(
        const Category(id: 'root', name: 'Root', companyId: 'c_organic'),
      );
      await repo.saveCategory(
        const Category(
          id: 'mid',
          name: 'Mid',
          companyId: 'c_organic',
          parentId: 'root',
        ),
      );
      await repo.saveCategory(
        const Category(
          id: 'leaf',
          name: 'Leaf',
          companyId: 'c_organic',
          parentId: 'mid',
        ),
      );

      await repo.deleteCategory('mid', companyId: 'c_organic');

      final leaf = (await repo.category('leaf', companyId: 'c_organic'))!;
      expect(leaf.parentId, 'root', reason: 'orphans must not be left behind');
      expect(await repo.category('mid', companyId: 'c_organic'), isNull);
    });

    test('deleting a category moves its products to the parent', () async {
      await repo.saveCategory(
        const Category(id: 'root', name: 'Root', companyId: 'c_organic'),
      );
      await repo.saveCategory(
        const Category(
          id: 'child',
          name: 'Child',
          companyId: 'c_organic',
          parentId: 'root',
          productList: ['p_move'],
        ),
      );
      await repo.saveProduct(
        const Product(
          id: 'p_move',
          companyId: 'c_organic',
          categoryId: 'child',
          name: 'Mover',
        ),
      );

      await repo.deleteCategory('child', companyId: 'c_organic');

      final moved = (await repo.product('p_move'))!;
      expect(moved.categoryId, 'root');

      final root = (await repo.category('root', companyId: 'c_organic'))!;
      expect(root.productList, contains('p_move'));
    });

    test('categories() returns global + own company only', () async {
      await repo.saveCategory(
        const Category(id: 'mine', name: 'Mine', companyId: 'c_organic'),
      );
      await repo.saveCategory(
        const Category(
          id: 'theirs',
          name: 'Theirs',
          companyId: 'c_techtronics',
        ),
      );

      final list = await repo.categories(companyId: 'c_organic').first;
      final ids = list.map((c) => c.id);
      expect(ids, contains('mine'));
      expect(ids, contains('cat_veg'), reason: 'global categories are shared');
      expect(ids, isNot(contains('theirs')));
    });
  });

  group('Vouchers', () {
    test('vouchers() is scoped to a company', () async {
      final list = await repo.vouchers('c_organic').first;
      expect(list.map((v) => v.code), contains('FRESH20'));
      expect(list.map((v) => v.code), isNot(contains('TECH1000')));
    });

    test('saveVoucher creates and then updates by id', () async {
      await repo.saveVoucher(
        const Voucher(id: 'v_new', companyId: 'c_organic', code: 'NEW10'),
      );
      await repo.saveVoucher(
        const Voucher(
          id: 'v_new',
          companyId: 'c_organic',
          code: 'NEW10',
          discountValue: 25,
        ),
      );

      final list = await repo.vouchers('c_organic').first;
      expect(list.where((v) => v.id == 'v_new'), hasLength(1));
      expect(list.firstWhere((v) => v.id == 'v_new').discountValue, 25);
    });

    test('saveVoucher requires a company', () async {
      expect(
        () =>
            repo.saveVoucher(const Voucher(id: 'v', companyId: '', code: 'X')),
        throwsArgumentError,
      );
    });

    test('voucherByCode ignores case and whitespace', () async {
      final found = await repo.voucherByCode('c_organic', '  fresh20 ');
      expect(found, isNotNull);
      expect(found!.code, 'FRESH20');
    });

    test('voucherByCode does not leak another store\'s code', () async {
      expect(await repo.voucherByCode('c_techtronics', 'FRESH20'), isNull);
      expect(await repo.voucherByCode('c_organic', 'NOPE'), isNull);
    });

    test('deleteVoucher removes the code and is company scoped', () async {
      await repo.saveVoucher(
        const Voucher(id: 'v_del', companyId: 'c_organic', code: 'DELME'),
      );
      await repo.deleteVoucher('v_del', companyId: 'c_organic');

      expect(await repo.voucherByCode('c_organic', 'DELME'), isNull);
    });

    test('the vouchers stream emits after a write', () async {
      final events = <List<Voucher>>[];
      final sub = repo.vouchers('c_organic').listen(events.add);
      await tick();

      await repo.saveVoucher(
        const Voucher(id: 'v_stream', companyId: 'c_organic', code: 'STREAM'),
      );
      await tick();

      expect(events.length, greaterThanOrEqualTo(2));
      expect(events.last.map((v) => v.code), contains('STREAM'));
      await sub.cancel();
    });
  });
}
