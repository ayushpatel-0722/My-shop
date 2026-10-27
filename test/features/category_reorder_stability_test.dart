import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/category.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/core/services/service_locator.dart';
import 'package:myshop/features/admin/categories/admin_categories_screen.dart';

import '../helpers/test_harness.dart';

/// Saves slowly and then re-emits the list, like Firestore: the new order comes
/// back from the backend while the drop animation may still be running.
class _SlowRepo extends MockAppRepository {
  @override
  Future<void> reorderCategories(List<Category> orderedSiblings) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await super.reorderCategories(orderedSiblings);
  }
}

void main() {
  late _SlowRepo repo;

  setUp(() {
    TestHarness.setupPlatformChannels();
    repo = _SlowRepo();
    ServiceLocator.instance.repository = repo;
    TestHarness.signIn(TestHarness.admin);
  });

  tearDown(() => TestHarness.signOut());

  Future<void> seed() async {
    for (final n in ['Apparel', 'Bakery', 'Cafe']) {
      await repo.saveCategory(
        Category(id: 'cat_${n.toLowerCase()}', companyId: 'c_organic', name: n),
      );
    }
  }

  /// Advances time in small steps so an exception in any frame is caught.
  Future<void> settleWatching(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull, reason: 'frame $i');
    }
  }

  Future<void> openReorder(WidgetTester tester) async {
    await seed();
    await pumpTestApp(tester, const AdminCategoriesScreen());
    await tester.tap(find.byKey(const Key('category-reorder-toggle')));
    await tester.pumpAndSettle();
  }

  Future<List<int>> orders() async {
    final cats = await repo.categories(companyId: 'c_organic').first;
    return [
      for (final id in [
        'cat_apparel',
        'cat_bakery',
        'cafe',
      ].map((e) => e == 'cafe' ? 'cat_cafe' : e))
        cats.firstWhere((c) => c.id == id).sortOrder,
    ];
  }

  testWidgets('dragging with a slow, re-emitting backend does not throw', (
    tester,
  ) async {
    await openReorder(tester);
    final handle = find.byKey(const Key('category-drag-handle-cat_apparel'));
    await tester.ensureVisible(handle);
    await tester.timedDrag(
      handle,
      const Offset(0, 220),
      const Duration(milliseconds: 600),
    );
    await settleWatching(tester);

    final o = await orders();
    expect(o[0], greaterThan(o[1]), reason: 'Apparel now below Bakery');
  });

  testWidgets('rapid move buttons with a slow backend do not throw', (
    tester,
  ) async {
    await openReorder(tester);
    Future<void> tap(String key) async {
      final f = find.byKey(Key(key));
      await tester.ensureVisible(f);
      await tester.pump();
      await tester.tap(f);
      await tester.pump(const Duration(milliseconds: 30));
      expect(tester.takeException(), isNull, reason: key);
    }

    await tap('category-move-down-cat_apparel');
    await tap('category-move-down-cat_apparel');
    await tap('category-move-up-cat_cafe');
    await settleWatching(tester);
  });

  testWidgets('leaving and re-entering reorder mode mid-save does not throw', (
    tester,
  ) async {
    await openReorder(tester);
    final f = find.byKey(const Key('category-move-down-cat_apparel'));
    await tester.ensureVisible(f);
    await tester.tap(f);
    await tester.pump(const Duration(milliseconds: 30));
    await tester.tap(find.byKey(const Key('category-reorder-toggle')));
    await tester.pump(const Duration(milliseconds: 30));
    await tester.tap(find.byKey(const Key('category-reorder-toggle')));
    await settleWatching(tester);
  });

  testWidgets('covering the reorder list with a route, changing data, then '
      'popping back does not throw', (tester) async {
    await openReorder(tester);
    final context = tester.element(find.byType(AdminCategoriesScreen));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Center(child: Text('edit page'))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('edit page'), findsOneWidget);

    // A save on the edit page makes the backend re-emit the category list
    // while the reorder list is hidden underneath.
    await repo.saveCategory(
      const Category(
        id: 'cat_apparel',
        companyId: 'c_organic',
        name: 'Apparel 2',
      ),
    );
    await repo.saveCategory(
      const Category(id: 'cat_zed', companyId: 'c_organic', name: 'Zed'),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    Navigator.of(context).pop();
    await settleWatching(tester);
  });

  testWidgets('resizing across the desktop breakpoint while reordering does '
      'not throw', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    tester.view.physicalSize = const Size(1400, 900);
    await openReorder(tester);
    expect(find.byKey(const Key('category-drag-handle-cat_apparel')), findsOne);

    // Narrow (mobile drawer layout) ...
    tester.view.physicalSize = const Size(800, 900);
    await settleWatching(tester);
    // ... and wide again (desktop sidebar layout).
    tester.view.physicalSize = const Size(1400, 900);
    await settleWatching(tester);
    expect(find.byKey(const Key('category-drag-handle-cat_apparel')), findsOne);
  });

  testWidgets('clicking move buttons with a mouse hovering (tooltips open) '
      'does not throw', (tester) async {
    await openReorder(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);

    Future<void> click(String key) async {
      final f = find.byKey(Key(key));
      await tester.ensureVisible(f);
      await tester.pump();
      await mouse.moveTo(tester.getCenter(f));
      // Let the hover tooltip open.
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull, reason: 'hover $key');
      await mouse.down(tester.getCenter(f));
      await mouse.up();
      await tester.pump(const Duration(milliseconds: 30));
      expect(tester.takeException(), isNull, reason: 'click $key');
    }

    await click('category-move-down-cat_apparel');
    await click('category-move-down-cat_apparel');
    await click('category-move-up-cat_cafe');
    await settleWatching(tester);
  });

  testWidgets('reorder rows show the product photo as the category image', (
    tester,
  ) async {
    await repo.saveProduct(
      const Product(
        id: 'p_img',
        companyId: 'c_organic',
        name: 'Cane Chair',
        unit: 1,
        unitType: 'pieces',
        amount: 100,
        images: ['https://images.example.com/chair.jpg'],
      ),
    );
    await repo.saveCategory(
      const Category(
        id: 'cat_chairs',
        companyId: 'c_organic',
        name: 'Chairs',
        productList: ['p_img'],
      ),
    );
    await pumpTestApp(tester, const AdminCategoriesScreen());
    await tester.tap(find.byKey(const Key('category-reorder-toggle')));
    await tester.pumpAndSettle();

    final row = find.byKey(const Key('category-tile-cat_chairs'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    final photo = find.descendant(of: row, matching: find.byType(Image));
    expect(photo, findsOneWidget);
    expect(
      ((tester.widget<Image>(photo)).image as NetworkImage).url,
      'https://images.example.com/chair.jpg',
    );
  });
}
