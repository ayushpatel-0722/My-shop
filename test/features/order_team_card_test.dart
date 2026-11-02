import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/employee.dart';
import 'package:myshop/core/models/order.dart';
import 'package:myshop/features/admin/orders/widgets/order_team_card.dart';

import '../helpers/test_harness.dart';

void main() {
  late MockAppRepository repo;

  setUp(() {
    TestHarness.setupPlatformChannels();
    repo = TestHarness.useMockRepository();
    TestHarness.signIn(TestHarness.admin);
  });
  tearDown(TestHarness.signOut);

  Future<Order> placeConfirmed() async {
    await repo.placeOrder(
      Order(
        id: 'ord_1',
        userId: 'u1',
        companyId: 'c_organic',
        items: const [OrderItem(productId: 'p', qty: 1, unitPrice: 10)],
      ),
    );
    await repo.updateOrderStatus(
      'ord_1',
      OrderStatus.confirmed,
      companyId: 'c_organic',
    );
    return (await repo.order('ord_1', companyId: 'c_organic'))!;
  }

  testWidgets('lists only packers and assigns the chosen one', (tester) async {
    await repo.saveEmployee(
      const Employee(
        id: 'e_disp',
        companyId: 'c_organic',
        name: 'Dev Dispatcher',
        email: 'd@x.in',
        role: 'Dispatcher',
        permissions: {'canPack': false, 'canDispatch': true},
      ),
    );
    final order = await placeConfirmed();
    await pumpTestApp(
      tester,
      Scaffold(
        body: OrderTeamCard(order: order, companyId: 'c_organic'),
      ),
      user: TestHarness.admin,
    );
    expect(find.byKey(const Key('order-packing-chip')), findsOneWidget);

    await tester.tap(find.byKey(const Key('order-assign-packer')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ramesh Packer'), findsWidgets);
    expect(find.textContaining('Dev Dispatcher'), findsNothing);

    await tester.tap(find.textContaining('Ramesh Packer').last);
    await tester.pumpAndSettle();
    final stored = await repo.order('ord_1', companyId: 'c_organic');
    expect(stored!.assignedEmployeeId, 'e_1');
  });

  testWidgets('after packing starts the packer is shown read-only for ready', (
    tester,
  ) async {
    await placeConfirmed();
    await repo.updateOrderStatus(
      'ord_1',
      OrderStatus.packing,
      companyId: 'c_organic',
    );
    await repo.updateOrderStatus(
      'ord_1',
      OrderStatus.ready,
      companyId: 'c_organic',
    );
    final order = (await repo.order('ord_1', companyId: 'c_organic'))!;
    await pumpTestApp(
      tester,
      Scaffold(
        body: OrderTeamCard(order: order, companyId: 'c_organic'),
      ),
      user: TestHarness.admin,
    );
    expect(find.byKey(const Key('order-assign-packer')), findsNothing);
    expect(find.byKey(const Key('order-assigned-readonly')), findsOneWidget);
  });
}
