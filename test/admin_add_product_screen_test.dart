import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/models/app_user.dart';
import 'package:myshop/core/services/auth_session.dart';
import 'package:myshop/core/services/service_locator.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/app/theme/app_theme.dart';
import 'package:myshop/features/admin/products/admin_add_product_screen.dart';

void main() {
  setUp(() {
    ServiceLocator.instance.repository = MockAppRepository();
  });

  testWidgets('renders AdminAddProductScreen with mobile width without any errors', (tester) async {
    AuthSession.currentUser = AppUser(
      id: 'a_1',
      companyId: 'c_organic',
      companyName: 'GreenLeaf Organics',
      name: 'Admin GreenLeaf',
      email: 'admin@greenleaf.in',
      role: 'admin',
    );

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const AdminAddProductScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Product Specification'), findsOneWidget);
    expect(find.text('Basic Information'), findsOneWidget);
    expect(find.text('Pricing & Measurement'), findsOneWidget);
    expect(find.text('Product Gallery'), findsOneWidget);
    expect(find.text('Variant Matrix'), findsOneWidget);
  });

  testWidgets('renders AdminAddProductScreen on desktop, adds image and variant', (tester) async {
    AuthSession.currentUser = AppUser(
      id: 'a_1',
      companyId: 'c_organic',
      companyName: 'GreenLeaf Organics',
      name: 'Admin GreenLeaf',
      email: 'admin@greenleaf.in',
      role: 'admin',
    );

    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const AdminAddProductScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Add an image
    final imageInput = find.widgetWithText(TextFormField, 'Image URL');
    await tester.ensureVisible(imageInput);
    await tester.pumpAndSettle();
    await tester.enterText(imageInput, 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c');
    final addImgBtn = find.widgetWithText(FilledButton, 'Add');
    await tester.tap(addImgBtn);
    await tester.pumpAndSettle();

    expect(find.text('1 added'), findsOneWidget);

    // Open add variant dialog
    final addVariantBtn = find.widgetWithText(FilledButton, 'Add Variant');
    await tester.ensureVisible(addVariantBtn);
    await tester.pumpAndSettle();
    await tester.tap(addVariantBtn);
    await tester.pumpAndSettle();

    expect(find.text('Add Product Variant'), findsOneWidget);
    final addVariantDialogBtn = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Add Variant'),
    );
    await tester.tap(addVariantDialogBtn);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.qr_code), findsOneWidget);
  });
}
