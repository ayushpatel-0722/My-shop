import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myshop/app/routes/app_router.dart';
import 'package:myshop/features/account/account_screen.dart';

import '../helpers/test_harness.dart';

void main() {
  setUp(() {
    TestHarness.setupPlatformChannels();
    TestHarness.useMockRepository();
  });
  tearDown(TestHarness.signOut);

  Future<void> pumpAccount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      buildTestApp(
        const AccountScreen(),
        user: TestHarness.shopper,
        extraRoutes: [
          GoRoute(
            path: AppRoutes.role,
            builder: (_, _) => const Scaffold(body: Text('Role screen')),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Switch role asks, signs out and opens the role screen', (
    tester,
  ) async {
    TestHarness.signIn(TestHarness.shopper);
    await pumpAccount(tester);
    final tile = find.byKey(const Key('switch-role-tile'));
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('switch-role-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Role screen'), findsOneWidget);
  });
}
