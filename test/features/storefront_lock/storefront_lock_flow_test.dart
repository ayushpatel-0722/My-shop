import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myshop/app/l10n/app_localizations.dart';
import 'package:myshop/app/routes/app_router.dart';
import 'package:myshop/app/theme/app_theme.dart';
import 'package:myshop/core/models/company.dart';
import 'package:myshop/features/admin/admin_shell.dart';
import 'package:myshop/features/admin/banners/admin_ads_banners_screen.dart';
import 'package:myshop/features/admin/home_config/admin_explore_categories_screen.dart';
import 'package:myshop/features/admin/home_config/admin_trending_now_screen.dart';
import 'package:myshop/features/admin/storefront_lock/storefront_access.dart';
import 'package:myshop/features/auth/auth_cubit.dart';

import '../../helpers/storefront_unlock.dart';
import '../../helpers/test_harness.dart';

/// The whole unlock flow as an admin lives it: real router, real sidebar,
/// real protected screens, other admin pages in between.
void main() {
  setUp(() async {
    TestHarness.setupPlatformChannels();
    final repo = TestHarness.useMockRepository();
    configureStorefrontLock(repo);
    await repo.createCompany(const Company(id: 'c1', slug: 's', name: 'Shop'));
    TestHarness.signIn(TestHarness.admin);
    resetAdminSidebarScroll();
  });
  tearDown(TestHarness.signOut);

  GoRouter buildRouter() => GoRouter(
    initialLocation: AppRoutes.admin,
    routes: [
      for (final (path, title) in [
        (AppRoutes.admin, 'Dashboard'),
        (AppRoutes.adminQr, 'QR Codes page'),
        (AppRoutes.adminVouchers, 'Vouchers page'),
      ])
        AdminRoute(
          path: path,
          builder: (_, _) => AdminShell(
            title: title,
            child: Center(child: Text(title)),
          ),
        ),
      AdminRoute(
        path: AppRoutes.adminExploreCategories,
        builder: (_, _) => const AdminExploreCategoriesScreen(),
      ),
      AdminRoute(
        path: AppRoutes.adminTrendingNow,
        builder: (_, _) => const AdminTrendingNowScreen(),
      ),
      AdminRoute(
        path: AppRoutes.adminAdsBanners,
        builder: (_, _) => const AdminAdsBannersScreen(),
      ),
    ],
  );

  final overlay = find.byKey(const Key('storefront-locked-overlay'));
  final groupLock = find.byKey(const Key('storefront-group-lock'));
  final appBarLock = find.byKey(const Key('storefront-lock-button'));

  Future<void> goTo(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).first);
    await tester.pumpAndSettle();
  }

  Future<void> typePassword(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const Key('storefront-password-field')),
      testStorefrontPassword,
    );
    await tester.tap(find.byKey(const Key('storefront-unlock-submit')));
    await tester.pumpAndSettle();
  }

  testWidgets('unlock once, roam the admin console, lock by hand, log out', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final router = buildRouter();
    final cubit = AuthCubit.seeded(TestHarness.admin);
    await tester.pumpWidget(
      BlocProvider<AuthCubit>.value(
        value: cubit,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Locked by default; the group title shows a lock.
    expect(StorefrontAccess.controller.unlocked, isFalse);
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);

    // 2. Tapping a protected item asks for the password, then opens it.
    await goTo(tester, 'Home Trending Now');
    expect(find.byKey(const Key('storefront-unlock-dialog')), findsOneWidget);
    await typePassword(tester);
    expect(find.text('Home Trending Now'), findsWidgets);
    expect(overlay, findsNothing, reason: 'unlocked and open for editing');

    // 3. The other two sections open with NO further password.
    await goTo(tester, 'Home Explore Categories');
    expect(find.byKey(const Key('storefront-unlock-dialog')), findsNothing);
    expect(overlay, findsNothing);
    await goTo(tester, 'Home Screen Ads Banner');
    expect(find.byKey(const Key('storefront-unlock-dialog')), findsNothing);
    expect(overlay, findsNothing);

    // 4. Other admin screens do NOT lock it (QR Codes, Vouchers, Dashboard).
    await goTo(tester, 'QR Codes');
    expect(find.text('QR Codes page'), findsWidgets);
    expect(StorefrontAccess.controller.unlocked, isTrue);
    expect(find.byIcon(Icons.lock_open_rounded), findsOneWidget);
    await goTo(tester, 'Vouchers');
    expect(StorefrontAccess.controller.unlocked, isTrue);
    await goTo(tester, 'Dashboard');
    expect(StorefrontAccess.controller.unlocked, isTrue);

    // 5. Back in a protected section: still open.
    await goTo(tester, 'Home Trending Now');
    expect(overlay, findsNothing);

    // 6. App bar unlock icon: confirmation first; Cancel keeps it open.
    expect(find.byIcon(Icons.lock_open_rounded), findsWidgets);
    await tester.tap(appBarLock);
    await tester.pumpAndSettle();
    expect(
      find.text('Do you want to lock all storefront configuration sections?'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('storefront-lock-confirm-cancel')));
    await tester.pumpAndSettle();
    expect(StorefrontAccess.controller.unlocked, isTrue);
    expect(overlay, findsNothing);

    // ...OK locks all three immediately (also the sidebar lock).
    await tester.tap(appBarLock);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('storefront-lock-confirm-ok')));
    await tester.pumpAndSettle();
    expect(StorefrontAccess.controller.unlocked, isFalse);
    expect(overlay, findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsWidgets);
    await goTo(tester, 'Home Screen Ads Banner');
    expect(find.byKey(const Key('storefront-unlock-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('storefront-unlock-cancel')));
    await tester.pumpAndSettle();
    expect(overlay, findsWidgets, reason: 'cancelled: still locked');

    // 7. Opened by direct link while locked: cannot be edited, the add
    // button does nothing.
    GoRouter.of(
      tester.element(find.byType(AdminShell).first),
    ).go(AppRoutes.adminAdsBanners);
    await tester.pumpAndSettle();
    expect(overlay, findsOneWidget);
    expect(find.byKey(const Key('ads-banner-add')), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('ads-banner-add')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ads-banner-save')), findsNothing);

    // 8. Unlock again from the group title, then log out without locking.
    await tester.tap(groupLock);
    await tester.pumpAndSettle();
    await typePassword(tester);
    expect(StorefrontAccess.controller.unlocked, isTrue);
    await goTo(tester, 'Vouchers');
    expect(StorefrontAccess.controller.unlocked, isTrue);
    await tester.tap(find.byIcon(Icons.logout_rounded).first);
    await tester.pumpAndSettle();
    expect(
      StorefrontAccess.controller.unlocked,
      isFalse,
      reason: 'logging out locks everything',
    );

    // 9. Logging in again: locked by default.
    TestHarness.signIn(TestHarness.admin);
    router.go(AppRoutes.admin);
    await tester.pumpAndSettle();
    expect(StorefrontAccess.controller.unlocked, isFalse);
    expect(find.byIcon(Icons.lock_rounded), findsWidgets);
  });
}
