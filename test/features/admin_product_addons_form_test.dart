import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/core/models/product_addon.dart';
import 'package:myshop/features/admin/products/admin_add_product_screen.dart';

import '../helpers/test_harness.dart';

/// The product form saves add-ons with the product, loads them again for
/// editing, and a product without add-ons saves exactly as before.
void main() {
  late MockAppRepository repo;

  setUp(() {
    TestHarness.setupPlatformChannels();
    repo = TestHarness.useMockRepository();
    TestHarness.signIn(TestHarness.admin);
  });

  tearDown(() => TestHarness.signOut());

  const existing = Product(
    id: 'p_sofa',
    companyId: 'c_organic',
    categoryId: 'cat_x',
    name: 'Corner Sofa',
    details: 'Soft three seater',
    amount: 30000,
    discountAmt: 27000,
    stockQty: 4,
    unit: 1,
    unitType: 'pieces',
    addOns: [
      ProductAddOn(id: 'ao_a', title: 'Assembly', amount: 1000),
      ProductAddOn(
        id: 'ao_b',
        title: 'Floor delivery',
        amount: 500,
        discountAmt: 400,
        isActive: false,
      ),
    ],
    addOnSelection: AddOnSelectionType.radio,
  );

  Future<void> openForm(WidgetTester tester, {Product? product}) async {
    await pumpTestApp(
      tester,
      AdminAddProductScreen(product: product),
      user: TestHarness.admin,
      size: const Size(1200, 2400),
    );
    await tester.pumpAndSettle();
  }

  /// Saving goes through the async repository, which pumping alone does not
  /// advance.
  Future<void> settleSave(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapSave(WidgetTester tester, String label) async {
    // Leave the text field first, like a person tapping the button would.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final btn = find.text(label);
    await tester.ensureVisible(btn);
    await tester.pumpAndSettle();
    await tester.tap(btn);
    await tester.pumpAndSettle();
    await settleSave(tester);
  }

  testWidgets('the add-ons block is on the form, checkbox by default', (
    tester,
  ) async {
    await openForm(tester);
    final editor = find.byKey(const Key('addons-editor'));
    await tester.ensureVisible(editor);
    expect(editor, findsOneWidget);
    expect(find.byKey(const Key('addons-empty')), findsOneWidget);
    final seg = tester.widget<SegmentedButton<String>>(
      find.byKey(const Key('addon-selection-type')),
    );
    expect(seg.selected, {AddOnSelectionType.checkbox});
  });

  testWidgets('editing loads the saved add-ons and selection type', (
    tester,
  ) async {
    await repo.saveProduct(existing);
    await openForm(tester, product: existing);
    await tester.ensureVisible(find.byKey(const Key('addons-editor')));

    expect(find.byKey(const Key('addon-tile-ao_a')), findsOneWidget);
    expect(find.byKey(const Key('addon-tile-ao_b')), findsOneWidget);
    expect(find.text('Disabled'), findsOneWidget);
    final seg = tester.widget<SegmentedButton<String>>(
      find.byKey(const Key('addon-selection-type')),
    );
    expect(seg.selected, {AddOnSelectionType.radio});
  });

  testWidgets('updating saves changed add-ons with the product', (
    tester,
  ) async {
    await repo.saveProduct(existing);
    await openForm(tester, product: existing);

    // Remove one, enable the other, add a new one.
    await tester.ensureVisible(find.byKey(const Key('addons-editor')));
    await tester.tap(find.byKey(const Key('addon-remove-ao_a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addon-active-ao_b')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addon-add-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('addon-title-field')),
      'Gift wrap',
    );
    await tester.enterText(find.byKey(const Key('addon-price-field')), '0');
    await tester.tap(find.byKey(const Key('addon-save-button')));
    await tester.pumpAndSettle();

    await tapSave(tester, 'Update Product');

    final saved = (await repo.product('p_sofa'))!;
    expect(saved.addOns.map((a) => a.title), ['Floor delivery', 'Gift wrap']);
    expect(saved.addOns.first.isActive, isTrue);
    expect(saved.addOns.first.price, 400);
    expect(saved.addOns.last.price, 0);
    expect(saved.addOns.last.id, startsWith('ao_'));
    expect(saved.addOnSelection, AddOnSelectionType.radio);
  });

  testWidgets('an update without touching add-ons keeps them', (tester) async {
    await repo.saveProduct(existing);
    await openForm(tester, product: existing);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Product Title *'),
      'Corner Sofa XL',
    );
    await tapSave(tester, 'Update Product');
    final saved = (await repo.product('p_sofa'))!;
    expect(saved.name, 'Corner Sofa XL', reason: 'the save really ran');
    expect(saved.addOns.length, 2);
    expect(saved.addOns.last.isActive, isFalse);
    expect(saved.addOnSelection, AddOnSelectionType.radio);
  });

  testWidgets('a product without add-ons still saves, with none', (
    tester,
  ) async {
    const plain = Product(
      id: 'p_plain',
      companyId: 'c_organic',
      categoryId: 'cat_x',
      name: 'Plain Stool',
      details: 'A stool',
      amount: 900,
      stockQty: 3,
    );
    await repo.saveProduct(plain);
    await openForm(tester, product: plain);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Product Title *'),
      'Plain Stool 2',
    );
    await tapSave(tester, 'Update Product');
    final saved = (await repo.product('p_plain'))!;
    expect(saved.name, 'Plain Stool 2', reason: 'the save really ran');
    expect(saved.addOns, isEmpty);
    expect(saved.addOnSelection, AddOnSelectionType.checkbox);
  });
}
