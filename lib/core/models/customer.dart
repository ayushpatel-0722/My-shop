/// Customer / shopper model (Firestore: /users, docId = Firebase Auth UID).
class Customer {
  final String id; // = Firebase Auth UID
  final String name;
  final String mobileNumber; // unique login identifier (OTP verified)
  final String email;
  final List<AddressEntry> addresses;
  final Map<String, int> cartData; // productId -> qty
  final List<String> savedVouchers;
  final List<String> fcmTokens;
  final String preferredLanguage; // en | gu | hi

  const Customer({
    required this.id,
    required this.name,
    required this.mobileNumber,
    this.email = '',
    this.addresses = const [],
    this.cartData = const {},
    this.savedVouchers = const [],
    this.fcmTokens = const [],
    this.preferredLanguage = 'en',
  });

  factory Customer.fromMap(String id, Map<String, dynamic> map) => Customer(
    id: id,
    name: map['name'] ?? '',
    mobileNumber: map['mobileNumber'] ?? '',
    email: map['email'] ?? '',
    addresses: (map['addresses'] as List? ?? const [])
        .map((e) => AddressEntry.fromMap(e))
        .toList(),
    cartData: (map['cartData'] as Map? ?? const {}).map(
      (k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 1),
    ),
    savedVouchers: List<String>.from(map['savedVouchers'] ?? const []),
    fcmTokens: List<String>.from(map['fcmTokens'] ?? const []),
    preferredLanguage: map['preferredLanguage'] ?? 'en',
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'mobileNumber': mobileNumber,
    'email': email,
    'addresses': addresses.map((e) => e.toMap()).toList(),
    'cartData': cartData,
    'savedVouchers': savedVouchers,
    'fcmTokens': fcmTokens,
    'preferredLanguage': preferredLanguage,
  };
}

class AddressEntry {
  final String houseNo;
  final String address;
  final String pincode;
  final bool isDefault;
  final String label;
  final double lat;
  final double lng;

  const AddressEntry({
    this.houseNo = '',
    this.address = '',
    this.pincode = '',
    this.isDefault = false,
    this.label = 'Home',
    this.lat = 0,
    this.lng = 0,
  });

  /// Backwards compatibility for line1
  String get line1 => formattedAddress;

  /// Returns full formatted string e.g. "Flat 102, Green Valley, 380001"
  String get formattedAddress {
    final parts = [
      if (houseNo.trim().isNotEmpty) houseNo.trim(),
      if (address.trim().isNotEmpty) address.trim(),
      if (pincode.trim().isNotEmpty) pincode.trim(),
    ];
    return parts.join(', ');
  }

  factory AddressEntry.fromMap(Map<String, dynamic> map) {
    final legacyLine1 = map['line1'] as String? ?? '';
    final rawAddress = map['address'] as String? ?? legacyLine1;
    return AddressEntry(
      houseNo: map['houseNo'] ?? '',
      address: rawAddress,
      pincode: map['pincode'] ?? '',
      isDefault: map['isDefault'] ?? false,
      label: map['label'] ?? 'Home',
      lat: (map['lat'] ?? 0).toDouble(),
      lng: (map['lng'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'houseNo': houseNo,
    'address': address,
    'line1': formattedAddress,
    'pincode': pincode,
    'isDefault': isDefault,
    'label': label,
    'lat': lat,
    'lng': lng,
  };
}
