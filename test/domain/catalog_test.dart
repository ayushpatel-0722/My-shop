import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/domain/catalog.dart';
import 'package:myshop/core/models/product.dart';

Product p(
  String id, {
  String companyId = 'c_organic',
  String categoryId = 'cat_veg',
  String name = 'Product',
  String sku = '',
  double amount = 100,
  double discount = 0,
  int stock = 50,
  bool unlimited = false,
  String details = '',
}) => Product(
  id: id,
  companyId: companyId,
  categoryId: categoryId,
  name: name,
  sku: sku,
  details: details,
  amount: amount,
  discountAmt: discount,
  stockQty: stock,
  isUnlimitedStock: unlimited,
);

void main() {
  group('Catalog — search', () {
    final tomato = p(
      'p1',
      name: 'Fresh Tomatoes',
      sku: 'TOM-500',
      details: 'Vine ripened',
    );

    test('matches on name, case-insensitively', () {
      expect(Catalog.matchesSearch(tomato, 'TOMATO'), isTrue);
      expect(Catalog.matchesSearch(tomato, 'tomato'), isTrue);
    });

    test('matches on sku and details', () {
      expect(Catalog.matchesSearch(tomato, 'tom-500'), isTrue);
      expect(Catalog.matchesSearch(tomato, 'vine'), isTrue);
    });

    test('every term must match (multi-word search)', () {
      expect(Catalog.matchesSearch(tomato, 'fresh tomatoes'), isTrue);
      expect(Catalog.matchesSearch(tomato, 'fresh potatoes'), isFalse);
    });

    test('an empty query matches everything', () {
      expect(Catalog.matchesSearch(tomato, '   '), isTrue);
      expect(Catalog.matchesSearch(tomato, ''), isTrue);
    });
  });

  group('Catalog — stock status', () {
    test('classifies stock correctly', () {
      expect(Catalog.stockStatus(p('a', stock: 0)), StockStatus.outOfStock);
      expect(Catalog.stockStatus(p('a', stock: 5)), StockStatus.lowStock);
      expect(Catalog.stockStatus(p('a', stock: 500)), StockStatus.inStock);
      expect(
        Catalog.stockStatus(p('a', stock: 0, unlimited: true)),
        StockStatus.unlimited,
      );
    });

    test('honours a custom low-stock threshold', () {
      expect(
        Catalog.stockStatus(p('a', stock: 15), lowStockThreshold: 10),
        StockStatus.inStock,
      );
      expect(
        Catalog.stockStatus(p('a', stock: 9), lowStockThreshold: 10),
        StockStatus.lowStock,
      );
    });

    test('only out-of-stock items are not sellable', () {
      expect(Catalog.stockStatus(p('a', stock: 0)).isSellable, isFalse);
      expect(Catalog.stockStatus(p('a', stock: 1)).isSellable, isTrue);
    });
  });

  group('Catalog — filtering & sorting', () {
    final products = <Product>[
      p('p1', name: 'Banana', amount: 40),
      p('p2', name: 'Apple', amount: 60, discount: 45),
      p('p3', name: 'Carrot', amount: 20, categoryId: 'cat_veg2'),
      p('p4', name: 'Zucchini', amount: 80, companyId: 'c_other'),
      p('p5', name: 'Sold out bread', amount: 30, stock: 0),
    ];

    test('filters by company', () {
      final result = Catalog.apply(
        products,
        CatalogQuery(companyIds: {'c_organic'}),
      );
      expect(result.map((e) => e.id), isNot(contains('p4')));
    });

    test('filters by category', () {
      final result = Catalog.apply(
        products,
        CatalogQuery(categoryIds: {'cat_veg2'}),
      );
      expect(result.single.id, 'p3');
    });

    test('filters to discounted items only', () {
      final result = Catalog.apply(
        products,
        CatalogQuery(discountedOnly: true),
      );
      expect(result.single.id, 'p2');
    });

    test('filters to items in stock only', () {
      final result = Catalog.apply(products, CatalogQuery(inStockOnly: true));
      expect(result.map((e) => e.id), isNot(contains('p5')));
    });

    test('sorts by name and by price', () {
      expect(
        Catalog.apply(
          products,
          CatalogQuery(sort: ProductSort.nameAsc),
        ).map((e) => e.name).toList().sublist(0, 4),
        ['Apple', 'Banana', 'Carrot', 'Zucchini'],
      );
      expect(
        Catalog.apply(
          products,
          CatalogQuery(sort: ProductSort.priceDesc),
        ).first.name,
        'Zucchini',
      );
      final cheapestFirst = Catalog.apply(
        products,
        CatalogQuery(sort: ProductSort.priceAsc),
      );
      expect(cheapestFirst.first.name, 'Carrot');
      expect(cheapestFirst.last.name, 'Sold out bread');
    });

    test('sold out items sink to the bottom', () {
      final result = Catalog.apply(products, const CatalogQuery());
      expect(result.last.id, 'p5');

      final relevanceOnly = Catalog.apply(
        products,
        const CatalogQuery(includeOutOfStockLast: false),
      );
      expect(relevanceOnly.last.id, 'p5', reason: 'source order is preserved');
    });

    test('the input list is never mutated', () {
      final source = <Product>[p('a', name: 'Zzz'), p('b', name: 'Aaa')];
      final sorted = Catalog.apply(
        source,
        CatalogQuery(sort: ProductSort.nameAsc),
      );
      expect(sorted.first.name, 'Aaa');
      expect(source.first.name, 'Zzz');
    });

    test('an identity query keeps everything', () {
      expect(CatalogQuery().isIdentity, isTrue);
      expect(CatalogQuery(search: 'x').isIdentity, isFalse);
      expect(
        Catalog.apply(products, const CatalogQuery()).length,
        products.length,
      );
    });
  });

  group('Catalog — aggregates', () {
    final products = <Product>[
      p('p1', categoryId: 'cat_veg'),
      p('p2', categoryId: 'cat_veg'),
      p('p3', categoryId: 'cat_fruit'),
      p('p4', categoryId: ''),
      p('p5', stock: 3),
      p('p6', stock: 0),
      p('p7', amount: 100, discount: 80),
    ];

    test('counts products per category', () {
      final counts = Catalog.countByCategory(products);
      expect(counts['cat_veg'], 2);
      expect(counts['cat_fruit'], 1);
      expect(counts.containsKey(''), isFalse);
    });

    test('lists used category ids', () {
      expect(Catalog.usedCategoryIds(products), {'cat_veg', 'cat_fruit'});
    });

    test('finds low stock products', () {
      expect(Catalog.lowStock(products).map((e) => e.id), ['p5']);
    });

    test('summarises the catalogue', () {
      final summary = Catalog.summarize(products);
      expect(summary.total, 7);
      expect(summary.outOfStock, 1);
      expect(summary.lowStock, 1);
      expect(summary.discounted, 1);
      expect(summary.inStock, 6);
    });
  });

  group('Product — helpers used by the catalogue', () {
    test('searchIndex covers the searchable fields', () {
      final product = p('p1', name: 'Honey', sku: 'HNY-1', details: 'Raw');
      expect(product.searchIndex, contains('honey'));
      expect(product.searchIndex, contains('hny-1'));
      expect(product.searchIndex, contains('raw'));
    });

    test('discount helpers', () {
      final discounted = p('p1', amount: 200, discount: 150);
      expect(discounted.price, 150);
      expect(discounted.isDiscounted, isTrue);
      expect(discounted.discountPercent, 25);

      final full = p('p2', amount: 200);
      expect(full.price, 200);
      expect(full.isDiscounted, isFalse);
      expect(full.discountPercent, 0);
    });

    test('isLowStock respects the unlimited flag', () {
      expect(p('a', stock: 2).isLowStock(), isTrue);
      expect(p('a', stock: 0).isLowStock(), isFalse);
      expect(p('a', stock: 2, unlimited: true).isLowStock(), isFalse);
    });
  });
}
