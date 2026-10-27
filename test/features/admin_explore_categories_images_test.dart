import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/models/category.dart';
import 'package:myshop/core/models/home_explore_category.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/features/admin/home_config/admin_explore_categories_screen.dart';

import '../helpers/test_harness.dart';

/// Home Explore Categories (admin) shows a real picture for each category:
/// its own image, else the photo of its first product, else the emoji.
void main() {
  late dynamic repo;

  setUp(() {
    TestHarness.setupPlatformChannels();
    repo = TestHarness.useMockRepository();
    TestHarness.signIn(TestHarness.admin);
  });

  tearDown(() => TestHarness.signOut());

  Future<void> seedAndOpen(WidgetTester tester) async {
    await repo.saveProduct(
      const Product(
        id: 'p_chair',
        companyId: 'c_organic',
        name: 'Cane Chair',
        amount: 100,
        images: ['https://images.example.com/chair.jpg'],
      ),
    );
    await repo.saveCategory(
      const Category(
        id: 'cat_emoji',
        companyId: 'c_organic',
        name: 'Chairs',
        iconUrl: '\u{1FA91}', // emoji only
        productList: ['p_chair'],
      ),
    );
    await repo.saveCategory(
      const Category(
        id: 'cat_own',
        companyId: 'c_organic',
        name: 'Tables',
        iconUrl: 'https://images.example.com/own-icon.jpg',
        productList: ['p_chair'],
      ),
    );
    await repo.saveCategory(
      const Category(
        id: 'cat_bare',
        companyId: 'c_organic',
        name: 'Empty',
        iconUrl: '\u{1F4C1}',
      ),
    );
    for (final (i, id) in ['cat_emoji', 'cat_own', 'cat_bare'].indexed) {
      await repo.saveHomeExploreCategory(
        HomeExploreCategory(
          id: 'c_organic_$id',
          shopId: 'c_organic',
          categoryId: id,
          categoryName: id,
          displayOrder: i,
        ),
      );
    }
    await pumpTestApp(tester, const AdminExploreCategoriesScreen());
  }

  List<String> imageUrlsIn(WidgetTester tester, Finder scope) => [
    for (final w in tester.widgetList<Image>(
      find.descendant(of: scope, matching: find.byType(Image)),
    ))
      if (w.image is NetworkImage) (w.image as NetworkImage).url,
  ];

  testWidgets('configured categories show their image or product photo', (
    tester,
  ) async {
    await seedAndOpen(tester);

    final urls = imageUrlsIn(tester, find.byType(ReorderableListView));
    // cat_emoji -> product photo; cat_own -> its own icon; cat_bare -> none.
    expect(urls, contains('https://images.example.com/chair.jpg'));
    expect(urls, contains('https://images.example.com/own-icon.jpg'));
    expect(urls, hasLength(2), reason: 'the empty category keeps its emoji');
    expect(find.text('\u{1F4C1}'), findsOneWidget);
  });

  testWidgets('the add-category picker shows the same pictures', (
    tester,
  ) async {
    await seedAndOpen(tester);
    await tester.tap(find.text('Add Category').first);
    await tester.pumpAndSettle();

    final sheetList = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(ListView),
    );
    final urls = imageUrlsIn(tester, sheetList);
    expect(urls, contains('https://images.example.com/chair.jpg'));
    expect(urls, contains('https://images.example.com/own-icon.jpg'));
    expect(urls, hasLength(2));
  });
}
