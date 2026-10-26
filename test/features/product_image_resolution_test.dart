import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/app/l10n/app_localizations.dart';
import 'package:myshop/core/models/home_trending_item.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/core/widgets/app_product_image.dart';
import 'package:myshop/features/marketplace/widgets/product_card.dart';

void main() {
  group('Product Image Resolution Tests', () {
    test('Product.fromMap resolves images when images is a List<String>', () {
      final p = Product.fromMap('p1', {
        'name': 'Apple',
        'images': ['https://example.com/apple.png'],
      });
      expect(p.images, ['https://example.com/apple.png']);
      expect(p.imageUrl, 'https://example.com/apple.png');
    });

    test('Product.fromMap resolves images when images is a single String', () {
      final p = Product.fromMap('p1', {
        'name': 'Apple',
        'images': 'https://example.com/single_apple.png',
      });
      expect(p.images, ['https://example.com/single_apple.png']);
      expect(p.imageUrl, 'https://example.com/single_apple.png');
    });

    test('Product.fromMap resolves images when key is imageUrl', () {
      final p = Product.fromMap('p1', {
        'name': 'Orange',
        'imageUrl': 'https://example.com/orange.png',
      });
      expect(p.images, ['https://example.com/orange.png']);
      expect(p.imageUrl, 'https://example.com/orange.png');
    });

    test('Product.fromMap resolves images when key is image or photoUrl', () {
      final p = Product.fromMap('p1', {
        'name': 'Banana',
        'image': 'https://example.com/banana.png',
        'photoUrl': 'https://example.com/banana_photo.png',
      });
      expect(p.images, contains('https://example.com/banana.png'));
      expect(p.images, contains('https://example.com/banana_photo.png'));
    });

    test('Product.fromMap resolves images from JSON-encoded array string', () {
      final p = Product.fromMap('p1', {
        'name': 'Mango',
        'images':
            '["https://example.com/mango1.png", "https://example.com/mango2.png"]',
      });
      expect(p.images, [
        'https://example.com/mango1.png',
        'https://example.com/mango2.png',
      ]);
    });

    test(
      'Product.toMap includes only canonical images field and excludes legacy fields',
      () {
        const p = Product(
          id: 'p1',
          companyId: 'c1',
          name: 'Grape',
          images: ['https://example.com/grape.png'],
        );
        final map = p.toMap();
        expect(map['images'], ['https://example.com/grape.png']);
        expect(map.containsKey('imageUrl'), isFalse);
        expect(map.containsKey('imageUrls'), isFalse);
        expect(map.containsKey('thumbnailUrl'), isFalse);
      },
    );

    test('Creating a product with empty images results in empty list []', () {
      const p = Product(
        id: 'p_empty',
        companyId: 'c1',
        name: 'No Image Product',
        images: [],
      );
      final map = p.toMap();
      expect(map['images'], isEmpty);
      expect(map['images'], isA<List>());
      expect(map.containsKey('imageUrl'), isFalse);
      expect(map.containsKey('imageUrls'), isFalse);
    });

    test(
      'Creating a product with multiple images preserves list and order',
      () {
        const p = Product(
          id: 'p_multi',
          companyId: 'c1',
          name: 'Multi Image Product',
          images: [
            'https://example.com/img1.jpg',
            'https://example.com/img2.jpg',
            'https://example.com/img3.jpg',
          ],
        );
        final map = p.toMap();
        expect(map['images'], [
          'https://example.com/img1.jpg',
          'https://example.com/img2.jpg',
          'https://example.com/img3.jpg',
        ]);
        expect(p.imageUrl, 'https://example.com/img1.jpg');
      },
    );

    test(
      'Editing an existing product: removing one image preserves remaining images',
      () {
        const original = Product(
          id: 'p_edit',
          companyId: 'c1',
          name: 'Editable Product',
          images: [
            'https://example.com/img1.jpg',
            'https://example.com/img2.jpg',
            'https://example.com/img3.jpg',
          ],
        );
        // Remove index 1
        final updatedImages = List<String>.from(original.images)..removeAt(1);
        final updated = original.copyWith(images: updatedImages);
        expect(updated.images, [
          'https://example.com/img1.jpg',
          'https://example.com/img3.jpg',
        ]);
        final map = updated.toMap();
        expect(map['images'], [
          'https://example.com/img1.jpg',
          'https://example.com/img3.jpg',
        ]);
        expect(map.containsKey('imageUrl'), isFalse);
        expect(map.containsKey('imageUrls'), isFalse);
      },
    );

    test(
      'Migrating a product that only has imageUrl into canonical images list',
      () {
        final p = Product.fromMap('p_legacy1', {
          'companyId': 'c1',
          'name': 'Old Legacy 1',
          'imageUrl': 'https://example.com/legacy_single.jpg',
        });
        expect(p.images, ['https://example.com/legacy_single.jpg']);
        final map = p.toMap();
        expect(map['images'], ['https://example.com/legacy_single.jpg']);
        expect(map.containsKey('imageUrl'), isFalse);
      },
    );

    test(
      'Migrating a product that only has imageUrls list into canonical images list',
      () {
        final p = Product.fromMap('p_legacy2', {
          'companyId': 'c1',
          'name': 'Old Legacy 2',
          'imageUrls': [
            'https://example.com/legacy_a.jpg',
            'https://example.com/legacy_b.jpg',
          ],
        });
        expect(p.images, [
          'https://example.com/legacy_a.jpg',
          'https://example.com/legacy_b.jpg',
        ]);
        final map = p.toMap();
        expect(map['images'], [
          'https://example.com/legacy_a.jpg',
          'https://example.com/legacy_b.jpg',
        ]);
        expect(map.containsKey('imageUrls'), isFalse);
      },
    );

    test('Handling missing or null legacy image fields gracefully', () {
      final p = Product.fromMap('p_null', {
        'companyId': 'c1',
        'name': 'Null Images Product',
        'images': null,
        'imageUrl': null,
        'imageUrls': null,
      });
      expect(p.images, isEmpty);
      expect(p.imageUrl, '');
      final map = p.toMap();
      expect(map['images'], isEmpty);
      expect(map.containsKey('imageUrl'), isFalse);
    });
  });

  group('HomeTrendingItem Image and Price Persistence Tests', () {
    test('HomeTrendingItem serializes and deserializes imageUrl and price', () {
      final item = HomeTrendingItem(
        id: 'c1_p1',
        shopId: 'c1',
        itemType: 'product',
        productId: 'p1',
        productName: 'Organic Honey',
        imageUrl: 'https://example.com/honey.png',
        price: 299.0,
      );

      final map = item.toMap();
      expect(map['imageUrl'], 'https://example.com/honey.png');
      expect(map['price'], 299.0);

      final restored = HomeTrendingItem.fromMap(map, id: 'c1_p1');
      expect(restored.imageUrl, 'https://example.com/honey.png');
      expect(restored.price, 299.0);
      expect(restored.productName, 'Organic Honey');
    });

    test('HomeTrendingItem.fromMap accepts image and amount fallbacks', () {
      final restored = HomeTrendingItem.fromMap({
        'shopId': 'c1',
        'itemType': 'product',
        'productId': 'p1',
        'image': 'https://example.com/legacy_honey.png',
        'amount': 250,
      }, id: 'c1_p1');

      expect(restored.imageUrl, 'https://example.com/legacy_honey.png');
      expect(restored.price, 250.0);
    });
  });

  group('AppProductImage Widget Tests', () {
    testWidgets('Renders fallback when url is null or empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppProductImage(url: '', fallback: Text('Fallback Active')),
          ),
        ),
      );

      expect(find.text('Fallback Active'), findsOneWidget);
    });

    testWidgets('Renders Image.asset when url starts with assets/', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppProductImage(url: 'assets/images/sample.png'),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
      final imageWidget = tester.widget<Image>(find.byType(Image));
      expect(imageWidget.image, isA<AssetImage>());
    });

    testWidgets('Renders Image.network when url starts with https://', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppProductImage(
              url: 'https://images.unsplash.com/sample.jpg',
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
      final imageWidget = tester.widget<Image>(find.byType(Image));
      expect(imageWidget.image, isA<NetworkImage>());
    });
  });

  group('ProductCard Image Integration Tests', () {
    testWidgets('ProductCard displays AppProductImage with product.imageUrl', (
      tester,
    ) async {
      const prod = Product(
        id: 'p_test',
        companyId: 'c1',
        name: 'Fresh Tomatoes',
        amount: 45,
        images: ['https://images.unsplash.com/tomatoes.jpg'],
      );

      await tester.pumpWidget(
        MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 280,
                child: ProductCard(product: prod),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AppProductImage), findsOneWidget);
      final appImage = tester.widget<AppProductImage>(
        find.byType(AppProductImage),
      );
      expect(appImage.url, 'https://images.unsplash.com/tomatoes.jpg');
    });
  });
}
