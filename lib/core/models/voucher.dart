import '../utils/type_utils.dart';
import '../../app/l10n/l10n_service.dart';

/// The three ways a voucher can reduce the payable amount.
class VoucherType {
  /// Flat currency amount off the eligible subtotal.
  static const fixedAmount = 'fixed_amount';

  /// Percentage off the eligible subtotal (0–100).
  static const percentage = 'percentage';

  /// Waives the delivery charge.
  static const freeShipping = 'free_shipping';

  static const values = <String>[fixedAmount, percentage, freeShipping];

  static String label(String type) {
    switch (type) {
      case percentage:
        return L10n.current.percentage;
      case fixedAmount:
        return L10n.current.fixedAmount;
      case freeShipping:
        return L10n.current.freeShipping;
      default:
        return type;
    }
  }
}

/// What part of the cart a voucher is allowed to discount.
class VoucherScope {
  static const allCategories = 'all_categories';
  static const specificCategory = 'specific_category';
  static const specificProduct = 'specific_product';

  static const values = <String>[
    allCategories,
    specificCategory,
    specificProduct,
  ];

  static String label(String scope) {
    switch (scope) {
      case specificCategory:
        return L10n.current.specificCategories;
      case specificProduct:
        return L10n.current.specificProducts;
      default:
        return L10n.current.allCategories;
    }
  }
}

/// Voucher / coupon model (Firestore: `/companies/{companyId}/vouchers`).
///
/// Vouchers are always store-scoped: a code belongs to exactly one company
/// and is never shared across tenants.
class Voucher {
  final String id;
  final String companyId;

  /// Human facing code, stored (and compared) in upper case.
  final String code;

  /// One of [VoucherType].
  final String discountType;

  /// Percentage (0–100) or currency amount depending on [discountType].
  final double discountValue;

  /// One of [VoucherScope].
  final String appliesTo;

  /// Used when [appliesTo] is [VoucherScope.specificProduct].
  final List<String> productIds;

  /// Used when [appliesTo] is [VoucherScope.specificCategory].
  final List<String> categoryIds;

  /// How many times a single shopper may redeem this voucher
  /// (0 or less means unlimited).
  final int perUserLimit;

  /// How many times this voucher may be redeemed in total
  /// (0 or less means unlimited).
  final int maxUses;

  /// Expiry moment. Screens store the **end of the chosen day** so a voucher
  /// stays valid for the whole of its last day.
  final DateTime? expiryDate;

  /// Minimum cart value (whole cart) required to redeem.
  final double minOrderAmt;

  /// Restricts the voucher to a shopper's very first order.
  final bool firstTimeOnly;

  /// Admin kill-switch: a paused voucher stays configured but unusable.
  final bool isActive;

  /// Order ids that already redeemed this voucher (global usage).
  final List<String> usedOrderIds;

  /// `userId -> number of redemptions` (per-user usage).
  final Map<String, int> usageByUser;

  const Voucher({
    required this.id,
    required this.companyId,
    required this.code,
    this.discountType = VoucherType.fixedAmount,
    this.discountValue = 0,
    this.appliesTo = VoucherScope.allCategories,
    this.productIds = const <String>[],
    this.categoryIds = const <String>[],
    this.perUserLimit = 1,
    this.maxUses = 100,
    this.expiryDate,
    this.minOrderAmt = 0,
    this.firstTimeOnly = false,
    this.isActive = true,
    this.usedOrderIds = const <String>[],
    this.usageByUser = const <String, int>{},
  });

  // -------------------------------------------------------------- Parsing --

  factory Voucher.fromMap(String id, Map<String, dynamic> map) => Voucher(
    id: id,
    companyId: asString(map['companyId']),
    code: Voucher.normalizeCode(asString(map['code'])),
    discountType: _sanitizeType(asString(map['discountType'])),
    discountValue: asDouble(map['discountValue']),
    appliesTo: _sanitizeScope(asString(map['appliesTo'])),
    productIds: asStringList(map['productIds']),
    categoryIds: asStringList(map['categoryIds']),
    perUserLimit: asInt(map['perUserLimit'], 1),
    maxUses: asInt(map['maxUses'], 100),
    expiryDate: asDateTime(map['expiryDate']),
    minOrderAmt: asDouble(map['minOrderAmt']),
    firstTimeOnly: asBool(map['firstTimeOnly']),
    // Old documents predate `isActive`, so default to enabled.
    isActive: map.containsKey('isActive')
        ? asBool(map['isActive'], true)
        : true,
    usedOrderIds: asStringList(map['usedOrderIds']),
    usageByUser: asIntMap(map['usageByUser']),
  );

  Map<String, dynamic> toMap() => <String, dynamic>{
    'companyId': companyId,
    'code': normalizedCode,
    'codeUpper': normalizedCode,
    'discountType': discountType,
    'discountValue': discountValue,
    'appliesTo': appliesTo,
    'productIds': productIds,
    'categoryIds': categoryIds,
    'perUserLimit': perUserLimit,
    'maxUses': maxUses,
    'expiryDate': expiryDate?.toIso8601String(),
    'minOrderAmt': minOrderAmt,
    'firstTimeOnly': firstTimeOnly,
    'isActive': isActive,
    'usedOrderIds': usedOrderIds,
    'usageByUser': usageByUser,
    'usageCount': usageCount,
  };

  static String _sanitizeType(String type) =>
      VoucherType.values.contains(type) ? type : VoucherType.fixedAmount;

  static String _sanitizeScope(String scope) =>
      VoucherScope.values.contains(scope) ? scope : VoucherScope.allCategories;

  /// Trims, collapses whitespace and upper-cases a typed code.
  static String normalizeCode(String raw) =>
      raw.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();

  // ----------------------------------------------------------------- State --

