import 'dart:convert';

/// Tenant / Company model (Firestore: /companies).
class Company {
  final String id;
  final String name;
  final String slug;
  final String companyPassword; // hashed in production
  final String status; // active | suspended | inactive
  final String details;
  final String address;
  final String location; // maps link
  final String logoUrl;
  final String currency; // INR | USD
  final List<String> deliveryTypes; // self_pickup | home_delivery
  final List<WeeklyHours> weeklyHours;
  final DateTime? openingDate;

  /// Profile badge shown next to the store name (managed by the platform).
  final bool isVerified;

  /// Number of shoppers following this store (denormalised counter).
  final int followers;

  /// Minutes the store needs to pick & pack an order (ETA on order cards).
  final int handlingMinutes;

  /// Minutes a parcel takes once it leaves the store (ETA on order cards).
  final int deliveryMinutes;

  const Company({
    required this.id,
    required this.name,
    required this.slug,
    this.companyPassword = '',
    this.status = 'active',
    this.details = '',
    this.address = '',
    this.location = '',
    this.logoUrl = '',
    this.currency = 'INR',
    this.deliveryTypes = const ['self_pickup', 'home_delivery'],
    this.weeklyHours = const [],
    this.openingDate,
    this.isVerified = false,
    this.followers = 0,
    this.handlingMinutes = 45,
    this.deliveryMinutes = 30,
  });

  factory Company.fromMap(String id, Map<String, dynamic> map) => Company(
    id: id,
    name: map['name'] ?? '',
    slug: map['slug'] ?? id,
    companyPassword: map['companyPassword'] ?? '',
    status: map['status'] ?? 'active',
    details: map['details'] ?? '',
    address: map['address'] ?? '',
    location: map['location'] ?? '',
    logoUrl: map['logoUrl'] ?? '',
    currency: map['currency'] ?? 'INR',
    deliveryTypes: List<String>.from(map['deliveryTypes'] ?? const []),
    weeklyHours: (map['weeklyHours'] as List? ?? const [])
        .map((e) => WeeklyHours.fromMap(e))
        .toList(),
    openingDate: map['openingDate'] != null
        ? DateTime.tryParse(map['openingDate'].toString())
        : null,
    isVerified: map['isVerified'] is bool
        ? map['isVerified'] as bool
        : map['verified'] == true,
    followers: _asInt(map['followers']),
    handlingMinutes: _asIntWithDefault(map['handlingMinutes'], 45),
    deliveryMinutes: _asIntWithDefault(map['deliveryMinutes'], 30),
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'slug': slug,
    'companyPassword': companyPassword,
    'status': status,
    'details': details,
    'address': address,
    'location': location,
    'logoUrl': logoUrl,
    'currency': currency,
    'deliveryTypes': deliveryTypes,
    'weeklyHours': weeklyHours.map((e) => e.toMap()).toList(),
    'openingDate': openingDate?.toIso8601String(),
    'isVerified': isVerified,
    'followers': followers,
    'handlingMinutes': handlingMinutes,
    'deliveryMinutes': deliveryMinutes,
  };

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _asIntWithDefault(Object? value, int fallback) {
    final parsed = _asInt(value);
    return parsed <= 0 ? fallback : parsed;
  }

  bool get isActive => status == 'active';

  String get currencySymbol => currency == 'USD' ? '\$' : '₹';

  /// Returns true when currently within weekly opening hours.
  bool isOpenNow([DateTime? now]) {
    final t = now ?? DateTime.now();
    final weekday = t.weekday; // 1 = Mon .. 7 = Sun
    if (weeklyHours.isEmpty) return true;
    if (weekday > weeklyHours.length) return true;
    final today = weeklyHours[weekday - 1];
    if (today.isClosed) return false;
    final minutes = t.hour * 60 + t.minute;
    final open = _toMinutes(today.openTime);
    final close = _toMinutes(today.closeTime);
    if (close == 0) return true; // open all day
    return minutes >= open && minutes < close;
  }

  static int _toMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  static List<WeeklyHours> defaultWeek() => WeeklyHours.defaultWeek();
}

class WeeklyHours {
  final String day; // Mon .. Sun
  final String openTime; // "09:00"
  final String closeTime; // "21:00"
  final bool isClosed;

  const WeeklyHours({
    required this.day,
    required this.openTime,
    required this.closeTime,
    this.isClosed = false,
  });

  factory WeeklyHours.fromMap(Map<String, dynamic> map) => WeeklyHours(
    day: map['day'] ?? '',
    openTime: map['openTime'] ?? '09:00',
    closeTime: map['closeTime'] ?? '21:00',
    isClosed: map['isClosed'] ?? false,
  );

  Map<String, dynamic> toMap() => {
    'day': day,
    'openTime': openTime,
    'closeTime': closeTime,
    'isClosed': isClosed,
  };

  static List<WeeklyHours> defaultWeek() => [
    const WeeklyHours(day: 'Mon', openTime: '09:00', closeTime: '21:00'),
    const WeeklyHours(day: 'Tue', openTime: '09:00', closeTime: '21:00'),
    const WeeklyHours(day: 'Wed', openTime: '09:00', closeTime: '21:00'),
    const WeeklyHours(day: 'Thu', openTime: '09:00', closeTime: '21:00'),
    const WeeklyHours(day: 'Fri', openTime: '09:00', closeTime: '22:00'),
    const WeeklyHours(day: 'Sat', openTime: '10:00', closeTime: '22:00'),
    const WeeklyHours(
      day: 'Sun',
      openTime: '00:00',
      closeTime: '00:00',
      isClosed: true,
    ),
  ];
}

/// JSON helper used by the mock repository.
T jsonDecodeMap<T>(String json) => jsonDecode(json) as T;
