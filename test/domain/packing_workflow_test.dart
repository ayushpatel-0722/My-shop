import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/domain/employee_roles.dart';
import 'package:myshop/core/domain/order_status.dart';
import 'package:myshop/core/domain/packing_workflow.dart';
import 'package:myshop/core/models/order.dart';

Order _order(String status, {bool done = false, String? assignedTo}) => Order(
  id: 'o1',
  userId: 'u1',
  companyId: 'c1',
  items: const [OrderItem(productId: 'p', qty: 2, unitPrice: 10)],
  orderStatus: status,
  employeePackingDone: done,
  assignedEmployeeId: assignedTo,
);

const packer = EmployeeAccess({EmployeePermission.pack: true});
const dispatcher = EmployeeAccess({EmployeePermission.dispatch: true});
const both = EmployeeAccess({
  EmployeePermission.pack: true,
  EmployeePermission.dispatch: true,
});
const none = EmployeeAccess({'canSomethingElse': true});

void main() {
  orderPermissionTests();
  group('EmployeeAccess', () {
    test('legacy profiles without permissions keep packing access', () {
      const legacy = EmployeeAccess({});
      expect(legacy.canPack, isTrue);
      expect(legacy.canDispatch, isFalse);
      expect(legacy.canManageOrders, isFalse);
    });

    test('explicit switches are honoured', () {
      expect(packer.canDispatch, isFalse);
      expect(dispatcher.canPack, isFalse);
      expect(none.hasFulfilmentAccess, isFalse);
    });

    test('every role yields a full permission map', () {
      for (final r in EmployeeRole.values) {
        expect(r.fullPermissions.keys, EmployeePermission.all);
      }
    });

    test('each role gets exactly the access it is defined with', () {
      final manager = EmployeeAccess(EmployeeRole.manager.fullPermissions);
      final pack = EmployeeAccess(EmployeeRole.orderPacker.fullPermissions);
      final deliver = EmployeeAccess(
        EmployeeRole.orderDelivery.fullPermissions,
      );
      expect([
        manager.canPack,
        manager.canDispatch,
        manager.canManageOrders,
      ], everyElement(isTrue));
      expect(pack.canPack, isTrue);
      expect([pack.canDispatch, pack.canManageOrders], everyElement(isFalse));
      expect(deliver.canDispatch, isTrue);
      expect([deliver.canPack, deliver.canManageOrders], everyElement(isFalse));
    });

    test('resolve: stored id wins, legacy profiles are never promoted', () {
      expect(EmployeeRole.resolve('manager', const {}), EmployeeRole.manager);
      expect(
        EmployeeRole.resolve('order_delivery', const {}),
        EmployeeRole.orderDelivery,
      );
      expect(
        EmployeeRole.resolve('Dispatcher', {EmployeePermission.dispatch: true}),
        EmployeeRole.orderDelivery,
      );
      expect(
        EmployeeRole.resolve('Manager', {
          EmployeePermission.pack: true,
          EmployeePermission.dispatch: true,
        }),
        EmployeeRole.orderPacker,
      );
      expect(EmployeeRole.resolve(null, const {}), EmployeeRole.orderPacker);
    });
  });

  group('stageOf / stagesFor', () {
    test('packer: pack stages plus a read-only hand-over history', () {
      expect(PackingWorkflow.stagesFor(packer), [
        PackingStage.toPack,
        PackingStage.inProgress,
        PackingStage.handedOver,
      ]);
      expect(
        PackingWorkflow.stageOf(_order(OrderStatus.confirmed), packer),
        PackingStage.toPack,
      );
      expect(
        PackingWorkflow.stageOf(_order(OrderStatus.packing), packer),
        PackingStage.inProgress,
      );
      expect(
        PackingWorkflow.stageOf(_order(OrderStatus.ready), packer),
        PackingStage.handedOver,
      );
    });

    test('dispatcher only sees ready and later orders', () {
      expect(PackingWorkflow.stagesFor(dispatcher), [
        PackingStage.toDispatch,
        PackingStage.outForDelivery,
        PackingStage.delivered,
      ]);
      expect(
        PackingWorkflow.stageOf(_order(OrderStatus.confirmed), dispatcher),
        isNull,
      );
      expect(
        PackingWorkflow.stageOf(_order(OrderStatus.packing), dispatcher),
        isNull,
      );
      expect(
        PackingWorkflow.stageOf(_order(OrderStatus.ready), dispatcher),
        PackingStage.toDispatch,
      );
      expect(
        PackingWorkflow.stageOf(_order(OrderStatus.onTheWay), dispatcher),
        PackingStage.outForDelivery,
      );
      expect(
        PackingWorkflow.stageOf(_order(OrderStatus.completed), dispatcher),
        PackingStage.delivered,
      );
    });

    test('pending and cancelled never appear, for anyone', () {
      for (final a in [packer, dispatcher, both]) {
        expect(PackingWorkflow.stageOf(_order(OrderStatus.pending), a), isNull);
        expect(
          PackingWorkflow.stageOf(_order(OrderStatus.cancelled), a),
          isNull,
        );
      }
    });

    test('an order lands in at most one of the employee\'s stages', () {
      for (final a in [packer, dispatcher, both]) {
        for (final s in OrderStatus.all) {
          for (final done in [false, true]) {
            final stage = PackingWorkflow.stageOf(_order(s, done: done), a);
            if (stage != null) {
              expect(PackingWorkflow.stagesFor(a), contains(stage));
            }
          }
        }
      }
    });

    test('no fulfilment access means no tabs', () {
      expect(PackingWorkflow.stagesFor(none), isEmpty);
    });
  });

  group('eligibility', () {
    test('assignment limits only the packing phase', () {
      final confirmed = _order(OrderStatus.confirmed, assignedTo: 'e2');
      expect(PackingWorkflow.isEligible(confirmed, 'e1', packer), isFalse);
      expect(PackingWorkflow.isEligible(confirmed, 'e2', packer), isTrue);
      final ready = _order(OrderStatus.ready, assignedTo: 'e2');
      expect(PackingWorkflow.isEligible(ready, 'e1', dispatcher), isTrue);
    });
  });

  group('nextAction', () {
    test(
      'packer walks start -> mark packed, which hands the order over as ready',
      () {
        expect(
          PackingWorkflow.nextAction(
            _order(OrderStatus.confirmed),
            'e1',
            packer,
          ),
          PackingAction.startPacking,
        );
        expect(
          PackingWorkflow.nextAction(_order(OrderStatus.packing), 'e1', packer),
          PackingAction.markPacked,
        );
        expect(
          PackingWorkflow.nextAction(_order(OrderStatus.ready), 'e1', packer),
          isNull,
        );
        expect(
          PackingWorkflow.targetStatus(PackingAction.markPacked),
          OrderStatus.ready,
        );
      },
    );

    test('packer cannot dispatch, dispatcher cannot pack', () {
      expect(
        PackingWorkflow.nextAction(_order(OrderStatus.ready), 'e1', packer),
        isNull,
      );
      expect(
        PackingWorkflow.nextAction(
          _order(OrderStatus.confirmed),
          'e1',
          dispatcher,
        ),
        isNull,
      );
    });

    test('dispatcher walks ready -> on the way -> completed', () {
      expect(
        PackingWorkflow.nextAction(_order(OrderStatus.ready), 'e1', dispatcher),
        PackingAction.startDelivery,
      );
      expect(
        PackingWorkflow.nextAction(
          _order(OrderStatus.onTheWay),
          'e1',
          dispatcher,
        ),
        PackingAction.markDelivered,
      );
      expect(
        PackingWorkflow.nextAction(
          _order(OrderStatus.completed),
          'e1',
          dispatcher,
        ),
        isNull,
      );
    });

    test('nobody gets an action on pending / cancelled orders', () {
      for (final a in [packer, dispatcher, both]) {
        for (final s in [OrderStatus.pending, OrderStatus.cancelled]) {
          expect(PackingWorkflow.nextAction(_order(s), 'e1', a), isNull);
        }
      }
    });

    test('employee without permissions gets nothing', () {
      for (final s in OrderStatus.all) {
        expect(PackingWorkflow.nextAction(_order(s), 'e1', none), isNull);
      }
    });

    test('every action is a legal move in the shared status rules', () {
      final cases = {
        PackingAction.startPacking: OrderStatus.confirmed,
        PackingAction.markPacked: OrderStatus.packing,
        PackingAction.startDelivery: OrderStatus.ready,
        PackingAction.markDelivered: OrderStatus.onTheWay,
      };
      cases.forEach((action, from) {
        expect(PackingWorkflow.isLegalFor(_order(from), action), isTrue);
      });
      // Skipping a stage is rejected.
      expect(
        PackingWorkflow.isLegalFor(
          _order(OrderStatus.confirmed),
          PackingAction.markDelivered,
        ),
        isFalse,
      );
    });
  });
}

