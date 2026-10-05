import 'package:flutter/material.dart';
import 'package:myshop/app/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/models/company.dart';
import 'package:myshop/core/models/customer.dart';
import 'package:myshop/core/models/order.dart';
import 'package:myshop/features/account/widgets/add_edit_address_dialog.dart';
import 'package:myshop/features/checkout/payment/widgets/address_selector.dart';
import 'package:myshop/features/checkout/payment/widgets/customer_details_card.dart';
import 'package:myshop/features/checkout/payment/widgets/delivery_widgets.dart';

import '../helpers/test_harness.dart';

/// U3 — reusable checkout widgets.
///
/// CustomerDetailsCard (read-only profile), AddressSelector (saved addresses,
/// max 3), DeliveryTypeSelector (per shop, from the shop model) and
/// PickupShopCard (self-pickup details), plus the shared address form.
void main() {
  setUp(TestHarness.setupPlatformChannels);

  Widget shell(Widget child) => MaterialApp(
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,

    theme: ThemeData.light(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  group('CustomerDetailsCard', () {
    testWidgets('renders the profile read-only when complete', (tester) async {
      await tester.pumpWidget(
        shell(
          const CustomerDetailsCard(
            name: 'Asha Shopper',
            email: 'asha@mail.com',
            mobile: '9876543210',
          ),
        ),
      );

      expect(find.text('Customer Details'), findsOneWidget);
      expect(find.byKey(const Key('customer-name')), findsOneWidget);
      expect(find.text('Asha Shopper'), findsOneWidget);
      expect(find.text('9876543210'), findsOneWidget);
      expect(find.text('asha@mail.com'), findsOneWidget);
      expect(find.byKey(const Key('customer-profile-warning')), findsNothing);
    });

    testWidgets('missing name or mobile shows the warning + Update Profile', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          const CustomerDetailsCard(
            name: '',
            email: 'asha@mail.com',
            mobile: '',
          ),
          user: TestHarness.shopper,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('customer-profile-warning')), findsOneWidget);
      expect(
        find.text(
          'Please complete your profile (name & mobile) before placing an order.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('update-profile-link')), findsOneWidget);
    });
  });

  group('AddressSelector', () {
    final home = TestHarness.homeAddress;
    final work = TestHarness.workAddress;

    testWidgets(
      'lists saved addresses as selectable cards with an add button',
      (tester) async {
        AddressEntry? selected;
        await tester.pumpWidget(
          shell(
            StatefulBuilder(
              builder: (context, setState) => AddressSelector(
                addresses: const [
                  TestHarness.homeAddress,
                  TestHarness.workAddress,
                ],
                selectedAddressId: selected?.id,
                onSelected: (a) => setState(() => selected = a),
                onEdit: (_) {},
                onAddNew: () {},
              ),
            ),
          ),
        );

        expect(find.byKey(Key('address-card-${home.id}')), findsOneWidget);
        expect(find.byKey(Key('address-card-${work.id}')), findsOneWidget);
        expect(find.text('2/3'), findsOneWidget, reason: 'capacity counter');
        expect(find.byKey(const Key('add-new-address')), findsOneWidget);

        await tester.tap(find.byKey(Key('address-card-${work.id}')));
        await tester.pumpAndSettle();
        expect(selected?.id, work.id);
      },
    );

    testWidgets('offers the empty state for a profile without addresses', (
      tester,
    ) async {
      await tester.pumpWidget(
        shell(
          AddressSelector(
            addresses: const [],
            selectedAddressId: null,
            onSelected: (_) {},
            onEdit: (_) {},
            onAddNew: () {},
          ),
        ),
      );

      expect(find.byKey(const Key('empty-address-state')), findsOneWidget);
      expect(find.byKey(const Key('add-address-empty')), findsOneWidget);
    });

    testWidgets('hides Add New Address at the three-address cap', (
      tester,
    ) async {
      final full = [
        TestHarness.homeAddress,
        TestHarness.workAddress,
        const AddressEntry(
          id: 'addr_3',
          name: 'Asha Shopper',
          phone: '9876543210',
          address: 'Lake View',
          city: 'Ahmedabad',
          state: 'Gujarat',
          pincode: '380015',
          label: 'Other',
        ),
      ];

      await tester.pumpWidget(
        shell(
          AddressSelector(
            addresses: full,
            selectedAddressId: full.first.id,
            onSelected: (_) {},
            onEdit: (_) {},
            onAddNew: () {},
          ),
        ),
      );

      expect(find.text('3/3'), findsOneWidget);
      expect(find.byKey(const Key('add-new-address')), findsNothing);
      expect(find.byKey(const Key('edit-address-addr_3')), findsOneWidget);
    });
  });

  group('DeliveryTypeSelector', () {
    const both = Company(
      id: 'c_both',
      name: 'GreenLeaf Organics',
      slug: 'c_both',
      deliveryTypes: ['self_pickup', 'home_delivery'],
    );
    const pickupOnly = Company(
      id: 'c_pickup',
      name: 'TechTronics Hub',
      slug: 'c_pickup',
      deliveryTypes: ['self_pickup'],
    );

    testWidgets('shows both options when the shop offers both', (tester) async {
      String value = DeliveryType.homeDelivery;
      await tester.pumpWidget(
        shell(
          StatefulBuilder(
            builder: (context, setState) => DeliveryTypeSelector(
              company: both,
              value: value,
              onChanged: (t) => setState(() => value = t),
            ),
          ),
        ),
      );

      expect(find.text('Home delivery'), findsOneWidget);
      expect(find.text('Self pickup'), findsOneWidget);
      expect(find.text('This shop does not offer home delivery'), findsNothing);
    });

    testWidgets('pickup-only shops explain themselves and auto-select pickup', (
      tester,
    ) async {
      String value = DeliveryType.homeDelivery; // stale choice from elsewhere
      await tester.pumpWidget(
        shell(
          StatefulBuilder(
            builder: (context, setState) => DeliveryTypeSelector(
              company: pickupOnly,
              value: value,
              onChanged: (t) => setState(() => value = t),
            ),
          ),
        ),
      );

      expect(find.text('Home delivery'), findsNothing);
      expect(find.text('Self pickup'), findsOneWidget);
      expect(
        find.text('This shop does not offer home delivery'),
        findsOneWidget,
      );

      final selector = tester.widget<SegmentedButton<String>>(
        find.byKey(const Key('delivery-type-selector')),
      );
      expect(selector.selected, {
        DeliveryType.selfPickup,
      }, reason: 'home is impossible -> self pickup is used');
    });

    testWidgets('tapping a segment reports the new type', (tester) async {
      String value = DeliveryType.homeDelivery;
      await tester.pumpWidget(
        shell(
          StatefulBuilder(
            builder: (context, setState) => DeliveryTypeSelector(
              company: both,
              value: value,
              onChanged: (t) => setState(() => value = t),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Self pickup'));
      await tester.pumpAndSettle();
      expect(value, DeliveryType.selfPickup);
    });
  });

  group('PickupShopCard', () {
    testWidgets('shows name, address, phone and timings', (tester) async {
      await tester.pumpWidget(
        shell(
          const PickupShopCard(
            shopName: 'GreenLeaf Organics',
            address: '12 Market Street, Ahmedabad',
            phone: '079 4000 1234',
            timings: 'Mon 09:00–20:00',
          ),
        ),
      );

      expect(find.byKey(const Key('pickup-shop-card')), findsOneWidget);
      expect(find.text('GreenLeaf Organics'), findsOneWidget);
      expect(find.text('12 Market Street, Ahmedabad'), findsOneWidget);
      expect(find.text('079 4000 1234'), findsOneWidget);
      expect(find.text('Mon 09:00–20:00'), findsOneWidget);
    });

    test('toSnapshot freezes the pickup details for the order', () {
      const card = PickupShopCard(
        shopName: 'GreenLeaf Organics',
        address: '12 Market Street',
        phone: '079 4000 1234',
        timings: 'Mon 09:00–20:00',
      );
      final snap = card.toSnapshot();
      expect(snap.name, 'GreenLeaf Organics');
      expect(snap.address, '12 Market Street');
      expect(snap.phone, '079 4000 1234');
      expect(snap.timings, 'Mon 09:00–20:00');
    });
  });

  group('Address form', () {
    setUp(() {
      TestHarness.bootServiceLocator();
      TestHarness.signIn(TestHarness.shopperWithAddresses);
    });

    tearDown(() => TestHarness.signOut());

    /// Pumps the app with the sheet opener and taps it open.
    Future<void> openSheet(WidgetTester tester) async {
      await pumpTestApp(
        tester,
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => AddEditAddressSheet.show(context),
            child: const Text('open'),
          ),
        ),
        user: TestHarness.shopperWithAddresses,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('empty submit reports phone and pincode problems', (
      tester,
    ) async {
      await openSheet(tester);

      expect(find.text('Add New Address'), findsOneWidget);
      expect(find.text('Save & Deliver Here'), findsOneWidget);

      await tester.tap(find.text('Save & Deliver Here'));
      await tester.pumpAndSettle();

      expect(find.text('Enter name'), findsOneWidget);
      expect(find.text('Enter phone'), findsOneWidget);
      expect(find.text('Enter pincode'), findsOneWidget);
      expect(find.text('Enter house/flat number'), findsOneWidget);
    });

    testWidgets('validates phone = 10 digits and pincode = 6 digits', (
      tester,
    ) async {
      await openSheet(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mobile Number *'),
        '123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Pincode *'),
        '38',
      );
      await tester.tap(find.text('Save & Deliver Here'));
      await tester.pumpAndSettle();

      expect(find.text('10 digits required'), findsOneWidget);
      expect(find.text('6 digits'), findsOneWidget);
    });

    testWidgets('a valid form saves the address with label and default flag', (
      tester,
    ) async {
      AddressEntry? result;
      await pumpTestApp(
        tester,
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await AddEditAddressSheet.show(context);
            },
            child: const Text('open'),
          ),
        ),
        user: TestHarness.shopperWithAddresses,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full Name *'),
        'Asha Shopper',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mobile Number *'),
        '9876543210',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Pincode *'),
        '380001',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'City *'),
        'Ahmedabad',
      );
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Address Line 1 (House / Flat / Block) *',
        ),
        '12 Market Street',
      );

      // Pick the "Work" label before saving.
      await tester.ensureVisible(find.text('Save Address As'));
      await tester.tap(find.text('Work'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save & Deliver Here'));
      await tester.pumpAndSettle();

      expect(result, isNotNull, reason: 'the sheet hands the entry back');
      expect(result!.name, 'Asha Shopper');
      expect(result!.phone, '9876543210');
      expect(result!.pincode, '380001');
      expect(result!.city, 'Ahmedabad');
      expect(result!.houseNo, '12 Market Street');
      expect(result!.label, 'Work');
      expect(result!.isDefault, isFalse);
    });
  });
}
