import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/app/l10n/app_localizations.dart';
import 'package:myshop/app/theme/app_theme.dart';
import 'package:myshop/core/models/app_user.dart';
import 'package:myshop/core/services/auth_session.dart';
import 'package:myshop/core/services/service_locator.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/widgets/app_product_image.dart';
import 'package:myshop/features/admin/dashboard/admin_dashboard_screen.dart';

void main() {
  setUp(() {
    ServiceLocator.instance.repository = MockAppRepository();
    AuthSession.currentUser = AppUser(
      id: 'admin_test',
      companyId: 'masala-mart',
      companyName: 'Masala Mart',
      name: 'Admin Test',
      email: 'admin@masalamart.in',
      role: 'admin',
    );
  });

  testWidgets(
    'Admin Dashboard Store Modules render vertically with icon on top and title below',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: AppTheme.light(),
          home: const AdminDashboardScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify 'Store Modules' header is rendered
      expect(find.text('Store Modules'), findsOneWidget);

      // Verify key modules are present
      expect(find.text('Orders Pipeline'), findsOneWidget);
      expect(find.text('Products'), findsOneWidget);
      expect(find.text('Categories'), findsOneWidget);
      expect(find.text('Home Explore Categories'), findsOneWidget);
      expect(find.text('Home Trending Now'), findsOneWidget);

      // Verify that the title text is below the icon
      final iconFinder = find.byIcon(Icons.inventory_2);
      final titleFinder = find.text('Products');
      expect(iconFinder, findsOneWidget);
      expect(titleFinder, findsOneWidget);

      final iconBottom = tester.getBottomLeft(iconFinder).dy;
      final titleTop = tester.getTopLeft(titleFinder).dy;
      // Icon must be above title in a vertical layout
      expect(titleTop, greaterThan(iconBottom));
    },
  );

  testWidgets('AppProductImage renders fallback when no images provided', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppProductImage(
            url: null,
            urls: [],
            fallback: Text('Custom Fallback Active'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Custom Fallback Active'), findsOneWidget);
  });
}
