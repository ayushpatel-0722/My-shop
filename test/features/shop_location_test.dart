import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/company.dart';
import 'package:myshop/core/models/review.dart';
import 'package:myshop/core/widgets/shop_map.dart';
import 'package:myshop/features/marketplace/company_store/company_store_screen.dart';

import '../helpers/test_harness.dart';

/// The shop's location, call and reviews on the shopper's store page, driven
/// by what the shop admin saved in Shop Settings.
void main() {
  late MockAppRepository repo;

  setUp(() {
    TestHarness.setupPlatformChannels();
    repo = TestHarness.useMockRepository();
    TestHarness.signIn(TestHarness.shopper);
  });

  tearDown(() => TestHarness.signOut());

  group('shopMapUrl', () {
    const base = Company(id: 'c', name: 'S', slug: 's');

    test('uses the Google Maps link the admin saved', () {
      expect(
        shopMapUrl(base.copyWith(location: ' https://maps.app.goo.gl/abc ')),
        'https://maps.app.goo.gl/abc',
      );
    });

    test('falls back to a Maps search of the address', () {
      final url = shopMapUrl(base.copyWith(address: '12 Market Street'))!;
      expect(url, startsWith('https://www.google.com/maps/search/'));
      expect(Uri.parse(url).queryParameters['query'], '12 Market Street');
    });

    test('a link that is not http(s) is ignored', () {
      final url = shopMapUrl(
        base.copyWith(location: 'maps.google.com/x', address: 'Road 5'),
      )!;
      expect(Uri.parse(url).queryParameters['query'], 'Road 5');
    });

    test('no link and no address means no map', () {
      expect(shopMapUrl(base), isNull);
    });
  });

  Future<void> setShop({
    String? phone,
    String? address,
    String? location,
  }) async {
    final c = (await repo.company('c_organic'))!;
    await repo.updateCompanyDetails(
      c.copyWith(phone: phone, address: address, location: location),
    );
  }

  Future<void> openStore(WidgetTester tester) async {
    await pumpTestApp(
      tester,
      const CompanyStoreScreen(slug: 'greenleaf-organics'),
      user: TestHarness.shopper,
      size: const Size(430, 6000),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows address with Directions, call, reviews and delivery', (
    tester,
  ) async {
    await setShop(phone: '+91 98765 43210');
    await openStore(tester);

    expect(find.byKey(const Key('store-info-card')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('store-address'))).data,
      '12 Market Street, Ahmedabad',
    );
    expect(find.byKey(const Key('store-directions-button')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('store-phone-number'))).data,
      '+91 98765 43210',
    );
    expect(find.text('Call shop'), findsOneWidget);
    expect(
      find.text('See all reviews'),
      findsNothing,
      reason: 'under 5 reviews',
    );
    // Delivery info stays on the page.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Icon &&
            (w.icon == Icons.local_shipping_outlined ||
                w.icon == Icons.storefront_outlined),
      ),
      findsWidgets,
    );
  });

  testWidgets(
    'Directions goes to the admin\'s map link (copied if it cannot open)',
    (tester) async {
      await setShop(location: 'https://maps.app.goo.gl/greenleaf');
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await openStore(tester);

      await tester.tap(find.byKey(const Key('store-location-row')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();

      expect(copied, 'https://maps.app.goo.gl/greenleaf');
      expect(find.text('Map link copied'), findsOneWidget);
    },
  );

  testWidgets('without a map link the address is shown with a search link', (
    tester,
  ) async {
    await setShop(location: '');
    await openStore(tester);
    expect(find.byKey(const Key('store-directions-button')), findsOneWidget);
  });

  testWidgets('no address and no link: no location row', (tester) async {
    await setShop(location: '', address: '');
    await openStore(tester);
    expect(find.byKey(const Key('store-location-row')), findsNothing);
    expect(find.byKey(const Key('store-info-card')), findsOneWidget);
  });

  testWidgets('no phone: no call row', (tester) async {
    await openStore(tester);
    expect(find.byKey(const Key('store-phone-row')), findsNothing);
  });

  testWidgets('the reviews row appears with five reviews and opens them', (
    tester,
  ) async {
    for (var i = 0; i < 4; i++) {
      await repo.submitReview(
        Review(
          id: 'x$i',
          orderId: 'xo$i',
          userId: 'xu$i',
          companyId: 'c_organic',
          rating: 5,
        ),
      );
    }
    await openStore(tester);
    expect(find.text('See all reviews'), findsOneWidget);
    await tester.tap(find.byKey(const Key('store-reviews-row')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('store-reviews-row')), findsNothing);
  });

  testWidgets('a shop with few reviews shows no review text at all', (
    tester,
  ) async {
    await openStore(tester);
    expect(find.text('No reviews yet'), findsNothing);
    expect(find.byKey(const Key('store-reviews-row')), findsNothing);
  });
}
