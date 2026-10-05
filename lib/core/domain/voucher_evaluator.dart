import '../models/cart_item.dart';
import '../models/voucher.dart';
import '../../app/l10n/l10n_service.dart';

/// Why a voucher could not be applied to the current cart.
///
/// Using an enum (instead of ad-hoc strings) keeps checkout messages stable
/// and makes the rules unit-testable without any Flutter binding.
enum VoucherRejection {
  /// Applied successfully.
  none,

  /// No voucher with that code exists for the store.
  notFound,

  /// The admin switched the voucher off.
  inactive,

  /// Past the expiry date.
  expired,

  /// Cart is below [Voucher.minOrderAmt].
  minOrderNotMet,

  /// None of the cart lines match the voucher scope
  /// (specific product / specific category).
  scopeMismatch,

  /// This shopper already redeemed the voucher [Voucher.perUserLimit] times.
  perUserLimitReached,

  /// The voucher hit its global [Voucher.maxUses] cap.
  usageLimitReached,

  /// Voucher is reserved for a shopper's first order.
  firstTimeOnly,
}

/// Default, user facing copy for every [VoucherRejection].
/// Localized rejection/success messages per reason; re-read per call so it
/// follows the active language.
Map<VoucherRejection, String> get voucherRejectionMessages => {
  VoucherRejection.none: L10n.current.voucherApplied2,
  VoucherRejection.notFound: L10n.current.thatCodeIsNotValidForThisStore,
  VoucherRejection.inactive: L10n.current.thisVoucherIsCurrentlyDisabled,
  VoucherRejection.expired: L10n.current.thisVoucherHasExpired,
  VoucherRejection.minOrderNotMet: L10n.current.addAFewMoreItemsToUseThisVoucher,
  VoucherRejection.scopeMismatch:
      L10n.current.thisVoucherDoesNotApplyToTheItemsInYourCart,
  VoucherRejection.perUserLimitReached:
      L10n.current.youHaveAlreadyUsedThisVoucherTheMaximumNumberOfTimes,
  VoucherRejection.usageLimitReached:
      L10n.current.thisVoucherHasReachedItsRedemptionLimit,
  VoucherRejection.firstTimeOnly: L10n.current.thisVoucherIsForFirstTimeOrdersOnly,
};

/// Outcome of validating one voucher against one cart.
class VoucherEvaluation {
  /// The voucher that was evaluated (null when nothing was supplied).
  final Voucher? voucher;

  final VoucherRejection reason;

  /// Sum of every cart line, regardless of voucher scope.
  final double cartSubtotal;

  /// Portion of [cartSubtotal] the voucher is allowed to discount.
  final double eligibleSubtotal;

  /// Amount taken off the items.
  final double discount;

  /// Amount taken off the delivery charge (free-shipping vouchers).
  final double deliveryDiscount;

  /// Number of cart lines the voucher scope matched.
  final int matchedItemCount;

  const VoucherEvaluation({
    this.voucher,
    this.reason = VoucherRejection.none,
    this.cartSubtotal = 0,
    this.eligibleSubtotal = 0,
    this.discount = 0,
    this.deliveryDiscount = 0,
    this.matchedItemCount = 0,
  });

  /// True only when a voucher was supplied **and** every rule passed.
  bool get isAccepted => voucher != null && reason == VoucherRejection.none;

  /// Combined item + shipping savings.
  double get totalSavings => discount + deliveryDiscount;

  /// Stable, user facing message for the result.
  String get message =>
      voucherRejectionMessages[reason] ?? L10n.current.voucherCannotBeApplied;

  @override
  String toString() =>
      'VoucherEvaluation(${voucher?.code}, ${reason.name}, '
      'discount: $discount, shipping: $deliveryDiscount)';
}

/// Everything the evaluator needs to know about the shopper / moment.
///
/// Kept as a value object so tests never depend on [DateTime.now()].
class VoucherContext {
  final DateTime now;
  final String userId;

  /// Number of orders the shopper placed **before** this one
  /// (used by [Voucher.firstTimeOnly]).
  final int previousOrderCount;

