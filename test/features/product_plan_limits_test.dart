import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myshop/app/l10n/app_localizations.dart';
import 'package:myshop/app/routes/app_router.dart';
import 'package:myshop/app/theme/app_theme.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/domain/product_limits.dart';
import 'package:myshop/core/models/app_user.dart';
import 'package:myshop/core/models/company.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/features/admin/products/admin_add_product_screen.dart';
import 'package:myshop/features/admin/subscription/admin_subscription_screen.dart';
import 'package:myshop/features/product/details/product_details_screen.dart';

import '../helpers/test_harness.dart';

const _shop = 'c_plan';
const _admin = AppUser(
  id: 'a_plan',
  companyId: _shop,
  companyName: 'Plan Shop',
  name: 'Plan Admin',
  email: 'plan@shop.in',
  role: 'admin',
);

Product _p(String id, {bool published = true, String shop = _shop}) => Product(
  id: id,
  companyId: shop,
  categoryId: 'cat_x',
  name: 'Item $id',
  details: 'd',
  amount: 100,
  stockQty: 5,
  isPublished: published,
);

void main() {
  group('ProductLimits (pure rules)', () {
    test('total cap is max_products + 20%, computed from the plan', () {
      expect(const ProductLimits(50).totalCap, 60);
      expect(const ProductLimits(100).totalCap, 120);
      expect(const ProductLimits(5).totalCap, 6);
      expect(const ProductLimits(33).totalCap, 39); // rounded down
      expect(const ProductLimits(null).totalCap, isNull);
      expect(const ProductLimits(null).hasLimit, isFalse);
    });

    ProductLimitDecision d(
      int max, {
      required bool isNew,
      bool wasPublished = false,
      bool wantsPublished = true,
      required int total,
      required int published,
    }) => ProductLimits(max).decide(
      isNew: isNew,
      wasPublished: wasPublished,
      wantsPublished: wantsPublished,
      otherTotal: total,
      otherPublished: published,
    );

    test('publish within the plan limit: allowed', () {
      expect(
        d(50, isNew: true, total: 49, published: 49),
        ProductLimitDecision.allowed,
      );
    });
    test('publish beyond the plan limit: warn, keep unpublished', () {
      expect(
        d(50, isNew: true, total: 50, published: 50),
        ProductLimitDecision.publishBlocked,
      );
    });
    test('create unpublished inside the extra 20%: allowed', () {
      expect(
        d(50, isNew: true, wantsPublished: false, total: 59, published: 50),
        ProductLimitDecision.allowed,
      );
    });
    test('create beyond the total limit: blocked (even unpublished)', () {
      expect(
        d(50, isNew: true, wantsPublished: false, total: 60, published: 50),
        ProductLimitDecision.createBlocked,
      );
      expect(
        d(50, isNew: true, total: 60, published: 50),
        ProductLimitDecision.createBlocked,
      );
    });
    test('publish an existing unpublished product when full: warn', () {
      expect(
        d(50, isNew: false, total: 59, published: 50),
        ProductLimitDecision.publishBlocked,
      );
    });
    test(
      'editing never blocks on the total cap; published stays published',
      () {
        expect(
          d(
            50,
            isNew: false,
            wasPublished: true,
            wantsPublished: true,
            total: 70,
            published: 55,
          ),
          ProductLimitDecision.allowed,
        );
        expect(
          d(50, isNew: false, wantsPublished: false, total: 70, published: 55),
          ProductLimitDecision.allowed,
        );
      },
    );
    test('no plan limit: always allowed', () {
      expect(
        const ProductLimits(null).decide(
          isNew: true,
          wasPublished: false,
          wantsPublished: true,
          otherTotal: 9999,
          otherPublished: 9999,
        ),
        ProductLimitDecision.allowed,
      );
    });
  });

  group('Company reads max_products', () {
    test('number, text and missing', () {
      expect(
        Company.fromMap('c', {'name': 'x', 'max_products': 50}).maxProducts,
        50,
      );
      expect(
        Company.fromMap('c', {'name': 'x', 'max_products': '25'}).maxProducts,
        25,
      );
      expect(Company.fromMap('c', {'name': 'x'}).maxProducts, isNull);
      expect(
        Company.fromMap('c', {'name': 'x', 'max_products': 0}).maxProducts,
        isNull,
      );
    });
    test('a shop-supplied alias is ignored (only max_products counts)', () {
      expect(
        Company.fromMap('c', {'name': 'x', 'maxProducts': 999}).maxProducts,
        isNull,
      );
    });
    test('the app never writes it back', () {
      const c = Company(id: 'c', name: 'x', slug: 'x', maxProducts: 50);
      expect(c.toMap().containsKey('max_products'), isFalse);
      expect(c.toEditableMap().containsKey('max_products'), isFalse);
    });
  });

  group('Repository guard (plan 5: publish 5, hold 6)', () {
    late MockAppRepository repo;

    setUp(() async {
      TestHarness.setupPlatformChannels();
      repo = TestHarness.useMockRepository();
      await repo.createCompany(
        const Company(
          id: _shop,
          name: 'Plan Shop',
          slug: 'plan',
          maxProducts: 5,
        ),
      );
    });

    Future<void> fill(int published, int unpublished) async {
      for (var i = 0; i < published; i++) {
        await repo.saveProduct(_p('pub$i'));
      }
      for (var i = 0; i < unpublished; i++) {
        await repo.saveProduct(_p('unp$i', published: false));
      }
    }

    test('published products beyond the plan are saved unpublished', () async {
      await fill(5, 0);
      await repo.saveProduct(_p('sixth'));
      expect((await repo.product('sixth'))!.isPublished, isFalse);
      final c = await repo.productCounts(_shop);
      expect((c.total, c.published), (6, 5));
    });

    test('creating beyond the total limit throws; nothing is saved', () async {
      await fill(5, 1);
      await expectLater(
        repo.saveProduct(_p('seventh', published: false)),
        throwsA(isA<ProductLimitException>().having((e) => e.cap, 'cap', 6)),
      );
      expect(await repo.product('seventh'), isNull);
      expect((await repo.productCounts(_shop)).total, 6);
    });

    test('unpublishing frees a publishing slot', () async {
      await fill(5, 1);
      await repo.saveProduct(_p('pub0', published: false));
      await repo.saveProduct(_p('unp0', published: true));
      expect((await repo.product('unp0'))!.isPublished, isTrue);
      expect((await repo.productCounts(_shop)).published, 5);
    });

    test(
      'publishing an unpublished product when full stays unpublished',
      () async {
        await fill(5, 1);
        await repo.saveProduct(_p('unp0', published: true));
        expect((await repo.product('unp0'))!.isPublished, isFalse);
      },
    );

    test('deleting frees room to create again', () async {
      await fill(5, 1);
      await repo.deleteProduct('unp0', companyId: _shop);
      await repo.saveProduct(_p('again', published: false));
      expect((await repo.productCounts(_shop)).total, 6);
    });

    test('updating a product is not counted twice', () async {
      await fill(5, 1); // full on both counts
      await repo.saveProduct(_p('pub0').copyWith(name: 'Renamed'));
      final saved = (await repo.product('pub0'))!;
      expect(saved.name, 'Renamed');
      expect(saved.isPublished, isTrue, reason: 'already published: stays');
      expect((await repo.productCounts(_shop)).total, 6);
    });

    test('other shops are not counted', () async {
      await fill(5, 1);
      await repo.saveProduct(_p('foreign', shop: 'c_organic'));
      expect((await repo.productCounts(_shop)).total, 6);
    });

    test('shoppers see only published products', () async {
      await fill(2, 2);
      final shopper = await repo.products(companyId: _shop).first;
      expect(shopper.map((p) => p.id).toSet(), {'pub0', 'pub1'});
      final admin = await repo
          .products(companyId: _shop, includeUnpublished: true)
          .first;
      expect(admin.length, 4);
    });

    test('a shop with no plan limit is unrestricted', () async {
      await repo.createCompany(
        const Company(id: 'c_free', name: 'F', slug: 'f'),
      );
      for (var i = 0; i < 80; i++) {
        await repo.saveProduct(_p('f$i', shop: 'c_free'));
      }
      expect((await repo.productCounts('c_free')).published, 80);
    });
  });

  group('Add / Update Product form', () {
    late MockAppRepository repo;

    setUp(() async {
      TestHarness.setupPlatformChannels();
      repo = TestHarness.useMockRepository();
      TestHarness.signIn(_admin);
      await repo.createCompany(
        const Company(
          id: _shop,
          name: 'Plan Shop',
          slug: 'plan',
          maxProducts: 5,
        ),
      );
    });
    tearDown(TestHarness.signOut);

    Future<void> open(WidgetTester tester, {Product? product}) async {
      await pumpTestApp(
        tester,
        AdminAddProductScreen(product: product),
        user: _admin,
        size: const Size(1200, 2400),
      );
    }

    /// The save button's spinner never "settles", so advance time by hand.
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> tap(WidgetTester tester, String label) async {
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final btn = find.text(label);
      await tester.ensureVisible(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await settle(tester);
    }

    Future<void> fillNew(WidgetTester tester, String title) async {
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Product Title *'),
        title,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'MRP / Original Price (₹) *'),
        '100',
      );
    }

    testWidgets('the form has a Published switch, on for new products', (
      tester,
    ) async {
      await open(tester);
      final sw = find.byKey(const Key('product-published-switch'));
      await tester.ensureVisible(sw);
      expect(tester.widget<SwitchListTile>(sw).value, isTrue);
    });

    testWidgets('51st-style publish: warns, OK saves it unpublished', (
      tester,
    ) async {
      for (var i = 0; i < 5; i++) {
        await repo.saveProduct(_p('pub$i'));
      }
      await open(tester);
      await fillNew(tester, 'Brand New');
      await tap(tester, 'Create Product');

      expect(
        find.byKey(const Key('product-publish-limit-dialog')),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Your plan lets you publish up to 5 products, and all 5 slots are in use.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('upgrade your plan'), findsOneWidget);
      expect(find.text('Save as unpublished'), findsOneWidget);
      expect(
        find.byKey(const Key('product-publish-limit-upgrade')),
        findsOneWidget,
      );
      expect(find.text('5 of 5 used'), findsOneWidget);
      // Never wider than 600.
      final dialogBox = tester.getSize(
        find
            .descendant(
              of: find.byKey(const Key('product-publish-limit-dialog')),
              matching: find.byType(ConstrainedBox),
            )
            .first,
      );
      expect(dialogBox.width, lessThanOrEqualTo(600));

      await tester.tap(find.byKey(const Key('product-publish-limit-ok')));
      await settle(tester);

      final all = await repo
          .products(companyId: _shop, includeUnpublished: true)
          .first;
      final created = all.where((p) => p.name == 'Brand New');
      expect(created, hasLength(1));
      expect(created.single.isPublished, isFalse);
      expect((await repo.productCounts(_shop)).published, 5);
    });

    testWidgets('Cancel on the publish warning creates nothing', (
      tester,
    ) async {
      for (var i = 0; i < 5; i++) {
        await repo.saveProduct(_p('pub$i'));
      }
      await open(tester);
      await fillNew(tester, 'Brand New');
      await tap(tester, 'Create Product');
      await tester.tap(find.byKey(const Key('product-publish-limit-cancel')));
      await settle(tester);
      expect((await repo.productCounts(_shop)).total, 5);
    });

    testWidgets('creating over the total limit: blocked, upgrade offered', (
      tester,
    ) async {
      for (var i = 0; i < 5; i++) {
        await repo.saveProduct(_p('pub$i'));
      }
      await repo.saveProduct(_p('unp0', published: false)); // 6 = cap
      await open(tester);
      await fillNew(tester, 'One Too Many');
      await tap(tester, 'Create Product');

      expect(
        find.byKey(const Key('product-create-limit-dialog')),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'You have reached the maximum of 6 products allowed on your current plan.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'upgrade your plan or delete products you no longer need to free up space.',
        ),
        findsOneWidget,
      );
      expect(find.text('6 of 6 used'), findsOneWidget);
      expect(
        find.byKey(const Key('product-create-limit-upgrade')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('product-create-limit-close')));
      await settle(tester);
      expect(
        (await repo.productCounts(_shop)).total,
        6,
        reason: 'nothing added',
      );
    });

    testWidgets('Upgrade plan in the create-limit dialog opens the plan page', (
      tester,
    ) async {
      for (var i = 0; i < 5; i++) {
        await repo.saveProduct(_p('pub$i'));
      }
      await repo.saveProduct(_p('unp0', published: false));
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const AdminAddProductScreen()),
          GoRoute(
            path: AppRoutes.adminSubscription,
            builder: (_, _) => const Text('PLAN PAGE'),
          ),
        ],
      );
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();
      await fillNew(tester, 'One Too Many');
      await tap(tester, 'Create Product');
      await tester.tap(find.byKey(const Key('product-create-limit-upgrade')));
      await settle(tester);
      expect(find.text('PLAN PAGE'), findsOneWidget);
    });

    testWidgets('update: publishing an unpublished product when full warns', (
      tester,
    ) async {
      for (var i = 0; i < 5; i++) {
        await repo.saveProduct(_p('pub$i'));
      }
      await repo.saveProduct(_p('unp0', published: false));
      final target = (await repo.product('unp0'))!;
      await open(tester, product: target);

      final sw = find.byKey(const Key('product-published-switch'));
      await tester.ensureVisible(sw);
      await tester.pumpAndSettle();
      await tester.tap(sw);
      await tester.pumpAndSettle();
      await tap(tester, 'Update Product');

      expect(
        find.byKey(const Key('product-publish-limit-dialog')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('product-publish-limit-ok')));
      await settle(tester);
      expect((await repo.product('unp0'))!.isPublished, isFalse);
      expect((await repo.productCounts(_shop)).published, 5);
    });

    testWidgets('update: editing a published product does not warn', (
      tester,
    ) async {
      for (var i = 0; i < 5; i++) {
        await repo.saveProduct(_p('pub$i'));
      }
      await open(tester, product: (await repo.product('pub0'))!);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Product Title *'),
        'Edited',
      );
      await tap(tester, 'Update Product');
      expect(
        find.byKey(const Key('product-publish-limit-dialog')),
        findsNothing,
      );
      final saved = (await repo.product('pub0'))!;
      expect(saved.name, 'Edited');
      expect(saved.isPublished, isTrue);
    });
  });

  group('Visibility and plan page', () {
    late MockAppRepository repo;

    setUp(() async {
      TestHarness.setupPlatformChannels();
      repo = TestHarness.useMockRepository();
      await repo.createCompany(
        const Company(
          id: _shop,
          name: 'Plan Shop',
          slug: 'plan',
          maxProducts: 5,
        ),
      );
      await repo.saveProduct(_p('hidden', published: false));
      await repo.saveProduct(_p('shown'));
    });
    tearDown(TestHarness.signOut);

    testWidgets('a shopper cannot open an unpublished product by link', (
      tester,
    ) async {
      TestHarness.signIn(TestHarness.shopper);
      await pumpTestApp(
        tester,
        const ProductDetailsScreen(productId: 'hidden', shopId: _shop),
        user: TestHarness.shopper,
        size: const Size(420, 900),
      );
      expect(find.text('Product not found'), findsOneWidget);
    });

    testWidgets('a published product opens for a shopper', (tester) async {
      TestHarness.signIn(TestHarness.shopper);
      await pumpTestApp(
        tester,
        const ProductDetailsScreen(productId: 'shown', shopId: _shop),
        user: TestHarness.shopper,
        size: const Size(420, 900),
      );
      expect(find.text('Product not found'), findsNothing);
    });

    testWidgets("the shop's own admin can open an unpublished product", (
      tester,
    ) async {
      TestHarness.signIn(_admin);
      await pumpTestApp(
        tester,
        const ProductDetailsScreen(productId: 'hidden', shopId: _shop),
        user: _admin,
        size: const Size(420, 900),
      );
      expect(find.text('Product not found'), findsNothing);
    });

    testWidgets('the plan page shows published and total usage', (
      tester,
    ) async {
      TestHarness.signIn(_admin);
      await pumpTestApp(
        tester,
        const AdminSubscriptionScreen(),
        user: _admin,
        size: const Size(1200, 1000),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('subscription-published')),
          matching: find.text('1 / 5'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('subscription-total')),
          matching: find.text('2 / 6'),
        ),
        findsOneWidget,
      );
    });
  });
}
