import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/features/account/account_screen.dart';
import 'package:myshop/features/help_support/contact_support_screen.dart';
import 'package:myshop/features/help_support/help_support_screen.dart';
import 'package:myshop/features/help_support/models/faq_item.dart';

import '../helpers/test_harness.dart';

void main() {
  setUp(() {
    TestHarness.setupPlatformChannels();
    TestHarness.useMockRepository();
  });

  group('HelpSupportScreen and FAQ Accordion', () {
    testWidgets('renders search, categories, and expandable FAQ cards', (
      tester,
    ) async {
      await pumpTestApp(
        tester,
        const HelpSupportScreen(),
        user: TestHarness.shopper,
      );

      // Verify header and Help button
      expect(find.text('Help & Support'), findsOneWidget);
      expect(find.text('Help'), findsOneWidget);

      // Verify category chips
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Orders & Tracking'), findsOneWidget);

      // Verify first FAQ question is displayed
      final firstFaq = defaultFaqs.first;
      expect(find.text(firstFaq.question), findsOneWidget);

      // Tap to expand accordion
      await tester.tap(find.text(firstFaq.question));
      await tester.pumpAndSettle();

      // Verify answer is visible after expansion
      expect(find.text(firstFaq.answer), findsOneWidget);
    });

    testWidgets('filtering FAQs by search query updates list', (tester) async {
      await pumpTestApp(
        tester,
        const HelpSupportScreen(),
        user: TestHarness.shopper,
      );

      // Enter search term
      await tester.enterText(find.byType(TextField), 'refund');
      await tester.pumpAndSettle();

      // Verify matching FAQs appear
      expect(find.textContaining('refund', findRichText: true), findsWidgets);
    });
  });

  group('ContactSupportScreen', () {
    testWidgets('validates required fields and submits support query', (
      tester,
    ) async {
      await pumpTestApp(
        tester,
        const ContactSupportScreen(),
        user: TestHarness.shopper,
      );

      expect(find.text('Contact Support'), findsOneWidget);
      expect(find.text('Submit Query & Send Email'), findsOneWidget);

      // Tap submit without filling required fields
      await tester.tap(find.text('Submit Query & Send Email'));
      await tester.pumpAndSettle();

      // Verify validation prompts
      expect(find.text('Please enter a summary'), findsOneWidget);

      // Enter subject and message into text fields
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(3), 'shopper@example.com'); // email
      await tester.enterText(
        fields.at(4),
        '123 Market St, Ahmedabad',
      ); // address
      await tester.enterText(fields.at(5), 'Order Payment Issue'); // subject
      await tester.enterText(
        fields.at(6),
        'My payment was debited but order shows pending',
      ); // message
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text('Submit Query & Send Email'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Success dialog should show
      expect(find.text('Query Submitted & Email Sent!'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });
  });

  group('AccountScreen Role Visibility', () {
    testWidgets('hides Portals & Admin section for shopper (user role)', (
      tester,
    ) async {
      await pumpTestApp(
        tester,
        const AccountScreen(),
        user: TestHarness.shopper,
      );

      // Shopper should not see Portals & Admin
      expect(find.text('Portals & Admin'), findsNothing);
      expect(find.text('Admin Dashboard'), findsNothing);
      expect(find.text('Employee Portal'), findsNothing);

      // Help & Support tile is present
      expect(find.text('Help & Support'), findsOneWidget);
    });

    testWidgets('shows Portals & Admin section for admin role', (tester) async {
      await pumpTestApp(tester, const AccountScreen(), user: TestHarness.admin);

      // Admin should see Portals & Admin
      expect(find.text('Portals & Admin'), findsOneWidget);
      expect(find.text('Admin Dashboard'), findsOneWidget);
    });
  });
}
