import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/domain/category_tree.dart';
import 'package:myshop/core/models/category.dart';

void main() {
  group('CategoryTree — building', () {
    final flat = <Category>[
      const Category(id: 'root', name: 'Apparel'),
      const Category(id: 'men', name: 'Men', parentId: 'root'),
      const Category(id: 'shirts', name: 'Shirts', parentId: 'men'),
      const Category(id: 'women', name: 'Women', parentId: 'root'),
      const Category(id: 'lone', name: 'Electronics'),
    ];

    test('nests children under their parents', () {
      final tree = CategoryTree.build(flat);

      expect(tree.roots.map((n) => n.id), ['root', 'lone']);
      final apparel = tree.roots.firstWhere((n) => n.id == 'root');
      expect(apparel.children.map((n) => n.id), ['men', 'women']);
      expect(apparel.depth, 0);
      expect(apparel.children.first.depth, 1);
      expect(
        apparel.children.firstWhere((n) => n.id == 'men').children.single.id,
        'shirts',
      );
    });

    test('sorts siblings alphabetically, case-insensitively', () {
      final tree = CategoryTree.build([
        const Category(id: 'b', name: 'bananas'),
        const Category(id: 'a', name: 'Apples'),
        const Category(id: 'c', name: 'cherries'),
      ]);
      expect(tree.roots.map((n) => n.name), ['Apples', 'bananas', 'cherries']);
    });

    test('a missing parent promotes the child to a root', () {
      final tree = CategoryTree.build([
        const Category(id: 'orphan', name: 'Orphan', parentId: 'does-not-exist'),
      ]);
      expect(tree.roots.map((n) => n.id), ['orphan']);
    });

    test('a self referencing parent does not hang the builder', () {
      final tree = CategoryTree.build([
        const Category(id: 'loop', name: 'Loop', parentId: 'loop'),
      ]);
      expect(tree.roots.map((n) => n.id), ['loop']);
      expect(tree.repairedCycles.map((c) => c.id), ['loop']);
    });

    test('a two-node cycle is repaired and reported', () {
      final tree = CategoryTree.build([
        const Category(id: 'a', name: 'A', parentId: 'b'),
        const Category(id: 'b', name: 'B', parentId: 'a'),
      ]);
      expect(tree.roots, isNotEmpty);
      expect(tree.repairedCycles, isNotEmpty);
    });

    test('flatten returns a depth-first list', () {
      final tree = CategoryTree.build(flat);
      expect(tree.flatten().map((n) => n.id),
          ['root', 'men', 'shirts', 'women', 'lone']);
    });

    test('an empty list builds an empty tree', () {
      final tree = CategoryTree.build(const <Category>[]);
      expect(tree.roots, isEmpty);
      expect(tree.flatten(), isEmpty);
    });
  });

  group('CategoryTree — counts', () {
    test('totalProductCount includes descendants', () {
      final tree = CategoryTree.build([
        const Category(id: 'root', name: 'Root', productList: ['p1']),
        const Category(id: 'child', name: 'Child', parentId: 'root', productList: ['p2', 'p3']),
        const Category(
          id: 'grand',
          name: 'Grand',
          parentId: 'child',
          productList: ['p4'],
        ),
      ]);

      final root = tree.roots.single;
      expect(root.directProductCount, 1);
      expect(root.totalProductCount, 4);
      expect(root.descendantCount, 2);
      expect(root.isLeaf, isFalse);
      expect(root.children.single.totalProductCount, 3);
    });
  });

  group('CategoryTree — visible rows', () {
    test('children are hidden when the parent is collapsed', () {
      final tree = CategoryTree.build([
        const Category(id: 'root', name: 'Root'),
        const Category(id: 'child', name: 'Child', parentId: 'root'),
      ]);

      expect(tree.visibleRows({'root'}).map((n) => n.id), ['root', 'child']);
      expect(tree.visibleRows(<String>{}).map((n) => n.id), ['root']);
    });

    test('defaultExpandedIds expands every parent', () {
      final tree = CategoryTree.build([
        const Category(id: 'root', name: 'Root'),
        const Category(id: 'child', name: 'Child', parentId: 'root'),
        const Category(id: 'leaf', name: 'Leaf', parentId: 'child'),
      ]);
      final expanded = tree.defaultExpandedIds;
      expect(expanded, containsAll(['root', 'child']));
      expect(expanded, isNot(contains('leaf')));
    });
  });

  group('CategoryHierarchy — helpers', () {
    final all = <Category>[
      const Category(id: 'root', name: 'Apparel'),
      const Category(id: 'men', name: 'Men', parentId: 'root'),
      const Category(id: 'shirts', name: 'Shirts', parentId: 'men'),
      const Category(id: 'women', name: 'Women', parentId: 'root'),
    ];

    test('descendantIds walks the whole sub-tree', () {
      expect(CategoryHierarchy.descendantIds('root', all), {'men', 'shirts', 'women'});
      expect(CategoryHierarchy.descendantIds('men', all), {'shirts'});
      expect(CategoryHierarchy.descendantIds('shirts', all), isEmpty);
    });

    test('descendantIds survives a cycle in stored data', () {
      final cyclic = <Category>[
        const Category(id: 'a', name: 'A', parentId: 'c'),
        const Category(id: 'b', name: 'B', parentId: 'a'),
        const Category(id: 'c', name: 'C', parentId: 'b'),
      ];
      expect(CategoryHierarchy.descendantIds('a', cyclic), {'b', 'c'});
    });

    test('wouldCreateCycle catches self and descendant parents', () {
      expect(
        CategoryHierarchy.wouldCreateCycle(
          categoryId: 'men',
          newParentId: 'men',
          all: all,
        ),
        isTrue,
      );
      expect(
        CategoryHierarchy.wouldCreateCycle(
          categoryId: 'men',
          newParentId: 'shirts',
          all: all,
        ),
        isTrue,
      );
      expect(
        CategoryHierarchy.wouldCreateCycle(
          categoryId: 'men',
          newParentId: 'women',
          all: all,
        ),
        isFalse,
      );
      expect(
        CategoryHierarchy.wouldCreateCycle(
          categoryId: 'men',
          newParentId: null,
          all: all,
        ),
        isFalse,
      );
    });

    test('pathTo returns the breadcrumb', () {
      expect(
        CategoryHierarchy.pathTo('shirts', all).map((c) => c.name),
        ['Apparel', 'Men', 'Shirts'],
      );
      expect(CategoryHierarchy.pathLabel('shirts', all), 'Apparel / Men / Shirts');
    });

    test('pathTo terminates on a cycle', () {
      final cyclic = <Category>[
        const Category(id: 'a', name: 'A', parentId: 'b'),
        const Category(id: 'b', name: 'B', parentId: 'a'),
      ];
      expect(CategoryHierarchy.pathTo('a', cyclic).length, 2);
    });

    test('pathTo on an unknown id is empty', () {
      expect(CategoryHierarchy.pathTo('nope', all), isEmpty);
    });
  });
}
