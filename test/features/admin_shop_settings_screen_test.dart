import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/company.dart';
import 'package:myshop/features/admin/shop/admin_shop_settings_screen.dart';

import '../helpers/test_harness.dart';

const _week = [
  WeeklyHours(day: 'Mon', openTime: '09:00', closeTime: '21:00'),
  WeeklyHours(day: 'Tue', openTime: '09:00', closeTime: '21:00'),
  WeeklyHours(day: 'Wed', openTime: '09:00', closeTime: '21:00'),
  WeeklyHours(day: 'Thu', openTime: '09:00', closeTime: '21:00'),
  WeeklyHours(day: 'Fri', openTime: '09:00', closeTime: '22:00'),
  WeeklyHours(day: 'Sat', openTime: '10:00', closeTime: '22:00'),
  WeeklyHours(
    day: 'Sun',
    openTime: '00:00',
    closeTime: '00:00',
    isClosed: true,
  ),
];

const _company = Company(
  id: 'c_shop',
  name: 'Woodnest Living',
  slug: 'woodnest-living',
  companyPassword: 'secret-pass',
  details: 'Old description',
  address: 'Old address, Ahmedabad',
  category: 'Furniture',
  logoUrl: 'https://img.example.com/logo.jpg',
  weeklyHours: _week,
  minOrderAmount: 2000,
);

