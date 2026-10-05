import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myshop/app/l10n/app_localizations.dart';
import 'package:myshop/app/routes/app_router.dart';
import 'package:myshop/app/widgets/language_selector.dart';
import 'package:myshop/core/services/auth_session.dart';
import 'package:myshop/features/splash/role_selection_screen.dart';

import '../helpers/test_harness.dart';

void main() {
  setUp(() {
    TestHarness.setupPlatformChannels();
    TestHarness.useMockRepository();
    AuthSession.set(null, restoring: false);
    AuthSession.hasCompletedInitialBoot = true;
  });

  Widget buildRoleSelectionApp({required List<String> navigatedRoutes}) {
    final router = GoRouter(
      initialLocation: AppRoutes.role,
      routes: [
        GoRoute(
          path: AppRoutes.role,
          builder: (context, state) => const RoleSelectionScreen(),
        ),
        GoRoute(
          path: AppRoutes.adminLogin,
          builder: (context, state) {
            navigatedRoutes.add(AppRoutes.adminLogin);
            return const Scaffold(body: Text('Admin Login Screen'));
          },
        ),
        GoRoute(
          path: AppRoutes.employeeLogin,
          builder: (context, state) {
            navigatedRoutes.add(AppRoutes.employeeLogin);
            return const Scaffold(body: Text('Employee Login Screen'));
          },
        ),
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) {
            navigatedRoutes.add(AppRoutes.home);
            return const Scaffold(body: Text('Home Screen'));
          },
        ),
        GoRoute(
          path: AppRoutes.companyOnboarding,
          builder: (context, state) {
            navigatedRoutes.add(AppRoutes.companyOnboarding);
            return const Scaffold(body: Text('Company Onboarding Screen'));
          },
        ),
      ],
    );

    return MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
    );
  }

  group('RoleSelectionScreen Tests', () {
    testWidgets('renders all role options, headers, and language selector', (
      tester,
    ) async {
      final navigatedRoutes = <String>[];
      await tester.pumpWidget(
        buildRoleSelectionApp(navigatedRoutes: navigatedRoutes),
      );
      await tester.pumpAndSettle();

      // Header & Icon
      expect(find.byIcon(Icons.storefront), findsOneWidget);
      expect(find.text('Continue as'), findsOneWidget);
      expect(
        find.text('Choose your account type to proceed'),
        findsOneWidget,
      );

      // Role Cards
      expect(find.text('I am an Admin'), findsOneWidget);
      expect(find.byIcon(Icons.admin_panel_settings), findsOneWidget);

      expect(find.text('I am an Employee'), findsOneWidget);
      expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);

      expect(find.text('I am a Shopper'), findsOneWidget);
      expect(find.byIcon(Icons.shopping_bag_outlined), findsOneWidget);

      // Company onboarding action
      expect(find.text('Create a new Company'), findsOneWidget);
      expect(find.byIcon(Icons.add_business), findsOneWidget);

      // Language selector
      expect(find.byType(LanguageSelector), findsOneWidget);
    });

    testWidgets('tapping "I am an Admin" navigates to Admin Login', (
      tester,
    ) async {
      final navigatedRoutes = <String>[];
      await tester.pumpWidget(
        buildRoleSelectionApp(navigatedRoutes: navigatedRoutes),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('I am an Admin'));
      await tester.pumpAndSettle();

      expect(navigatedRoutes, contains(AppRoutes.adminLogin));
      expect(find.text('Admin Login Screen'), findsOneWidget);
    });

    testWidgets('tapping "I am an Employee" navigates to Employee Login', (
      tester,
    ) async {
      final navigatedRoutes = <String>[];
      await tester.pumpWidget(
        buildRoleSelectionApp(navigatedRoutes: navigatedRoutes),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('I am an Employee'));
      await tester.pumpAndSettle();

      expect(navigatedRoutes, contains(AppRoutes.employeeLogin));
      expect(find.text('Employee Login Screen'), findsOneWidget);
    });

    testWidgets('tapping "I am a Shopper" navigates to Home', (tester) async {
      final navigatedRoutes = <String>[];
      await tester.pumpWidget(
        buildRoleSelectionApp(navigatedRoutes: navigatedRoutes),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('I am a Shopper'));
      await tester.pumpAndSettle();

      expect(navigatedRoutes, contains(AppRoutes.home));
      expect(find.text('Home Screen'), findsOneWidget);
    });

    testWidgets(
      'tapping "Create a new Company" navigates to Company Onboarding',
      (tester) async {
        final navigatedRoutes = <String>[];
        await tester.pumpWidget(
          buildRoleSelectionApp(navigatedRoutes: navigatedRoutes),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Create a new Company'));
        await tester.pumpAndSettle();

        expect(navigatedRoutes, contains(AppRoutes.companyOnboarding));
        expect(find.text('Company Onboarding Screen'), findsOneWidget);
      },
    );
  });
}
