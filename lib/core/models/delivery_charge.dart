/// Delivery charge by pincode (Firestore: /delivery_charges or /companies/{id}/delivery_charges).
class DeliveryCharge {
  final String pincode; // docId
  final String companyId; // empty = platform-wide
  final double charge;
  final bool isFree;
  final double minOrderAmount;
  final double freeAboveAmount;
  final bool isServiceable;
  final String estimatedDays;

  const DeliveryCharge({
    required this.pincode,
    this.companyId = '',
    this.charge = 0,
    this.isFree = false,
    this.minOrderAmount = 0,
    this.freeAboveAmount = 0,
    this.isServiceable = true,
    this.estimatedDays = '',
  });

  factory DeliveryCharge.fromMap(String pincode, Map<String, dynamic> map) {
    final rawCharge = (map['charge'] ?? 0).toDouble();
    final isFreeExplicit = map['isFree'] as bool?;
    final isFree = isFreeExplicit ?? (rawCharge == 0);

    return DeliveryCharge(
      pincode: pincode,
      companyId: map['companyId'] ?? '',
      charge: rawCharge,
      isFree: isFree,
      minOrderAmount: (map['minOrderAmount'] ?? 0).toDouble(),
      freeAboveAmount: (map['freeAboveAmount'] ?? 0).toDouble(),
      isServiceable: map['isServiceable'] ?? true,
      estimatedDays: map['estimatedDays'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'companyId': companyId,
    'charge': isFree ? 0.0 : charge,
    'isFree': isFree,
    'minOrderAmount': minOrderAmount,
    'freeAboveAmount': freeAboveAmount,
    'isServiceable': isServiceable,
    'estimatedDays': estimatedDays,
  };

  DeliveryCharge copyWith({
    String? pincode,
    String? companyId,
    double? charge,
    bool? isFree,
    double? minOrderAmount,
    double? freeAboveAmount,
    bool? isServiceable,
    String? estimatedDays,
  }) {
    return DeliveryCharge(
      pincode: pincode ?? this.pincode,
      companyId: companyId ?? this.companyId,
      charge: charge ?? this.charge,
      isFree: isFree ?? this.isFree,
      minOrderAmount: minOrderAmount ?? this.minOrderAmount,
      freeAboveAmount: freeAboveAmount ?? this.freeAboveAmount,
      isServiceable: isServiceable ?? this.isServiceable,
      estimatedDays: estimatedDays ?? this.estimatedDays,
    );
  }
}
