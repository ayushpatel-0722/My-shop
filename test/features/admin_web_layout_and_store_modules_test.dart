import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/app/l10n/app_localizations.dart';
import 'package:myshop/app/theme/app_theme.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/app_user.dart';
import 'package:myshop/core/services/auth_session.dart';
import 'package:myshop/core/services/service_locator.dart';
import 'package:myshop/features/admin/admin_shell.dart';
import 'package:myshop/features/admin/dashboard/admin_dashboard_screen.dart';

void main() {
  setUp(() {
    ServiceLocator.instance.repository = MockAppRepository();
    AuthSession.currentUser = const AppUser(
      id: 'admin_test',
      companyId: 'masala-mart',
      companyName: 'Masala Mart',
      name: 'Admin Test',
      email: 'admin@masalamart.in',
      role: 'admin',
    );
  });

  tearDown(() {
    AuthSession.currentUser = null;
  });

  Widget buildTestWidget({required Widget child, ThemeData? theme}) {
    return MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: theme ?? AppTheme.light(),
      home: child,
    );
  }

  group('Admin Web Layout Tests (Desktop vs Mobile)', () {
    testWidgets(
      'Desktop view (> 1024) shows permanent sidebar and desktop AppBar',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          buildTestWidget(
            child: const AdminShell(
              title: 'Store Dashboard',
              child: Text('Main Content Area'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Permanent sidebar branding
        expect(find.text('Admin Console'), findsOneWidget);
        expect(find.text('Masala Mart'), findsWidgets); // In sidebar & AppBar
        expect(find.text('LIVE'), findsOneWidget); // In desktop AppBar badge

        // Section headers in desktop sidebar
        expect(find.text('MAIN'), findsOneWidget);
        expect(find.text('CATALOG & SALES'), findsOneWidget);
        expect(find.text('STOREFRONT CONFIG'), findsOneWidget);
        expect(find.text('OPERATIONS & DATA'), findsOneWidget);

        // Key navigation items in sidebar
        expect(find.text('Dashboard'), findsOneWidget);
        expect(find.text('Orders Pipeline'), findsOneWidget);
        expect(find.text('Products'), findsOneWidget);
        expect(find.text('Categories'), findsOneWidget);
        expect(find.text('Vouchers'), findsOneWidget);
        expect(find.text('Delivery Charges'), findsOneWidget);
        expect(find.text('Banners'), findsOneWidget);
        expect(find.text('Home Explore Categories'), findsOneWidget);
        expect(find.text('Home Trending Now'), findsOneWidget);
        expect(find.text('QR Codes'), findsOneWidget);
        expect(find.text('Reports'), findsOneWidget);

        // Shopper App and user profile in sidebar footer
        expect(find.text('Shopper App'), findsOneWidget);
        expect(find.text('Admin Test'), findsOneWidget);
        expect(find.text('ADMIN'), findsOneWidget);

        // Main content is rendered inside desktop framed area
        expect(find.text('Main Content Area'), findsOneWidget);

        // Verify no slide-out Drawer overlay is active in desktop layout
        expect(find.byType(Drawer), findsNothing);
      },
    );

    testWidgets(
      'Mobile view (< 1024) preserves mobile AppBar with slide-out Drawer',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          buildTestWidget(
            child: const AdminShell(
              title: 'Mobile Dashboard',
              child: Text('Mobile Content'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Desktop sidebar is NOT visible
        expect(find.text('MAIN'), findsNothing);
        expect(find.text('CATALOG & SALES'), findsNothing);

        // Drawer is defined on Scaffold
        final scaffoldFinder = find.byType(Scaffold).first;
        final scaffoldState = tester.state<ScaffoldState>(scaffoldFinder);
        expect(scaffoldState.hasDrawer, isTrue);

        // Open the drawer
        scaffoldState.openDrawer();
        await tester.pumpAndSettle();

        // Drawer content is now rendered
        expect(find.text('Admin Console'), findsOneWidget);
        expect(find.text('Orders Pipeline'), findsOneWidget);
        expect(find.text('Products'), findsOneWidget);
      },
    );
  });

  group('Store Module Cards Redesign Tests', () {
    testWidgets(
      'Cards display top icon in themed container, centered title, and subtitle',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          buildTestWidget(child: const AdminDashboardScreen()),
        );
        await tester.pumpAndSettle();

        // Verify Store Modules section
        expect(find.text('Store Modules'), findsOneWidget);
        expect(find.text('15 modules available'), findsOneWidget);

        // Check key modules and their supporting subtitles
        expect(find.text('Orders Pipeline'), findsWidgets);
        expect(find.text('Manage & dispatch orders'), findsOneWidget);

        expect(find.text('Products'), findsWidgets);
        expect(find.text('Catalog, pricing & stock'), findsOneWidget);

        expect(find.text('Categories'), findsWidgets);
        expect(find.text('Organize catalog taxonomy'), findsOneWidget);

        expect(find.text('Vouchers'), findsWidgets);
        expect(find.text('Coupons & discounts'), findsOneWidget);

        expect(find.text('Employees'), findsWidgets);
        expect(find.text('Staff roles & permissions'), findsOneWidget);

        expect(find.text('Home Explore Categories'), findsWidgets);
        expect(find.text('Curate home category pills'), findsOneWidget);

        expect(find.text('Home Trending Now'), findsWidgets);
        expect(find.text('Manage trending home shelf'), findsOneWidget);

        // Verify that for Products module, icon is placed vertically above the title
        final iconFinder = find.byIcon(Icons.inventory_2).last;
        final titleFinder = find.text('Products').last;
        final subtitleFinder = find.text('Catalog, pricing & stock');

        final iconBottom = tester.getBottomLeft(iconFinder).dy;
        final titleTop = tester.getTopLeft(titleFinder).dy;
        final titleBottom = tester.getBottomLeft(titleFinder).dy;
        final subtitleTop = tester.getTopLeft(subtitleFinder).dy;

        // Icon above title
        expect(titleTop, greaterThan(iconBottom));
        // Title above subtitle
        expect(subtitleTop, greaterThan(titleBottom));
      },
    );

    testWidgets(
      'Store Module Cards support mouse hover states without layout error',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          buildTestWidget(child: const AdminDashboardScreen()),
        );
        await tester.pumpAndSettle();

        final cardFinder = find.text('Manage & dispatch orders');
        expect(cardFinder, findsOneWidget);

        // Move mouse over the card
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);

        await gesture.moveTo(tester.getCenter(cardFinder));
        await tester.pumpAndSettle();

        // Verify no exceptions or overflows on hover
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Responsive column layout: 2 cols on mobile, 3 on tablet, 4 on desktop',
      (tester) async {
        // 1. Mobile (width 400) -> 2 columns
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          buildTestWidget(child: const AdminDashboardScreen()),
        );
        await tester.pumpAndSettle();

        final gridFinder = find.byType(GridView).first;
        final gridWidgetMobile = tester.widget<GridView>(gridFinder);
        final delegateMobile =
            gridWidgetMobile.gridDelegate
                as SliverGridDelegateWithFixedCrossAxisCount;
        expect(delegateMobile.crossAxisCount, 2);

        // 2. Tablet (width 800) -> 3 columns
        tester.view.physicalSize = const Size(800, 800);
        await tester.pumpWidget(
          buildTestWidget(child: const AdminDashboardScreen()),
        );
        await tester.pumpAndSettle();

        final gridWidgetTablet = tester.widget<GridView>(
          find.byType(GridView).first,
        );
        final delegateTablet =
            gridWidgetTablet.gridDelegate
                as SliverGridDelegateWithFixedCrossAxisCount;
        expect(delegateTablet.crossAxisCount, 3);

        // 3. Desktop (width 1280) -> 4 columns
        tester.view.physicalSize = const Size(1280, 800);
        await tester.pumpWidget(
          buildTestWidget(child: const AdminDashboardScreen()),
        );
        await tester.pumpAndSettle();

        final gridWidgetDesktop = tester.widget<GridView>(
          find.byType(GridView).first,
        );
        final delegateDesktop =
            gridWidgetDesktop.gridDelegate
                as SliverGridDelegateWithFixedCrossAxisCount;
        expect(delegateDesktop.crossAxisCount, 4);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );
  });

  group('Centralized Admin Color Palette & Dark Mode Tests', () {
    testWidgets('Theme tokens correctly switch between light and dark modes', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Theme(
            data: AppTheme.light(),
            child: Builder(
              builder: (context) {
                expect(
                  AppTheme.adminSidebarBackground(context),
                  AppTheme.adminSidebarBgLight,
                );
                expect(
                  AppTheme.adminCardBorder(context),
                  AppTheme.adminCardBorderLight,
                );
                expect(
                  AppTheme.adminActiveNavBackground(context),
                  AppTheme.adminActiveNavBgLight,
                );
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.pumpWidget(
        MaterialApp(
          home: Theme(
            data: AppTheme.dark(),
            child: Builder(
              builder: (context) {
                expect(
                  AppTheme.adminSidebarBackground(context),
                  AppTheme.adminSidebarBgDark,
                );
                expect(
                  AppTheme.adminCardBorder(context),
                  AppTheme.adminCardBorderDark,
                );
                expect(
                  AppTheme.adminActiveNavBackground(context),
                  AppTheme.adminActiveNavBgDark,
                );
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pump();
    });
  });

  group('Admin Responsive Typography & Cards Tests', () {
    testWidgets(
      'AppTheme admin responsive getters scale between desktop and mobile',
      (tester) async {
        // Desktop
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          buildTestWidget(
            child: Builder(
              builder: (context) {
                expect(AppTheme.adminMetricValue(context).fontSize, 26);
                expect(AppTheme.adminMetricLabel(context).fontSize, 13.5);
                expect(AppTheme.adminPageTitle(context).fontSize, 24);
                expect(AppTheme.adminSectionTitle(context).fontSize, 18);
                expect(AppTheme.adminCardTitle(context).fontSize, 15.5);
                expect(AppTheme.adminBody(context).fontSize, 14.5);
                expect(AppTheme.adminBodySmall(context).fontSize, 13);
                expect(AppTheme.adminBadgeText(context).fontSize, 11.5);
                return const SizedBox();
              },
            ),
          ),
        );
        await tester.pump();

        // Mobile
        tester.view.physicalSize = const Size(375, 812);
        await tester.pumpWidget(
          buildTestWidget(
            child: Builder(
              builder: (context) {
                expect(AppTheme.adminMetricValue(context).fontSize, 20);
                expect(AppTheme.adminMetricLabel(context).fontSize, 12);
                expect(AppTheme.adminPageTitle(context).fontSize, 20);
                expect(AppTheme.adminSectionTitle(context).fontSize, 16);
                expect(AppTheme.adminCardTitle(context).fontSize, 14);
                expect(AppTheme.adminBody(context).fontSize, 13.5);
                expect(AppTheme.adminBodySmall(context).fontSize, 11.5);
                expect(AppTheme.adminBadgeText(context).fontSize, 10.5);
                return const SizedBox();
              },
            ),
          ),
        );
        await tester.pump();
      },
    );

    testWidgets('Dashboard metrics display responsive text at desktop view', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestWidget(child: const AdminDashboardScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text("Today's Orders"), findsOneWidget);
      expect(find.text("Today's Revenue"), findsOneWidget);
      expect(find.text('Order Pipeline'), findsOneWidget);
    });
  });
}
