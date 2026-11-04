import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myshop/app/l10n/app_localizations.dart';
import 'package:myshop/app/routes/app_router.dart';
import 'package:myshop/app/theme/app_theme.dart';
import 'package:myshop/features/auth/auth_cubit.dart';
import 'package:myshop/features/notifications/notifications_screen.dart';

import '../helpers/test_harness.dart';

/// Back from the notification centre, with the app bar arrow and with the
/// phone's own back.
void main() {
  setUp(() {
    TestHarness.setupPlatformChannels();
    TestHarness.useMockRepository();
  });

  Future<GoRouter> open(WidgetTester tester, {required String start}) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final router = GoRouter(
      initialLocation: start,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (_, _) => const Scaffold(body: Text('HOME PAGE')),
        ),
        GoRoute(
          path: AppRoutes.account,
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push(AppRoutes.notifications),
              child: const Text('ACCOUNT PAGE'),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.notifications,
          builder: (_, _) => const NotificationsScreen(),
        ),
      ],
    );
    await tester.pumpWidget(
      BlocProvider<AuthCubit>.value(
        value: AuthCubit.seeded(TestHarness.shopper),
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
    return router;
  }

  testWidgets('back arrow returns to the screen it was opened from', (
    tester,
  ) async {
    await open(tester, start: AppRoutes.account);
    await tester.tap(find.text('ACCOUNT PAGE'));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationsScreen), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('ACCOUNT PAGE'), findsOneWidget);
  });

  testWidgets('phone back returns to the screen it was opened from', (
    tester,
  ) async {
    await open(tester, start: AppRoutes.account);
    await tester.tap(find.text('ACCOUNT PAGE'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('ACCOUNT PAGE'), findsOneWidget);
  });

  testWidgets('opened with nothing underneath, phone back lands on home', (
    tester,
  ) async {
    await open(tester, start: AppRoutes.notifications);
    expect(find.byType(NotificationsScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('HOME PAGE'), findsOneWidget);
  });
}
