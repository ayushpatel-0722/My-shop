import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myshop/app/l10n/app_localizations.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/domain/packing_workflow.dart';
import 'package:myshop/core/models/app_user.dart';
import 'package:myshop/core/models/employee.dart';
import 'package:myshop/core/models/order.dart';
import 'package:myshop/core/services/service_locator.dart';
import 'package:myshop/features/auth/auth_cubit.dart';
import 'package:myshop/features/employee/order_queue/employee_order_queue_screen.dart';
import 'package:myshop/features/employee/packing/packing_actions.dart';
import 'package:myshop/features/employee/packing/packing_screen.dart';

import '../helpers/test_harness.dart';

class _FailingRepo extends MockAppRepository {
  bool fail = true;
  @override
  Stream<List<Order>> orders({String userId = '', String companyId = ''}) =>
      fail
      ? Stream<List<Order>>.error(StateError('permission-denied'))
      : super.orders(userId: userId, companyId: companyId);
}

Order _order(String id, String status, {String name = 'Asha'}) => Order(
  id: id,
  userId: 'u1',
  companyId: 'c_organic',
  customerName: name,
  orderStatus: status,
  items: const [
    OrderItem(
      productId: 'p1',
      qty: 3,
      unitPrice: 50,
      name: 'Turmeric',
      variantLabel: '500g',
      variantSku: 'TUR-500',
    ),
    OrderItem(productId: 'p2', qty: 1, unitPrice: 20, name: 'Salt'),
    OrderItem(productId: 'p3', qty: 2, unitPrice: 10),
  ],
);

