import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/app/l10n/app_localizations.dart';
import 'package:myshop/core/services/auth_session.dart';
import 'package:myshop/features/auth/auth_cubit.dart';
import 'package:myshop/features/company_onboarding/company_onboarding_screen.dart';

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

  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> navigateToStep2(WidgetTester tester) async {
    // Fill Step 0
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
      '123 Main St',
    );
    await tester.pumpAndSettle();

    // Step 0 -> Step 1
    await tester.tap(find.byKey(const Key('onboarding_next_button')));
    await tester.pumpAndSettle();

    // Step 1 -> Step 2
    await tester.tap(find.byKey(const Key('onboarding_next_button')));
    await tester.pumpAndSettle();
  }

  group('CompanyOnboardingScreen Validation Tests', () {
    testWidgets(
      'Step 0 shows error for all required fields when Next is tapped with empty inputs',
      (tester) async {
        configureViewport(tester);
        await tester.pumpWidget(wrapWithApp(const CompanyOnboardingScreen()));
        await tester.pumpAndSettle();

        // Tap Next button with empty inputs
        final nextButton = find.byKey(const Key('onboarding_next_button'));
        expect(nextButton, findsOneWidget);
        await tester.tap(nextButton);
        await tester.pumpAndSettle();

        // Verify all Step 0 error texts are displayed
        expect(find.text('Company name is required'), findsOneWidget);
        expect(find.text('Store category is required'), findsOneWidget);
        expect(
          find.text('Company subtitle/details are required'),
          findsOneWidget,
        );
        expect(find.text('Address is required'), findsOneWidget);

        // Verify snackbar
        expect(
          find.text('Please fill in all required company fields'),
          findsOneWidget,
        );
      },
    );

    testWidgets('Step 0 error messages clear when user types into the fields', (
      tester,
    ) async {
      configureViewport(tester);
      await tester.pumpWidget(wrapWithApp(const CompanyOnboardingScreen()));
      await tester.pumpAndSettle();

      // Trigger errors
      await tester.tap(find.byKey(const Key('onboarding_next_button')));
      await tester.pumpAndSettle();

      expect(find.text('Company name is required'), findsOneWidget);

      // Type into Company Name field
      await tester.enterText(
        find.byKey(const Key('company_name_field')),
        'Test Cafe',
      );
      await tester.pumpAndSettle();

      expect(find.text('Company name is required'), findsNothing);
    });

    testWidgets('Step 2 requires at least one delivery option', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(wrapWithApp(const CompanyOnboardingScreen()));
      await tester.pumpAndSettle();

      await navigateToStep2(tester);

      // Uncheck both delivery options in Step 2
      final selfPickupTile = find.byKey(const Key('delivery_self_pickup_tile'));
      final homeDeliveryTile = find.byKey(
        const Key('delivery_home_delivery_tile'),
      );

      await tester.tap(selfPickupTile);
      await tester.tap(homeDeliveryTile);
      await tester.pumpAndSettle();

      // Try tapping Save
      await tester.tap(find.byKey(const Key('onboarding_save_button')));
      await tester.pumpAndSettle();

      expect(
        find.text('Please select at least one delivery option'),
        findsOneWidget,
      );
    });

    testWidgets(
      'Step 2 validates all required fields including admin mobile number',
      (tester) async {
        configureViewport(tester);
        await tester.pumpWidget(wrapWithApp(const CompanyOnboardingScreen()));
        await tester.pumpAndSettle();

        await navigateToStep2(tester);

        // Tap Save button with empty inputs
        final saveBtn = find.byKey(const Key('onboarding_save_button'));
        expect(saveBtn, findsOneWidget);
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        // Verify all required error messages on Step 2
        expect(find.text('Company password is required'), findsOneWidget);
        expect(find.text('Company logo URL is required'), findsOneWidget);
        expect(find.text('Company banner URL is required'), findsOneWidget);
        expect(
          find.text('Storefront profile image URL is required'),
          findsOneWidget,
        );
        expect(find.text('Admin name is required'), findsOneWidget);
        expect(find.text('Admin email is required'), findsOneWidget);
        expect(find.text('Admin mobile number is required'), findsOneWidget);
        expect(find.text('Admin password is required'), findsOneWidget);
        expect(find.text('Please confirm your password'), findsOneWidget);
        expect(
          find.text('Please fill in all required fields correctly'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Step 2 validates email, mobile number format, password match, and URL',
      (tester) async {
        configureViewport(tester);
        await tester.pumpWidget(wrapWithApp(const CompanyOnboardingScreen()));
        await tester.pumpAndSettle();

        await navigateToStep2(tester);

        // Enter invalid values
        await tester.enterText(
          find.byKey(const Key('company_password_field')),
          '123456',
        );
        await tester.enterText(
          find.byKey(const Key('company_logo_url_field')),
          'invalid-url',
        );
        await tester.enterText(
          find.byKey(const Key('company_banner_url_field')),
          'invalid-url',
        );
        await tester.enterText(
          find.byKey(const Key('company_profile_image_url_field')),
          'invalid-url',
        );
        await tester.enterText(
          find.byKey(const Key('admin_name_field')),
          'John Admin',
        );
        await tester.enterText(
          find.byKey(const Key('admin_email_field')),
          'invalid-email',
        );
        await tester.enterText(
          find.byKey(const Key('admin_mobile_field')),
          '12345',
        );
        await tester.enterText(
          find.byKey(const Key('admin_password_field')),
          '123456',
        );
        await tester.enterText(
          find.byKey(const Key('admin_password_confirm_field')),
          '654321',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('onboarding_save_button')));
        await tester.pumpAndSettle();

        expect(
          find.text('Please enter a valid HTTP or HTTPS URL'),
          findsWidgets,
        );
        expect(find.text('Please enter a valid email address'), findsOneWidget);
        expect(
          find.text('Please enter a valid 10-digit mobile number'),
          findsOneWidget,
        );
        expect(find.text('Passwords do not match'), findsOneWidget);

        // Verify that typing valid values clears the errors
        await tester.enterText(
          find.byKey(const Key('admin_mobile_field')),
          '9876543210',
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Please enter a valid 10-digit mobile number'),
          findsNothing,
        );

        await tester.enterText(
          find.byKey(const Key('admin_email_field')),
          'admin@test.com',
        );
        await tester.pumpAndSettle();
        expect(find.text('Please enter a valid email address'), findsNothing);
      },
    );
  });
}
