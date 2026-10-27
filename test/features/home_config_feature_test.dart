import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/category.dart';
import 'package:myshop/core/models/home_explore_category.dart';
import 'package:myshop/core/models/home_trending_item.dart';
import 'package:myshop/core/models/product.dart';

void main() {
  group('HomeExploreCategory Model', () {
    test('creates and serializes to/from map correctly', () {
      final now = DateTime(2026, 10, 20, 12, 0);
      final item = HomeExploreCategory(
        id: 'masala-mart_cat-1',
        shopId: 'masala-mart',
        shopName: 'Masala Mart',
        categoryId: 'cat-whole-spices',
        categoryName: 'Whole Spices',
        isActive: true,
        displayOrder: 2,
        createdAt: now,
        updatedAt: now,
        createdBy: 'admin-user',
      );

      final map = item.toMap();
      expect(map['id'], 'masala-mart_cat-1');
      expect(map['shopId'], 'masala-mart');
      expect(map['shopName'], 'Masala Mart');
      expect(map['categoryId'], 'cat-whole-spices');
      expect(map['categoryName'], 'Whole Spices');
      expect(map['isActive'], true);
      expect(map['displayOrder'], 2);
      expect(map['createdBy'], 'admin-user');

      final reconstructed = HomeExploreCategory.fromMap(
        map,
        id: 'masala-mart_cat-1',
      );
      expect(reconstructed.id, item.id);
      expect(reconstructed.shopId, item.shopId);
      expect(reconstructed.categoryId, item.categoryId);
      expect(reconstructed.categoryName, item.categoryName);
      expect(reconstructed.isActive, item.isActive);
      expect(reconstructed.displayOrder, item.displayOrder);
    });

    test('copyWith updates fields as expected', () {
      const item = HomeExploreCategory(
        id: '1',
        shopId: 'masala-mart',
        categoryId: 'cat-1',
        isActive: true,
        displayOrder: 0,
      );

      final updated = item.copyWith(
        isActive: false,
        displayOrder: 5,
        categoryName: 'Blended Masalas',
      );

      expect(updated.id, '1');
      expect(updated.shopId, 'masala-mart');
      expect(updated.categoryId, 'cat-1');
      expect(updated.isActive, false);
      expect(updated.displayOrder, 5);
      expect(updated.categoryName, 'Blended Masalas');
    });
  });

  group('HomeTrendingItem Model', () {
    test(
      'creates and serializes product and category trending items correctly',
      () {
        const prodItem = HomeTrendingItem(
          id: 'trend-prod-1',
          shopId: 'masala-mart',
          shopName: 'Masala Mart',
          itemType: 'product',
          productId: 'prod-turmeric',
          productName: 'Turmeric Powder',
          isActive: true,
          displayOrder: 0,
        );

        expect(prodItem.isProduct, true);
        expect(prodItem.isCategory, false);

        final prodMap = prodItem.toMap();
        expect(prodMap['itemType'], 'product');
        expect(prodMap['productId'], 'prod-turmeric');
        expect(prodMap['categoryId'], isNull);

        final reconstructedProd = HomeTrendingItem.fromMap(
          prodMap,
          id: 'trend-prod-1',
        );
        expect(reconstructedProd.isProduct, true);
        expect(reconstructedProd.productId, 'prod-turmeric');

        const catItem = HomeTrendingItem(
          id: 'trend-cat-1',
          shopId: 'masala-mart',
          itemType: 'category',
          categoryId: 'cat-whole-spices',
          categoryName: 'Whole Spices',
          isActive: true,
          displayOrder: 1,
        );

        expect(catItem.isProduct, false);
        expect(catItem.isCategory, true);

        final catMap = catItem.toMap();
        expect(catMap['itemType'], 'category');
        expect(catMap['categoryId'], 'cat-whole-spices');
        expect(catMap['productId'], isNull);
      },
    );
  });

  group('Repository Home Config Operations', () {
    late MockAppRepository repo;

    setUp(() {
      repo = MockAppRepository();
    });

    test(
      'saves, queries, filters, reorders, and deletes HomeExploreCategories',
      () async {
        // Initially empty
        final initial = await repo
            .homeExploreCategories(shopId: 'masala-mart')
            .first;
        expect(initial, isEmpty);

        // Save 3 categories
        const cat1 = HomeExploreCategory(
          id: 'cat_entry_1',
          shopId: 'masala-mart',
          categoryId: 'cat-whole-spices',
          categoryName: 'Whole Spices',
          displayOrder: 0,
          isActive: true,
        );
        const cat2 = HomeExploreCategory(
          id: 'cat_entry_2',
          shopId: 'masala-mart',
          categoryId: 'cat-masala-powders',
          categoryName: 'Masala Powders',
          displayOrder: 1,
          isActive: false, // inactive
        );
        const cat3 = HomeExploreCategory(
          id: 'cat_entry_3',
          shopId: 'coffee-house',
          categoryId: 'cat-coffee-beans',
          categoryName: 'Coffee Beans',
          displayOrder: 0,
          isActive: true,
        );

        await repo.saveHomeExploreCategory(cat1);
        await repo.saveHomeExploreCategory(cat2);
        await repo.saveHomeExploreCategory(cat3);

        // Query all for masala-mart
        final allMasala = await repo
            .homeExploreCategories(shopId: 'masala-mart')
            .first;
        expect(allMasala.length, 2);
        expect(
          allMasala.map((e) => e.id),
          containsAll(['cat_entry_1', 'cat_entry_2']),
        );

        // Query activeOnly for masala-mart
        final activeMasala = await repo
            .homeExploreCategories(shopId: 'masala-mart', activeOnly: true)
            .first;
        expect(activeMasala.length, 1);
        expect(activeMasala.first.id, 'cat_entry_1');

        // Reorder categories
        final reordered = [
          cat2.copyWith(displayOrder: 0),
          cat1.copyWith(displayOrder: 1),
        ];
        await repo.reorderHomeExploreCategories(reordered);

        final afterReorder = await repo
            .homeExploreCategories(shopId: 'masala-mart')
            .first;
        expect(afterReorder.first.id, 'cat_entry_2');
        expect(afterReorder.first.displayOrder, 0);
        expect(afterReorder.last.id, 'cat_entry_1');
        expect(afterReorder.last.displayOrder, 1);

        // Delete a category
        await repo.deleteHomeExploreCategory('cat_entry_2');
        final afterDelete = await repo
            .homeExploreCategories(shopId: 'masala-mart')
            .first;
        expect(afterDelete.length, 1);
        expect(afterDelete.first.id, 'cat_entry_1');
      },
    );

    test(
      'saves, queries, filters, reorders, and deletes HomeTrendingItems',
      () async {
        // Initially empty
        final initial = await repo.homeTrendingNow(shopId: 'masala-mart').first;
        expect(initial, isEmpty);

        // Save mixed product and category items
        const item1 = HomeTrendingItem(
          id: 'trend_1',
          shopId: 'masala-mart',
          itemType: 'product',
          productId: 'prod-turmeric',
          productName: 'Turmeric Powder',
          displayOrder: 0,
          isActive: true,
        );
        const item2 = HomeTrendingItem(
          id: 'trend_2',
          shopId: 'masala-mart',
          itemType: 'category',
          categoryId: 'cat-whole-spices',
          categoryName: 'Whole Spices',
          displayOrder: 1,
          isActive: true,
        );
        const item3 = HomeTrendingItem(
          id: 'trend_3',
          shopId: 'masala-mart',
          itemType: 'product',
          productId: 'prod-coriander',
          productName: 'Coriander Powder',
          displayOrder: 2,
          isActive: false, // inactive
        );

        await repo.saveHomeTrendingItem(item1);
        await repo.saveHomeTrendingItem(item2);
        await repo.saveHomeTrendingItem(item3);

        // Query all for masala-mart
        final all = await repo.homeTrendingNow(shopId: 'masala-mart').first;
        expect(all.length, 3);

        // Query activeOnly
        final activeOnly = await repo
            .homeTrendingNow(shopId: 'masala-mart', activeOnly: true)
            .first;
        expect(activeOnly.length, 2);
        expect(activeOnly[0].isProduct, true);
        expect(activeOnly[1].isCategory, true);

        // Reorder items
        final reordered = [
          item2.copyWith(displayOrder: 0),
          item1.copyWith(displayOrder: 1),
          item3.copyWith(displayOrder: 2),
        ];
        await repo.reorderHomeTrendingItems(reordered);

        final afterReorder = await repo
            .homeTrendingNow(shopId: 'masala-mart', activeOnly: true)
            .first;
        expect(afterReorder[0].id, 'trend_2');
        expect(afterReorder[0].isCategory, true);
        expect(afterReorder[1].id, 'trend_1');
        expect(afterReorder[1].isProduct, true);

        // Delete an item
        await repo.deleteHomeTrendingItem('trend_1');
        final afterDelete = await repo
            .homeTrendingNow(shopId: 'masala-mart', activeOnly: true)
            .first;
        expect(afterDelete.length, 1);
        expect(afterDelete.first.id, 'trend_2');
      },
    );
  });

  group('Trending Now - Category Filtering & Product Selection', () {
    // Exact matching logic used in AdminTrendingNowScreen
    bool productMatchesCategory(Product p, Category cat) {
      final catId = p.categoryId.trim();
      if (catId.isNotEmpty) {
        if (catId == cat.id ||
            catId.toLowerCase() == cat.id.toLowerCase() ||
            catId.toLowerCase() == cat.name.toLowerCase() ||
            catId.replaceAll(' ', '-').toLowerCase() == cat.id.toLowerCase() ||
            catId.replaceAll('-', ' ').toLowerCase() ==
                cat.name.toLowerCase()) {
          return true;
        }
      }
      return cat.productList.contains(p.id);
    }

    const catWholeSpices = Category(
      id: 'cat-whole-spices',
      companyId: 'masala-mart',
      name: 'Whole Spices',
      productList: ['prod-cardamom'],
    );

    const catPowderedSpices = Category(
      id: 'cat-powdered-spices',
      companyId: 'masala-mart',
      name: 'Powdered Spices',
      productList: [],
    );

    final products = [
      const Product(
        id: 'prod-pepper',
        companyId: 'masala-mart',
        categoryId: 'cat-whole-spices',
        name: 'Whole Black Pepper',
        sku: 'WBP-01',
        amount: 150,
      ),
      const Product(
        id: 'prod-cardamom',
        companyId: 'masala-mart',
        categoryId: '', // matched via cat.productList
        name: 'Green Cardamom',
        sku: 'GC-02',
        amount: 320,
      ),
      const Product(
        id: 'prod-turmeric',
        companyId: 'masala-mart',
        categoryId: 'cat-powdered-spices',
        name: 'Pure Turmeric Powder',
        sku: 'TP-03',
        amount: 80,
      ),
      const Product(
        id: 'prod-chilli',
        companyId: 'masala-mart',
        categoryId: 'cat-powdered-spices',
        name: 'Red Chilli Powder',
        sku: 'RCP-04',
        amount: 95,
      ),
    ];

    test('filters products strictly by selected category', () {
      final wholeProducts = products
          .where((p) => productMatchesCategory(p, catWholeSpices))
          .toList();

      expect(wholeProducts.length, 2);
      expect(
        wholeProducts.map((p) => p.id),
        containsAll(['prod-pepper', 'prod-cardamom']),
      );
      expect(wholeProducts.any((p) => p.id == 'prod-turmeric'), isFalse);

      final powderedProducts = products
          .where((p) => productMatchesCategory(p, catPowderedSpices))
          .toList();

      expect(powderedProducts.length, 2);
      expect(
        powderedProducts.map((p) => p.id),
        containsAll(['prod-turmeric', 'prod-chilli']),
      );
    });

    test('search filters products within selected category', () {
      final wholeProducts = products
          .where((p) => productMatchesCategory(p, catWholeSpices))
          .toList();

      const query = 'pepper';
      final searchFiltered = wholeProducts.where((p) {
        return p.name.toLowerCase().contains(query) ||
            p.sku.toLowerCase().contains(query);
      }).toList();

      expect(searchFiltered.length, 1);
      expect(searchFiltered.first.id, 'prod-pepper');
    });

    test(
      'adds selected products as Trending items with itemType: product and never category',
      () {
        final existingEntries = <HomeTrendingItem>[];

        // Admin selects 2 products from category filter
        final selectedProductIds = {'prod-pepper', 'prod-cardamom'};
        final createdItems = <HomeTrendingItem>[];
        int offset = 0;

        for (final pId in selectedProductIds) {
          final p = products.firstWhere((prod) => prod.id == pId);
          createdItems.add(
            HomeTrendingItem(
              id: 'masala-mart_product_${p.id}',
              shopId: 'masala-mart',
              shopName: 'Masala Mart',
              itemType: 'product', // strictly product
              productId: p.id,
              productName: p.name,
              categoryName: catWholeSpices.name,
              isActive: true,
              displayOrder: existingEntries.length + offset,
              createdAt: DateTime.now(),
              createdBy: 'admin_123',
            ),
          );
          offset++;
        }

        expect(createdItems.length, 2);
        for (final item in createdItems) {
          expect(item.isProduct, isTrue);
          expect(item.isCategory, isFalse);
          expect(item.itemType, 'product');
          expect(item.shopId, 'masala-mart');
          expect(item.isActive, isTrue);
        }
        expect(createdItems[0].displayOrder, 0);
        expect(createdItems[1].displayOrder, 1);
      },
    );

    test('prevents duplicates for products already added in trending', () {
      final existingEntries = [
        const HomeTrendingItem(
          id: 'masala-mart_product_prod-pepper',
          shopId: 'masala-mart',
          itemType: 'product',
          productId: 'prod-pepper',
          productName: 'Whole Black Pepper',
          displayOrder: 0,
        ),
      ];

      final existingProductIds = existingEntries
          .where((e) => e.isProduct && e.productId != null)
          .map((e) => e.productId!)
          .toSet();

      expect(existingProductIds.contains('prod-pepper'), isTrue);
      expect(existingProductIds.contains('prod-cardamom'), isFalse);

      final availableProducts = products
          .where((p) => !existingProductIds.contains(p.id))
          .toList();

      expect(availableProducts.any((p) => p.id == 'prod-pepper'), isFalse);
      expect(availableProducts.any((p) => p.id == 'prod-cardamom'), isTrue);
    });
  });
}
