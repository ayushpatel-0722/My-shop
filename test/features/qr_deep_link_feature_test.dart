import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/app_user.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/core/services/auth_session.dart';
import 'package:myshop/core/services/deep_link_service.dart';
import 'package:myshop/core/services/qr_deep_link_service.dart';
import 'package:myshop/features/admin/qr/widgets/entity_qr_dialog.dart';
import 'package:myshop/features/marketplace/company_store/company_store_screen.dart';
import 'package:myshop/features/product/details/product_details_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../helpers/test_harness.dart';

void main() {
  late MockAppRepository mockRepo;

  setUp(() {
    TestHarness.setupPlatformChannels();
    mockRepo = TestHarness.useMockRepository();
    AuthSession.currentUser = const AppUser(
      id: 'admin_test',
      companyId: 'masala-mart',
      companyName: 'Masala Mart',
      name: 'Admin Test',
      email: 'admin@masalamart.in',
      role: 'admin',
    );
  });

  group('QrDeepLinkService URL Builders', () {
    test('public domain uses canonical myshop-8bd4d.web.app', () {
      expect(QrDeepLinkService.baseUrl, 'https://myshop-8bd4d.web.app');
    });

    test('generates standard public shop URL', () {
      final url = QrDeepLinkService.buildShopUrl('masala-mart');
      expect(url, 'https://myshop-8bd4d.web.app/shop/masala-mart');
    });

    test('generates standard public category URL with shop scope', () {
      final url = QrDeepLinkService.buildCategoryUrl(
        'masala-mart',
        'whole-spices',
      );
      expect(
        url,
        'https://myshop-8bd4d.web.app/shop/masala-mart/category/whole-spices',
      );
    });

    test('generates standard public product URL with shop scope', () {
      final url = QrDeepLinkService.buildProductUrl(
        'masala-mart',
        'mas_tur_001',
      );
      expect(
        url,
        'https://myshop-8bd4d.web.app/shop/masala-mart/product/mas_tur_001',
      );
    });

    test(
      'generates native app scheme URLs with custom scheme ecommerce://',
      () {
        expect(
          QrDeepLinkService.buildShopSchemeUrl('masala-mart'),
          'ecommerce://shop/masala-mart',
        );
        expect(
          QrDeepLinkService.buildCategorySchemeUrl('masala-mart', 'spices'),
          'ecommerce://shop/masala-mart/category/spices',
        );
        expect(
          QrDeepLinkService.buildProductSchemeUrl('masala-mart', 'prod_123'),
          'ecommerce://shop/masala-mart/product/prod_123',
        );
      },
    );
  });

  group('DeepLinkService Routing & Universal Link Parsing', () {
    final deepLinkService = DeepLinkService();

    test('parses web URL for shop', () {
      final uri = Uri.parse('https://myshop-8bd4d.web.app/shop/masala-mart');
      expect(deepLinkService.toRoute(uri), '/shop/masala-mart');
    });

    test('parses hash web URL for category (/ # / shop / ...)', () {
      final uri = Uri.parse(
        'https://myshop-8bd4d.web.app/#/shop/masala-mart/category/whole-spices',
      );
      expect(
        deepLinkService.toRoute(uri),
        '/shop/masala-mart/category/whole-spices',
      );
    });

    test('parses web URL for product', () {
      final uri = Uri.parse(
        'https://myshop-8bd4d.web.app/shop/masala-mart/product/mas_tur_001',
      );
      expect(
        deepLinkService.toRoute(uri),
        '/shop/masala-mart/product/mas_tur_001',
      );
    });

    test(
      'parses native ecommerce:// scheme URLs for shop, category, product',
      () {
        expect(
          deepLinkService.toRoute(Uri.parse('ecommerce://shop/masala-mart')),
          '/shop/masala-mart',
        );
        expect(
          deepLinkService.toRoute(
            Uri.parse('ecommerce://shop/masala-mart/category/organic'),
          ),
          '/shop/masala-mart/category/organic',
        );
        expect(
          deepLinkService.toRoute(
            Uri.parse('ecommerce://shop/masala-mart/product/mas_tur_001'),
          ),
          '/shop/masala-mart/product/mas_tur_001',
        );
      },
    );

    test('falls back safely on unknown URL schemes', () {
      expect(
        deepLinkService.toRoute(Uri.parse('https://example.com/unrelated')),
        null,
      );
    });
  });

  group('EntityQrShareDialog Widget', () {
    testWidgets('renders QR code, entity title, link, and toggles scheme', (
      tester,
    ) async {
      await pumpTestApp(
        tester,
        const Scaffold(
          body: EntityQrShareDialog(
            type: QrEntityType.product,
            title: 'Turmeric Powder 200g',
            shopId: 'masala-mart',
            productId: 'mas_tur_001',
          ),
        ),
        user: AuthSession.currentUser,
      );
      await tester.pumpAndSettle();

      // Verify header and title
      expect(find.text('PRODUCT LINK'), findsOneWidget);
      expect(find.text('Turmeric Powder 200g'), findsOneWidget);

      // Verify QR Image is rendered
      expect(find.byType(QrImageView), findsOneWidget);

      // Verify canonical HTTPS URL text initially
      expect(
        find.text(
          'https://myshop-8bd4d.web.app/shop/masala-mart/product/mas_tur_001',
        ),
        findsOneWidget,
      );

      // Verify Action buttons
      expect(find.byTooltip('Copy URL'), findsOneWidget);
      expect(find.text('Test Link'), findsOneWidget);
      expect(find.text('Download PNG'), findsOneWidget);

      // Switch to custom scheme ecommerce://
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Verify scheme updated in display
      expect(
        find.text('ecommerce://shop/masala-mart/product/mas_tur_001'),
        findsOneWidget,
      );
    });
  });

  group('Mismatched Shop & Unavailable Guards', () {
    testWidgets(
      'CompanyStoreScreen shows Store Unavailable when shop slug does not exist',
      (tester) async {
        await pumpTestApp(
          tester,
          const CompanyStoreScreen(slug: 'non_existent_shop_id_99999'),
          user: AuthSession.currentUser,
        );
        await tester.pumpAndSettle();

        // Check friendly error display
        expect(find.text('Store Unavailable'), findsOneWidget);
        expect(
          find.text(
            'The requested store could not be found or is temporarily unavailable.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'ProductDetailsScreen shows catalog mismatch guard when shopId does not match product owner',
      (tester) async {
        // Seed a product belonging to 'shop_a'
        const testProd = Product(
          id: 'prod_exclusive_a',
          companyId: 'shop_a',
          name: 'Shop A Exclusive Item',
          details: 'Details',
          categoryId: 'spices',
          amount: 99.0,
          images: ['https://example.com/item.jpg'],
        );
        await mockRepo.saveProduct(testProd);

        await pumpTestApp(
          tester,
          const ProductDetailsScreen(
            productId: 'prod_exclusive_a',
            shopId: 'masala-mart',
          ),
          user: AuthSession.currentUser,
        );
        await tester.pumpAndSettle();

        // Guard should intercept and show mismatch feedback
        expect(
          find.text('Product Not Available at this Store'),
          findsOneWidget,
        );
        expect(
          find.text('This product belongs to another merchant catalog.'),
          findsOneWidget,
        );
      },
    );
  });
}
