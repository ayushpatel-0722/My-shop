import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/models/banner.dart';
import 'package:myshop/core/models/company.dart';
import 'package:myshop/core/services/company_password.dart';
import 'package:myshop/features/admin/admin_shell.dart';
import 'package:myshop/features/admin/banners/admin_ads_banners_screen.dart';
import 'package:myshop/features/admin/home_config/admin_explore_categories_screen.dart';
import 'package:myshop/features/admin/home_config/admin_trending_now_screen.dart';
import 'package:myshop/features/admin/storefront_lock/locked_admin_shell.dart';
import 'package:myshop/features/admin/storefront_lock/storefront_access.dart';
import 'package:myshop/features/admin/storefront_lock/storefront_lock_controller.dart';

import '../../helpers/storefront_unlock.dart';
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

      // Locking asks first: Cancel keeps it open, OK locks.
      await tester.tap(find.byKey(const Key('storefront-lock-button')));
      await tester.pumpAndSettle();
      expect(
        find.text('Do you want to lock all storefront configuration sections?'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('storefront-lock-confirm-cancel')));
      await tester.pumpAndSettle();
      expect(c.unlocked, isTrue);

      await tester.tap(find.byKey(const Key('storefront-lock-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('storefront-lock-confirm-ok')));
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
          shopId: 'c_organic',
        ),
      );
      await repo.saveAdBanner(
        const AdBanner(
          id: 'other',
          image: 'https://example.com/o.jpg',
          shopId: 'c_techtronics',
        ),
      );
      await pumpTestApp(
        tester,
        const AdminAdsBannersScreen(),
        user: TestHarness.admin,
      );
      expect(find.byKey(const Key('ads-banner-card-ad1')), findsOneWidget);
      expect(
        find.byKey(const Key('ads-banner-card-other')),
        findsNothing,
        reason: 'another shop\'s banner is not managed here',
      );

      // The home screen reads the same stream.
      expect((await repo.adBanners().first).map((b) => b.id), contains('ad1'));
      await repo.deleteBanner('ad1');
      expect(
        (await repo.adBanners().first).map((b) => b.id),
        isNot(contains('ad1')),
      );
    });

    testWidgets('a new banner is saved under the admin\'s shop', (
      tester,
    ) async {
      final repo = TestHarness.useMockRepository();
      configureStorefrontLock(repo);
      TestHarness.signIn(TestHarness.admin);
      await pumpTestApp(
        tester,
        const AdminAdsBannersScreen(),
        user: TestHarness.admin,
      );
      await unlockStorefront(tester);
      await tester.tap(find.byKey(const Key('ads-banner-add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('ads-banner-image-field')),
        'https://example.com/new.png',
      );
      await tester.tap(find.byKey(const Key('ads-banner-save')));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final saved = await repo.adBanners().first;
      final added = saved.singleWhere(
        (b) => b.image == 'https://example.com/new.png',
      );
      expect(added.shopId, TestHarness.admin.companyId);
    });
  });

  group('Admin menu: Home Screen Config group', () {
    Future<void> pumpMenu(WidgetTester tester, Widget page) => pumpTestApp(
      tester,
      page,
      user: TestHarness.admin,
      size: const Size(1280, 1200),
    );

    testWidgets('is its own group, separate from Storefront Config', (
      tester,
    ) async {
      TestHarness.useMockRepository();
      await pumpMenu(tester, const AdminShell(title: 'Dash', child: Text('x')));
      expect(find.text('STOREFRONT CONFIG'), findsOneWidget);
      expect(find.text('HOME SCREEN CONFIG'), findsOneWidget);
      expect(find.byKey(const Key('storefront-group-lock')), findsOneWidget);
      expect(find.text('Home Trending Now'), findsOneWidget);
      expect(find.text('Home Screen Ads Banner'), findsOneWidget);
      expect(StorefrontAccess.controller.unlocked, isFalse);
    });

    testWidgets('header lock opens the dialog and unlocks the group', (
      tester,
    ) async {
      final repo = TestHarness.useMockRepository();
      repo.storefrontLockHashValue = _testHash;
      await pumpMenu(tester, const AdminShell(title: 'Dash', child: Text('x')));
      await tester.tap(find.byKey(const Key('storefront-group-lock')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('storefront-unlock-dialog')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('storefront-password-field')),
        _testPassword,
      );
      await tester.tap(find.byKey(const Key('storefront-unlock-submit')));
      await tester.pumpAndSettle();
      expect(StorefrontAccess.controller.unlocked, isTrue);

      // Tap the lock again: asks first, then locks on OK.
      await tester.tap(find.byKey(const Key('storefront-group-lock')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('storefront-lock-confirm-cancel')));
      await tester.pumpAndSettle();
      expect(StorefrontAccess.controller.unlocked, isTrue);
      await tester.tap(find.byKey(const Key('storefront-group-lock')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('storefront-lock-confirm-ok')));
      await tester.pumpAndSettle();
      expect(StorefrontAccess.controller.unlocked, isFalse);
    });

    testWidgets('signing out locks the group; the next login starts locked', (
      tester,
    ) async {
      final repo = TestHarness.useMockRepository();
      repo.storefrontLockHashValue = _testHash;
      TestHarness.signIn(TestHarness.admin);
      expect(
        await StorefrontAccess.controller.tryUnlock(_testPassword),
        UnlockResult.unlocked,
      );
      TestHarness.signOut();
      expect(StorefrontAccess.controller.unlocked, isFalse);
      TestHarness.signIn(TestHarness.admin);
      expect(StorefrontAccess.controller.unlocked, isFalse);
    });

    testWidgets('tapping a protected item while locked asks for the password', (
      tester,
    ) async {
      TestHarness.useMockRepository();
      await pumpMenu(tester, const AdminShell(title: 'Dash', child: Text('x')));
      await tester.tap(find.text('Home Trending Now'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('storefront-unlock-dialog')), findsOneWidget);
    });

    testWidgets('one unlock survives moving to other admin screens', (
      tester,
    ) async {
      final repo = TestHarness.useMockRepository();
      repo.storefrontLockHashValue = _testHash;
      TestHarness.signIn(TestHarness.admin);
      expect(
        await StorefrontAccess.controller.tryUnlock(_testPassword),
        UnlockResult.unlocked,
      );

      // A protected screen opens straight into edit mode...
      await pumpMenu(tester, const AdminAdsBannersScreen());
      expect(find.byKey(const Key('storefront-locked-overlay')), findsNothing);

      // ...and moving to any other admin page (QR Codes, Vouchers, ...) does
      // NOT lock it; the sidebar lock still shows "unlocked".
      await pumpMenu(tester, const AdminShell(title: 'Dash', child: Text('x')));
      await tester.pump();
      expect(StorefrontAccess.controller.unlocked, isTrue);
      expect(find.byIcon(Icons.lock_open_rounded), findsWidgets);

      // Back in a protected screen: still open, no password asked.
      await pumpMenu(tester, const AdminAdsBannersScreen());
      expect(find.byKey(const Key('storefront-locked-overlay')), findsNothing);
    });

    for (final entry in <String, Widget>{
      'explore categories': const AdminExploreCategoriesScreen(),
      'trending now': const AdminTrendingNowScreen(),
    }.entries) {
      testWidgets('one unlock survives ${entry.key} loading / no-shop pages', (
        tester,
      ) async {
        final repo = TestHarness.useMockRepository();
        repo.storefrontLockHashValue = _testHash;
        TestHarness.signIn(TestHarness.admin);
        expect(
          await StorefrontAccess.controller.tryUnlock(_testPassword),
          UnlockResult.unlocked,
        );
        // No shop is set up, so the screen shows its plain placeholder page.
        await pumpMenu(tester, entry.value);
        await tester.pump(const Duration(milliseconds: 100));
        expect(StorefrontAccess.controller.unlocked, isTrue);
      });
    }
  });
}
