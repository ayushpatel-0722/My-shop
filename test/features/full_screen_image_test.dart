import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/models/category.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/core/widgets/full_screen_image_viewer.dart';
import 'package:myshop/features/admin/categories/admin_add_category_screen.dart';
import 'package:myshop/features/admin/products/admin_add_product_screen.dart';

import '../helpers/test_harness.dart';

const _urls = [
  'https://images.example.com/a.jpg',
  'https://images.example.com/b.jpg',
  'https://images.example.com/c.jpg',
];

void main() {
  setUp(() {
    TestHarness.setupPlatformChannels();
    TestHarness.useMockRepository();
    TestHarness.signIn(TestHarness.admin);
  });

  tearDown(() => TestHarness.signOut());

  final viewer = find.byKey(const Key('fullscreen-image-viewer'));
  final close = find.byKey(const Key('fullscreen-image-close'));
  final counter = find.byKey(const Key('fullscreen-image-counter'));

  testWidgets('the viewer opens, pages through images and closes', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showFullScreenImages(context, urls: _urls, initialIndex: 1),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(viewer, findsOneWidget);
    expect(tester.widget<Text>(counter).data, '2 / 3');

    await tester.tap(find.byKey(const Key('fullscreen-image-next')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(counter).data, '3 / 3');
    expect(find.byKey(const Key('fullscreen-image-next')), findsNothing);

    await tester.tap(find.byKey(const Key('fullscreen-image-previous')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(counter).data, '2 / 3');

    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(viewer, findsNothing);
  });

  testWidgets('tapping a product gallery photo opens it full screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const product = Product(
      id: 'p_gallery',
      companyId: 'c_organic',
      name: 'Cane Chair',
      amount: 100,
      images: _urls,
    );
    await pumpTestApp(tester, const AdminAddProductScreen(product: product));

    final thumb = find.byKey(const Key('product-image-thumb-1'));
    await tester.ensureVisible(thumb);
    await tester.pumpAndSettle();
    await tester.tap(thumb);
    await tester.pumpAndSettle();

    expect(viewer, findsOneWidget);
    expect(
      tester.widget<Text>(counter).data,
      '2 / 3',
      reason: 'opens at idx 1',
    );
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(viewer, findsNothing);

    // The remove button on a thumbnail still removes and does not open it.
    final before = find.byKey(const Key('product-image-thumb-2'));
    expect(before, findsOneWidget);
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
    expect(viewer, findsNothing);
    expect(find.byKey(const Key('product-image-thumb-2')), findsNothing);
  });

  testWidgets('tapping the category image preview opens it full screen', (
    tester,
  ) async {
    const cat = Category(
      id: 'cat_img',
      companyId: 'c_organic',
      name: 'Chairs',
      iconUrl: 'https://images.example.com/chairs.jpg',
    );
    await pumpTestApp(tester, const AdminAddCategoryScreen(category: cat));

    final preview = find.byKey(const Key('category-image-preview'));
    await tester.ensureVisible(preview);
    await tester.pumpAndSettle();
    await tester.tap(preview);
    await tester.pumpAndSettle();

    expect(viewer, findsOneWidget);
    expect(counter, findsNothing, reason: 'a single image has no counter');
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(viewer, findsNothing);
  });

  testWidgets('an emoji category icon is not tappable', (tester) async {
    const cat = Category(
      id: 'cat_emoji',
      companyId: 'c_organic',
      name: 'Snacks',
      iconUrl: '\u{1F36A}',
    );
    await pumpTestApp(tester, const AdminAddCategoryScreen(category: cat));
    expect(find.byKey(const Key('category-image-preview')), findsNothing);
  });
}
