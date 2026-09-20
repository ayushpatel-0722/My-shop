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

  /// Products explicitly assigned to this category.
  final List<String> productList;

  const Category({
    required this.id,
    required this.name,
    this.companyId = '',
    this.details = '',
    this.type = '',
    this.parentId,
    this.iconUrl = '',
    this.productList = const <String>[],
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
      };

  // --------------------------------------------------------------- Derived --

  bool get isRoot => parentId == null || parentId!.isEmpty;
  bool get isGlobal => companyId.isEmpty;
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
    );
  }

  /// Adds [productId] to [productList] (no duplicates).
  Category withProduct(String productId) => productList.contains(productId)
      ? this
      : copyWith(productList: <String>[...productList, productId]);

  /// Removes [productId] from [productList].
  Category withoutProduct(String productId) => copyWith(
        productList:
            productList.where((e) => e != productId).toList(growable: false),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Category && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Category($id, $name, parent: $parentId)';
}