  /// Upper-case, whitespace free version of [code] used for comparisons.
  String get normalizedCode => normalizeCode(code);

  /// True once [expiryDate] has passed (relative to [now]).
  bool isExpiredAt(DateTime now) =>
      expiryDate != null && now.isAfter(expiryDate!);

  /// Kept for callers that do not care about the clock; prefer passing one.
  bool get isExpired => isExpiredAt(DateTime.now());

  /// Enabled **and** not expired.
  bool isLiveAt(DateTime now) => isActive && !isExpiredAt(now);

  /// Total redemptions so far.
  int get usageCount => usedOrderIds.length;

  /// Redemptions by a single shopper.
  int usageFor(String userId) =>
      userId.isEmpty ? 0 : (usageByUser[userId] ?? 0);

  /// Remaining global redemptions; `-1` when unlimited.
  int get usesRemaining =>
      maxUses <= 0 ? -1 : (maxUses - usageCount).clamp(0, maxUses).toInt();

  /// Remaining redemptions for one shopper; `-1` when unlimited.
  int usesRemainingFor(String userId) => perUserLimit <= 0
      ? -1
      : (perUserLimit - usageFor(userId)).clamp(0, perUserLimit).toInt();

  bool get isExhausted => maxUses > 0 && usageCount >= maxUses;

  /// Short badge shown on voucher tiles, e.g. `20% OFF`.
  String get discountLabel {
    switch (discountType) {
      case VoucherType.percentage:
        return L10n.current.off(_trim(discountValue));
      case VoucherType.freeShipping:
        return L10n.current.freeDelivery;
      default:
        return L10n.current.off4(_trim(discountValue));
    }
  }

  String get scopeLabel => VoucherScope.label(appliesTo);

  String get typeLabel => VoucherType.label(discountType);

  /// `20.0 -> "20"`, `20.5 -> "20.50"` (no trailing zero stripping surprises).
  static String _trim(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);

  // ------------------------------------------------------------------ Math --

  /// Discount for [eligibleSubtotal].
  ///
  /// Never returns a negative number and never exceeds [eligibleSubtotal],
  /// so an over-generous admin setting cannot produce a negative order.
  double computeDiscount(double eligibleSubtotal) {
    final base = eligibleSubtotal <= 0 || eligibleSubtotal.isNaN
        ? 0.0
        : eligibleSubtotal;
    if (base <= 0) return 0;

    final raw = discountType == VoucherType.percentage
        ? base * (discountValue.clamp(0, 100).toDouble()) / 100
        : discountType == VoucherType.fixedAmount
        ? discountValue
        : 0.0;

    if (raw.isNaN || raw <= 0) return 0;
    return raw > base ? base : raw;
  }

  // -------------------------------------------------------------- Mutation --

  /// Returns a copy with this order (and shopper) counted against the caps.
  ///
  /// Idempotent: replaying the same order id never double counts.
  Voucher registerUsage({required String orderId, String userId = ''}) {
    final alreadyCounted = usedOrderIds.contains(orderId);
    final nextOrders = alreadyCounted
        ? usedOrderIds
        : <String>[...usedOrderIds, orderId];

    final nextByUser = <String, int>{...usageByUser};
    if (userId.isNotEmpty && !alreadyCounted) {
      nextByUser[userId] = (nextByUser[userId] ?? 0) + 1;
    }
    return copyWith(usedOrderIds: nextOrders, usageByUser: nextByUser);
  }

  /// Reverses a redemption count when an order using this voucher is cancelled.
  Voucher releaseUsage({required String orderId, String userId = ''}) {
    final nextOrders = List<String>.from(usedOrderIds)..remove(orderId);
    final nextByUser = Map<String, int>.from(usageByUser);
    if (userId.isNotEmpty && (nextByUser[userId] ?? 0) > 0) {
      final updated = nextByUser[userId]! - 1;
      if (updated <= 0) {
        nextByUser.remove(userId);
      } else {
        nextByUser[userId] = updated;
      }
    }
    return copyWith(usedOrderIds: nextOrders, usageByUser: nextByUser);
  }

  Voucher copyWith({
    String? id,
    String? companyId,
    String? code,
    String? discountType,
    double? discountValue,
    String? appliesTo,
    List<String>? productIds,
    List<String>? categoryIds,
    int? perUserLimit,
    int? maxUses,
    DateTime? expiryDate,
    bool clearExpiryDate = false,
    double? minOrderAmt,
    bool? firstTimeOnly,
    bool? isActive,
    List<String>? usedOrderIds,
    Map<String, int>? usageByUser,
  }) => Voucher(
    id: id ?? this.id,
    companyId: companyId ?? this.companyId,
    code: code ?? this.code,
    discountType: discountType ?? this.discountType,
    discountValue: discountValue ?? this.discountValue,
    appliesTo: appliesTo ?? this.appliesTo,
    productIds: productIds ?? this.productIds,
    categoryIds: categoryIds ?? this.categoryIds,
    perUserLimit: perUserLimit ?? this.perUserLimit,
    maxUses: maxUses ?? this.maxUses,
    expiryDate: clearExpiryDate ? null : (expiryDate ?? this.expiryDate),
    minOrderAmt: minOrderAmt ?? this.minOrderAmt,
    firstTimeOnly: firstTimeOnly ?? this.firstTimeOnly,
    isActive: isActive ?? this.isActive,
    usedOrderIds: usedOrderIds ?? this.usedOrderIds,
    usageByUser: usageByUser ?? this.usageByUser,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Voucher && other.id == id && other.code == code;

  @override
  int get hashCode => Object.hash(id, code);

  @override
  String toString() =>
      'Voucher(${normalizedCode.isNotEmpty ? normalizedCode : id}, '
      '$discountLabel, uses: $usageCount/$maxUses)';
}
