import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/models/category.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/features/admin/categories/admin_add_category_screen.dart';
import 'package:myshop/features/admin/products/admin_add_product_screen.dart';

import '../helpers/test_harness.dart';

/// The product and category add/edit forms use the full width of the screen
/// (they used to be centred in an 800 / 840 px column).
void main() {
  setUp(() {
    TestHarness.setupPlatformChannels();
    TestHarness.useMockRepository();
    TestHarness.signIn(TestHarness.admin);
  });

  tearDown(() => TestHarness.signOut());

  for (final width in [1200.0, 1600.0, 2200.0]) {
    testWidgets('product add/edit form fills a ${width.toInt()} px window', (
      tester,
    ) async {
      await pumpTestApp(
        tester,
        const AdminAddProductScreen(),
        size: Size(width, 900),
      );
      expect(tester.getSize(find.byType(Form)).width, width);

      // A text field inside it is far wider than the old 800 px column.
      final field = find.byType(TextFormField).first;
      expect(tester.getSize(field).width, greaterThan(width * 0.8));
    });

    testWidgets('category add/edit form fills a ${width.toInt()} px window', (
      tester,
    ) async {
      await pumpTestApp(
        tester,
        const AdminAddCategoryScreen(
          category: Category(id: 'c1', companyId: 'c_organic', name: 'Chairs'),
        ),
        size: Size(width, 900),
      );
      expect(tester.getSize(find.byType(Form)).width, width);
      expect(
        tester.getSize(find.byType(TextFormField).first).width,
        greaterThan(width * 0.8),
      );
    });
  }

  testWidgets('product edit form also fills the window', (tester) async {
    await pumpTestApp(
      tester,
      const AdminAddProductScreen(
        product: Product(
          id: 'p1',
          companyId: 'c_organic',
          name: 'Cane Chair',
          amount: 100,
        ),
      ),
      size: const Size(1600, 900),
    );
    expect(tester.getSize(find.byType(Form)).width, 1600);
  });
}
