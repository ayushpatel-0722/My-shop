import '../models/order.dart';

/// The order lifecycle as a state machine.
///
/// Previously the UI advanced orders with `trackerChain[index + 1]` and let
/// *any* screen write *any* status. That made it impossible to reject
/// nonsense transitions (completed -> pending) and made cancelled orders
/// vanish from the admin board. All movement now goes through these rules.
class OrderStatusRules {
  const OrderStatusRules._();

  /// Allowed `from -> to` moves. An empty set means the status is terminal.
  static const Map<String, Set<String>> transitions = {
    OrderStatus.pending: {OrderStatus.confirmed, OrderStatus.cancelled},
    OrderStatus.confirmed: {OrderStatus.packing, OrderStatus.cancelled},
    OrderStatus.packing: {OrderStatus.ready, OrderStatus.cancelled},
    OrderStatus.ready: {OrderStatus.onTheWay, OrderStatus.cancelled},
    OrderStatus.onTheWay: {OrderStatus.completed},
    OrderStatus.completed: <String>{},
    OrderStatus.cancelled: <String>{},
  };

  /// Every status the admin pipeline board shows, in display order.
  static const List<String> boardColumns = [
    OrderStatus.pending,
    OrderStatus.confirmed,
    OrderStatus.packing,
    OrderStatus.ready,
    OrderStatus.onTheWay,
    OrderStatus.completed,
    OrderStatus.cancelled,
  ];

  /// Statuses that mean "work is still outstanding".
  static const List<String> openStatuses = [
    OrderStatus.pending,
    OrderStatus.confirmed,
    OrderStatus.packing,
    OrderStatus.ready,
    OrderStatus.onTheWay,
  ];

  static Set<String> allowedNext(String from) =>
      transitions[from] ?? const <String>{};

  /// True when an order may move from [from] to [to].
  ///
  /// A no-op transition (`from == to`) is always allowed so idempotent
  /// retries do not blow up.
  static bool canTransition(String from, String to) =>
      from == to || allowedNext(from).contains(to);

  /// The next *forward* stage, ignoring cancellation. Null when terminal.
  static String? nextStage(String from) {
    for (final candidate in allowedNext(from)) {
      if (candidate != OrderStatus.cancelled) return candidate;
    }
    return null;
  }

  /// The previous stage in the happy path, for "undo" style actions.
  static String? previousStage(String from) {
    final index = OrderStatus.trackerChain.indexOf(from);
    if (index <= 0) return null;
    return OrderStatus.trackerChain[index - 1];
  }

  static bool isTerminal(String status) => allowedNext(status).isEmpty;

  static bool isOpen(String status) => !isTerminal(status);

  /// A shopper may cancel until the parcel has left the store.
  static bool isCancellable(String status) =>
      allowedNext(status).contains(OrderStatus.cancelled);

  /// 0-based position in the customer facing tracker (-1 when cancelled).
  static int trackerIndex(String status) =>
      OrderStatus.trackerChain.indexOf(status);

  /// Throws [ArgumentError] when the move is illegal.
  ///
  /// Repositories call this before writing, so a bad transition is rejected
  /// with a clear message instead of corrupting the order pipeline.
  static void ensureTransition(String from, String to) {
    if (!canTransition(from, to)) {
      throw ArgumentError(
        'Illegal order status transition: "$from" -> "$to". '
        'Allowed from "$from": ${allowedNext(from).join(", ")}',
      );
    }
  }

  /// Guards the whole write path: rejects unknown statuses too.
  static void ensureValidStatus(String status) {
    if (!OrderStatus.all.contains(status)) {
      throw ArgumentError('Unknown order status: "$status".');
    }
  }
}
