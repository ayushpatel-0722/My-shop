/// Delivery charge by pincode (Firestore: /delivery_charges).
class DeliveryCharge {
  final String pincode; // docId
  final String companyId; // empty = platform-wide
  final double charge;
  final bool isServiceable;

  const DeliveryCharge({
    required this.pincode,
    this.companyId = '',
    this.charge = 0,
    this.isServiceable = true,
  });

  factory DeliveryCharge.fromMap(String pincode, Map<String, dynamic> map) =>
      DeliveryCharge(
        pincode: pincode,
        companyId: map['companyId'] ?? '',
        charge: (map['charge'] ?? 0).toDouble(),
        isServiceable: map['isServiceable'] ?? true,
      );

  Map<String, dynamic> toMap() => {
        'companyId': companyId,
        'charge': charge,
        'isServiceable': isServiceable,
      };
}
