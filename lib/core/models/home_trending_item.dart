import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an admin-configured trending entry (either a product or a category)
/// for the user home screen "Trending Now" section.
///
/// Stored in the top-level Firestore collection `home_trending_now`.
class HomeTrendingItem {
  final String id;
  final String shopId;
  final String shopName;
  final String itemType; // 'product' | 'category'
  final String? productId;
  final String? categoryId;
  final String? productName;
  final String? categoryName;
  final String? imageUrl;
  final double? price;
  final bool isActive;
  final int displayOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String createdBy;

  const HomeTrendingItem({
    required this.id,
    required this.shopId,
    this.shopName = '',
    required this.itemType,
    this.productId,
    this.categoryId,
    this.productName,
    this.categoryName,
    this.imageUrl,
    this.price,
    this.isActive = true,
    this.displayOrder = 0,
    this.createdAt,
    this.updatedAt,
    this.createdBy = '',
  });

  bool get isProduct => itemType == 'product';
  bool get isCategory => itemType == 'category';

  factory HomeTrendingItem.fromMap(Map<String, dynamic> map, {String id = ''}) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      return null;
    }

    return HomeTrendingItem(
      id: id.isNotEmpty ? id : (map['id'] as String? ?? ''),
      shopId: map['shopId'] as String? ?? '',
      shopName: map['shopName'] as String? ?? '',
      itemType: map['itemType'] as String? ?? 'product',
      productId: map['productId'] as String?,
      categoryId: map['categoryId'] as String?,
      productName: map['productName'] as String?,
      categoryName: map['categoryName'] as String?,
      imageUrl:
          (map['imageUrl'] ??
                  map['image'] ??
                  map['productImage'] ??
                  map['photoUrl'])
              as String?,
      price:
          (map['price'] as num?)?.toDouble() ??
          (map['amount'] as num?)?.toDouble(),
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
      'itemType': itemType,
      if (productId != null && productId!.isNotEmpty) 'productId': productId,
      if (categoryId != null && categoryId!.isNotEmpty)
        'categoryId': categoryId,
      if (productName != null) 'productName': productName,
      if (categoryName != null) 'categoryName': categoryName,
      if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
      if (price != null) 'price': price,
      'isActive': isActive,
      'displayOrder': displayOrder,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'createdBy': createdBy,
    };
  }

  HomeTrendingItem copyWith({
    String? id,
    String? shopId,
    String? shopName,
    String? itemType,
    String? productId,
    String? categoryId,
    String? productName,
    String? categoryName,
    String? imageUrl,
    double? price,
    bool? isActive,
    int? displayOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return HomeTrendingItem(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      shopName: shopName ?? this.shopName,
      itemType: itemType ?? this.itemType,
      productId: productId ?? this.productId,
      categoryId: categoryId ?? this.categoryId,
      productName: productName ?? this.productName,
      categoryName: categoryName ?? this.categoryName,
      imageUrl: imageUrl ?? this.imageUrl,
      price: price ?? this.price,
      isActive: isActive ?? this.isActive,
      displayOrder: displayOrder ?? this.displayOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
