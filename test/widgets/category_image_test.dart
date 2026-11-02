import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/category.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/core/widgets/category_image.dart';

import '../helpers/test_harness.dart';

void main() {
  late MockAppRepository repo;

  setUp(() {
    TestHarness.setupPlatformChannels();
    repo = TestHarness.useMockRepository();
  });

  /// Pumps without settling: in tests every network image ends in an error
  /// (and so in the fallback) once the frame loop runs, so the requested URL
  /// has to be read from the first frames.
  Future<void> pumpCategory(WidgetTester tester, Category cat) async {
    await tester.pumpWidget(
      buildTestApp(
        Scaffold(
          body: SizedBox(
            width: 80,
            height: 80,
            child: CategoryImage(
              category: cat,
              fallback: (_) => const Text('fallback'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> seedProduct() => repo.saveProduct(
    const Product(
      id: 'p1',
      companyId: 'c_organic',
      name: 'Sofa',
      unit: 1,
      unitType: 'pieces',
      amount: 100,
      images: ['https://img.example.com/sofa.jpg'],
    ),
  );

  String shownUrl(WidgetTester tester) =>
      ((tester.widget<Image>(find.byType(Image).first)).image as NetworkImage)
          .url;

  testWidgets(
    'a category without its own image shows its first product photo',
    (tester) async {
      await seedProduct();
      await pumpCategory(
        tester,
        const Category(
          id: 'c1',
          companyId: 'c_organic',
          name: 'Sofas',
          iconUrl: '🛋️',
          productList: ['missing', 'p1'],
        ),
      );
      expect(shownUrl(tester), 'https://img.example.com/sofa.jpg');
    },
  );

  testWidgets('its own image URL wins over the product photo', (tester) async {
    await seedProduct();
    await pumpCategory(
      tester,
      const Category(
        id: 'c1',
        companyId: 'c_organic',
        name: 'Sofas',
        iconUrl: 'https://img.example.com/own.jpg',
        productList: ['p1'],
      ),
    );
    expect(shownUrl(tester), 'https://img.example.com/own.jpg');
  });

  testWidgets('an empty category falls back to the glyph', (tester) async {
    await pumpCategory(
      tester,
      const Category(id: 'c1', companyId: 'c_organic', name: 'Empty'),
    );
    expect(find.text('fallback'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
