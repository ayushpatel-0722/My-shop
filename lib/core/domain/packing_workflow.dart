import '../models/order.dart';
import 'employee_roles.dart';
import 'order_status.dart';

/// Where an order sits on the fulfilment floor, from one employee's view.
///
/// This is a permission-restricted *view* of the real order pipeline
/// ([OrderStatusRules]); it adds no statuses of its own. `pending` orders
/// (not yet confirmed by the admin) and `cancelled` orders are never shown.
enum PackingStage {
  // --- packing (canPack) ---
  /// Confirmed by the store, nobody has started packing yet.
  toPack,

  /// `packing` status, the packer has not finished.
  inProgress,

  /// For a packer without dispatch rights: everything past packing.
  handedOver,

  // --- dispatch (canDispatch) ---
  /// `ready`: packed and waiting to leave the shop.
  toDispatch,

  /// `on_the_way`.
  outForDelivery,

  /// `completed`.
  delivered,
}

/// What a fulfilment employee may do to an order.
enum PackingAction { startPacking, markPacked, startDelivery, markDelivered }

class PackingWorkflow {
  const PackingWorkflow._();

  /// The tabs an employee with [access] sees, in display order.
  static List<PackingStage> stagesFor(EmployeeAccess access) => [
    if (access.canPack) ...[PackingStage.toPack, PackingStage.inProgress],
    if (access.canDispatch) ...[
      PackingStage.toDispatch,
      PackingStage.outForDelivery,
      PackingStage.delivered,
    ] else if (access.canPack)
      PackingStage.handedOver,
  ];

  /// The stage of [order] for someone with [access], or null when the order
  /// is not on that employee's floor.
  static PackingStage? stageOf(Order order, EmployeeAccess access) {
    final status = order.orderStatus;
    if (access.canPack) {
      if (status == OrderStatus.confirmed) return PackingStage.toPack;
      if (status == OrderStatus.packing) return PackingStage.inProgress;
    }
    if (access.canDispatch) {
      if (status == OrderStatus.ready) return PackingStage.toDispatch;
      if (status == OrderStatus.onTheWay) return PackingStage.outForDelivery;
      if (status == OrderStatus.delivered || status == OrderStatus.completed) {
        return PackingStage.delivered;
      }
    } else if (access.canPack &&
        (status == OrderStatus.ready ||
            status == OrderStatus.onTheWay ||
            status == OrderStatus.delivered ||
            status == OrderStatus.completed)) {
      return PackingStage.handedOver;
    }
    return null;
  }

  /// Visibility of [order] to [employeeId].
  ///
  /// An order assigned to a packer stays with that packer while it is being
  /// packed. After packing (ready and later) it is shared with dispatchers.
  static bool isEligible(
    Order order,
    String employeeId,
    EmployeeAccess access,
  ) {
    if (stageOf(order, access) == null) return false;
    final packingPhase =
        order.orderStatus == OrderStatus.confirmed ||
        order.orderStatus == OrderStatus.packing;
    if (!packingPhase) return true;
    final assigned = order.assignedEmployeeId;
    return assigned == null || assigned.isEmpty || assigned == employeeId;
  }

  /// The single next step the employee may take, or null.
  ///
  /// Payment, cancellation and every admin-only move stay out of reach, and a
  /// stage can never be skipped: packing must start before it is finished.
  /// The packer owns the whole stretch up to `ready`.
  static PackingAction? nextAction(
    Order order,
    String employeeId,
    EmployeeAccess access,
  ) {
    if (!isEligible(order, employeeId, access)) return null;
    switch (order.orderStatus) {
      case OrderStatus.confirmed:
        return access.canPack ? PackingAction.startPacking : null;
      case OrderStatus.packing:
        return access.canPack ? PackingAction.markPacked : null;
      case OrderStatus.ready:
        return access.canDispatch ? PackingAction.startDelivery : null;
      case OrderStatus.onTheWay:
        return access.canDispatch ? PackingAction.markDelivered : null;
      default:
        return null;
    }
  }

  /// The order status an action writes.
  static String targetStatus(PackingAction action) => switch (action) {
    PackingAction.startPacking => OrderStatus.packing,
    PackingAction.markPacked => OrderStatus.ready,
    PackingAction.startDelivery => OrderStatus.onTheWay,
    PackingAction.markDelivered => OrderStatus.delivered,
  };

  /// The stage an order lands in once [action] succeeded, so the dashboard
  /// can follow it to the right tab.
  static PackingStage stageAfter(PackingAction action, EmployeeAccess access) =>
      switch (action) {
        PackingAction.startPacking => PackingStage.inProgress,
        PackingAction.markPacked =>
          access.canDispatch
              ? PackingStage.toDispatch
              : PackingStage.handedOver,
        PackingAction.startDelivery => PackingStage.outForDelivery,
        PackingAction.markDelivered => PackingStage.delivered,
      };

  /// Every status move an action makes must be legal in the shared rules.
  static bool isLegalFor(Order order, PackingAction action) {
    return OrderStatusRules.canTransition(
      order.orderStatus,
      targetStatus(action),
    );
  }
}
