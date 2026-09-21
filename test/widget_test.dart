import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myshop/app/routes/app_router.dart';
import 'package:myshop/core/services/auth_session.dart';
import 'package:myshop/core/services/service_locator.dart';
import 'package:myshop/main.dart';

void main() {
  setUp(() {
    AuthSession.set(null, restoring: false);
    AuthSession.hasCompletedInitialBoot = true;
  });

  testWidgets('app builds without crashing', (WidgetTester tester) async {
    ServiceLocator.instance.init(firebaseReady: false);

    await tester.pumpWidget(const Bootstrap(firebaseReady: false));
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
  });

  test('guest users are redirected away from cart and orders routes', () {
    expect(appRouteRedirect(AppRoutes.cart), AppRoutes.userLogin);
    expect(appRouteRedirect(AppRoutes.orders), AppRoutes.userLogin);
    expect(appRouteRedirect(AppRoutes.checkout), AppRoutes.userLogin);
  });
}
