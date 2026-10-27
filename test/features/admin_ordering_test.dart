import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/app/l10n/app_localizations.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/category.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/features/admin/categories/admin_categories_screen.dart';
import 'package:myshop/features/admin/categories/widgets/product_assignment_picker.dart';

import '../helpers/test_harness.dart';

/// A2 — drag-reorder of categories (F1) and products inside a category (F2).
///
/// Free-tier friendly: state is written only on drop / save, one batch.
void main() {
  late MockAppRepository repo;

  setUp(() {
    TestHarness.setupPlatformChannels();
    repo = TestHarness.useMockRepository();
    TestHarness.signIn(TestHarness.admin);
  });

  tearDown(() => TestHarness.signOut());

  group('F1 — category reorder', () {
    Future<void> seedTwo() async {
      await repo.saveCategory(
        const Category(
          id: 'cat_a',
          companyId: 'c_organic',
          name: 'Apparel',
          createdAt: null,
        ),
      );
      await repo.saveCategory(
        const Category(id: 'cat_b', companyId: 'c_organic', name: 'Bakery'),
      );
    }

    testWidgets('the Reorder toggle swaps the list for the drag view', (
      tester,
    ) async {
      await seedTwo();
      await pumpTestApp(tester, const AdminCategoriesScreen());

      // Normal mode has tiles with edit/delete actions, no handles.
      expect(find.byKey(const Key('category-tile-cat_a')), findsOneWidget);
      expect(find.byKey(const Key('category-drag-handle-cat_a')), findsNothing);

      await tester.tap(find.byKey(const Key('category-reorder-toggle')));
      await tester.pumpAndSettle();

      expect(find.text('Reordering: top level'), findsOneWidget);
      expect(
        find.byKey(const Key('category-drag-handle-cat_a')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('category-drag-handle-cat_b')),
        findsOneWidget,
      );
      expect(
        find.text('Drag the ≡ handle to set the order customers see.'),
        findsOneWidget,
      );
      // Edit / delete stay hidden while reordering.
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);

      await tester.tap(find.byKey(const Key('category-reorder-toggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('category-drag-handle-cat_a')), findsNothing);
    });

    testWidgets('dragging the handle writes the new order', (tester) async {
      await seedTwo();
      await pumpTestApp(tester, const AdminCategoriesScreen());

      await tester.tap(find.byKey(const Key('category-reorder-toggle')));
      await tester.pumpAndSettle();

      // Move "Apparel" below "Bakery".
      await tester.timedDrag(
        find.byKey(const Key('category-drag-handle-cat_a')),
        const Offset(0, 220),
        const Duration(milliseconds: 600),
      );
      await tester.pumpAndSettle();

      final cats = await repo.categories(companyId: 'c_organic').first;
      final a = cats.firstWhere((c) => c.id == 'cat_a');
      final b = cats.firstWhere((c) => c.id == 'cat_b');
      expect(b.sortOrder, lessThan(a.sortOrder), reason: 'Bakery is now first');
      expect(a.sortOrder, b.sortOrder + 1, reason: 'now neighbours');
      // The whole top level stays densely numbered 0..n-1 (the mock data
      // seeds other categories, so the absolute numbers are not fixed).
      final roots =
          cats.where((c) => c.parentId == null).map((c) => c.sortOrder).toList()
            ..sort();
      expect(roots, [for (var i = 0; i < roots.length; i++) i]);
    });

    testWidgets('the Reorder button on the list opens the drag view', (
      tester,
    ) async {
      await seedTwo();
      await pumpTestApp(tester, const AdminCategoriesScreen());

      expect(find.byKey(const Key('category-drag-handle-cat_a')), findsNothing);
      await tester.tap(find.byKey(const Key('category-arrange-button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('category-drag-handle-cat_a')),
        findsOneWidget,
      );
    });

    testWidgets('move up / move down buttons change and save the sequence', (
      tester,
    ) async {
      await seedTwo();
      await pumpTestApp(tester, const AdminCategoriesScreen());
      await tester.tap(find.byKey(const Key('category-reorder-toggle')));
      await tester.pumpAndSettle();

      Future<void> tap(String key) async {
        final f = find.byKey(Key(key));
        await tester.ensureVisible(f);
        await tester.pumpAndSettle();
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      // Apparel sits just above Bakery; move it down below Bakery...
      await tap('category-move-down-cat_a');
      var cats = await repo.categories(companyId: 'c_organic').first;
      var a = cats.firstWhere((c) => c.id == 'cat_a');
      var b = cats.firstWhere((c) => c.id == 'cat_b');
      expect(b.sortOrder, lessThan(a.sortOrder));

      // ...and back up again.
      await tap('category-move-up-cat_a');
      cats = await repo.categories(companyId: 'c_organic').first;
      a = cats.firstWhere((c) => c.id == 'cat_a');
      b = cats.firstWhere((c) => c.id == 'cat_b');
      expect(a.sortOrder, lessThan(b.sortOrder));
    });

    testWidgets('search text disables reordering with a hint', (tester) async {
      await seedTwo();
      await pumpTestApp(tester, const AdminCategoriesScreen());

      await tester.enterText(
        find.byKey(const Key('category-search-field')),
        'ba',
      );
      await tester.pumpAndSettle();

      expect(find.text('Clear search to reorder'), findsOneWidget);

      await tester.tap(find.byKey(const Key('category-reorder-toggle')));
      await tester.pumpAndSettle();

      // The reorder view stays off — the hint explains why.
      expect(find.text('Reordering: top level'), findsNothing);
      expect(find.byKey(const Key('category-drag-handle-cat_b')), findsNothing);
    });

    testWidgets('backfill numbers old categories by creation time', (
      tester,
    ) async {
      await seedTwo();
      // Simulate pre-ordering data: both siblings claim position 1.
      final cats = await repo.categories(companyId: 'c_organic').first;
      for (final c in cats) {
        await repo.saveCategory(c.copyWith(sortOrder: 1));
      }

      await pumpTestApp(tester, const AdminCategoriesScreen());
      await tester.tap(find.byKey(const Key('category-backfill-order')));
      await tester.pumpAndSettle();

      final fixed = await repo.categories(companyId: 'c_organic').first;
      final byId = {for (final c in fixed) c.id: c};
      expect(byId['cat_a']!.sortOrder, 0);
      expect(byId['cat_b']!.sortOrder, 1);
    });
  });

  group('F2 — product order inside a category', () {
    final products = [
      const Product(
        id: 'p_1',
        companyId: 'c_organic',
        categoryId: 'cat_a',
        name: 'Almonds',
      ),
      const Product(
        id: 'p_2',
        companyId: 'c_organic',
        categoryId: 'cat_a',
        name: 'Bread',
      ),
      const Product(
        id: 'p_3',
        companyId: 'c_organic',
        categoryId: 'cat_a',
        name: 'Carrots',
      ),
    ];

    Widget picker(
      List<String> selected,
      ValueChanged<List<String>> onChanged,
    ) => MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,

      home: Scaffold(
        body: SingleChildScrollView(
          child: ProductAssignmentPicker(
            allProducts: products,
            selectedProductIds: selected,
            onSelectedChanged: onChanged,
          ),
        ),
      ),
    );

    testWidgets('the assigned panel follows the selectedProductIds order', (
      tester,
    ) async {
      await tester.pumpWidget(picker(const ['p_2', 'p_1'], (_) {}));

      expect(find.byKey(const Key('assignment-counter')), findsOneWidget);
      expect(find.text('2 products selected'), findsOneWidget);
      expect(find.byKey(const Key('assign-card-p_1')), findsOneWidget);
      expect(find.byKey(const Key('assign-card-p_2')), findsOneWidget);
      expect(find.byKey(const Key('assign-card-p_3')), findsNothing);

      // Position badges mirror the order.
      expect(find.byKey(const Key('assign-position-p_2')), findsOneWidget);
    });

    testWidgets('dragging the handle reorders the assigned list', (
      tester,
    ) async {
      List<String> selected = ['p_1', 'p_2', 'p_3'];
      late StateSetter rebuild;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return picker(selected, (next) {
              // The parent screen owns the list and rebuilds on change.
              rebuild(() => selected = next);
            });
          },
        ),
      );

      // Move "Almonds" below "Bread".
      await tester.timedDrag(
        find.byKey(const Key('drag-handle-p_1')),
        const Offset(0, 220),
        const Duration(milliseconds: 600),
      );
      await tester.pumpAndSettle();

      expect(selected, [
        'p_2',
        'p_1',
        'p_3',
      ], reason: 'local order until saved');
    });

    testWidgets('search text disables the drag handles', (tester) async {
      await tester.pumpWidget(picker(const ['p_1', 'p_2'], (_) {}));

      await tester.enterText(find.byType(TextField), 'bread');
      await tester.pumpAndSettle();

      expect(find.text('Clear search to reorder'), findsOneWidget);
      expect(find.byKey(const Key('drag-handle-p_1')), findsNothing);
    });

    testWidgets('Add All and Clear All move everything', (tester) async {
      List<String> selected = ['p_1'];
      late StateSetter rebuild;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return picker(selected, (next) {
              rebuild(() => selected = next);
            });
          },
        ),
      );

      await tester.tap(find.text('Add All'));
      await tester.pumpAndSettle();
      expect(selected.length, 3, reason: 'p_2 + p_3 assigned');
      expect(find.text('3 products selected'), findsOneWidget);

      await tester.tap(find.text('Clear All'));
      await tester.pumpAndSettle();
      expect(selected, isEmpty);
    });

    testWidgets('ids without a product stay at the end of the order', (
      tester,
    ) async {
      await tester.pumpWidget(picker(const ['p_gone', 'p_2', 'p_1'], (_) {}));

      // The counter tracks assigned ids; unknown ids simply have no card.
      expect(find.text('3 products selected'), findsOneWidget);
      expect(find.byKey(const Key('assign-card-p_1')), findsOneWidget);
      expect(find.byKey(const Key('assign-card-p_2')), findsOneWidget);
    });

    testWidgets('a single product hides its drag handle', (tester) async {
      await tester.pumpWidget(picker(const ['p_1'], (_) {}));
      expect(find.text('1 product selected'), findsOneWidget);
      expect(find.byKey(const Key('drag-handle-p_1')), findsNothing);
    });
  });
}
