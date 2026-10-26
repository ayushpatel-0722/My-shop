import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an admin-configured category card for the user home screen
/// "Explore Categories" section.
///
/// Stored in the top-level Firestore collection `home_explore_categories`.
class HomeExploreCategory {
  final String id;
  final String shopId;
  final String shopName;
  final String categoryId;
  final String categoryName;
  final bool isActive;
  final int displayOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String createdBy;

  const HomeExploreCategory({
    required this.id,
    required this.shopId,
    this.shopName = '',
    required this.categoryId,
    this.categoryName = '',
    this.isActive = true,
    this.displayOrder = 0,
    this.createdAt,
    this.updatedAt,
    this.createdBy = '',
  });

  factory HomeExploreCategory.fromMap(
    Map<String, dynamic> map, {
    String id = '',
  }) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      return null;
    }

    return HomeExploreCategory(
      id: id.isNotEmpty ? id : (map['id'] as String? ?? ''),
      shopId: map['shopId'] as String? ?? '',
      shopName: map['shopName'] as String? ?? '',
      categoryId: map['categoryId'] as String? ?? '',
      categoryName: map['categoryName'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? true,
      displayOrder: (map['displayOrder'] as num?)?.toInt() ?? 0,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
      createdBy: map['createdBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shopId': shopId,
      'shopName': shopName,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'isActive': isActive,
      'displayOrder': displayOrder,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'createdBy': createdBy,
    };
  }

  HomeExploreCategory copyWith({
    String? id,
    String? shopId,
    String? shopName,
    String? categoryId,
    String? categoryName,
    bool? isActive,
    int? displayOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return HomeExploreCategory(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      shopName: shopName ?? this.shopName,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      isActive: isActive ?? this.isActive,
      displayOrder: displayOrder ?? this.displayOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
