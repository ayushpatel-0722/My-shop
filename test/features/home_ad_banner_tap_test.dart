import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/banner.dart';
import 'package:myshop/features/marketplace/home/home_screen.dart';

import '../helpers/test_harness.dart';

/// A tap on a home-screen ads banner follows its tap action.
void main() {
  late MockAppRepository repo;
  final launched = <Uri>[];

  setUp(() {
    TestHarness.setupPlatformChannels();
    repo = TestHarness.useMockRepository();
    launched.clear();
    HomeScreen.adLinkLauncher = (uri) async {
      launched.add(uri);
      return true;
    };
  });

  Future<void> openHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      buildTestApp(
        const HomeScreen(shopId: 'c_organic'),
        user: TestHarness.shopper,
        size: const Size(390, 900),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets(
    'shows only the shop\'s saved banners and opens an external link',
    (tester) async {
      await repo.saveAdBanner(
        const AdBanner(
          id: 'ext',
          image: '',
          actionType: BannerActionType.externalUrl,
          actionTarget: 'example.com/sale',
          shopId: 'c_organic',
        ),
      );
      await repo.saveAdBanner(
        const AdBanner(id: 'other', image: '', shopId: 'c_techtronics'),
      );
      await openHome(tester);

      expect(find.byKey(const Key('ad-banner-other')), findsNothing);
      await tester.tap(find.byKey(const Key('ad-banner-ext')));
      await tester.pump();
      expect(launched.single.toString(), 'https://example.com/sale');
    },
  );

  testWidgets('a banner without a target does nothing', (tester) async {
    await repo.saveAdBanner(
      const AdBanner(
        id: 'plain',
        image: '',
        actionType: BannerActionType.externalUrl,
        shopId: 'c_organic',
      ),
    );
    await openHome(tester);
    await tester.tap(find.byKey(const Key('ad-banner-plain')));
    await tester.pump();
    expect(launched, isEmpty);
  });
}
