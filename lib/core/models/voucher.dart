/// Voucher / coupon model (Firestore: /vouchers) — always company-scoped.
class Voucher {
  final String id;
  final String companyId;
  final String code;
  final String discountType; // fixed_amount | percentage | free_shipping
  final double discountValue;
  final String appliesTo; // specific_product | specific_category | all_categories
  final List<String> productIds;
  final List<String> categoryIds;
  final int perUserLimit;
  final int maxUses;
  final DateTime? expiryDate;
  final double minOrderAmt;
  final bool firstTimeOnly;
  final List<String> usedOrderIds;

  const Voucher({
    required this.id,
    required this.companyId,
    required this.code,
    this.discountType = 'fixed_amount',
    this.discountValue = 0,
    this.appliesTo = 'all_categories',
    this.productIds = const [],
    this.categoryIds = const [],
    this.perUserLimit = 1,
    this.maxUses = 100,
    this.expiryDate,
    this.minOrderAmt = 0,
    this.firstTimeOnly = false,
    this.usedOrderIds = const [],
  });

  factory Voucher.fromMap(String id, Map<String, dynamic> map) => Voucher(
        id: id,
        companyId: map['companyId'] ?? '',
        code: map['code'] ?? '',
        discountType: map['discountType'] ?? 'fixed_amount',
        discountValue: (map['discountValue'] ?? 0).toDouble(),
        appliesTo: map['appliesTo'] ?? 'all_categories',
        productIds: List<String>.from(map['productIds'] ?? const []),
        categoryIds: List<String>.from(map['categoryIds'] ?? const []),
        perUserLimit: map['perUserLimit'] ?? 1,
        maxUses: map['maxUses'] ?? 100,
        expiryDate: map['expiryDate'] != null
            ? DateTime.tryParse(map['expiryDate'].toString())
            : null,
        minOrderAmt: (map['minOrderAmt'] ?? 0).toDouble(),
        firstTimeOnly: map['firstTimeOnly'] ?? false,
        usedOrderIds: List<String>.from(map['usedOrderIds'] ?? const []),
      );

  Map<String, dynamic> toMap() => {
        'companyId': companyId,
        'code': code,
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
        'usedOrderIds': usedOrderIds,
      };

  bool get isExpired =>
      expiryDate != null && DateTime.now().isAfter(expiryDate!);

  /// Compute discount for the given company-item subtotal.
  double computeDiscount(double subtotal) {
    switch (discountType) {
      case 'percentage':
        return (subtotal * discountValue / 100).clamp(0, subtotal).toDouble();
      case 'fixed_amount':
        return discountValue.clamp(0, subtotal).toDouble();
      case 'free_shipping':
        return 0; // handled at delivery-charge level
      default:
        return 0;
    }
  }
}