void orderPermissionTests() {
  group('OrderPermissions', () {
    const admin = OrderPermissions.admin();
    final manager = OrderPermissions.employee(
      EmployeeAccess(EmployeeRole.manager.fullPermissions),
    );
    final pack = OrderPermissions.employee(
      EmployeeAccess(EmployeeRole.orderPacker.fullPermissions),
    );
    final deliver = OrderPermissions.employee(
      EmployeeAccess(EmployeeRole.orderDelivery.fullPermissions),
    );

    test('admin and manager move every status, cancel and verify payment', () {
      for (final p in [admin, manager]) {
        for (final e in OrderStatusRules.transitions.entries) {
          for (final to in e.value) {
            expect(p.canMove(e.key, to), isTrue);
          }
        }
        expect(p.canCancel, isTrue);
        expect(p.canVerifyPayment, isTrue);
      }
    });

    test('packer: Confirmed -> Packing -> Ready only', () {
      expect(pack.canMove('confirmed', 'packing'), isTrue);
      expect(pack.canMove('packing', 'ready'), isTrue);
      expect(pack.canMove('pending', 'confirmed'), isFalse);
      expect(pack.canMove('ready', 'on_the_way'), isFalse);
      expect(pack.canMove('on_the_way', 'completed'), isFalse);
      expect(pack.canMove('packing', 'cancelled'), isFalse);
      expect(pack.canCancel || pack.canVerifyPayment, isFalse);
    });

    test('delivery: Ready -> On the way -> Delivered only', () {
      expect(deliver.canMove('ready', 'on_the_way'), isTrue);
      expect(deliver.canMove('on_the_way', 'completed'), isTrue);
      expect(deliver.canMove('confirmed', 'packing'), isFalse);
      expect(deliver.canMove('packing', 'ready'), isFalse);
      expect(deliver.canMove('ready', 'cancelled'), isFalse);
      expect(deliver.canCancel || deliver.canVerifyPayment, isFalse);
    });
  });
}
