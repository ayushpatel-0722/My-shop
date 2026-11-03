import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/models/banner.dart';
import 'package:myshop/core/models/company.dart';
import 'package:myshop/core/services/company_password.dart';
import 'package:myshop/features/admin/banners/admin_ads_banners_screen.dart';
import 'package:myshop/features/admin/home_config/admin_explore_categories_screen.dart';
import 'package:myshop/features/admin/home_config/admin_trending_now_screen.dart';
import 'package:myshop/features/admin/storefront_lock/locked_admin_shell.dart';
import 'package:myshop/features/admin/storefront_lock/storefront_lock_controller.dart';

import '../../helpers/test_harness.dart';

// A throwaway password for tests only; the real one lives in Firebase as a
// salted hash and is never part of this repository.
const _testPassword = 'test-only-secret';
final _testHash = CompanyPassword.hash(_testPassword, iterations: 1000);

StorefrontLockController _controller({
  Future<String?> Function()? hash,
  AttemptLimiter? limiter,
}) => StorefrontLockController(
  loadHash: hash ?? () async => _testHash,
  limiter: limiter,
);

void main() {
  setUp(TestHarness.setupPlatformChannels);
  tearDown(TestHarness.signOut);

  group('AttemptLimiter', () {
    test('blocks after max failures, frees after cooldown', () {
      var now = DateTime(2026, 1, 1);
      final l = AttemptLimiter(maxAttempts: 3, now: () => now);
      l.fail();
      l.fail();
      expect(l.blocked, isFalse);
      l.fail();
      expect(l.blocked, isTrue);
      expect(l.secondsLeft, 30);
      now = now.add(const Duration(seconds: 31));
      expect(l.blocked, isFalse);
      expect(l.secondsLeft, 0);
    });

    test('reset clears the block', () {
      final l = AttemptLimiter(maxAttempts: 1)..fail();
      expect(l.blocked, isTrue);
      l.reset();
      expect(l.blocked, isFalse);
    });
  });

  group('StorefrontLockController', () {
    test('starts locked', () {
      expect(_controller().unlocked, isFalse);
    });

    test('correct password unlocks, lock() locks again', () async {
      final c = _controller();
      expect(await c.tryUnlock(_testPassword), UnlockResult.unlocked);
      expect(c.unlocked, isTrue);
      c.lock();
      expect(c.unlocked, isFalse);
    });

    test('wrong password stays locked', () async {
      final c = _controller();
      expect(await c.tryUnlock('nope'), UnlockResult.wrongPassword);
      expect(c.unlocked, isFalse);
    });

    test('not configured fails closed (null and blank)', () async {
      expect(
        await _controller(hash: () async => null).tryUnlock(''),
        UnlockResult.notConfigured,
      );
      expect(
        await _controller(hash: () async => '  ').tryUnlock(''),
        UnlockResult.notConfigured,
      );
    });

    test(
      'unreadable setting stays locked and is not a counted guess',
      () async {
        final limiter = AttemptLimiter(maxAttempts: 1);
        final c = _controller(
          hash: () async => throw StateError('offline'),
          limiter: limiter,
        );
        expect(await c.tryUnlock('x'), UnlockResult.checkFailed);
        expect(c.unlocked, isFalse);
        expect(limiter.blocked, isFalse);
      },
    );

    test('too many wrong attempts refuses even the right password', () async {
      final c = _controller(limiter: AttemptLimiter(maxAttempts: 2));
      expect(await c.tryUnlock('a'), UnlockResult.wrongPassword);
      expect(await c.tryUnlock('b'), UnlockResult.tooManyAttempts);
      expect(await c.tryUnlock(_testPassword), UnlockResult.tooManyAttempts);
      expect(c.unlocked, isFalse);
    });

    test('accepts a legacy plain-text stored value', () async {
      final c = _controller(hash: () async => 'plain-pass');
      expect(await c.tryUnlock('plain-pass'), UnlockResult.unlocked);
    });
  });

  group('LockedAdminShell', () {
    Future<StorefrontLockController> pumpShell(
      WidgetTester tester, {
      Widget? fab,
    }) async {
      final c = _controller();
      await pumpTestApp(
        tester,
        LockedAdminShell(
          title: 'Section',
          controller: c,
          actions: [
            IconButton(
              key: const Key('act'),
              icon: const Icon(Icons.add),
              onPressed: () {},
            ),
          ],
          floatingActionButton: fab,
          child: const Center(child: Text('content')),
        ),
        user: TestHarness.admin,
      );
      return c;
    }

    testWidgets('locked by default; unlock via dialog; relock', (tester) async {
      TestHarness.useMockRepository();
      final c = await pumpShell(
        tester,
        fab: FloatingActionButton(
          key: const Key('fab'),
          onPressed: () {},
          child: const Icon(Icons.add),
        ),
      );
      expect(find.byKey(const Key('storefront-lock-button')), findsOneWidget);
      expect(
        find.byKey(const Key('storefront-locked-overlay')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('fab')), findsNothing);

      await tester.tap(find.byKey(const Key('storefront-lock-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('storefront-unlock-dialog')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('storefront-password-field')),
        'wrong',
      );
      await tester.tap(find.byKey(const Key('storefront-unlock-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('storefront-unlock-error')), findsOneWidget);
      expect(c.unlocked, isFalse);

      await tester.enterText(
        find.byKey(const Key('storefront-password-field')),
        _testPassword,
      );
      await tester.tap(find.byKey(const Key('storefront-unlock-submit')));
      await tester.pumpAndSettle();
      expect(c.unlocked, isTrue);
      expect(find.byKey(const Key('storefront-locked-overlay')), findsNothing);
      expect(find.byKey(const Key('fab')), findsOneWidget);

      await tester.tap(find.byKey(const Key('storefront-lock-button')));
      await tester.pumpAndSettle();
      expect(c.unlocked, isFalse);
      expect(
        find.byKey(const Key('storefront-locked-overlay')),
        findsOneWidget,
      );
    });

    testWidgets('cancel leaves it locked', (tester) async {
      TestHarness.useMockRepository();
      final c = await pumpShell(tester);
      await tester.tap(find.byKey(const Key('storefront-unlock-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('storefront-unlock-cancel')));
      await tester.pumpAndSettle();
      expect(c.unlocked, isFalse);
    });
  });

  group('Each storefront section opens locked', () {
    for (final entry in <String, Widget>{
      'explore categories': const AdminExploreCategoriesScreen(),
      'trending now': const AdminTrendingNowScreen(),
      'ads banner': const AdminAdsBannersScreen(),
    }.entries) {
      testWidgets(entry.key, (tester) async {
        final repo = TestHarness.useMockRepository();
        TestHarness.signIn(TestHarness.admin);
        await repo.createCompany(
          const Company(id: 'c1', slug: 's', name: 'Shop'),
        );
        await pumpTestApp(tester, entry.value, user: TestHarness.admin);
        expect(find.byKey(const Key('storefront-lock-button')), findsOneWidget);
        expect(
          find.byKey(const Key('storefront-locked-overlay')),
          findsOneWidget,
        );
      });
    }
  });

  group('Ads banner screen', () {
    testWidgets('create and delete, and home carousel sees it', (tester) async {
      final repo = TestHarness.useMockRepository();
      TestHarness.signIn(TestHarness.admin);
      await repo.saveAdBanner(
        const AdBanner(
          id: 'ad1',
          image: 'https://example.com/ad1.jpg',
          actionType: BannerActionType.externalUrl,
          actionTarget: 'https://example.com',
          priority: 3,
        ),
      );
      await pumpTestApp(
        tester,
        const AdminAdsBannersScreen(),
        user: TestHarness.admin,
      );
      expect(find.byKey(const Key('ads-banner-card-ad1')), findsOneWidget);

      // The home screen reads the same stream.
      expect((await repo.adBanners().first).map((b) => b.id), contains('ad1'));
      await repo.deleteBanner('ad1');
      expect(
        (await repo.adBanners().first).map((b) => b.id),
        isNot(contains('ad1')),
      );
    });
  });
}