  const VoucherContext({
    required this.now,
    this.userId = '',
    this.previousOrderCount = 0,
  });
}

/// Pure voucher rule engine.
///
/// The same instance is used by:
///  * the shopper checkout screen (decide + explain),
///  * the store front (only advertise usable vouchers),
///  * the repository, when an order is placed (usage bookkeeping).
class VoucherEvaluator {
  const VoucherEvaluator();

  /// Tolerance used for all money comparisons.
  static const double epsilon = 0.005;

  /// True when [item] falls inside the voucher's scope.
  bool matches(Voucher voucher, CartItem item) {
    switch (voucher.appliesTo) {
      case VoucherScope.specificProduct:
        return voucher.productIds.contains(item.product.id);
      case VoucherScope.specificCategory:
        return voucher.categoryIds.contains(item.product.categoryId);
      default:
        return true;
    }
  }

  /// Subtotal of the lines the voucher is allowed to discount.
  double eligibleSubtotalFor(Voucher voucher, List<CartItem> items) =>
      items.fold<double>(
        0,
        (sum, item) => matches(voucher, item) ? sum + item.lineTotal : sum,
      );

  /// Applies every voucher rule and returns a fully described result.
  ///
  /// Never throws: a rejected voucher is a normal, explained outcome.
  VoucherEvaluation evaluate({
    Voucher? voucher,
    List<CartItem> items = const <CartItem>[],
    VoucherContext? context,
    double deliveryCharge = 0,
  }) {
    final ctx = context ?? VoucherContext(now: DateTime.now());
    final cartSubtotal = items.fold<double>(0, (sum, e) => sum + e.lineTotal);

    if (voucher == null) {
      return VoucherEvaluation(cartSubtotal: cartSubtotal);
    }

    VoucherEvaluation reject(
      VoucherRejection reason, {
      double eligible = 0,
      int matched = 0,
    }) =>
        VoucherEvaluation(
          voucher: voucher,
          reason: reason,
          cartSubtotal: cartSubtotal,
          eligibleSubtotal: eligible,
          matchedItemCount: matched,
        );

    if (!voucher.isActive) return reject(VoucherRejection.inactive);
    if (voucher.isExpiredAt(ctx.now)) return reject(VoucherRejection.expired);

    if (voucher.maxUses > 0 && voucher.usedOrderIds.length >= voucher.maxUses) {
      return reject(VoucherRejection.usageLimitReached);
    }

    if (ctx.userId.isNotEmpty &&
        voucher.perUserLimit > 0 &&
        voucher.usageFor(ctx.userId) >= voucher.perUserLimit) {
      return reject(VoucherRejection.perUserLimitReached);
    }

    if (voucher.firstTimeOnly && ctx.previousOrderCount > 0) {
      return reject(VoucherRejection.firstTimeOnly);
    }

    final matched = items.where((e) => matches(voucher, e)).length;
    final eligible = eligibleSubtotalFor(voucher, items);

    if (items.isEmpty || matched == 0 || eligible <= epsilon) {
      return reject(VoucherRejection.scopeMismatch, matched: matched);
    }

    if (voucher.minOrderAmt > 0 &&
        cartSubtotal + epsilon < voucher.minOrderAmt) {
      return reject(
        VoucherRejection.minOrderNotMet,
        eligible: eligible,
        matched: matched,
      );
    }

    return VoucherEvaluation(
      voucher: voucher,
      cartSubtotal: cartSubtotal,
      eligibleSubtotal: eligible,
      discount: voucher.computeDiscount(eligible),
      deliveryDiscount: voucher.discountType == VoucherType.freeShipping
          ? deliveryCharge
          : 0,
      matchedItemCount: matched,
    );
  }

  /// Filters a store's vouchers down to the ones a shopper can actually use
  /// right now for the given cart. Used by the store front and the
  /// "available offers" sheet so we never advertise a dead code.
  List<Voucher> usableVouchers(
    List<Voucher> vouchers, {
    List<CartItem> items = const <CartItem>[],
    VoucherContext? context,
  }) =>
      vouchers
          .where(
            (v) => evaluate(voucher: v, items: items, context: context).isAccepted,
          )
          .toList();
}
