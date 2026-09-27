import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/app/theme/app_theme.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/app_user.dart';
import 'package:myshop/core/models/category.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/core/services/auth_session.dart';
import 'package:myshop/core/services/service_locator.dart';
import 'package:myshop/features/admin/categories/admin_categories_screen.dart';
import 'package:myshop/features/admin/categories/widgets/product_assignment_picker.dart';

void main() {
  group('Category Model Tests', () {
    test('serializes toMap and deserializes fromMap accurately', () {
      final category = Category(
        id: 'cat_electronics',
        companyId: 'company_123',
        name: 'Electronics',
        details: 'Gadgets and appliances',
        type: 'Electronics',
        parentId: 'cat_root',
        iconUrl: '📱',
        productList: ['prod_1', 'prod_2'],
      );

      final map = category.toMap();
      expect(map['name'], 'Electronics');
      expect(map['companyId'], 'company_123');
      expect(map['details'], 'Gadgets and appliances');
      expect(map['type'], 'Electronics');
      expect(map['parentId'], 'cat_root');
      expect(map['iconUrl'], '📱');
      expect(map['productList'], ['prod_1', 'prod_2']);

      final restored = Category.fromMap('cat_electronics', map);
      expect(restored.id, 'cat_electronics');
      expect(restored.name, 'Electronics');
      expect(restored.companyId, 'company_123');
      expect(restored.details, 'Gadgets and appliances');
      expect(restored.type, 'Electronics');
      expect(restored.parentId, 'cat_root');
      expect(restored.iconUrl, '📱');
      expect(restored.productList, ['prod_1', 'prod_2']);
    });

    test('copyWith modifies fields and supports clearing parentId', () {
      final original = Category(
        id: 'cat_1',
        name: 'Dairy',
        companyId: 'c1',
        parentId: 'cat_parent',
        productList: ['p1'],
      );

      final updated = original.copyWith(
        name: 'Fresh Dairy',
        productList: ['p1', 'p2'],
      );

      expect(updated.id, 'cat_1');
      expect(updated.name, 'Fresh Dairy');
      expect(updated.parentId, 'cat_parent');
      expect(updated.productList, ['p1', 'p2']);

      final clearedParent = updated.copyWith(clearParentId: true);
      expect(clearedParent.parentId, isNull);
    });
  });

  group('Category Hierarchy & Validation Logic', () {
    Set<String> getDescendantIds(String rootId, List<Category> allCategories) {
      final descendants = <String>{};
      final queue = <String>[rootId];

      while (queue.isNotEmpty) {
        final current = queue.removeAt(0);
        for (final cat in allCategories) {
          if (cat.parentId == current && !descendants.contains(cat.id)) {
            descendants.add(cat.id);
            queue.add(cat.id);
          }
        }
      }
      return descendants;
    }

    test('detects all direct and nested descendants to prevent cycles', () {
      // Tree: Root -> Men -> Shirts -> Casual Shirts
      final tree = [
        const Category(id: 'root', name: 'Apparel'),
        const Category(id: 'men', name: 'Men', parentId: 'root'),
        const Category(id: 'shirts', name: 'Shirts', parentId: 'men'),
        const Category(id: 'casual', name: 'Casual Shirts', parentId: 'shirts'),
        const Category(id: 'women', name: 'Women', parentId: 'root'),
      ];

      // If editing 'men':
      final menDescendants = getDescendantIds('men', tree);
      expect(menDescendants, containsAll(['shirts', 'casual']));
      expect(menDescendants, isNot(contains('women')));
      expect(menDescendants, isNot(contains('root')));

      // If editing 'shirts':
      final shirtsDescendants = getDescendantIds('shirts', tree);
      expect(shirtsDescendants, contains('casual'));
      expect(shirtsDescendants, isNot(contains('men')));
    });

    test('validates case-insensitive unique name within same companyId', () {
      final categories = [
        const Category(id: '1', name: 'Groceries', companyId: 'c_abc'),
        const Category(id: '2', name: 'Electronics', companyId: 'c_abc'),
        const Category(id: '3', name: 'Groceries', companyId: 'c_xyz'),
      ];

      bool isDuplicate(String name, String companyId, {String excludeId = ''}) {
        final target = name.trim().toLowerCase();
        return categories.any(
          (c) =>
              (excludeId.isEmpty || c.id != excludeId) &&
              c.companyId == companyId &&
              c.name.trim().toLowerCase() == target,
        );
      }

      // "groceries" exists in c_abc
      expect(isDuplicate('groceries', 'c_abc'), isTrue);
      expect(isDuplicate('GROCERIES', 'c_abc'), isTrue);
      expect(isDuplicate('  Groceries  ', 'c_abc'), isTrue);

      // Same name in different company is allowed
      expect(isDuplicate('Electronics', 'c_xyz'), isFalse);

      // In edit mode for id '1', own name is not duplicate
      expect(isDuplicate('Groceries', 'c_abc', excludeId: '1'), isFalse);
    });
  });

  group('ProductAssignmentPicker Widget Tests', () {
    final sampleProducts = [
      const Product(
        id: 'p_101',
        name: 'Organic Honey',
        companyId: 'comp_1',
        categoryId: 'cat_1',
        amount: 250,
        discountAmt: 220,
      ),
      const Product(
        id: 'p_102',
        name: 'Green Tea',
        companyId: 'comp_1',
        categoryId: 'cat_1',
        amount: 150,
      ),
      const Product(
        id: 'p_103',
        name: 'Almond Milk',
        companyId: 'comp_1',
        categoryId: 'cat_1',
        amount: 180,
      ),
    ];

    testWidgets(
      'renders available and assigned products, handles search and selection',
      (tester) async {
        List<String> selected = ['p_101'];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return ProductAssignmentPicker(
                    allProducts: sampleProducts,
                    selectedProductIds: selected,
                    onSelectedChanged: (newSelected) {
                      setState(() {
                        selected = newSelected;
                      });
                    },
                  );
                },
              ),
            ),
          ),
        );

        // Verify counter
        expect(find.text('1 product selected'), findsOneWidget);

        // Verify product names are rendered
        expect(find.text('Organic Honey'), findsOneWidget);
        expect(find.text('Green Tea'), findsOneWidget);
        expect(find.text('Almond Milk'), findsOneWidget);

        // Search for "Green"
        await tester.enterText(find.byType(TextField), 'Green');
        await tester.pumpAndSettle();

        expect(find.text('Green Tea'), findsOneWidget);
        expect(find.text('Organic Honey'), findsNothing);
        expect(find.text('Almond Milk'), findsNothing);

        // Clear search
        await tester.tap(find.byIcon(Icons.clear));
        await tester.pumpAndSettle();

        expect(find.text('Organic Honey'), findsOneWidget);
        expect(find.text('Green Tea'), findsOneWidget);
      },
    );
  });

  group('AdminCategoriesScreen Tests', () {
    testWidgets('displays category ID and copies to clipboard on tap', (
      tester,
    ) async {
      final mockRepo = MockAppRepository();
      ServiceLocator.instance.repository = mockRepo;
      AuthSession.currentUser = AppUser(
        id: 'a_1',
        companyId: 'c_organic',
        companyName: 'GreenLeaf Organics',
        name: 'Admin GreenLeaf',
        email: 'admin@greenleaf.in',
        role: 'admin',
      );

      await mockRepo.saveCategory(
        const Category(
          id: 'cat_beverages',
          companyId: 'c_organic',
          name: 'Beverages',
          type: 'Drinks',
          productList: ['p_101'],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const AdminCategoriesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Beverages'), findsOneWidget);
      expect(find.text('ID: cat_beverages'), findsOneWidget);

      // The id badge is part of every category row, so scope the assertions
      // to the tile we just created (global seed categories are listed too).
      final tile = find.byKey(const Key('category-tile-cat_beverages'));
      expect(tile, findsOneWidget);
      expect(
        find.descendant(of: tile, matching: find.byIcon(Icons.copy_rounded)),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('category-id-cat_beverages')));
      await tester.pumpAndSettle();
      expect(
        find.text('Category ID copied to clipboard: cat_beverages'),
        findsOneWidget,
      );
    });
  });
}
