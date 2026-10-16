import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/models/customer.dart';
import 'package:myshop/features/account/widgets/add_edit_address_dialog.dart';
import 'package:myshop/features/checkout/payment/widgets/address_selector.dart';
import 'package:myshop/features/marketplace/widgets/location_picker_sheet.dart';

import '../helpers/test_harness.dart';

void main() {
  setUp(() {
    TestHarness.setupPlatformChannels();
    TestHarness.useMockRepository();
    TestHarness.signIn(TestHarness.shopper);
  });

  tearDown(() => TestHarness.signOut());

  group('Place order screen – Delivery address Add / Edit flow', () {
    testWidgets('Tapping add address on empty AddressSelector opens AddEditAddressSheet without error', (tester) async {
      bool addPressed = false;
      await pumpTestApp(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: AddressSelector(
              addresses: const [],
              selectedAddressId: null,
              onSelected: (_) {},
              onEdit: (_) {},
              onAddNew: () async {
                addPressed = true;
                await showAddressForm(context);
              },
            ),
          ),
        ),
        user: TestHarness.shopper,
      );

      // Verify empty state button is visible
      expect(find.byKey(const Key('add-address-empty')), findsOneWidget);

      // Tap add address
      await tester.tap(find.byKey(const Key('add-address-empty')));
      await tester.pumpAndSettle();

      expect(addPressed, isTrue);
      // Verify sheet opened cleanly
      expect(find.byType(AddEditAddressSheet), findsOneWidget);
      expect(find.text('Add New Address'), findsOneWidget);
    });

    testWidgets('Tapping add new address when addresses exist opens AddEditAddressSheet cleanly', (tester) async {
      bool addPressed = false;
      const existingAddr = AddressEntry(
        id: 'addr_1',
        name: 'John Doe',
        phone: '9876543210',
        houseNo: '101',
        address: 'MG Road',
        city: 'Ahmedabad',
        state: 'Gujarat',
        pincode: '380015',
        label: 'Home',
        isDefault: true,
      );

      await pumpTestApp(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: AddressSelector(
              addresses: const [existingAddr],
              selectedAddressId: 'addr_1',
              onSelected: (_) {},
              onEdit: (_) {},
              onAddNew: () async {
                addPressed = true;
                await showAddressForm(context);
              },
            ),
          ),
        ),
        user: TestHarness.shopper,
      );

      expect(find.byKey(const Key('add-new-address')), findsOneWidget);

      await tester.tap(find.byKey(const Key('add-new-address')));
      await tester.pumpAndSettle();

      expect(addPressed, isTrue);
      expect(find.byType(AddEditAddressSheet), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AddEditAddressSheet),
          matching: find.text('Add New Address'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Tapping edit address opens AddEditAddressSheet pre-filled', (tester) async {
      AddressEntry? edited;
      const existingAddr = AddressEntry(
        id: 'addr_1',
        name: 'John Doe',
        phone: '9876543210',
        houseNo: '101',
        address: 'MG Road',
        city: 'Ahmedabad',
        state: 'Gujarat',
        pincode: '380015',
        label: 'Home',
        isDefault: true,
      );

      await pumpTestApp(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: AddressSelector(
              addresses: const [existingAddr],
              selectedAddressId: 'addr_1',
              onSelected: (_) {},
              onEdit: (addr) async {
                edited = addr;
                await showAddressForm(context, initial: addr);
              },
              onAddNew: () {},
            ),
          ),
        ),
        user: TestHarness.shopper,
      );

      await tester.tap(find.byKey(const Key('edit-address-addr_1')));
      await tester.pumpAndSettle();

      expect(edited, equals(existingAddr));
      expect(find.byType(AddEditAddressSheet), findsOneWidget);
      expect(find.text('Edit Address'), findsOneWidget);
      expect(find.text('101'), findsOneWidget);
    });

    testWidgets('AddEditAddressSheet fills and saves address correctly', (tester) async {
      AddressEntry? savedResult;

      await pumpTestApp(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                savedResult = await AddEditAddressSheet.show(context);
              },
              child: const Text('Open Sheet'),
            ),
          ),
        ),
        user: TestHarness.shopper,
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.byType(AddEditAddressSheet), findsOneWidget);

      // Fill form
      await tester.enterText(find.widgetWithText(TextFormField, 'Full Name *'), 'Asha Patel');
      await tester.enterText(find.widgetWithText(TextFormField, 'Mobile Number *'), '9876543210');
      await tester.enterText(find.widgetWithText(TextFormField, 'Pincode *'), '380015');
      await tester.enterText(find.widgetWithText(TextFormField, 'City *'), 'Ahmedabad');
      await tester.ensureVisible(find.widgetWithText(TextFormField, 'Address Line 1 (House / Flat / Block) *'));
      await tester.enterText(find.widgetWithText(TextFormField, 'Address Line 1 (House / Flat / Block) *'), 'Flat 402, Shivalik High Street');
      await tester.ensureVisible(find.widgetWithText(TextFormField, 'Address Line 2 (Street / Area)'));
      await tester.enterText(find.widgetWithText(TextFormField, 'Address Line 2 (Street / Area)'), 'Near Keshavbaug Party Plot, Vastrapur');

      // Submit
      await tester.ensureVisible(find.text('Save & Deliver Here'));
      await tester.tap(find.text('Save & Deliver Here'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();

      // Sheet should pop and return the entry
      expect(savedResult, isNotNull);
      expect(savedResult!.name, 'Asha Patel');
      expect(savedResult!.phone, '9876543210');
      expect(savedResult!.pincode, '380015');
      expect(savedResult!.city, 'Ahmedabad');
    });

    testWidgets('LocationPickerSheet opening AddEditAddressSheet works cleanly', (tester) async {
      await pumpTestApp(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => LocationPickerSheet.show(context),
              child: const Text('Open Location Picker'),
            ),
          ),
        ),
        user: TestHarness.shopper,
      );

      await tester.tap(find.text('Open Location Picker'));
      await tester.pumpAndSettle();

      expect(find.byType(LocationPickerSheet), findsOneWidget);

      // Tap Add New Address
      await tester.tap(find.byKey(const Key('location-picker-add-address')));
      await tester.pumpAndSettle();

      expect(find.byType(AddEditAddressSheet), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AddEditAddressSheet),
          matching: find.text('Add New Address'),
        ),
        findsOneWidget,
      );
    });
  });
}
