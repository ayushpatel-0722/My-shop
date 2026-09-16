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
        cartData: (map['cartData'] as Map? ?? const {})
            .map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 1)),
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
  final String label;
  final String line1;
  final String pincode;
  final double lat;
  final double lng;

  const AddressEntry({
    this.label = '',
    this.line1 = '',
    this.pincode = '',
    this.lat = 0,
    this.lng = 0,
  });

  factory AddressEntry.fromMap(Map<String, dynamic> map) => AddressEntry(
        label: map['label'] ?? '',
        line1: map['line1'] ?? '',
        pincode: map['pincode'] ?? '',
        lat: (map['lat'] ?? 0).toDouble(),
        lng: (map['lng'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'label': label,
        'line1': line1,
        'pincode': pincode,
        'lat': lat,
        'lng': lng,
      };
}
