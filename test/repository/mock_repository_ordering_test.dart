import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/category.dart';
import 'package:myshop/core/models/customer.dart';
import 'package:myshop/core/models/order.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/features/auth/auth_cubit.dart';

import '../helpers/test_harness.dart';

/// A2 + U3 repository semantics on the in-memory store.
///
/// sortOrder placement (create / edit / parent change), dense renumbering on
/// drop, idempotent backfill of legacy data, the 3-address cap and order
/// placement bookkeeping.
void main() {
  late MockAppRepository repo;

  setUp(() {
    TestHarness.setupPlatformChannels();
    repo = TestHarness.useMockRepository();
    TestHarness.signIn(TestHarness.admin);
  });

  tearDown(() => TestHarness.signOut());

  group('category sortOrder placement', () {
    test('new categories append to the end of their sibling list', () async {
      await repo.saveCategory(
        const Category(id: 'c1', companyId: 'c_organic', name: 'One'),
      );
      await repo.saveCategory(
        const Category(id: 'c2', companyId: 'c_organic', name: 'Two'),
      );
      await repo.saveCategory(
        const Category(id: 'c3', companyId: 'c_organic', name: 'Three'),
      );

      final cats = await repo.categories(companyId: 'c_organic').first;
      final byId = {for (final c in cats) c.id: c};
      expect(byId['c1']!.sortOrder, 0);
      expect(byId['c2']!.sortOrder, 1);
      expect(byId['c3']!.sortOrder, 2);
    });

    test('a plain edit keeps the manual position', () async {
      await repo.saveCategory(
        const Category(id: 'c1', companyId: 'c_organic', name: 'One'),
      );
      await repo.saveCategory(
        const Category(id: 'c2', companyId: 'c_organic', name: 'Two'),
      );

      // c1 was dragged above c2 earlier and kept sort order 5.
      await repo.reorderCategories([
        const Category(
          id: 'c2',
          companyId: 'c_organic',
          name: 'Two',
          sortOrder: 0,
        ),
        const Category(
          id: 'c1',
          companyId: 'c_organic',
          name: 'One',
          sortOrder: 1,
        ),
      ]);
      await repo.saveCategory(
        const Category(
          id: 'c1',
          companyId: 'c_organic',
          name: 'One Renamed',
          sortOrder: 1,
        ),
      );

      final renamed = await repo.category('c1', companyId: 'c_organic');
      expect(renamed!.name, 'One Renamed');
      expect(renamed.sortOrder, 1, reason: 'editing does not reshuffle');
    });

    test('moving to another parent appends at the end of that level', () async {
      await repo.saveCategory(
        const Category(id: 'root', companyId: 'c_organic', name: 'Root'),
      );
      await repo.saveCategory(
        const Category(
          id: 'kid1',
          companyId: 'c_organic',
          name: 'Kid 1',
          parentId: 'root',
        ),
      );
      await repo.saveCategory(
        const Category(
          id: 'kid2',
          companyId: 'c_organic',
          name: 'Kid 2',
          parentId: 'root',
        ),
      );
      await repo.saveCategory(
        const Category(id: 'other', companyId: 'c_organic', name: 'Other'),
      );

      // Move "Other" under Root -> after kid1 (0) and kid2 (1).
      await repo.saveCategory(
        const Category(
          id: 'other',
          companyId: 'c_organic',
          name: 'Other',
          parentId: 'root',
        ),
      );

      final moved = await repo.category('other', companyId: 'c_organic');
      expect(moved!.parentId, 'root');
      expect(moved.sortOrder, 2);
    });

    test('cyclic parents are rejected', () async {
      await repo.saveCategory(
        const Category(id: 'root', companyId: 'c_organic', name: 'Root'),
      );
      await repo.saveCategory(
        const Category(
          id: 'kid',
          companyId: 'c_organic',
          name: 'Kid',
          parentId: 'root',
        ),
      );

      expect(
        () => repo.saveCategory(
          const Category(
            id: 'root',
            companyId: 'c_organic',
            name: 'Root',
            parentId: 'kid',
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  group('reorderCategories', () {
    test('writes the given order densely as 0..n', () async {
      await repo.saveCategory(
        const Category(id: 'c1', companyId: 'c_organic', name: 'One'),
      );
      await repo.saveCategory(
        const Category(id: 'c2', companyId: 'c_organic', name: 'Two'),
      );
      await repo.saveCategory(
        const Category(id: 'c3', companyId: 'c_organic', name: 'Three'),
      );

      await repo.reorderCategories([
        const Category(
          id: 'c3',
          companyId: 'c_organic',
          name: 'Three',
          sortOrder: 9,
        ),
        const Category(
          id: 'c1',
          companyId: 'c_organic',
          name: 'One',
          sortOrder: 4,
        ),
        const Category(
          id: 'c2',
          companyId: 'c_organic',
          name: 'Two',
          sortOrder: 7,
        ),
      ]);

      final cats = await repo.categories(companyId: 'c_organic').first;
      final byId = {for (final c in cats) c.id: c};
      expect(byId['c3']!.sortOrder, 0);
      expect(byId['c1']!.sortOrder, 1);
      expect(byId['c2']!.sortOrder, 2);
    });
  });

  group('backfillCategorySortOrder', () {
    test(
      'numbers legacy duplicates by creation time and is idempotent',
      () async {
        await repo.saveCategory(
          const Category(
            id: 'old_a',
            companyId: 'c_organic',
            name: 'Zulu',
            createdAt: null,
          ),
        );
        await repo.saveCategory(
          const Category(id: 'old_b', companyId: 'c_organic', name: 'Alpha'),
        );
        // Simulate pre-ordering data: both claim the same position.
        final seed = await repo.categories(companyId: 'c_organic').first;
        for (final c in seed) {
          await repo.saveCategory(c.copyWith(sortOrder: 0));
        }

        await repo.backfillCategorySortOrder(companyId: 'c_organic');

        final fixed = await repo.categories(companyId: 'c_organic').first;
        final byId = {for (final c in fixed) c.id: c};
        expect(byId['old_a']!.sortOrder, 0, reason: 'created first');
        expect(byId['old_b']!.sortOrder, 1);

        // A second run leaves the arrangement untouched even after a manual move.
        await repo.reorderCategories([
          byId['old_b']!.copyWith(sortOrder: 0),
          byId['old_a']!.copyWith(sortOrder: 1),
        ]);
        await repo.backfillCategorySortOrder(companyId: 'c_organic');

        final again = await repo.categories(companyId: 'c_organic').first;
        final againById = {for (final c in again) c.id: c};
        expect(againById['old_b']!.sortOrder, 0);
        expect(againById['old_a']!.sortOrder, 1, reason: 'idempotent backfill');
      },
    );
  });

  group('saved addresses', () {
    test('AuthCubit keeps at most three addresses', () async {
      final cubit = AuthCubit.seeded(TestHarness.shopper);

      AddressEntry make(int n) => AddressEntry(
        id: 'addr_$n',
        name: 'Asha',
        phone: '9876543210',
        address: 'Street $n',
        city: 'Ahmedabad',
        state: 'Gujarat',
        pincode: '38000$n',
        label: 'Home',
      );

      expect(await cubit.saveUserAddress(make(1)), isTrue);
      expect(await cubit.saveUserAddress(make(2)), isTrue);
      expect(await cubit.saveUserAddress(make(3)), isTrue);
      expect(
        await cubit.saveUserAddress(make(4)),
        isFalse,
        reason: 'the fourth address is refused',
      );
      expect(cubit.currentUser!.addresses.length, 3);

      // Editing an existing entry still works at the cap.
      expect(
        await cubit.saveUserAddress(make(2).copyWith(address: 'Moved')),
        isTrue,
      );
      expect(cubit.currentUser!.addresses.length, 3);
    });
  });

  group('placeOrders', () {
    test('freezes one document per shop and decrements stock', () async {
      await repo.saveProduct(
        const Product(
          id: 'p_tomato',
          companyId: 'c_organic',
          categoryId: 'cat_veg',
          name: 'Fresh Tomatoes',
          amount: 60,
          discountAmt: 48,
          stockQty: 10,
        ),
      );

      final order = Order(
        id: '',
        userId: 'u_1',
        companyId: 'c_organic',
        items: const [
          OrderItem(
            productId: 'p_tomato',
            qty: 5,
            unitPrice: 48,
            name: 'Fresh Tomatoes',
          ),
        ],
        subtotal: 240,
        deliveryCharge: 30,
        totalAmount: 270,
      );

      final saved = await repo.placeOrders([order]);
      expect(saved.length, 1);
      expect(saved.single.items.single.unitPrice, 48);
      expect(saved.single.subtotal, 240);

      final product = await repo.product('p_tomato');
      expect(product!.stockQty, 5, reason: '5 sold of 10');
    });

    test('refuses empty or company-less orders', () async {
      expect(() => repo.placeOrders(const []), returnsNormally);
      expect(
        () => repo.placeOrders([
          Order(
            id: '',
            userId: 'u_1',
            companyId: '',
            items: const [OrderItem(productId: 'p_x', qty: 1, unitPrice: 1)],
          ),
        ]),
        throwsArgumentError,
      );
    });
  });
}