void main() {
  late MockAppRepository repo;

  /// `placeOrder` always starts at pending, so walk the real pipeline.
  Future<void> place(String id, String status, {String? assignTo}) async {
    await repo.placeOrder(_order(id, OrderStatus.pending));
    for (final step in OrderStatus.trackerChain.skip(1)) {
      if (status == OrderStatus.pending) break;
      await repo.updateOrderStatus(id, step, companyId: 'c_organic');
      if (step == status) break;
    }
    if (assignTo != null) await repo.assignEmployee(id, assignTo);
  }

  setUp(() {
    TestHarness.setupPlatformChannels();
    repo = TestHarness.useMockRepository();
    TestHarness.signIn(TestHarness.employee);
  });
  tearDown(TestHarness.signOut);

  Future<void> seed() async {
    await place('ord_confirmed', OrderStatus.confirmed);
    await place('ord_packing', OrderStatus.packing);
    await place('ord_pending', OrderStatus.pending);
  }

  testWidgets('dashboard shows stage counts and only eligible orders', (
    tester,
  ) async {
    await seed();
    await pumpTestApp(
      tester,
      const EmployeeOrderQueueScreen(),
      user: TestHarness.employee,
    );
    // pending is hidden; the other two are counted once each.
    expect(find.byKey(const Key('employee-total')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('employee-total')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('employee-order-ord_confirmed')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('employee-order-ord_pending')), findsNothing);

    await tester.tap(find.byKey(const Key('employee-tab-inProgress')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('employee-order-ord_packing')), findsOneWidget);
  });

  testWidgets('start packing moves the order to In progress', (tester) async {
    await seed();
    await pumpTestApp(
      tester,
      const EmployeeOrderQueueScreen(),
      user: TestHarness.employee,
    );
    await tester.tap(find.byKey(const Key('employee-action-ord_confirmed')));
    await tester.pumpAndSettle();

    final stored = await repo.order('ord_confirmed', companyId: 'c_organic');
    expect(stored!.orderStatus, OrderStatus.packing);
    // The dashboard follows the order to the In progress tab (it is shown
    // there, with its checklist progress) and says so in a toast.
    expect(
      find.byKey(const Key('employee-progress-ord_confirmed')),
      findsOneWidget,
    );
    expect(find.text('Packing started'), findsOneWidget);
  });

  testWidgets('empty stage shows the empty state, not a blank screen', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      const EmployeeOrderQueueScreen(),
      user: TestHarness.employee,
    );
    expect(find.byKey(const Key('employee-empty')), findsOneWidget);
  });

  testWidgets('a failing query shows an error with a working retry', (
    tester,
  ) async {
    final failing = _FailingRepo();
    ServiceLocator.instance.repository = failing;
    await pumpTestApp(
      tester,
      const EmployeeOrderQueueScreen(),
      user: TestHarness.employee,
    );
    expect(find.byKey(const Key('employee-error')), findsOneWidget);

    failing.fail = false;
    await tester.tap(find.byKey(const Key('employee-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('employee-error')), findsNothing);
    expect(find.byKey(const Key('employee-empty')), findsOneWidget);
  });

  testWidgets('manifest lists every product with its quantity', (tester) async {
    await seed();
    await pumpTestApp(
      tester,
      const PackingScreen(orderId: 'ord_confirmed'),
      user: TestHarness.employee,
    );
    for (var i = 0; i < 3; i++) {
      expect(find.byKey(Key('packing-item-$i')), findsOneWidget);
    }
    expect(find.text('Turmeric'), findsOneWidget);
    expect(find.text('×3'), findsOneWidget);
    expect(find.text('SKU: TUR-500'), findsOneWidget);
    expect(find.byKey(const Key('packing-action')), findsOneWidget);
  });

  testWidgets('manifest of a handed-over order offers no action', (
    tester,
  ) async {
    await place('ord_ready', OrderStatus.ready);
    await pumpTestApp(
      tester,
      const PackingScreen(orderId: 'ord_ready'),
      user: TestHarness.employee,
    );
    expect(find.byKey(const Key('packing-action')), findsNothing);
  });

  testWidgets('an order assigned to another employee is not available', (
    tester,
  ) async {
    await place('ord_x', OrderStatus.confirmed, assignTo: 'someone_else');
    await pumpTestApp(
      tester,
      const PackingScreen(orderId: 'ord_x'),
      user: TestHarness.employee,
    );
    expect(find.byKey(const Key('packing-not-allowed')), findsOneWidget);
  });

  const dispatcherUser = AppUser(
    id: 'e_2',
    companyId: 'c_organic',
    name: 'Dev Dispatcher',
    role: 'employee',
    employeeRole: 'Dispatcher',
    permissions: {'canDispatch': true},
  );
  const noDutyUser = AppUser(
    id: 'e_3',
    companyId: 'c_organic',
    name: 'Cash Cashier',
    role: 'employee',
    employeeRole: 'Cashier',
    permissions: {'canViewReports': true},
  );

  testWidgets('a dispatcher sees ready orders and can start delivery', (
    tester,
  ) async {
    await place('ord_ready', OrderStatus.ready);
    await place('ord_confirmed', OrderStatus.confirmed);
    TestHarness.signIn(dispatcherUser);
    await pumpTestApp(
      tester,
      const EmployeeOrderQueueScreen(),
      user: dispatcherUser,
    );
    expect(find.byKey(const Key('employee-tab-toDispatch')), findsOneWidget);
    expect(find.byKey(const Key('employee-tab-toPack')), findsNothing);
    expect(find.byKey(const Key('employee-order-ord_ready')), findsOneWidget);
    expect(find.byKey(const Key('employee-order-ord_confirmed')), findsNothing);

    await tester.tap(find.byKey(const Key('employee-action-ord_ready')));
    await tester.pumpAndSettle();
    final stored = await repo.order('ord_ready', companyId: 'c_organic');
    expect(stored!.orderStatus, OrderStatus.onTheWay);
  });

  testWidgets('an employee with no fulfilment permission sees a clear notice', (
    tester,
  ) async {
    await seed();
    TestHarness.signIn(noDutyUser);
    await pumpTestApp(
      tester,
      const EmployeeOrderQueueScreen(),
      user: noDutyUser,
    );
    expect(find.byKey(const Key('employee-no-access')), findsOneWidget);
    expect(find.byKey(const Key('employee-order-ord_confirmed')), findsNothing);
  });

  group('checklist and details process', () {
    testWidgets('before packing starts the items are read-only with a hint', (
      tester,
    ) async {
      await place('ord_c', OrderStatus.confirmed);
      await pumpTestApp(
        tester,
        const PackingScreen(orderId: 'ord_c'),
        user: TestHarness.employee,
      );
      expect(find.byKey(const Key('packing-start-hint')), findsOneWidget);
      final box = tester.widget<Checkbox>(find.byType(Checkbox).first);
      expect(box.onChanged, isNull);
      expect(box.value, isFalse);
    });

    testWidgets('Mark as packed needs every item ticked', (tester) async {
      await place('ord_p', OrderStatus.packing);
      await pumpTestApp(
        tester,
        const PackingScreen(orderId: 'ord_p'),
        user: TestHarness.employee,
      );
      FilledButton action() =>
          tester.widget<FilledButton>(find.byKey(const Key('packing-action')));
      expect(action().onPressed, isNull);
      expect(find.byKey(const Key('packing-check-hint')), findsOneWidget);

      // Tick two of three: still blocked and the progress says so.
      await tester.tap(find.byKey(const Key('packing-item-0')));
      await tester.tap(find.byKey(const Key('packing-item-1')));
      await tester.pump();
      expect(find.text('2 of 3 items checked'), findsOneWidget);
      expect(action().onPressed, isNull);

      await tester.tap(find.byKey(const Key('packing-item-2')));
      await tester.pump();
      expect(action().onPressed, isNotNull);
      expect(find.byKey(const Key('packing-check-hint')), findsNothing);
    });

    testWidgets('Select all / Clear all toggle every item', (tester) async {
      await place('ord_p', OrderStatus.packing);
      await pumpTestApp(
        tester,
        const PackingScreen(orderId: 'ord_p'),
        user: TestHarness.employee,
      );
      await tester.tap(find.byKey(const Key('packing-select-all')));
      await tester.pump();
      expect(find.text('3 of 3 items checked'), findsOneWidget);
      await tester.tap(find.byKey(const Key('packing-select-all')));
      await tester.pump();
      expect(find.text('0 of 3 items checked'), findsOneWidget);
    });

    testWidgets('ticks survive leaving and reopening the screen', (
      tester,
    ) async {
      await place('ord_p', OrderStatus.packing);
      await tester.runAsync(() async {});
      await pumpTestApp(
        tester,
        const PackingScreen(orderId: 'ord_p'),
        user: TestHarness.employee,
      );
      await tester.tap(find.byKey(const Key('packing-item-1')));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));

      await pumpTestApp(
        tester,
        const SizedBox.shrink(),
        user: TestHarness.employee,
      );
      await pumpTestApp(
        tester,
        const PackingScreen(orderId: 'ord_p'),
        user: TestHarness.employee,
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(find.text('1 of 3 items checked'), findsOneWidget);
    });

    testWidgets('a packed order shows every item ticked and locked', (
      tester,
    ) async {
      await place('ord_d', OrderStatus.ready);
      await pumpTestApp(
        tester,
        const PackingScreen(orderId: 'ord_d'),
        user: TestHarness.employee,
      );
      expect(find.text('3 of 3 items checked'), findsOneWidget);
      expect(find.byKey(const Key('packing-action')), findsNothing);
    });

    testWidgets('the card previews products and the in-progress checklist', (
      tester,
    ) async {
      await place('ord_p', OrderStatus.packing);
      await pumpTestApp(
        tester,
        const EmployeeOrderQueueScreen(),
        user: TestHarness.employee,
      );
      await tester.tap(find.byKey(const Key('employee-tab-inProgress')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('employee-item-strip')), findsOneWidget);
      expect(find.text('×3'), findsOneWidget);
      expect(find.byKey(const Key('employee-progress-ord_p')), findsOneWidget);
      // In progress the card sends the packer to the checklist.
      expect(find.text('Open & pack'), findsOneWidget);
    });
  });

  testWidgets('a phone-width card with many items does not overflow', (
    tester,
  ) async {
    final many = Order(
      id: 'ord_many',
      userId: 'u1',
      companyId: 'c_organic',
      customerName: 'A very long customer name that keeps going and going',
      items: [
        for (var i = 0; i < 8; i++)
          OrderItem(productId: 'p$i', qty: 12, unitPrice: 5, name: 'Item $i'),
      ],
    );
    await repo.placeOrder(many);
    await repo.updateOrderStatus(
      'ord_many',
      OrderStatus.confirmed,
      companyId: 'c_organic',
    );
    await pumpTestApp(
      tester,
      const EmployeeOrderQueueScreen(),
      user: TestHarness.employee,
      size: const Size(360, 800),
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('more'), findsOneWidget);
  });

  group('live permissions', () {
    Employee profile(Map<String, bool> permissions) => Employee(
      id: 'e_1',
      companyId: 'c_organic',
      name: 'Ramesh Packer',
      email: 'packer@greenleaf.in',
      permissions: permissions,
    );

    testWidgets('an admin change shows up without logging in again', (
      tester,
    ) async {
      await seed();
      // The session still carries the permissions it had at login (none).
      await pumpTestApp(
        tester,
        const EmployeeOrderQueueScreen(),
        user: TestHarness.employee,
      );
      expect(
        find.byKey(const Key('employee-action-ord_confirmed')),
        findsOneWidget,
      );

      // The admin turns packing off and dispatch on.
      await repo.saveEmployee(profile({'canPack': false, 'canDispatch': true}));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('employee-action-ord_confirmed')),
        findsNothing,
      );
      expect(find.byKey(const Key('employee-tab-toPack')), findsNothing);
      expect(find.byKey(const Key('employee-tab-toDispatch')), findsOneWidget);
    });

    testWidgets('without the packing permission the Start button is hidden', (
      tester,
    ) async {
      await seed();
      await repo.saveEmployee(
        profile({'canPack': false, 'canDispatch': false}),
      );
      await pumpTestApp(
        tester,
        const EmployeeOrderQueueScreen(),
        user: TestHarness.employee,
      );
      expect(find.byKey(const Key('employee-no-access')), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('details hide the action when the permission is gone', (
      tester,
    ) async {
      await place('ord_p', OrderStatus.packing);
      await repo.saveEmployee(profile({'canPack': false, 'canDispatch': true}));
      await pumpTestApp(
        tester,
        const PackingScreen(orderId: 'ord_p'),
        user: TestHarness.employee,
      );
      // A dispatcher has no business with an order still being packed.
      expect(find.byKey(const Key('packing-not-allowed')), findsOneWidget);
      expect(find.byKey(const Key('packing-action')), findsNothing);
    });
  });

  testWidgets('details of a many-item order fit a phone and need all ticks', (
    tester,
  ) async {
    await repo.placeOrder(
      Order(
        id: 'ord_big',
        userId: 'u1',
        companyId: 'c_organic',
        customerName: 'Ayush Kumar Patel',
        items: [
          for (var i = 0; i < 7; i++)
            OrderItem(
              productId: 'p$i',
              qty: 2,
              unitPrice: 5,
              name: 'Very long product name number $i for wrapping check',
              image: 'https://img.example.com/$i.jpg',
              variantLabel: '500 g',
              variantSku: 'SKU-$i',
            ),
        ],
      ),
    );
    for (final step in [OrderStatus.confirmed, OrderStatus.packing]) {
      await repo.updateOrderStatus('ord_big', step, companyId: 'c_organic');
    }
    await pumpTestApp(
      tester,
      const PackingScreen(orderId: 'ord_big'),
      user: TestHarness.employee,
      size: const Size(390, 800),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('packing-select-all')));
    await tester.pump();
    expect(find.text('7 of 7 items checked'), findsOneWidget);
  });

  test('packing errors are turned into readable reasons', () {
    expect(
      packingErrorDetail('[cloud_firestore/permission-denied] Missing'),
      contains('Permission denied'),
    );
    expect(
      packingErrorDetail(StateError('Action x is not allowed for o1')),
      contains('changed by someone else'),
    );
  });

  group('details screen flow', () {
    testWidgets('the back arrow returns to the dashboard, not home', (
      tester,
    ) async {
      await place('ord_c', OrderStatus.confirmed);
      final router = GoRouter(
        initialLocation: '/employee/packing/ord_c',
        routes: [
          GoRoute(
            path: '/employee',
            builder: (_, _) => const Scaffold(body: Text('Dashboard page')),
          ),
          GoRoute(
            path: '/employee/packing/:orderId',
            builder: (_, s) =>
                PackingScreen(orderId: s.pathParameters['orderId']!),
          ),
          GoRoute(
            path: '/home',
            builder: (_, _) => const Scaffold(body: Text('Home page')),
          ),
        ],
      );
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AuthCubit>.value(
              value: AuthCubit.seeded(TestHarness.employee),
            ),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('packing-title')), findsOneWidget);
      await tester.tap(find.byKey(const Key('packing-back')));
      await tester.pumpAndSettle();
      expect(find.text('Dashboard page'), findsOneWidget);
      expect(find.text('Home page'), findsNothing);
    });

    testWidgets('Start packing on the details unlocks the checklist', (
      tester,
    ) async {
      await place('ord_c', OrderStatus.confirmed);
      await pumpTestApp(
        tester,
        const PackingScreen(orderId: 'ord_c'),
        user: TestHarness.employee,
      );
      expect(find.byKey(const Key('packing-start-hint')), findsOneWidget);
      await tester.tap(find.byKey(const Key('packing-action')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('packing-start-hint')), findsNothing);
      expect(find.byKey(const Key('packing-select-all')), findsOneWidget);
      expect(requestedPackingStage.value, PackingStage.inProgress);
    });

    testWidgets('the stepper marks the current step and "your step"', (
      tester,
    ) async {
      await place('ord_p', OrderStatus.packing);
      await pumpTestApp(
        tester,
        const PackingScreen(orderId: 'ord_p'),
        user: TestHarness.employee,
      );
      expect(find.byKey(const Key('packing-progress-card')), findsOneWidget);
      expect(find.byKey(const Key('packing-step-5')), findsOneWidget);
      expect(find.byKey(const Key('packing-your-step')), findsOneWidget);
    });

    testWidgets('the pincode is not repeated when the address has it', (
      tester,
    ) async {
      await repo.placeOrder(
        Order(
          id: 'ord_addr',
          userId: 'u1',
          companyId: 'c_organic',
          customerName: 'Rohan',
          address: '22 Shyamal Road, Ahmedabad, 380015',
          pincode: '380015',
          items: const [
            OrderItem(productId: 'p', qty: 1, unitPrice: 5, name: 'X'),
          ],
        ),
      );
      for (final st in [
        OrderStatus.confirmed,
        OrderStatus.packing,
        OrderStatus.ready,
      ]) {
        await repo.updateOrderStatus('ord_addr', st, companyId: 'c_organic');
      }
      const dispatcher = AppUser(
        id: 'e_2',
        companyId: 'c_organic',
        name: 'Dev Dispatcher',
        role: 'employee',
        permissions: {'canDispatch': true},
      );
      TestHarness.signIn(dispatcher);
      await pumpTestApp(
        tester,
        const PackingScreen(orderId: 'ord_addr'),
        user: dispatcher,
        size: const Size(1400, 1800),
      );
      expect(find.text('22 Shyamal Road, Ahmedabad, 380015'), findsOneWidget);
      expect(find.textContaining('380015 - 380015'), findsNothing);
    });

    testWidgets('delivery details show to a dispatcher only', (tester) async {
      await place('ord_r', OrderStatus.ready);
      const dispatcher = AppUser(
        id: 'e_2',
        companyId: 'c_organic',
        name: 'Dev Dispatcher',
        role: 'employee',
        permissions: {'canDispatch': true},
      );
      TestHarness.signIn(dispatcher);
      await pumpTestApp(
        tester,
        const PackingScreen(orderId: 'ord_r'),
        user: dispatcher,
      );
      expect(find.byKey(const Key('packing-info-card')), findsOneWidget);
      // The seeded order has no address; the row appears only with one.
      expect(find.byKey(const Key('packing-address')), findsNothing);
    });
  });
}
