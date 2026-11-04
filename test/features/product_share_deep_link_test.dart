import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/core/services/deep_link_handler.dart';
import 'package:myshop/core/services/deep_link_service.dart';
import 'package:myshop/core/services/qr_deep_link_service.dart';
import 'package:myshop/core/utils/product_share.dart';
import 'package:myshop/features/product/details/product_details_screen.dart';
import 'package:share_plus/share_plus.dart';

import '../helpers/test_harness.dart';

class _FakeLinks extends DeepLinkService {
  _FakeLinks({this.initial});
  final Uri? initial;
  final controller = StreamController<Uri>.broadcast();
  @override
  Future<Uri?> getInitialLink() async => initial;
  @override
  Stream<Uri> get stream => controller.stream;
}

const _product = Product(
  id: 'mas_tur_001',
  companyId: 'masala-mart',
  categoryId: 'spices',
  name: 'Turmeric',
  amount: 50,
  stockQty: 10,
  images: ['https://example.com/t.jpg'],
);

void main() {
  late MockAppRepository repo;
  final links = DeepLinkService();

  setUp(() {
    TestHarness.setupPlatformChannels();
    repo = TestHarness.useMockRepository();
  });

  group('Share link = Admin QR / Product Link', () {
    test('shopper link is exactly the admin product URL', () {
      expect(
        ProductShare.linkFor(_product),
        QrDeepLinkService.buildProductUrl('masala-mart', 'mas_tur_001'),
      );
      expect(
        ProductShare.linkFor(_product),
        '${QrDeepLinkService.baseUrl}/shop/masala-mart/product/mas_tur_001',
      );
    });

    test('ids are encoded the same way as the admin builder', () {
      const odd = Product(
        id: 'a b/1',
        companyId: 'shop x',
        categoryId: 'c',
        name: 'n',
        amount: 1,
      );
      expect(
        ProductShare.linkFor(odd),
        QrDeepLinkService.buildProductUrl('shop x', 'a b/1'),
      );
    });

    test('admin QR (https and ecommerce://) opens the same shopper route', () {
      final admin = QrDeepLinkService.buildProductUrl(
        'masala-mart',
        'mas_tur_001',
      );
      final scheme = QrDeepLinkService.buildProductSchemeUrl(
        'masala-mart',
        'mas_tur_001',
      );
      const route = '/shop/masala-mart/product/mas_tur_001';
      expect(links.toRoute(Uri.parse(admin)), route);
      expect(links.toRoute(Uri.parse(scheme)), route);
    });

    test('message holds the product, shop and link', () {
      final text = ProductShare.messageFor(_product, shopName: 'Masala Mart');
      expect(text, contains('Turmeric'));
      expect(text, contains('Masala Mart'));
      expect(text, contains(ProductShare.linkFor(_product)));
    });
  });

  group('Link parsing', () {
    test('web path link with hash form', () {
      expect(
        links.toRoute(
          Uri.parse(
            'https://myshop-8bd4d.web.app/#/shop/masala-mart/product/p1',
          ),
        ),
        '/shop/masala-mart/product/p1',
      );
    });

    test('product / category link with the id missing opens the shop', () {
      expect(
        links.toRoute(Uri.parse('https://myshop-8bd4d.web.app/shop/m/product')),
        '/shop/m',
      );
      expect(
        links.toRoute(
          Uri.parse('https://myshop-8bd4d.web.app/shop/m/product/'),
        ),
        '/shop/m',
      );
      expect(
        links.toRoute(Uri.parse('ecommerce://shop/m/category')),
        '/shop/m',
      );
    });

    test('foreign and malformed links are ignored', () {
      expect(links.toRoute(Uri.parse('https://example.com/shop/x')), isNotNull);
      expect(links.toRoute(Uri.parse('mailto:a@b.c')), isNull);
      expect(links.toRoute(Uri.parse('https://example.com/other')), isNull);
    });
  });

  group('DeepLinkHandler', () {
    DeepLinkHandler make(
      _FakeLinks svc,
      List<String> opened, {
      String Function()? here,
      Future<void> Function()? ready,
      DateTime Function()? now,
    }) => DeepLinkHandler(
      service: svc,
      navigate: opened.add,
      currentLocation: here ?? () => '/home',
      ready: ready ?? () async {},
      now: now,
      browserUri: null,
    );

    final link = Uri.parse(
      'https://myshop-8bd4d.web.app/shop/masala-mart/product/p1',
    );

    test('launch link (app closed) opens the product', () async {
      final opened = <String>[];
      final h = make(_FakeLinks(initial: link), opened)..start();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(opened, ['/shop/masala-mart/product/p1']);
      h.dispose();
    });

    test('link while the app is running opens the product', () async {
      final opened = <String>[];
      final svc = _FakeLinks();
      final h = make(svc, opened)..start();
      svc.controller.add(link);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(opened, ['/shop/masala-mart/product/p1']);
      h.dispose();
    });

    test(
      'the same link twice opens once; a later repeat opens again',
      () async {
        final opened = <String>[];
        var t = DateTime(2026, 1, 1);
        final h = make(_FakeLinks(), opened, now: () => t);
        await h.handle(link);
        await h.handle(link);
        expect(opened, hasLength(1));
        t = t.add(const Duration(seconds: 10));
        await h.handle(link);
        expect(opened, hasLength(2));
      },
    );

    test('already on that product: no second push', () async {
      final opened = <String>[];
      final h = make(
        _FakeLinks(),
        opened,
        here: () => '/shop/masala-mart/product/p1',
      );
      await h.handle(link);
      expect(opened, isEmpty);
    });

    test('different product opens even right after another', () async {
      final opened = <String>[];
      final h = make(_FakeLinks(), opened);
      await h.handle(link);
      await h.handle(Uri.parse(link.toString().replaceFirst('p1', 'p2')));
      expect(opened, hasLength(2));
    });

    test('waits for start-up before navigating', () async {
      final opened = <String>[];
      final gate = Completer<void>();
      final h = make(_FakeLinks(), opened, ready: () => gate.future);
      unawaited(h.handle(link));
      await Future<void>.delayed(Duration.zero);
      expect(opened, isEmpty);
      gate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(opened, hasLength(1));
    });

    test('links for other apps are ignored', () async {
      final opened = <String>[];
      final h = make(_FakeLinks(), opened);
      await h.handle(Uri.parse('https://example.com/other'));
      await h.handle(Uri.parse('mailto:a@b.c'));
      expect(opened, isEmpty);
    });
  });

  group('Share icon on Product Details', () {
    testWidgets('tapping opens the share sheet with the product link', (
      tester,
    ) async {
      await repo.saveProduct(_product);
      ShareParams? shared;
      ProductShare.sharer = (p) async => shared = p;
      addTearDown(() => ProductShare.sharer = (p) async {});

      await pumpTestApp(
        tester,
        const ProductDetailsScreen(
          productId: 'mas_tur_001',
          shopId: 'masala-mart',
        ),
        size: const Size(420, 900),
      );
      await tester.tap(find.byKey(const Key('product-share-button')));
      await tester.pump();
      expect(shared, isNotNull);
      expect(shared!.text, contains(ProductShare.linkFor(_product)));
    });

    testWidgets('no share sheet available: copies the link', (tester) async {
      await repo.saveProduct(_product);
      ProductShare.sharer = (p) async => throw UnsupportedError('no share');
      addTearDown(() => ProductShare.sharer = (p) async {});
      String? clip;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              clip = (call.arguments as Map)['text'] as String?;
            }
            return null;
          });

      await pumpTestApp(
        tester,
        const ProductDetailsScreen(productId: 'mas_tur_001'),
        size: const Size(420, 900),
      );
      await tester.tap(find.byKey(const Key('product-share-button')));
      await tester.pump();
      expect(clip, ProductShare.linkFor(_product));
    });

    testWidgets('deleted / invalid product shows Product not found', (
      tester,
    ) async {
      await pumpTestApp(
        tester,
        const ProductDetailsScreen(
          productId: 'gone_999',
          shopId: 'masala-mart',
        ),
        size: const Size(420, 900),
      );
      expect(find.text('Product not found'), findsOneWidget);
    });

    testWidgets('out-of-stock product still opens, marked out of stock', (
      tester,
    ) async {
      await repo.saveProduct(_product.copyWith(stockQty: 0));
      await pumpTestApp(
        tester,
        const ProductDetailsScreen(
          productId: 'mas_tur_001',
          shopId: 'masala-mart',
        ),
        size: const Size(420, 900),
      );
      expect(find.text('Out of Stock'), findsWidgets);
      expect(find.byKey(const Key('product-share-button')), findsOneWidget);
    });

    testWidgets('link with another shop id shows the mismatch guard', (
      tester,
    ) async {
      await repo.saveProduct(_product);
      await pumpTestApp(
        tester,
        const ProductDetailsScreen(
          productId: 'mas_tur_001',
          shopId: 'some-other-shop',
        ),
        size: const Size(420, 900),
      );
      expect(find.text('Product Not Available at this Store'), findsOneWidget);
    });
  });
}
