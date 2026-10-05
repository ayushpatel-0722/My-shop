import '../models/company.dart';
import '../models/order.dart';
import 'order_status.dart';
import '../../app/l10n/l10n_service.dart';

/// Delivery-estimate copy for the order history cards.
///
/// Shown only while an order is actually moving through the kitchen
/// (`packing` / `ready` / `on the way`), pulled from the store's estimated
/// handling and delivery times — never for pending/confirmed (nothing to
/// estimate yet) or terminal orders (delivered / cancelled).
class OrderEta {
  const OrderEta._();

  /// Human label like "Arriving by 6:30 PM today", or null when the status
  /// does not deserve an ETA.
  static String? label(Order order, Company? company, DateTime now) {
    final handling = company?.handlingMinutes ?? 45;
    final delivery = company?.deliveryMinutes ?? 30;
    final pickup = order.isSelfPickup;

    switch (order.orderStatus) {
      case OrderStatus.packing:
        return pickup
            ? L10n.current.readyForPickupBy(
                _fmt(now.add(Duration(minutes: handling)), now),
              )
            : L10n.current.arrivingBy(
                _fmt(now.add(Duration(minutes: handling + delivery)), now),
              );
      case OrderStatus.ready:
        return pickup
            ? L10n.current.readyForPickupBy(
                _fmt(now.add(const Duration(minutes: 10)), now),
              )
            : L10n.current.arrivingBy(
                _fmt(now.add(Duration(minutes: delivery)), now),
              );
      case OrderStatus.onTheWay:
        return L10n.current.arrivingBy(
          _fmt(now.add(Duration(minutes: delivery)), now),
        );
      default:
        return null;
    }
  }

  /// "6:30 PM today" / "9:00 AM tomorrow".
  static String _fmt(DateTime t, [DateTime? refNow]) {
    final now = refNow ?? DateTime.now();
    final suffix = t.hour >= 12 ? L10n.current.pm : L10n.current.am;
    var h12 = t.hour % 12;
    if (h12 == 0) h12 = 12;
    final time = t.minute == 0
        ? '$h12 $suffix'
        : '$h12:${t.minute.toString().padLeft(2, '0')} $suffix';

    final tomorrow = now.add(const Duration(days: 1));
    final sameDay =
        t.year == now.year && t.month == now.month && t.day == now.day;
    final isTomorrow =
        t.year == tomorrow.year &&
        t.month == tomorrow.month &&
        t.day == tomorrow.day;

    if (sameDay) return L10n.current.today(time);
    if (isTomorrow) return L10n.current.tomorrow(time);
    return time;
  }

  /// 0..1 progress along the customer-facing tracker (0 for cancelled).
  ///
  /// Used by the thin progress bar on the order history card.
  static double progress(String status) {
    if (status == OrderStatus.cancelled) return 0;
    final index = OrderStatusRules.trackerIndex(status);
    if (index < 0) return 0;
    return (index + 1) / OrderStatus.trackerChain.length;
  }
}
