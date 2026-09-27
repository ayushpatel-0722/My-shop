import 'dart:convert';
import '../../app/l10n/l10n_service.dart';

/// Tenant / Company model (Firestore: /companies).
class Company {
  final String id;
  final String name;
  final String slug;
  final String companyPassword; // hashed in production
  final String status; // active | suspended | inactive
  final String details;
  final String address;
  final String phone; // contact number shown on pickup cards
  final String location; // maps link
  final String logoUrl;
  final String bannerUrl;
  final String profileImageUrl;
  final String category;
  final double rating;
  final int reviewCount;
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

  /// Minimum order amount required for delivery (or 0 if no minimum).
  final double minOrderAmount;

  const Company({
    required this.id,
    required this.name,
    required this.slug,
    this.companyPassword = '',
    this.status = 'active',
    this.details = '',
    this.address = '',
    this.phone = '',
    this.location = '',
    this.logoUrl = '',
    this.bannerUrl = '',
    this.profileImageUrl = '',
    this.category = '',
    this.rating = 0.0,
    this.reviewCount = 0,
    this.currency = 'INR',
    this.deliveryTypes = const ['self_pickup', 'home_delivery'],
    this.weeklyHours = const [],
    this.openingDate,
    this.isVerified = false,
    this.followers = 0,
    this.handlingMinutes = 45,
    this.deliveryMinutes = 30,
    this.minOrderAmount = 0.0,
  });

  factory Company.fromMap(String id, Map<String, dynamic> map) => Company(
    id: id,
    name: map['name'] ?? '',
    slug: map['slug'] ?? id,
    companyPassword: map['companyPassword'] ?? '',
    status: map['status'] ?? 'active',
    details: map['details'] ?? '',
    address: map['address'] ?? '',
    phone: map['phone']?.toString() ?? '',
    location: map['location'] ?? '',
    logoUrl: map['logoUrl'] ?? map['logo'] ?? '',
    bannerUrl: map['bannerUrl'] ?? map['banner'] ?? '',
    profileImageUrl:
        map['profileImageUrl'] ?? map['profileImage'] ?? map['image'] ?? '',
    category: map['category'] ?? '',
    rating:
        (map['rating'] as num?)?.toDouble() ??
        (map['ratingAverage'] as num?)?.toDouble() ??
        0.0,
    reviewCount: _asInt(
      map['reviewCount'] ?? map['reviewsCount'] ?? map['reviews'],
    ),
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
    minOrderAmount:
        (map['minOrderAmount'] as num?)?.toDouble() ??
        (map['minOrder'] as num?)?.toDouble() ??
        (map['minOrderAmt'] as num?)?.toDouble() ??
        0.0,
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'slug': slug,
    'companyPassword': companyPassword,
    'status': status,
    'details': details,
    'address': address,
    'phone': phone,
    'location': location,
    'logoUrl': logoUrl,
    'bannerUrl': bannerUrl,
    'profileImageUrl': profileImageUrl,
    'category': category,
    'rating': rating,
    'reviewCount': reviewCount,
    'currency': currency,
    'deliveryTypes': deliveryTypes,
    'weeklyHours': weeklyHours.map((e) => e.toMap()).toList(),
    'openingDate': openingDate?.toIso8601String(),
    'isVerified': isVerified,
    'followers': followers,
    'handlingMinutes': handlingMinutes,
    'deliveryMinutes': deliveryMinutes,
    'minOrderAmount': minOrderAmount,
  };

  Company copyWith({
    String? id,
    String? name,
    String? slug,
    String? companyPassword,
    String? status,
    String? details,
    String? address,
    String? phone,
    String? location,
    String? logoUrl,
    String? bannerUrl,
    String? profileImageUrl,
    String? category,
    double? rating,
    int? reviewCount,
    String? currency,
    List<String>? deliveryTypes,
    List<WeeklyHours>? weeklyHours,
    DateTime? openingDate,
    bool? isVerified,
    int? followers,
    int? handlingMinutes,
    int? deliveryMinutes,
    double? minOrderAmount,
  }) => Company(
    id: id ?? this.id,
    name: name ?? this.name,
    slug: slug ?? this.slug,
    companyPassword: companyPassword ?? this.companyPassword,
    status: status ?? this.status,
    details: details ?? this.details,
    address: address ?? this.address,
    phone: phone ?? this.phone,
    location: location ?? this.location,
    logoUrl: logoUrl ?? this.logoUrl,
    bannerUrl: bannerUrl ?? this.bannerUrl,
    profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    category: category ?? this.category,
    rating: rating ?? this.rating,
    reviewCount: reviewCount ?? this.reviewCount,
    currency: currency ?? this.currency,
    deliveryTypes: deliveryTypes ?? this.deliveryTypes,
    weeklyHours: weeklyHours ?? this.weeklyHours,
    openingDate: openingDate ?? this.openingDate,
    isVerified: isVerified ?? this.isVerified,
    followers: followers ?? this.followers,
    handlingMinutes: handlingMinutes ?? this.handlingMinutes,
    deliveryMinutes: deliveryMinutes ?? this.deliveryMinutes,
    minOrderAmount: minOrderAmount ?? this.minOrderAmount,
  );

  /// Priority image for company card and storefront displays.
  String get displayImage => profileImageUrl.isNotEmpty
      ? profileImageUrl
      : (bannerUrl.isNotEmpty ? bannerUrl : logoUrl);

  /// Priority banner for storefront header.
  String get bannerImage => bannerUrl.isNotEmpty
      ? bannerUrl
      : (profileImageUrl.isNotEmpty ? profileImageUrl : logoUrl);

  bool get allowsHomeDelivery => deliveryTypes.contains('home_delivery');
  bool get allowsSelfPickup => deliveryTypes.contains('self_pickup');
  bool get isSelfPickupOnly => allowsSelfPickup && !allowsHomeDelivery;

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
    WeeklyHours(day: L10n.current.mon, openTime: '09:00', closeTime: '21:00'),
    WeeklyHours(day: L10n.current.tue, openTime: '09:00', closeTime: '21:00'),
    WeeklyHours(day: L10n.current.wed, openTime: '09:00', closeTime: '21:00'),
    WeeklyHours(day: L10n.current.thu, openTime: '09:00', closeTime: '21:00'),
    WeeklyHours(day: L10n.current.fri, openTime: '09:00', closeTime: '22:00'),
    WeeklyHours(day: L10n.current.sat, openTime: '10:00', closeTime: '22:00'),
    WeeklyHours(
      day: L10n.current.sun,
      openTime: '00:00',
      closeTime: '00:00',
      isClosed: true,
    ),
  ];
}

/// JSON helper used by the mock repository.
T jsonDecodeMap<T>(String json) => jsonDecode(json) as T;
