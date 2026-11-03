import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/category.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/core/widgets/category_cover_builder.dart';
import 'package:myshop/features/marketplace/home/home_screen.dart';
import 'package:myshop/features/marketplace/widgets/product_card.dart';

import '../helpers/test_harness.dart';

/// The home page loads its long product lists a page at a time, so opening it
/// no longer builds (and downloads the pictures of) every product at once.
void main() {
  late MockAppRepository repo;

  setUp(() {
    TestHarness.setupPlatformChannels();
    repo = TestHarness.useMockRepository();
  });

  Future<void> seed(int n) async {
    for (var i = 0; i < n; i++) {
      await repo.saveProduct(
        Product(
          id: 'bulk_$i',
          companyId: 'c_organic',
          categoryId: 'cat_x',
          name: 'Bulk Item $i',
          amount: 100 + i.toDouble(),
          stockQty: 10,
          images: const ['https://example.com/p.jpg'],
        ),
      );
    }
  }

  /// The home page always has something animating (carousel, loading
  /// skeletons), so it never "settles": pump for set times instead.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      buildTestApp(
        const HomeScreen(),
        user: TestHarness.shopper,
        size: const Size(390, 900),
      ),
    );
    await settle(tester);
  }

  int built() =>
      find.byType(ProductCard).evaluate().length +
      find.byType(TrendingVerticalProductCard).evaluate().length;

  testWidgets('only the first page is built when the page opens', (
    tester,
  ) async {
    await seed(60);
    await openHome(tester);
    // Without paging this was every product twice over (60 + 60+).
    expect(built(), lessThanOrEqualTo(30));
    expect(built(), greaterThan(0));
  });

  testWidgets('scrolling to the bottom loads the next page', (tester) async {
    await seed(60);
    await openHome(tester);
    final first = built();

    final scrollable = find.byType(Scrollable).first;
    for (var i = 0; i < 6; i++) {
      await tester.drag(scrollable, const Offset(0, -1500));
      await settle(tester);
    }
    expect(built(), greaterThan(first), reason: 'more were loaded');
  });

  test('a category tile has several photos to fall back on', () {
    const cat = Category(
      id: 'c',
      companyId: 'x',
      name: 'Spices',
      productList: ['a', 'b', 'c', 'd', 'e', 'missing'],
    );
    final urls = CategoryCoverBuilder.coversFor(cat, {
      'a': 'u1',
      'b': 'u1', // the same photo twice counts once
      'c': 'u2',
      'd': 'u3',
      'e': 'u4',
    });
    expect(urls, ['u1', 'u2', 'u3', 'u4']);
    expect(CategoryCoverBuilder.coversFor(cat, {}), isEmpty);
    expect(
      CategoryCoverBuilder.coversFor(cat, {'e': 'u4', 'a': 'u1'}, max: 1),
      ['u1'],
      reason: 'in the category\'s own order',
    );
  });
}
