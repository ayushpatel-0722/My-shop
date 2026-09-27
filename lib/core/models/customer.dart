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
  final String id;
  final String name;
  final String phone;
  final String houseNo;
  final String address;
  final String line2;
  final String landmark;
  final String city;
  final String state;
  final String pincode;
  final bool isDefault;
  final String label;
  final double lat;
  final double lng;

  const AddressEntry({
    this.id = '',
    this.name = '',
    this.phone = '',
    this.houseNo = '',
    this.address = '',
    this.line2 = '',
    this.landmark = '',
    this.city = '',
    this.state = '',
    this.pincode = '',
    this.isDefault = false,
    this.label = 'Home',
    this.lat = 0,
    this.lng = 0,
  });

  /// Maximum saved addresses per user (enforced in the app layer).
  static const int maxAddresses = 3;

  /// Backwards compatibility for line1
  String get line1 => formattedAddress;

  /// Returns full formatted string e.g. "Flat 102, Green Valley, Ahmedabad, Gujarat 380001"
  String get formattedAddress {
    final parts = [
      if (houseNo.trim().isNotEmpty) houseNo.trim(),
      if (address.trim().isNotEmpty) address.trim(),
      if (line2.trim().isNotEmpty) line2.trim(),
      if (landmark.trim().isNotEmpty) 'Near ${landmark.trim()}',
      if (city.trim().isNotEmpty) city.trim(),
      if (state.trim().isNotEmpty) state.trim(),
      if (pincode.trim().isNotEmpty) pincode.trim(),
    ];
    return parts.isEmpty ? 'Ahmedabad, Gujarat' : parts.join(', ');
  }

  /// Returns short summary e.g. "Green Valley, Ahmedabad" or "Ahmedabad - 380001"
  String get shortLocation {
    final area = address.trim();
    final c = city.trim();
    final pin = pincode.trim();
    if (area.isNotEmpty && c.isNotEmpty) return '$area, $c';
    if (area.isNotEmpty) return area;
    if (c.isNotEmpty && pin.isNotEmpty) return '$c - $pin';
    if (c.isNotEmpty) return c;
    return formattedAddress;
  }

  AddressEntry copyWith({
    String? id,
    String? name,
    String? phone,
    String? houseNo,
    String? address,
    String? line2,
    String? landmark,
    String? city,
    String? state,
    String? pincode,
    bool? isDefault,
    String? label,
    double? lat,
    double? lng,
  }) => AddressEntry(
    id: id ?? this.id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    houseNo: houseNo ?? this.houseNo,
    address: address ?? this.address,
    line2: line2 ?? this.line2,
    landmark: landmark ?? this.landmark,
    city: city ?? this.city,
    state: state ?? this.state,
    pincode: pincode ?? this.pincode,
    isDefault: isDefault ?? this.isDefault,
    label: label ?? this.label,
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
  );

  factory AddressEntry.fromMap(Map<String, dynamic> map) {
    final legacyLine1 = map['line1'] as String? ?? '';
    final rawAddress = map['address'] as String? ?? legacyLine1;
    return AddressEntry(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      houseNo: map['houseNo']?.toString() ?? map['line1']?.toString() ?? '',
      address: rawAddress,
      line2: map['line2']?.toString() ?? '',
      landmark: map['landmark']?.toString() ?? '',
      city: map['city']?.toString() ?? '',
      state: map['state']?.toString() ?? '',
      pincode: map['pincode']?.toString() ?? '',
      isDefault: map['isDefault'] == true,
      label: map['label']?.toString() ?? 'Home',
      lat: (map['lat'] ?? 0).toDouble(),
      lng: (map['lng'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'phone': phone,
    'houseNo': houseNo,
    'address': address,
    'city': city,
    'state': state,
    'line1': formattedAddress,
    'pincode': pincode,
    'isDefault': isDefault,
    'label': label,
    'lat': lat,
    'lng': lng,
  };
}
