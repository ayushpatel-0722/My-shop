import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myshop/app/l10n/app_localizations.dart';
import 'package:myshop/app/routes/app_router.dart';
import 'package:myshop/app/theme/app_theme.dart';
import 'package:myshop/features/admin/admin_shell.dart';

import '../helpers/test_harness.dart';

/// Admin (web) sidebar: choosing an item far down the menu changes only the
/// content; the menu keeps its scroll position and does not animate.
void main() {
  setUp(() {
    TestHarness.setupPlatformChannels();
    TestHarness.useMockRepository();
    TestHarness.signIn(TestHarness.admin);
    resetAdminSidebarScroll();
  });
  tearDown(() => TestHarness.signOut());

  Widget app(GoRouter router) => MaterialApp.router(
    theme: AppTheme.light(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    routerConfig: router,
  );

  GoRouter buildRouter() => GoRouter(
    initialLocation: AppRoutes.admin,
    routes: [
      for (final path in [
        AppRoutes.admin,
        AppRoutes.adminOrders,
        AppRoutes.adminProducts,
        AppRoutes.adminCategories,
        AppRoutes.adminVouchers,
        AppRoutes.adminEmployees,
        AppRoutes.adminAdmins,
        AppRoutes.adminDelivery,
        AppRoutes.adminBanners,
        AppRoutes.adminShopSettings,
        AppRoutes.adminReviews,
        AppRoutes.adminRecommendations,
        AppRoutes.adminReports,
        AppRoutes.adminQr,
        AppRoutes.adminExploreCategories,
        AppRoutes.adminTrendingNow,
      ])
        AdminRoute(
          path: path,
          builder: (_, state) => AdminShell(
            title: 'PAGE ${state.matchedLocation}',
            child: Center(child: Text('BODY ${state.matchedLocation}')),
          ),
        ),
    ],
  );

  Finder sidebarList() => find.descendant(
    of: find.byType(AdminShell),
    matching: find.byType(ListView),
  );

  double sidebarOffset(WidgetTester tester) => tester
      .state<ScrollableState>(
        find
            .descendant(
              of: sidebarList().first,
              matching: find.byType(Scrollable),
            )
            .first,
      )
      .position
      .pixels;

  Future<void> openAdmin(WidgetTester tester) async {
    // Short and wide: desktop layout, with a menu longer than the screen.
    tester.view.physicalSize = const Size(1400, 520);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(app(buildRouter()));
    await tester.pumpAndSettle();
  }

  testWidgets('selecting a lower menu item keeps the menu where it was', (
    tester,
  ) async {
    await openAdmin(tester);
    expect(find.text('BODY ${AppRoutes.admin}'), findsOneWidget);
    expect(sidebarOffset(tester), 0);

    // Scroll the menu down, as the admin does to reach a lower item.
    await tester.drag(sidebarList().first, const Offset(0, -400));
    await tester.pumpAndSettle();
    final scrolled = sidebarOffset(tester);
    expect(scrolled, greaterThan(100));

    // Tap the last item that is visible.
    final items = find.descendant(
      of: sidebarList().first,
      matching: find.byType(InkWell),
    );
    final visible = items.evaluate().length;
    expect(visible, greaterThan(3));
    await tester.tap(items.at(visible - 3));
    await tester.pump(); // ONE frame: a transition would still show both pages

    expect(
      find.byType(AdminShell),
      findsOneWidget,
      reason: 'no page animation',
    );
    expect(find.textContaining('BODY /admin/'), findsOneWidget);
    expect(find.text('BODY ${AppRoutes.admin}'), findsNothing);

    await tester.pumpAndSettle();
    expect(
      sidebarOffset(tester),
      scrolled,
      reason: 'the menu must not jump back to the top',
    );
  });

  testWidgets('a second pick keeps the position too', (tester) async {
    await openAdmin(tester);
    await tester.drag(sidebarList().first, const Offset(0, -400));
    await tester.pumpAndSettle();
    final scrolled = sidebarOffset(tester);

    for (var i = 0; i < 2; i++) {
      final items = find.descendant(
        of: sidebarList().first,
        matching: find.byType(InkWell),
      );
      await tester.tap(items.at(items.evaluate().length - 2 - i));
      await tester.pumpAndSettle();
      expect(sidebarOffset(tester), scrolled);
    }
  });

  testWidgets('a page opened directly shows its menu item in view', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.view.physicalSize = const Size(1400, 520);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final router = GoRouter(
      initialLocation: AppRoutes.adminTrendingNow,
      routes: [
        for (final path in [AppRoutes.admin, AppRoutes.adminTrendingNow])
          AdminRoute(
            path: path,
            builder: (_, s) => const AdminShell(title: 'T', child: SizedBox()),
          ),
      ],
    );
    await tester.pumpWidget(app(router));
    await tester.pumpAndSettle();
    expect(
      sidebarOffset(tester),
      greaterThan(0),
      reason: 'scrolled to the item',
    );
  });
}
