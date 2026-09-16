/// Category model (Firestore: /categories) — supports nested trees via parentId.
class Category {
  final String id;
  final String companyId; // empty = global
  final String name;
  final String details;
  final String type;
  final String? parentId;
  final String iconUrl;
  final List<String> productList;

  const Category({
    required this.id,
    required this.name,
    this.companyId = '',
    this.details = '',
    this.type = '',
    this.parentId,
    this.iconUrl = '',
    this.productList = const [],
  });

  factory Category.fromMap(String id, Map<String, dynamic> map) => Category(
        id: id,
        name: map['name'] ?? '',
        companyId: map['companyId'] ?? '',
        details: map['details'] ?? '',
        type: map['type'] ?? '',
        parentId: map['parentId'],
        iconUrl: map['iconUrl'] ?? '',
        productList: List<String>.from(map['productList'] ?? const []),
      );

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
      parentId: clearParentId ? null : (parentId ?? this.parentId),
      iconUrl: iconUrl ?? this.iconUrl,
      productList: productList ?? this.productList,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'companyId': companyId,
        'details': details,
        'type': type,
        'parentId': parentId,
        'iconUrl': iconUrl,
        'productList': productList,
      };
}
