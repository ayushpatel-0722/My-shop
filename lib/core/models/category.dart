import '../utils/type_utils.dart';

/// Category model (Firestore: `/categories` or
/// `/companies/{companyId}/categories`) — supports nested trees via parentId.
class Category {
  final String id;

  /// Owning store; empty means a platform-wide (global) category.
  final String companyId;

  final String name;
  final String details;

  /// Free-form grouping label, e.g. `Grocery`, `Electronics`.
  final String type;

  /// Parent category id; null for a top level category.
  final String? parentId;

  /// Either an emoji / short glyph or an http(s) image URL.
  final String iconUrl;

  /// Products explicitly assigned to this category, **in display order**.
  ///
  /// The array position is the position customers see inside the category, so
  /// the admin's arrangement is stored as-is and read back in the same order.
  final List<String> productList;

  /// Manual ordering among siblings (same [parentId]); lower comes first.
  ///
  /// Legacy categories (no value stored) read as 0 and fall back to
  /// [createdAt] then name when sorting, so nothing disappears before the
  /// one-time backfill runs.
  final int sortOrder;

  final DateTime? createdAt;

  const Category({
    required this.id,
    required this.name,
    this.companyId = '',
    this.details = '',
    this.type = '',
    this.parentId,
    this.iconUrl = '',
    this.productList = const <String>[],
    this.sortOrder = 0,
    this.createdAt,
  });

  // -------------------------------------------------------------- Parsing --

  factory Category.fromMap(String id, Map<String, dynamic> map) {
    final rawParent = asString(map['parentId']);
    return Category(
      id: id,
      name: asString(map['name']),
      companyId: asString(map['companyId']),
      details: asString(map['details']),
      type: asString(map['type']),
      parentId: rawParent.isEmpty ? null : rawParent,
      iconUrl: asString(map['iconUrl']),
      productList: asStringList(map['productList']),
      sortOrder: asInt(map['sortOrder']),
      createdAt: asDateTime(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'name': name,
    'companyId': companyId,
    'details': details,
    'type': type,
    'parentId': parentId,
    'iconUrl': iconUrl,
    'productList': productList,
    'sortOrder': sortOrder,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
  };

  // --------------------------------------------------------------- Derived --

  int get productCount => productList.length;
  bool get hasIcon => iconUrl.trim().isNotEmpty;

  /// True when [iconUrl] points at a remote image rather than an emoji glyph.
  bool get hasImageIcon => isHttpUrl(iconUrl);

  // -------------------------------------------------------------- Mutation --

  Category copyWith({
    String? id,
    String? companyId,
    String? name,
    String? details,
    String? type,
    String? parentId,
    bool clearParentId = false,
    String? iconUrl,
    List<String>? productList,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      details: details ?? this.details,
      type: type ?? this.type,
      parentId: clearParentId
          ? null
          : ((parentId == null || parentId.isEmpty) ? this.parentId : parentId),
      iconUrl: iconUrl ?? this.iconUrl,
      productList: productList ?? this.productList,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Adds [productId] to [productList] (no duplicates).
  Category withProduct(String productId) => productList.contains(productId)
      ? this
      : copyWith(productList: <String>[...productList, productId]);

  /// Removes [productId] from [productList].
  Category withoutProduct(String productId) => copyWith(
    productList: productList
        .where((e) => e != productId)
        .toList(growable: false),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Category && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Category($id, $name, parent: $parentId)';
}