void main() {
  late MockAppRepository repo;

  setUp(() async {
    TestHarness.setupPlatformChannels();
    repo = TestHarness.useMockRepository();
    await repo.createCompany(_company);
    TestHarness.signIn(TestHarness.admin.copyWith(companyId: 'c_shop'));
  });

  tearDown(() => TestHarness.signOut());

  Future<void> open(WidgetTester tester) =>
      pumpTestApp(tester, const AdminShopSettingsScreen());

  Finder field(String key) => find.byKey(Key(key));

  Future<void> enter(WidgetTester tester, String key, String text) async {
    final f = field(key);
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.enterText(f, text);
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = field(key);
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<Company> saved() async => (await repo.company('c_shop'))!;

  bool saveEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(field('shop-save-button')).onPressed != null;

  String statusText(WidgetTester tester) =>
      tester.widget<Text>(field('shop-save-status')).data!;

  testWidgets('shows the shop as it is saved today', (tester) async {
    await open(tester);

    expect(find.text('Old description'), findsOneWidget);
    expect(find.text('Old address, Ahmedabad'), findsOneWidget);
    expect(find.text('Furniture'), findsOneWidget);
    expect(find.text('Woodnest Living'), findsWidgets);
    expect(find.text('2000'), findsOneWidget, reason: 'minimum order');
    expect(find.text('45'), findsOneWidget, reason: 'packing minutes');
    expect(find.text('30'), findsOneWidget, reason: 'delivery minutes');
    expect(tester.widget<Chip>(field('shop-status-chip')).label, isA<Text>());
    expect(field('shop-open-now-chip'), findsOneWidget);
    expect(find.text('INR (₹)'), findsOneWidget);

    // Nothing to save yet.
    expect(saveEnabled(tester), isFalse);
    expect(statusText(tester), 'All changes saved');
    // The shop name (admin login) cannot be edited.
    expect(
      tester.widget<TextFormField>(field('shop-name-field')).enabled,
      isFalse,
    );
  });

  testWidgets('editing details enables Save and saves them', (tester) async {
    await open(tester);
    await enter(tester, 'shop-details-field', 'Handcrafted furniture.');
    await enter(tester, 'shop-phone-field', '+91 98765 43210');
    await enter(tester, 'shop-map-field', 'https://maps.example.com/shop');
    await enter(tester, 'shop-min-order-field', '2500');

    expect(saveEnabled(tester), isTrue);
    expect(statusText(tester), 'You have unsaved changes');

    await tester.tap(field('shop-save-button'));
    await tester.pumpAndSettle();

    final c = await saved();
    expect(c.details, 'Handcrafted furniture.');
    expect(c.phone, '+91 98765 43210');
    expect(c.location, 'https://maps.example.com/shop');
    expect(c.minOrderAmount, 2500);
    // Protected fields are untouched.
    expect(c.name, 'Woodnest Living');
    expect(c.companyPassword, 'secret-pass');
    expect(c.slug, 'woodnest-living');

    expect(find.text('Shop details saved.'), findsOneWidget);
    expect(saveEnabled(tester), isFalse);
    expect(statusText(tester), 'All changes saved');
  });

  testWidgets('Discard puts the saved values back', (tester) async {
    await open(tester);
    await enter(tester, 'shop-details-field', 'Something else');
    expect(saveEnabled(tester), isTrue);

    await tester.tap(field('shop-discard-button'));
    await tester.pumpAndSettle();

    expect(find.text('Old description'), findsOneWidget);
    expect(find.text('Something else'), findsNothing);
    expect(saveEnabled(tester), isFalse);
    expect((await saved()).details, 'Old description');
  });

  group('opening hours', () {
    testWidgets('re-opening Sunday gives sensible hours and saves', (
      tester,
    ) async {
      await open(tester);
      expect(field('shop-day-open-6'), findsNothing, reason: 'Sunday closed');
      expect(find.text('Closed'), findsOneWidget);

      await tapKey(tester, 'shop-day-switch-6');
      expect(field('shop-day-open-6'), findsOneWidget);
      expect(
        tester.widget<OutlinedButton>(field('shop-day-open-6')).child,
        isA<Text>().having((t) => t.data, 'text', '09:00'),
      );

      await tester.tap(field('shop-save-button'));
      await tester.pumpAndSettle();
      final sunday = (await saved()).weeklyHours[6];
      expect(sunday.isClosed, isFalse);
      expect([sunday.openTime, sunday.closeTime], ['09:00', '21:00']);
    });

    testWidgets('closing a day is saved', (tester) async {
      await open(tester);
      await tapKey(tester, 'shop-day-switch-0'); // Monday off
      await tester.tap(field('shop-save-button'));
      await tester.pumpAndSettle();
      expect((await saved()).weeklyHours[0].isClosed, isTrue);
    });

    testWidgets('"apply Monday hours to every day" copies them', (
      tester,
    ) async {
      await open(tester);
      await tapKey(tester, 'shop-copy-hours');
      await tester.tap(field('shop-save-button'));
      await tester.pumpAndSettle();

      for (final d in (await saved()).weeklyHours) {
        expect(
          [d.openTime, d.closeTime, d.isClosed],
          ['09:00', '21:00', false],
        );
      }
    });

    testWidgets('a shop cannot close every day', (tester) async {
      await open(tester);
      await tapKey(tester, 'shop-day-switch-0'); // Mon off; Sun already off
      await tapKey(tester, 'shop-copy-hours'); // everything now closed
      await tester.tap(field('shop-save-button'));
      await tester.pumpAndSettle();

      expect(find.text('Keep at least one day open.'), findsOneWidget);
      expect((await saved()).weeklyHours.any((d) => !d.isClosed), isTrue);
    });
  });

  group('delivery', () {
    testWidgets('options and numbers are saved', (tester) async {
      await open(tester);
      await tapKey(tester, 'shop-delivery-home'); // turn home delivery off
      await enter(tester, 'shop-handling-field', '60');
      await enter(tester, 'shop-delivery-minutes-field', '120');
      await tester.tap(field('shop-save-button'));
      await tester.pumpAndSettle();

      final c = await saved();
      expect(c.deliveryTypes, ['self_pickup']);
      expect(c.handlingMinutes, 60);
      expect(c.deliveryMinutes, 120);
    });

    testWidgets('at least one option is required', (tester) async {
      await open(tester);
      await tapKey(tester, 'shop-delivery-pickup');
      await tapKey(tester, 'shop-delivery-home');
      expect(field('shop-delivery-error'), findsOneWidget);

      await tester.tap(field('shop-save-button'));
      await tester.pumpAndSettle();
      expect(find.text('Choose at least one delivery option.'), findsWidgets);
      expect((await saved()).deliveryTypes, isNotEmpty);
    });
  });

  group('validation blocks saving', () {
    Future<void> expectRejected(
      WidgetTester tester, {
      required String key,
      required String text,
      required String message,
    }) async {
      await open(tester);
      await enter(tester, key, text);
      await tester.tap(field('shop-save-button'));
      await tester.pumpAndSettle();
      expect(find.text(message), findsWidgets, reason: message);
      expect(await saved(), isA<Company>());
      expect(
        (await saved()).toEditableMap(),
        _company.toEditableMap(),
        reason: 'nothing was written',
      );
    }

    testWidgets(
      'empty description',
      (tester) => expectRejected(
        tester,
        key: 'shop-details-field',
        text: '   ',
        message: 'Add a short description of your shop',
      ),
    );

    testWidgets(
      'empty address',
      (tester) => expectRejected(
        tester,
        key: 'shop-address-field',
        text: '',
        message: 'Address is required',
      ),
    );

    testWidgets(
      'bad phone number',
      (tester) => expectRejected(
        tester,
        key: 'shop-phone-field',
        text: 'call me',
        message: 'Use digits, spaces, + or - only',
      ),
    );

    testWidgets(
      'phone number that is too short',
      (tester) => expectRejected(
        tester,
        key: 'shop-phone-field',
        text: '12345',
        message: 'Enter a valid phone number',
      ),
    );

    testWidgets(
      'map link that is not a link',
      (tester) => expectRejected(
        tester,
        key: 'shop-map-field',
        text: 'near the station',
        message: 'The map link must start with http:// or https://',
      ),
    );

    testWidgets(
      'image link that is not a link',
      (tester) => expectRejected(
        tester,
        key: 'shop-banner-field',
        text: 'banner.png',
        message: 'The Banner link must start with http:// or https://',
      ),
    );

    testWidgets(
      'negative minimum order',
      (tester) => expectRejected(
        tester,
        key: 'shop-min-order-field',
        text: '-5',
        message: 'Enter 0 or a positive amount',
      ),
    );

    testWidgets(
      'packing time of zero',
      (tester) => expectRejected(
        tester,
        key: 'shop-handling-field',
        text: '0',
        message: '1 - 1440 minutes',
      ),
    );
  });

  testWidgets('a saved image link shows a preview that opens full screen', (
    tester,
  ) async {
    await open(tester);
    await tapKey(tester, 'shop-logo-preview');
    expect(find.byKey(const Key('fullscreen-image-viewer')), findsOneWidget);
    await tester.tap(find.byKey(const Key('fullscreen-image-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fullscreen-image-viewer')), findsNothing);
  });

  testWidgets('an empty image field has no tappable preview', (tester) async {
    await open(tester);
    await tapKey(tester, 'shop-banner-preview'); // banner is empty
    expect(find.byKey(const Key('fullscreen-image-viewer')), findsNothing);
  });

  testWidgets('an account with no shop shows a clear message', (tester) async {
    TestHarness.signIn(TestHarness.admin.copyWith(companyId: ''));
    await open(tester);
    expect(find.text('No shop is linked to this account.'), findsOneWidget);
    expect(field('shop-save-button'), findsNothing);
  });

  group('time pickers', () {
    /// Opens the picker behind [key], types [hour]:[minute] (12-hour clock;
    /// the AM/PM that was preselected is kept unless [pm] is given) and taps OK.
    Future<void> pickTime(
      WidgetTester tester,
      String key, {
      required String hour,
      required String minute,
      bool? pm,
      bool confirm = true,
    }) async {
      await tapKey(tester, key);
      expect(find.byType(TimePickerDialog), findsOneWidget);
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();
      final inputs = find.descendant(
        of: find.byType(TimePickerDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(inputs.at(0), hour);
      await tester.enterText(inputs.at(1), minute);
      if (pm != null) {
        await tester.tap(find.text(pm ? 'PM' : 'AM'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text(confirm ? 'OK' : 'Cancel'));
      await tester.pumpAndSettle();
    }

    String label(WidgetTester tester, String key) =>
        ((tester.widget<OutlinedButton>(field(key)).child) as Text).data!;

    testWidgets('choosing an opening and closing time saves them', (
      tester,
    ) async {
      await open(tester);
      await pickTime(tester, 'shop-day-open-0', hour: '10', minute: '30');
      await pickTime(tester, 'shop-day-close-0', hour: '8', minute: '45');
      expect(label(tester, 'shop-day-open-0'), '10:30');
      expect(label(tester, 'shop-day-close-0'), '20:45');
      expect(saveEnabled(tester), isTrue);

      await tester.tap(field('shop-save-button'));
      await tester.pumpAndSettle();
      final monday = (await saved()).weeklyHours[0];
      expect([monday.openTime, monday.closeTime], ['10:30', '20:45']);
      // Other days are untouched.
      expect((await saved()).weeklyHours[1].openTime, '09:00');
    });

    testWidgets('cancelling the picker changes nothing', (tester) async {
      await open(tester);
      await pickTime(
        tester,
        'shop-day-open-0',
        hour: '11',
        minute: '15',
        confirm: false,
      );
      expect(label(tester, 'shop-day-open-0'), '09:00');
      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('a closing time before opening is an overnight shift', (
      tester,
    ) async {
      await open(tester);
      expect(field('shop-day-overnight-0'), findsNothing);
      // 8:30 AM close with a 9:00 AM open: closes the next morning.
      await pickTime(
        tester,
        'shop-day-close-0',
        hour: '8',
        minute: '30',
        pm: false,
      );
      expect(label(tester, 'shop-day-close-0'), '08:30');
      expect(field('shop-day-overnight-0'), findsOneWidget);
      expect(find.text('closes next day'), findsOneWidget);

      await tester.tap(field('shop-save-button'));
      await tester.pumpAndSettle();
      expect((await saved()).weeklyHours[0].closeTime, '08:30');
      expect(find.text('Shop details saved.'), findsOneWidget);
    });

    testWidgets('the same opening and closing time blocks saving', (
      tester,
    ) async {
      await open(tester);
      // 9:00 AM close with a 9:00 AM open.
      await pickTime(
        tester,
        'shop-day-close-0',
        hour: '9',
        minute: '00',
        pm: false,
      );
      await tester.tap(field('shop-save-button'));
      await tester.pumpAndSettle();
      expect(
        find.text('Mon: opening and closing time cannot be the same.'),
        findsOneWidget,
      );
      expect((await saved()).weeklyHours[0].closeTime, '21:00');
    });
  });

  group('open 24 hours', () {
    testWidgets('the chip hides the times and saves 00:00 to 00:00', (
      tester,
    ) async {
      await open(tester);
      expect(field('shop-day-open-0'), findsOneWidget);

      await tapKey(tester, 'shop-day-24h-0');
      expect(field('shop-day-open-0'), findsNothing);
      expect(field('shop-day-close-0'), findsNothing);
      expect(
        tester.widget<FilterChip>(field('shop-day-24h-0')).selected,
        isTrue,
      );

      await tester.tap(field('shop-save-button'));
      await tester.pumpAndSettle();
      final monday = (await saved()).weeklyHours[0];
      expect(
        [monday.openTime, monday.closeTime, monday.isClosed],
        ['00:00', '00:00', false],
      );
      expect(find.text('Shop details saved.'), findsOneWidget);
    });

    testWidgets('turning it off puts normal hours back', (tester) async {
      await open(tester);
      await tapKey(tester, 'shop-day-24h-0');
      await tapKey(tester, 'shop-day-24h-0');
      expect(field('shop-day-open-0'), findsOneWidget);
      expect(
        ((tester.widget<OutlinedButton>(field('shop-day-open-0')).child)
                as Text)
            .data,
        '09:00',
      );
    });

    testWidgets('an all-day shop shows as open now', (tester) async {
      await open(tester);
      // Make every day open 24 hours.
      await tapKey(tester, 'shop-day-24h-0');
      await tapKey(tester, 'shop-copy-hours');
      expect(find.text('Open now'), findsOneWidget);
    });
  });

  group('translations', () {
    Future<void> openIn(WidgetTester tester, String code) => pumpTestApp(
      tester,
      Builder(
        builder: (context) => Localizations.override(
          context: context,
          locale: Locale(code),
          child: const AdminShopSettingsScreen(),
        ),
      ),
    );

    testWidgets('Hindi', (tester) async {
      await openIn(tester, 'hi');
      expect(find.text('दुकान सेटिंग्स'), findsWidgets);
      expect(find.text('दुकान का विवरण'), findsOneWidget);
      expect(find.text('खुलने का समय'), findsOneWidget);
      expect(find.text('डिलीवरी और ऑर्डर'), findsOneWidget);
      expect(find.text('ब्रांडिंग चित्र'), findsOneWidget);
      expect(find.text('सभी बदलाव सहेजे गए'), findsOneWidget);
      expect(find.text('बदलाव सहेजें'), findsOneWidget);
      expect(find.text('Save changes'), findsNothing);
      expect(find.text('Opening hours'), findsNothing);
    });

    testWidgets('Gujarati', (tester) async {
      await openIn(tester, 'gu');
      expect(find.text('દુકાન સેટિંગ્સ'), findsWidgets);
      expect(find.text('દુકાનની વિગતો'), findsOneWidget);
      expect(find.text('ખુલવાનો સમય'), findsOneWidget);
      expect(find.text('ડિલિવરી અને ઓર્ડર'), findsOneWidget);
      expect(find.text('બધા ફેરફારો સાચવાયા'), findsOneWidget);
      expect(find.text('ફેરફારો સાચવો'), findsOneWidget);
      expect(find.text('Save changes'), findsNothing);
    });

    testWidgets('validation messages are translated too', (tester) async {
      await openIn(tester, 'hi');
      await enter(tester, 'shop-phone-field', 'call me');
      await tester.tap(field('shop-save-button'));
      await tester.pumpAndSettle();
      expect(
        find.text('केवल अंक, स्पेस, + या - का उपयोग करें'),
        findsOneWidget,
      );
      expect(find.text('Use digits, spaces, + or - only'), findsNothing);
    });
  });
}
