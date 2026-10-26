import 'package:flutter/material.dart';
import 'package:myshop/app/l10n/app_localizations.dart';
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
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,

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
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,

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
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,

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
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: AppTheme.light(),
        home: const AdminProductsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Organic Honey'), findsOneWidget);
    expect(find.text('ID: p_101'), findsOneWidget);

    // Seed products are listed as well, so assert against this product's row.
    final tile = find.byKey(const Key('product-tile-p_101'));
    expect(tile, findsOneWidget);
    expect(
      find.descendant(of: tile, matching: find.byIcon(Icons.copy_rounded)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tile, matching: find.byIcon(Icons.edit_outlined)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tile, matching: find.byIcon(Icons.delete_outline)),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('product-id-p_101')));
    await tester.pumpAndSettle();
    expect(find.text('Product ID copied to clipboard: p_101'), findsOneWidget);
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
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,

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

  testWidgets(
    'AdminAddProductScreen generates Cartesian variant matrix and saves specs and policy',
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

      tester.view.physicalSize = const Size(1200, 1000);
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
          home: const AdminAddProductScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1: Basic Info
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Product Title *'),
        'Assorted Dry Fruits Box',
      );

      // Step 3: Pricing
      await tester.enterText(
        find.widgetWithText(TextFormField, 'MRP / Original Price (₹) *'),
        '1200',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Selling / Discounted Price (₹)'),
        '999',
      );

      // Step 4: Add Option 1 (Weight: 250g, 500g)
      final addOptionBtn = find.widgetWithText(OutlinedButton, 'Add Option');
      await tester.ensureVisible(addOptionBtn);
      await tester.pumpAndSettle();
      await tester.tap(addOptionBtn);
      await tester.pumpAndSettle();

      expect(find.text('Add Product Option'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Option Name *'),
        'Weight',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Option Values (comma separated) *'),
        '250g, 500g',
      );
      await tester.tap(find.text('Save Option'));
      await tester.pumpAndSettle();

      expect(find.text('Weight: '), findsOneWidget);

      // Add Option 2 (Box: Standard, Festive)
      await tester.tap(addOptionBtn);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Option Name *'),
        'Box',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Option Values (comma separated) *'),
        'Standard, Festive',
      );
      await tester.tap(find.text('Save Option'));
      await tester.pumpAndSettle();

      expect(find.text('Box: '), findsOneWidget);

      // Generate Matrix
      final genMatrixBtn = find.widgetWithText(FilledButton, 'Generate Matrix');
      await tester.tap(genMatrixBtn);
      await tester.pumpAndSettle();

      // 4 combinations generated (2x2)
      expect(find.text('4 Variant Combinations:'), findsOneWidget);
      expect(find.text('250g / Standard'), findsOneWidget);
      expect(find.text('250g / Festive'), findsOneWidget);
      expect(find.text('500g / Standard'), findsOneWidget);
      expect(find.text('500g / Festive'), findsOneWidget);

      // Step 5: Add Specification
      final addSpecBtn = find.widgetWithText(TextButton, 'Add Spec');
      await tester.ensureVisible(addSpecBtn);
      await tester.pumpAndSettle();
      await tester.tap(addSpecBtn);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Spec Key').first,
        'Shelf Life',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Spec Value').first,
        '6 Months',
      );

      // Policy
      final policyField = find.widgetWithText(
        TextFormField,
        'Delivery & Return Policy',
      );
      await tester.ensureVisible(policyField);
      await tester.pumpAndSettle();
      await tester.enterText(policyField, 'Free delivery. 7-day replacement.');

      // Save Product
      final createBtn = find.text('Create Product');
      await tester.ensureVisible(createBtn);
      await tester.pumpAndSettle();
      await tester.tap(createBtn);
      await tester.pumpAndSettle();

      final allProducts = await mockRepo.products(companyId: 'c_organic').first;
      final createdProduct = allProducts.firstWhere(
        (p) => p.name == 'Assorted Dry Fruits Box',
      );
      expect(createdProduct, isNotNull);
      expect(createdProduct.options.length, 2);
      expect(createdProduct.variants.length, 4);
      expect(createdProduct.specifications.length, 1);
      expect(createdProduct.specifications.first.key, 'Shelf Life');
      expect(createdProduct.specifications.first.value, '6 Months');
      expect(createdProduct.policy, 'Free delivery. 7-day replacement.');
    },
  );

  testWidgets('AdminAddProductScreen supports Unlimited Stock mode', (
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

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: AppTheme.light(),
        home: const AdminAddProductScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Product Title *'),
      'Digital Recipe eBook',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'MRP / Original Price (₹) *'),
      '199',
    );

    // Select Unlimited Stock
    final unlimitedSeg = find.text('Unlimited Stock');
    await tester.ensureVisible(unlimitedSeg);
    await tester.pumpAndSettle();
    await tester.tap(unlimitedSeg);
    await tester.pumpAndSettle();

    expect(find.textContaining('Unlimited Inventory:'), findsOneWidget);

    final createBtn = find.text('Create Product');
    await tester.ensureVisible(createBtn);
    await tester.pumpAndSettle();
    await tester.tap(createBtn);
    await tester.pumpAndSettle();

    final allProducts = await mockRepo.products(companyId: 'c_organic').first;
    final created = allProducts.firstWhere(
      (p) => p.name == 'Digital Recipe eBook',
    );
    expect(created.isUnlimitedStock, isTrue);
    expect(created.isInStock, isTrue);
  });
}
