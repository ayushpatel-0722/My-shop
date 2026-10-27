import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myshop/app/l10n/app_localizations.dart';
import 'package:myshop/core/widgets/back_to_admin_button.dart';
import 'package:myshop/features/marketplace/categories/categories_screen.dart';
import 'package:myshop/features/marketplace/home/home_screen.dart';
import 'package:myshop/features/product/search/search_screen.dart';

import '../helpers/test_harness.dart';

/// An admin previewing the shopper app gets a "back to admin" icon in the
/// shopper app bars, and only an admin does.
void main() {
  setUp(() {
    TestHarness.setupPlatformChannels();
    TestHarness.useMockRepository();
  });

  tearDown(() => TestHarness.signOut());

  final button = find.byKey(const Key('back-to-admin-button'));

  Future<void> pumpButtonInRouter(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => Scaffold(
            appBar: AppBar(
              title: const Text('shop'),
              actions: const [BackToAdminButton()],
            ),
          ),
        ),
        GoRoute(
          path: '/admin',
          builder: (_, _) => const Scaffold(body: Text('admin console page')),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an admin sees the icon and it opens the admin console', (
    tester,
  ) async {
    TestHarness.signIn(TestHarness.admin);
    await pumpButtonInRouter(tester);
    expect(button, findsOneWidget);

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('admin console page'), findsOneWidget);
  });

  for (final entry in {
    'a shopper': TestHarness.shopper,
    'an employee': TestHarness.employee,
    'a signed-out visitor': null,
  }.entries) {
    testWidgets('${entry.key} never sees the icon', (tester) async {
      TestHarness.signIn(entry.value);
      await pumpButtonInRouter(tester);
      expect(button, findsNothing);
    });
  }

  testWidgets('the icon appears when the admin signs in and goes when they '
      'sign out', (tester) async {
    TestHarness.signOut();
    await pumpButtonInRouter(tester);
    expect(button, findsNothing);

    TestHarness.signIn(TestHarness.admin);
    await tester.pumpAndSettle();
    expect(button, findsOneWidget);

    TestHarness.signOut();
    await tester.pumpAndSettle();
    expect(button, findsNothing);
  });

  group('on the real shopper screens', () {
    const screens = <String, Widget>{
      'home': HomeScreen(),
      'categories': CategoriesScreen(),
      'search': SearchScreen(),
    };
    const sizes = <String, Size>{
      'mobile': Size(420, 900),
      'desktop web': Size(1500, 900),
    };

    for (final screen in screens.entries) {
      for (final size in sizes.entries) {
        testWidgets('${screen.key} / ${size.key}: shown to an admin only', (
          tester,
        ) async {
          // Some shopper screens already overflow slightly at phone width with
          // the test data; that is unrelated to this check, so only layout
          // overflow reports are ignored (any other error still fails).
          final original = FlutterError.onError;
          FlutterError.onError = (details) {
            if (details.toString().contains('overflowed')) return;
            original?.call(details);
          };
          addTearDown(() => FlutterError.onError = original);

          TestHarness.signIn(TestHarness.admin);
          await pumpTestApp(
            tester,
            screen.value,
            user: TestHarness.admin,
            size: size.value,
          );
          expect(button, findsOneWidget, reason: 'admin');

          TestHarness.signIn(TestHarness.shopper);
          await tester.pumpAndSettle();
          expect(button, findsNothing, reason: 'shopper');
        });
      }
    }
  });
}
