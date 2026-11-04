import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myshop/app/l10n/app_localizations.dart';
import 'package:myshop/app/l10n/locale_cubit.dart';
import 'package:myshop/core/services/auth_session.dart';
import 'package:myshop/features/auth/admin_login/admin_login_screen.dart';
import 'package:myshop/features/auth/auth_cubit.dart';
import 'package:myshop/features/auth/employee_login/employee_login_screen.dart';
import 'package:myshop/features/company_onboarding/company_onboarding_screen.dart';
import 'package:myshop/features/splash/role_selection_screen.dart';

import '../helpers/test_harness.dart';

/// The role choice, both logins and Create Company at phone, tablet and
/// desktop sizes: no overflow, nothing clipped, password toggle works.
void main() {
  setUp(() {
    TestHarness.setupPlatformChannels();
    TestHarness.useMockRepository();
    AuthSession.set(null, restoring: false);
    AuthSession.hasCompletedInitialBoot = true;
  });

  const sizes = <String, Size>{
    'small phone': Size(320, 568),
    'phone': Size(390, 844),
    'large phone': Size(430, 932),
    'tablet': Size(800, 1100),
    'small browser': Size(1024, 600),
    'desktop': Size(1440, 900),
    'large desktop': Size(1920, 1080),
  };

  Widget app(Widget child) => MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => AuthCubit()),
      BlocProvider(create: (_) => LocaleCubit()),
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      routerConfig: GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => child)],
      ),
    ),
  );

  void setSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  final screens = <String, Widget Function()>{
    'role selection': () => const RoleSelectionScreen(),
    'admin login': () => const AdminLoginScreen(),
    'employee login': () => const EmployeeLoginScreen(),
    'create company': () => const CompanyOnboardingScreen(),
  };

  for (final screen in screens.entries) {
    for (final size in sizes.entries) {
      testWidgets('${screen.key} fits on a ${size.key}', (tester) async {
        setSize(tester, size.value);
        await tester.pumpWidget(app(screen.value()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('create company: every step fits a small phone', (tester) async {
    setSize(tester, sizes['small phone']!);
    await tester.pumpWidget(app(const CompanyOnboardingScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 3'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('company_name_field')),
      'Test Cafe',
    );
    await tester.enterText(
      find.byKey(const Key('store_category_field')),
      'Cafe',
    );
    await tester.enterText(
      find.byKey(const Key('app_subtitle_field')),
      'Fresh coffee',
    );
    await tester.enterText(
      find.byKey(const Key('store_address_field')),
      '12 Market Street',
    );
    await tester.tap(find.byKey(const Key('onboarding_next_button')));
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('onboarding_next_button')));
    await tester.pumpAndSettle();
    expect(find.text('Step 3 of 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin login: password can be shown and hidden', (tester) async {
    setSize(tester, sizes['phone']!);
    await tester.pumpWidget(app(const AdminLoginScreen()));
    await tester.pumpAndSettle();

    // Step 1 asks for the company, with its password hidden.
    expect(find.text('Step 1 of 2'), findsOneWidget);
    TextField passwordField() =>
        tester.widget<TextField>(find.byType(TextField).at(1));
    expect(passwordField().obscureText, isTrue);
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    expect(passwordField().obscureText, isFalse);
    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();
    expect(passwordField().obscureText, isTrue);
  });

  testWidgets('employee login names the role and has a password toggle', (
    tester,
  ) async {
    setSize(tester, sizes['phone']!);
    await tester.pumpWidget(app(const EmployeeLoginScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Employee'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });

  testWidgets('admin login names the role', (tester) async {
    setSize(tester, sizes['desktop']!);
    await tester.pumpWidget(app(const AdminLoginScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('Admin Login'), findsOneWidget);
  });
}
