import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/models/app_user.dart';
import 'package:myshop/core/services/auth_session.dart';
import 'package:myshop/core/services/service_locator.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/app/theme/app_theme.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/features/admin/categories/admin_add_category_screen.dart';
import 'package:myshop/features/admin/products/admin_add_product_screen.dart';
import 'package:myshop/features/admin/products/admin_products_screen.dart';

void main() {
  setUp(() {
    ServiceLocator.instance.repository = MockAppRepository();
  });

  testWidgets(
    'renders AdminAddProductScreen with mobile width without any errors',
    (tester) async {
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
    },
  );

  testWidgets(
    'renders AdminAddProductScreen on desktop, adds image and variant',
    (tester) async {
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
      await tester.enterText(
        imageInput,
        'https://images.unsplash.com/photo-1546069901-ba9599a7e63c',
      );
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
    },
  );

  testWidgets('category creation requires at least one product assignment', (
    tester,
  ) async {
    AuthSession.currentUser = AppUser(
      id: 'a_1',
      companyId: 'c_organic',
      companyName: 'GreenLeaf Organics',
      name: 'Admin GreenLeaf',
      email: 'admin@greenleaf.in',
      role: 'admin',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const AdminAddCategoryScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Fresh Produce');
    await tester.enterText(find.byType(TextFormField).at(1), 'Grocery');

    final createBtn = find.text('Create Category');
    expect(createBtn, findsOneWidget);

    await tester.tap(createBtn);
    await tester.pump();

    expect(
      find.text('Please select at least one product for the category'),
      findsOneWidget,
    );
  });

  testWidgets('AdminProductsScreen displays edit icon for products', (
    tester,
  ) async {
    final mockRepo = MockAppRepository();
    ServiceLocator.instance.repository = mockRepo;
    AuthSession.currentUser = AppUser(
      id: 'a_1',
      companyId: 'c_organic',
      companyName: 'GreenLeaf Organics',
      name: 'Admin GreenLeaf',
      email: 'admin@greenleaf.in',
      role: 'admin',
    );

    await mockRepo.saveProduct(
      const Product(
        id: 'p_101',
        companyId: 'c_organic',
        categoryId: 'cat_1',
        name: 'Organic Honey',
        amount: 250,
        stockQty: 15,
        unitType: 'bottle',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const AdminProductsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Organic Honey'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets(
    'AdminAddProductScreen in edit mode pre-populates details and updates',
    (tester) async {
      final mockRepo = MockAppRepository();
      ServiceLocator.instance.repository = mockRepo;
      AuthSession.currentUser = AppUser(
        id: 'a_1',
        companyId: 'c_organic',
        companyName: 'GreenLeaf Organics',
        name: 'Admin GreenLeaf',
        email: 'admin@greenleaf.in',
        role: 'admin',
      );

      const existingProduct = Product(
        id: 'p_101',
        companyId: 'c_organic',
        categoryId: 'cat_1',
        name: 'Pure Raw Honey',
        details: 'Organic wild bee honey',
        subDetails: '500g glass jar',
        amount: 450,
        discountAmt: 400,
        stockQty: 25,
        unit: 1,
        unitType: 'bottle',
      );
      await mockRepo.saveProduct(existingProduct);

      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const AdminAddProductScreen(product: existingProduct),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Product'), findsOneWidget);
      expect(find.text('Update Product'), findsOneWidget);
      expect(find.text('Pure Raw Honey'), findsOneWidget);
      expect(find.text('Organic wild bee honey'), findsOneWidget);
      expect(find.text('450'), findsOneWidget);
      expect(find.text('400'), findsOneWidget);

      // Edit title
      final titleField = find.widgetWithText(TextFormField, 'Product Title *');
      await tester.enterText(titleField, 'Pure Raw Honey - Updated');

      final updateBtn = find.text('Update Product');
      await tester.ensureVisible(updateBtn);
      await tester.pumpAndSettle();
      await tester.tap(updateBtn);
      await tester.pumpAndSettle();

      final updated = await mockRepo.product('p_101');
      expect(updated, isNotNull);
      expect(updated!.name, 'Pure Raw Honey - Updated');
      expect(updated.id, 'p_101');
    },
  );
}
