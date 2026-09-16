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
  };

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
