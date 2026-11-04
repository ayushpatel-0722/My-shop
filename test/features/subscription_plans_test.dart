import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/domain/subscription_plans.dart';
import 'package:myshop/core/models/app_user.dart';
import 'package:myshop/core/models/category.dart';
import 'package:myshop/core/models/company.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/features/admin/subscription/admin_subscription_screen.dart';

import '../helpers/test_harness.dart';

const _admin = AppUser(
  id: 'a_plan',
  companyId: 'c_sub',
  companyName: 'Sub Shop',
  name: 'Sub Admin',
  email: 'sub@shop.in',
  role: 'admin',
);

void main() {
  group('SubscriptionPlan', () {
    test('the three plans and their limits', () {
      expect(SubscriptionPlan.basic.maxProducts, 50);
      expect(SubscriptionPlan.golden.maxProducts, 80);
      expect(SubscriptionPlan.diamond.maxProducts, 120);
      expect(SubscriptionPlan.basic.maxCategories, 4);
      expect(SubscriptionPlan.golden.maxCategories, 5);
      expect(SubscriptionPlan.diamond.maxCategories, 7);
    });

    test('read from the stored value, any case; unknown is null', () {
      expect(SubscriptionPlan.fromId('Golden'), SubscriptionPlan.golden);
      expect(SubscriptionPlan.fromId(' diamond '), SubscriptionPlan.diamond);
      expect(SubscriptionPlan.fromId('platinum'), isNull);
      expect(SubscriptionPlan.fromId(null), isNull);
    });

    test('a plain max_products number maps to the matching plan', () {
      expect(SubscriptionPlan.matchingMaxProducts(50), SubscriptionPlan.basic);
      expect(
        SubscriptionPlan.matchingMaxProducts(120),
        SubscriptionPlan.diamond,
      );
      expect(SubscriptionPlan.matchingMaxProducts(70), isNull);
    });

    test('upgrades are the bigger plans only', () {
      expect(SubscriptionPlan.basic.upgrades, [
        SubscriptionPlan.golden,
        SubscriptionPlan.diamond,
      ]);
      expect(SubscriptionPlan.diamond.upgrades, isEmpty);
    });

    test('contact is Ayush Patel', () {
      expect(PlanContact.name, 'Ayush Patel');
      expect(PlanContact.email, 'work.ayushkumar112428@gmail.com');
    });
  });

  group('Company limit follows its plan', () {
    test('plan decides max_products, whatever max_products says', () {
      final c = Company.fromMap('c', {
        'name': 'x',
        'plan': 'golden',
        'max_products': 5,
      });
      expect(c.plan, SubscriptionPlan.golden);
      expect(c.maxProducts, 80);
    });
    test('no plan: max_products is used; neither: no limit', () {
      expect(
        Company.fromMap('c', {'name': 'x', 'max_products': 50}).maxProducts,
        50,
      );
      expect(Company.fromMap('c', {'name': 'x'}).maxProducts, isNull);
    });
    test('the app never writes plan back', () {
      const c = Company(
        id: 'c',
        name: 'x',
        slug: 'x',
        plan: SubscriptionPlan.basic,
      );
      expect(c.toMap().containsKey('plan'), isFalse);
      expect(c.toEditableMap().containsKey('plan'), isFalse);
    });
  });

  group('Subscription Plan page', () {
    late MockAppRepository repo;

    setUp(() {
      TestHarness.setupPlatformChannels();
      repo = TestHarness.useMockRepository();
      TestHarness.signIn(_admin);
      AdminSubscriptionScreen.launcher = (_) async => true;
    });
    tearDown(TestHarness.signOut);

    Future<void> open(
      WidgetTester tester,
      Company company, {
      Size size = const Size(1300, 1200),
    }) async {
      await repo.createCompany(company);
      await pumpTestApp(
        tester,
        const AdminSubscriptionScreen(),
        user: _admin,
        size: size,
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
    }

    const golden = Company(
      id: 'c_sub',
      name: 'Sub Shop',
      slug: 'sub',
      plan: SubscriptionPlan.golden,
      maxProducts: 80,
    );

    testWidgets('shows all three plans with their limits', (tester) async {
      await open(tester, golden);
      for (final id in ['basic', 'golden', 'diamond']) {
        expect(find.byKey(Key('plan-card-$id')), findsOneWidget);
      }
      expect(find.text('Basic'), findsWidgets);
      expect(find.text('Golden'), findsWidgets);
      expect(find.text('Diamond'), findsWidgets);
      expect(find.text('Publish up to 50 products'), findsOneWidget);
      expect(find.text('Publish up to 80 products'), findsOneWidget);
      expect(find.text('Publish up to 120 products'), findsOneWidget);
      expect(find.text('Up to 4 categories'), findsOneWidget);
      expect(find.text('Up to 5 categories'), findsOneWidget);
      expect(find.text('Up to 7 categories'), findsOneWidget);
      // +20% in total, rounded down: 60 / 96 / 144.
      expect(
        find.text(
          'Keep up to 60 products in total (extra ones stay unpublished)',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('up to 96 products'), findsOneWidget);
      expect(find.textContaining('up to 144 products'), findsOneWidget);
      expect(find.byKey(const Key('plan-popular')), findsOneWidget);
    });

    testWidgets('marks the current plan and offers only bigger ones', (
      tester,
    ) async {
      await open(tester, golden);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('subscription-current-name')))
            .data,
        'Golden',
      );
      expect(find.byKey(const Key('plan-current-golden')), findsOneWidget);
      expect(find.byKey(const Key('plan-upgrade-diamond')), findsOneWidget);
      expect(find.byKey(const Key('plan-upgrade-basic')), findsNothing);
      expect(find.byKey(const Key('plan-upgrade-golden')), findsNothing);
    });

    testWidgets('a max_products-only shop shows as the matching plan', (
      tester,
    ) async {
      await open(
        tester,
        const Company(
          id: 'c_sub',
          name: 'Sub Shop',
          slug: 's',
          maxProducts: 50,
        ),
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('subscription-current-name')))
            .data,
        'Basic',
      );
      expect(find.byKey(const Key('plan-upgrade-golden')), findsOneWidget);
      expect(find.byKey(const Key('plan-upgrade-diamond')), findsOneWidget);
    });

    testWidgets('an unusual limit shows as a custom plan', (tester) async {
      await open(
        tester,
        const Company(
          id: 'c_sub',
          name: 'Sub Shop',
          slug: 's',
          maxProducts: 70,
        ),
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('subscription-current-name')))
            .data,
        'Custom plan',
      );
    });

    testWidgets('usage: published, total and categories against the plan', (
      tester,
    ) async {
      await repo.saveProduct(
        const Product(id: 'p1', companyId: 'c_sub', name: 'A', amount: 1),
      );
      await repo.saveProduct(
        const Product(
          id: 'p2',
          companyId: 'c_sub',
          name: 'B',
          amount: 1,
          isPublished: false,
        ),
      );
      await repo.saveCategory(
        const Category(id: 'k1', companyId: 'c_sub', name: 'K'),
      );
      final inShop = (await repo.categories(companyId: 'c_sub').first).length;
      await open(tester, golden);
      Finder meter(String key, String text) =>
          find.descendant(of: find.byKey(Key(key)), matching: find.text(text));
      expect(meter('subscription-published', '1 / 80'), findsOneWidget);
      expect(meter('subscription-total', '2 / 96'), findsOneWidget);
      expect(meter('subscription-categories', '$inShop / 5'), findsOneWidget);
      expect(inShop, greaterThanOrEqualTo(1));
    });

    testWidgets('contact card names Ayush Patel and his email', (tester) async {
      await open(tester, golden);
      expect(
        find.textContaining('Ayush Patel · work.ayushkumar112428@gmail.com'),
        findsOneWidget,
      );
    });

    testWidgets('Upgrade emails Ayush with the plan and shop filled in', (
      tester,
    ) async {
      Uri? launched;
      AdminSubscriptionScreen.launcher = (u) async {
        launched = u;
        return true;
      };
      await open(tester, golden);
      final btn = find.byKey(const Key('plan-upgrade-diamond'));
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pump();
      expect(launched, isNotNull);
      expect(launched!.scheme, 'mailto');
      expect(launched!.path, 'work.ayushkumar112428@gmail.com');
      expect(
        launched!.queryParameters['subject'],
        'Plan upgrade request: Diamond (Sub Shop)',
      );
      expect(launched!.queryParameters['body'], contains('"Sub Shop"'));
      expect(launched!.queryParameters['body'], contains('Diamond plan'));
      expect(launched!.queryParameters['body'], contains('Hello Ayush Patel'));
    });

    testWidgets('no email app: says so, with the address', (tester) async {
      AdminSubscriptionScreen.launcher = (_) async => false;
      await open(tester, golden);
      final btn = find.byKey(const Key('plan-upgrade-diamond'));
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pump();
      expect(
        find.textContaining('work.ayushkumar112428@gmail.com'),
        findsWidgets,
      );
      expect(
        find.textContaining('Could not open your email app'),
        findsOneWidget,
      );
    });

    testWidgets('Copy email puts the address on the clipboard', (tester) async {
      String? clip;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              clip = (call.arguments as Map)['text'] as String?;
            }
            return null;
          });
      await open(tester, golden);
      final btn = find.byKey(const Key('plan-contact-copy'));
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pump();
      expect(clip, 'work.ayushkumar112428@gmail.com');
      expect(find.text('Email address copied'), findsOneWidget);
    });

    testWidgets('fits a phone: plans stack, nothing overflows', (tester) async {
      await open(tester, golden, size: const Size(390, 900));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('plan-card-basic')), findsOneWidget);
    });

    testWidgets('fits a wide screen: no overflow', (tester) async {
      await open(tester, golden);
      expect(tester.takeException(), isNull);
    });
  });
}
