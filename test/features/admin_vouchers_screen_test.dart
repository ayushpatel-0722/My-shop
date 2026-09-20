import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/voucher.dart';
import 'package:myshop/features/admin/vouchers/admin_vouchers_screen.dart';

import '../helpers/test_harness.dart';

void main() {
  late MockAppRepository repo;

  setUp(() {
    TestHarness.setupPlatformChannels();
    repo = TestHarness.useMockRepository();
    TestHarness.signIn(TestHarness.admin);
  });

  tearDown(() {
    TestHarness.signOut();
  });

  Finder field(String key) => find.byKey(Key(key));

  /// Opens the create sheet, fills it and saves.
  Future<void> fillAndSave(
    WidgetTester tester, {
    String code = 'WELCOME10',
    String value = '15',
  }) async {
    await tester.tap(field('voucher-create-button'));
    await tester.pumpAndSettle();

    await tester.enterText(field('voucher-code-field'), code);
    await tester.enterText(field('voucher-value-field'), value);
    await tester.pumpAndSettle();

    await tester.ensureVisible(field('voucher-save-button'));
    await tester.tap(field('voucher-save-button'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows only the signed-in store\'s vouchers', (tester) async {
    await pumpTestApp(tester, const AdminVouchersScreen());

    expect(find.text('FRESH20'), findsOneWidget);
    expect(find.text('FREESHIP'), findsOneWidget);
    expect(
      find.text('TECH1000'),
      findsNothing,
      reason: 'TechTronics codes must never leak into this store',
    );
  });

  testWidgets('summary counters reflect the store\'s vouchers', (tester) async {
    await pumpTestApp(tester, const AdminVouchersScreen());

    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('Expired'), findsOneWidget);
  });

  testWidgets('search narrows the list down to the typed code', (tester) async {
    await pumpTestApp(tester, const AdminVouchersScreen());

    await tester.enterText(field('voucher-search-field'), 'fresh');
    await tester.pumpAndSettle();

    expect(find.text('FRESH20'), findsOneWidget);
    expect(find.text('FREESHIP'), findsNothing);
  });

  testWidgets('an unmatched search shows the empty filter state', (tester) async {
    await pumpTestApp(tester, const AdminVouchersScreen());

    await tester.enterText(field('voucher-search-field'), 'ZZZZ');
    await tester.pumpAndSettle();

    expect(find.text('No vouchers match these filters'), findsOneWidget);
  });

  testWidgets('creates a voucher through the editor sheet', (tester) async {
    await pumpTestApp(tester, const AdminVouchersScreen());

    await fillAndSave(tester, code: 'WELCOME10', value: '15');

    final saved = await repo.voucherByCode('c_organic', 'WELCOME10');
    expect(saved, isNotNull);
    expect(saved!.companyId, 'c_organic');
    expect(saved.code, 'WELCOME10');
    expect(saved.discountValue, 15);
    expect(saved.isActive, isTrue);
    expect(saved.perUserLimit, 1);
    expect(saved.maxUses, 100);
    expect(saved.expiryDate, isNotNull);
  });

  testWidgets('rejects an invalid code instead of saving it', (tester) async {
    await pumpTestApp(tester, const AdminVouchersScreen());

    await tester.tap(field('voucher-create-button'));
    await tester.pumpAndSettle();
    await tester.enterText(field('voucher-code-field'), 'A');
    await tester.ensureVisible(field('voucher-save-button'));
    await tester.tap(field('voucher-save-button'));
    await tester.pumpAndSettle();

    expect(find.text('Use at least 3 characters.'), findsOneWidget);
    expect(await repo.voucherByCode('c_organic', 'A'), isNull);
  });

  testWidgets('refuses a duplicate code', (tester) async {
    await pumpTestApp(tester, const AdminVouchersScreen());

    await fillAndSave(tester, code: 'fresh20');

    expect(
      find.text('This code already exists for this store.'),
      findsOneWidget,
    );
  });

  testWidgets('rejects a percentage above 100', (tester) async {
    await pumpTestApp(tester, const AdminVouchersScreen());

    await fillAndSave(tester, code: 'CRAZY', value: '150');

    expect(find.text('Percentage cannot exceed 100.'), findsOneWidget);
    expect(await repo.voucherByCode('c_organic', 'CRAZY'), isNull);
  });

  testWidgets('editing an existing voucher keeps its id', (tester) async {
    await repo.saveVoucher(
      Voucher(
        id: 'v_edit',
        companyId: 'c_organic',
        code: 'EDITME',
        discountType: VoucherType.fixedAmount,
        discountValue: 25,
        expiryDate: DateTime.now().add(const Duration(days: 5)),
      ),
    );
    await pumpTestApp(tester, const AdminVouchersScreen());

    await tester.tap(find.descendant(
      of: find.byKey(const Key('voucher-tile-v_edit')),
      matching: find.byIcon(Icons.edit_outlined),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Edit Voucher'), findsOneWidget);
    expect(find.text('EDITME'), findsWidgets);

    await tester.enterText(field('voucher-value-field'), '45');
    await tester.ensureVisible(field('voucher-save-button'));
    await tester.tap(field('voucher-save-button'));
    await tester.pumpAndSettle();

    final updated = await repo.voucherByCode('c_organic', 'EDITME');
    expect(updated!.id, 'v_edit');
    expect(updated.discountValue, 45);
  });

  testWidgets('pausing a voucher toggles its active flag', (tester) async {
    await pumpTestApp(tester, const AdminVouchersScreen());

    final voucher = (await repo.voucherByCode('c_organic', 'FRESH20'))!;
    final toggle = find.descendant(
      of: find.byKey(Key('voucher-tile-${voucher.id}')),
      matching: find.byType(Switch),
    );
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect((await repo.voucherByCode('c_organic', 'FRESH20'))!.isActive, isFalse);
  });

  testWidgets('deleting asks for confirmation first', (tester) async {
    await pumpTestApp(tester, const AdminVouchersScreen());

    final voucher = (await repo.voucherByCode('c_organic', 'FRESH20'))!;
    await tester.tap(find.descendant(
      of: find.byKey(Key('voucher-tile-${voucher.id}')),
      matching: find.byIcon(Icons.delete_outline),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Delete voucher?'), findsOneWidget);

    // Cancelling keeps the voucher.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await repo.voucherByCode('c_organic', 'FRESH20'), isNotNull);

    // Confirming removes it.
    await tester.tap(find.descendant(
      of: find.byKey(Key('voucher-tile-${voucher.id}')),
      matching: find.byIcon(Icons.delete_outline),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(await repo.voucherByCode('c_organic', 'FRESH20'), isNull);
  });

  testWidgets('an empty store shows the create-first empty state', (tester) async {
    TestHarness.signIn(TestHarness.otherAdmin);
    // Remove every TechTronics voucher to hit the empty state.
    for (final v in await repo.vouchers('c_techtronics').first) {
      await repo.deleteVoucher(v.id, companyId: 'c_techtronics');
    }

    await pumpTestApp(tester, const AdminVouchersScreen());

    expect(find.text('No vouchers yet'), findsOneWidget);
    expect(find.text('Create Voucher'), findsOneWidget);
  });
}
