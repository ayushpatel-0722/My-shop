import '../models/cart_item.dart';
import '../models/voucher.dart';
import 'voucher_evaluator.dart';

/// Rounds to paise / cents so money never drifts by floating point noise.
double roundMoney(double value) => (value * 100).round() / 100;

/// One priced cart line, frozen at the moment of checkout.
///
/// Storing the resolved name/price on the order protects the order history
/// from later catalogue edits (a rename must not rewrite a receipt).
class PricedLine {
  final String productId;
  final String name;
  final String image;
  final int qty;
  final double unitPrice;

  const PricedLine({
    required this.productId,
    required this.name,
    this.image = '',
    required this.qty,
    required this.unitPrice,
  });

  double get lineTotal => roundMoney(unitPrice * qty);

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'name': name,
        'image': image,
        'qty': qty,
        'unitPrice': unitPrice,
        'lineTotal': lineTotal,
      };

  @override
  String toString() => 'PricedLine($productId, $qty x $unitPrice)';
}

/// The complete, itemised amount payable for one store's cart.
///
/// This is the single source of truth for money: checkout UI, the order that
/// gets persisted and the admin order detail all read the same numbers, so
/// the customer can never be charged a different amount than the one shown.
class OrderBill {
  final String companyId;
  final String companyName;
  final List<PricedLine> lines;
  final Voucher? voucher;
  final double subtotal;
  final double discount;
  final double deliveryCharge;
  final double total;
  final VoucherEvaluation evaluation;

  const OrderBill({
    required this.companyId,
    this.companyName = '',
    required this.lines,
    this.voucher,
    required this.subtotal,
    required this.discount,
    required this.deliveryCharge,
    required this.total,
    this.evaluation = const VoucherEvaluation(),
  });

  /// Number of units (sum of quantities), not number of distinct lines.
  int get itemCount => lines.fold(0, (sum, e) => sum + e.qty);

  bool get hasVoucher => voucher != null;

  /// True when the voucher only removed the shipping fee.
  bool get isShippingOnlyDiscount => discount <= 0 && deliveryCharge == 0;

  double get totalSavings => roundMoney(discount + _shippingSaved);

  /// How much of the raw delivery fee the voucher paid for.
  double get _shippingSaved =>
      evaluation.isAccepted ? evaluation.deliveryDiscount : 0;

  Map<String, dynamic> toMap() => {
        'companyId': companyId,
        'companyName': companyName,
        'subtotal': subtotal,
        'discount': discount,
        'deliveryCharge': deliveryCharge,
        'total': total,
        'voucherId': voucher?.id,
        'voucherCode': voucher?.code ?? '',
        'lines': lines.map((e) => e.toMap()).toList(),
      };

  @override
  String toString() =>
      'OrderBill($companyId, items: $itemCount, subtotal: $subtotal, '
      'discount: $discount, delivery: $deliveryCharge, total: $total)';
}

/// Builds an [OrderBill] from cart lines, a voucher and a delivery fee.
class OrderPricer {
  const OrderPricer();

  /// Prices [items].
  ///
  /// * [deliveryCharge] is the pincode fee; it is only added when
  ///   [deliveryRequired] is true (self-pickup pays no shipping).
  /// * A voucher is validated through [VoucherEvaluator], so an invalid code
  ///   silently contributes **zero** discount instead of a wrong total.
  /// * The total is clamped at 0 — a voucher can never make an order negative.
  OrderBill price({
    required String companyId,
    String companyName = '',
    required List<CartItem> items,
    Voucher? voucher,
    double deliveryCharge = 0,
    bool deliveryRequired = true,
    VoucherContext? context,
  }) {
    final lines = items
        .map(
          (e) => PricedLine(
            productId: e.product.id,
            name: e.product.name,
            image: e.product.images.isNotEmpty ? e.product.images.first : '',
            qty: e.qty,
            unitPrice: e.product.price,
          ),
        )
        .toList();

    final subtotal = roundMoney(lines.fold<double>(0, (s, e) => s + e.lineTotal));
    final rawDelivery = deliveryRequired ? roundMoney(deliveryCharge) : 0.0;

    final evaluation = voucher == null
        ? VoucherEvaluation(cartSubtotal: subtotal)
        : const VoucherEvaluator().evaluate(
            voucher: voucher,
            items: items,
            context: context,
            deliveryCharge: rawDelivery,
          );

    final applied = evaluation.isAccepted ? voucher : null;
    final discount =
        evaluation.isAccepted ? roundMoney(evaluation.discount) : 0.0;
    final shipping = evaluation.isAccepted
        ? roundMoney(_clamp(rawDelivery - evaluation.deliveryDiscount, 0, rawDelivery))
        : rawDelivery;
    final total = _clamp(subtotal - discount + shipping, 0, double.infinity);

    return OrderBill(
      companyId: companyId,
      companyName: companyName,
      lines: lines,
      voucher: applied,
      subtotal: subtotal,
      discount: discount,
      deliveryCharge: shipping,
      total: roundMoney(total),
      evaluation: evaluation,
    );
  }

  double _clamp(double value, double min, double max) {
    if (value.isNaN) return min;
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}
