import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/domain/catalog.dart';
import 'package:myshop/core/domain/category_tree.dart';
import 'package:myshop/core/models/category.dart';
import 'package:myshop/core/models/product.dart';

/// A2 — customer-facing ordering.
///
/// Categories render per level in admin-defined `sortOrder`; products render
/// by their index in `Category.productList` (missing ids last).
void main() {
  Category cat(
    String id,
    String name, {
    String? parentId,
    int sortOrder = 0,
    DateTime? createdAt,
    List<String> productList = const [],
  }) => Category(
    id: id,
    companyId: 'c_organic',
    name: name,
    parentId: parentId,
    sortOrder: sortOrder,
    createdAt: createdAt,
    productList: productList,
  );

  Product prod(String id, String name) =>
      Product(id: id, companyId: 'c_organic', categoryId: 'cat_a', name: name);

  group('CategoryHierarchy.compareByOrder / sortedByOrder', () {
    test('sortOrder wins over name and creation time', () {
      final sorted = CategoryHierarchy.sortedByOrder([
        cat('c', 'Charlie', sortOrder: 2),
        cat('a', 'Zulu', sortOrder: 0),
        cat('b', 'Alpha', sortOrder: 1),
      ]);

      expect(sorted.map((c) => c.id), ['a', 'b', 'c']);
    });

    test('ties fall back to createdAt then name', () {
      final t1 = DateTime(2026, 1, 1);
      final t2 = DateTime(2026, 2, 1);
      final sorted = CategoryHierarchy.sortedByOrder([
        cat('later', 'Same', sortOrder: 0, createdAt: t2),
        cat('zzz', 'Same', sortOrder: 0),
        cat('early', 'Same', sortOrder: 0, createdAt: t1),
      ]);

      // createdAt first (early < late), missing createdAt last, then name.
      expect(sorted.map((c) => c.id), ['early', 'later', 'zzz']);
    });
  });

  group('CategoryTree per-level order', () {
    test('each level sorts independently by sortOrder', () {
      final tree = CategoryTree.build([
        cat('root_b', 'Root B', sortOrder: 1),
        cat('root_a', 'Root A', sortOrder: 0),
        cat('kid_b', 'Kid B', parentId: 'root_a', sortOrder: 1),
        cat('kid_a', 'Kid A', parentId: 'root_a', sortOrder: 0),
      ]);

      expect(tree.roots.map((n) => n.id), ['root_a', 'root_b']);
      expect(tree.roots.first.children.map((n) => n.id), ['kid_a', 'kid_b']);
    });

    test('docs missing sortOrder never disappear — they sort by name', () {
      final tree = CategoryTree.build([cat('b', 'Beta'), cat('a', 'Alpha')]);
      expect(tree.roots.map((n) => n.id), ['a', 'b']);
    });
  });

  group('Catalog.apply productOrder', () {
    test('relevance sort follows Category.productList, unlisted last', () {
      final products = [
        prod('p3', 'Gamma'),
        prod('p1', 'Alpha'),
        prod('p2', 'Beta'),
        prod('p9', 'Unlisted'),
      ];

      final result = Catalog.apply(
        products,
        const CatalogQuery(productOrder: ['p2', 'p3', 'p1']),
      );

      expect(result.map((p) => p.id), ['p2', 'p3', 'p1', 'p9']);
    });

    test(
      'unlisted products tie-break alphabetically after the listed ones',
      () {
        final products = [
          prod('pz', 'Zeta'),
          prod('pa', 'Aardvark'),
          prod('p1', 'Listed'),
        ];

        final result = Catalog.apply(
          products,
          const CatalogQuery(productOrder: ['p1']),
        );

        expect(result.map((p) => p.id), ['p1', 'pa', 'pz']);
      },
    );

    test('explicit sort options override the curated order', () {
      final products = [prod('p2', 'Beta'), prod('p1', 'Alpha')];

      final result = Catalog.apply(
        products,
        const CatalogQuery(
          productOrder: ['p2', 'p1'],
          sort: ProductSort.nameDesc,
        ),
      );

      expect(result.map((p) => p.id), ['p2', 'p1'], reason: 'nameDesc');
    });

    test('a product listed twice keeps its first position', () {
      final products = [prod('p1', 'One'), prod('p2', 'Two')];
      final result = Catalog.apply(
        products,
        const CatalogQuery(productOrder: ['p2', 'p1', 'p2']),
      );
      expect(result.map((p) => p.id), ['p2', 'p1']);
    });
  });
}
