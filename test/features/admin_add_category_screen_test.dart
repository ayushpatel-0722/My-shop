import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/category.dart';
import 'package:myshop/features/admin/categories/admin_add_category_screen.dart';

import '../helpers/test_harness.dart';

void main() {
  late MockAppRepository repo;

  setUp(() {
    TestHarness.setupPlatformChannels();
    repo = TestHarness.useMockRepository();
    TestHarness.signIn(TestHarness.admin);
  });

  tearDown(() => TestHarness.signOut());

  testWidgets('AdminAddCategoryScreen mounts cleanly in add mode', (
    tester,
  ) async {
    await pumpTestApp(tester, const AdminAddCategoryScreen());
    await tester.pumpAndSettle();
    expect(find.byType(AdminAddCategoryScreen), findsOneWidget);
  });

  testWidgets(
    'AdminAddCategoryScreen mounts cleanly in edit mode with category object',
    (tester) async {
      const cat = Category(
        id: 'cat_coffee',
        companyId: 'coffee-house-shop',
        name: 'Coffee Powder',
        type: 'Coffee Products',
        details: 'Fresh ground coffee powder',
        productList: ['chp-pow-001'],
      );
      await repo.saveCategory(cat);

      await pumpTestApp(tester, const AdminAddCategoryScreen(category: cat));
      await tester.pumpAndSettle();
      expect(find.byType(AdminAddCategoryScreen), findsOneWidget);
      expect(find.text('Coffee Powder'), findsOneWidget);
      expect(find.text('Coffee Products'), findsWidgets);
    },
  );

  testWidgets(
    'AdminAddCategoryScreen mounts cleanly in edit mode with categoryId',
    (tester) async {
      const cat = Category(
        id: 'cat_beans',
        companyId: 'c_organic',
        name: 'Coffee Beans',
        type: 'Coffee Products',
        details: 'Whole roasted beans',
        productList: ['chp-bean-001'],
      );
      await repo.saveCategory(cat);

      await pumpTestApp(
        tester,
        const AdminAddCategoryScreen(categoryId: 'cat_beans'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AdminAddCategoryScreen), findsOneWidget);
      expect(find.text('Coffee Beans'), findsOneWidget);
    },
  );
}
