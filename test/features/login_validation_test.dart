import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/app/l10n/app_localizations.dart';
import 'package:myshop/core/services/auth_session.dart';
import 'package:myshop/features/auth/admin_login/admin_login_screen.dart';
import 'package:myshop/features/auth/auth_cubit.dart';
import 'package:myshop/features/auth/employee_login/employee_login_screen.dart';
import 'package:myshop/features/auth/user_login/user_login_screen.dart';

import '../helpers/test_harness.dart';

void main() {
  setUp(() {
    TestHarness.setupPlatformChannels();
    TestHarness.useMockRepository();
    AuthSession.set(null, restoring: false);
    AuthSession.hasCompletedInitialBoot = true;
  });

  Widget wrapWithApp(Widget child) {
    return BlocProvider(
      create: (_) => AuthCubit(),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }

  group('AdminLoginScreen Validation Tests', () {
    testWidgets('Step 1 shows error when Next is clicked with empty inputs', (
      tester,
    ) async {
      await tester.pumpWidget(wrapWithApp(const AdminLoginScreen()));
      await tester.pumpAndSettle();

      // Tap Next button with empty company name and password
      final nextButton = find.widgetWithText(ElevatedButton, 'Next');
      expect(nextButton, findsOneWidget);
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // Verify SnackBar and inline error texts appear
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.text('Please enter company name and company password.'),
        findsWidgets,
      );
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Inline errors clear on typing', (tester) async {
      await tester.pumpWidget(wrapWithApp(const AdminLoginScreen()));
      await tester.pumpAndSettle();

      // Trigger validation error
      await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
      await tester.pumpAndSettle();

      // Enter company name
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, 'Greenleaf Organics');
      await tester.pumpAndSettle();

      // Company name error should clear
      final companyField = tester.widget<TextField>(textFields.first);
      expect(companyField.decoration?.errorText, isNull);
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('EmployeeLoginScreen Validation Tests', () {
    testWidgets('Shows error feedback on empty submission', (tester) async {
      await tester.pumpWidget(wrapWithApp(const EmployeeLoginScreen()));
      await tester.pumpAndSettle();

      // Click Login button with empty inputs
      final loginBtn = find.widgetWithText(ElevatedButton, 'Login');
      expect(loginBtn, findsOneWidget);
      await tester.tap(loginBtn);
      await tester.pumpAndSettle();

      // Verify SnackBar or inline errors appear
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.text('Company name and password are required.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Shows error on invalid email format', (tester) async {
      await tester.pumpWidget(wrapWithApp(const EmployeeLoginScreen()));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'MyCompany');
      await tester.enterText(textFields.at(1), 'invalid-email');
      await tester.enterText(textFields.at(2), '123456');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter admin email and password.'), findsWidgets);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Shows error when password is less than 6 characters', (
      tester,
    ) async {
      await tester.pumpWidget(wrapWithApp(const EmployeeLoginScreen()));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'MyCompany');
      await tester.enterText(textFields.at(1), 'emp@company.com');
      await tester.enterText(textFields.at(2), '123');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();

      expect(
        find.text('Admin password must be at least 6 characters.'),
        findsWidgets,
      );
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('UserLoginScreen Validation Tests', () {
    testWidgets('Shows error on empty mobile submission', (tester) async {
      await tester.pumpWidget(wrapWithApp(const UserLoginScreen()));
      await tester.pumpAndSettle();

      final sendOtpBtn = find.widgetWithText(ElevatedButton, 'Send OTP');
      expect(sendOtpBtn, findsOneWidget);
      await tester.tap(sendOtpBtn);
      await tester.pumpAndSettle();

      expect(find.text('Please enter your mobile number'), findsWidgets);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Shows error on invalid 10-digit mobile number', (
      tester,
    ) async {
      await tester.pumpWidget(wrapWithApp(const UserLoginScreen()));
      await tester.pumpAndSettle();

      final mobileField = find.byType(TextField).first;
      await tester.enterText(mobileField, '12345');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Send OTP'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Enter a valid 10-digit Indian mobile number (e.g. 9876543210)',
        ),
        findsWidgets,
      );
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
