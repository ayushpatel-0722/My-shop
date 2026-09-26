import '../utils/type_utils.dart';

/// How a product is measured and sold.
class ProductType {
  /// Sold by weight (kg / g / l ...).
  static const weightBased = 'weight_based';

  /// Sold by count (pieces / packs ...).
  static const quantityBased = 'quantity_based';

  static const values = <String>[weightBased, quantityBased];

  static String label(String type) =>
      type == weightBased ? 'Weight based' : 'Quantity based';
}

/// Product option definition (e.g. Option name: "Weight", values: ["250g", "500g", "1kg"]).
class ProductOption {
  final String name;
  final List<String> values;

  const ProductOption({required this.name, this.values = const []});

  factory ProductOption.fromMap(Map<String, dynamic> map) => ProductOption(
    name: map['name']?.toString() ?? '',
    values: (map['values'] as List? ?? const [])
        .map((e) => e.toString())
        .toList(),
  );

  Map<String, dynamic> toMap() => {'name': name, 'values': values};
}

/// Custom key-value specification pair (e.g. Key: "Fabric", Value: "100% Cotton").
class ProductSpec {
  final String key;
  final String value;

  const ProductSpec({required this.key, required this.value});

  factory ProductSpec.fromMap(Map<String, dynamic> map) => ProductSpec(
    key: map['key']?.toString() ?? '',
    value: map['value']?.toString() ?? '',
  );

  Map<String, dynamic> toMap() => {'key': key, 'value': value};
}

/// Product variant model representing a distinct combination of attributes.
class ProductVariant {
  final String sku;
  final String title;
  final Map<String, String> attributes;
  final int stockQty;
  final bool isUnlimitedStock;
  final double priceOverride;
  final double unitValue;
  final String unitType;
  final String size;
  final String color;

  const ProductVariant({
    this.sku = '',
    this.title = '',
    this.attributes = const {},
    this.stockQty = 0,
    this.isUnlimitedStock = false,
    this.priceOverride = 0,
    this.unitValue = 0,
    this.unitType = '',
    this.size = '',
    this.color = '',
  });

  bool get isInStock => isUnlimitedStock || stockQty > 0;

  ProductVariant copyWith({
    String? sku,
    String? title,
    Map<String, String>? attributes,
    int? stockQty,
    bool? isUnlimitedStock,
    double? priceOverride,
    double? unitValue,
    String? unitType,
    String? size,
    String? color,
  }) {
    return ProductVariant(
      sku: sku ?? this.sku,
      title: title ?? this.title,
      attributes: attributes ?? this.attributes,
      stockQty: stockQty ?? this.stockQty,
      isUnlimitedStock: isUnlimitedStock ?? this.isUnlimitedStock,
      priceOverride: priceOverride ?? this.priceOverride,
      unitValue: unitValue ?? this.unitValue,
      unitType: unitType ?? this.unitType,
      size: size ?? this.size,
      color: color ?? this.color,
    );
  }

  factory ProductVariant.fromMap(Map<String, dynamic> map) {
    final rawAttrs = map['attributes'] as Map?;
    final attrs = rawAttrs != null
        ? rawAttrs.map((k, v) => MapEntry(k.toString(), v.toString()))
        : <String, String>{};

    final rawSize = map['size']?.toString() ?? attrs['Size'] ?? '';
    final rawColor = map['color']?.toString() ?? attrs['Color'] ?? '';
    final rawTitle = map['title']?.toString() ?? '';

    return ProductVariant(
      sku: map['sku']?.toString() ?? '',
      title: rawTitle.isNotEmpty
          ? rawTitle
          : (attrs.isNotEmpty
                ? attrs.values.join(' / ')
                : ([rawSize, rawColor].where((s) => s.isNotEmpty).join(' / '))),
      attributes: attrs.isNotEmpty
          ? attrs
          : {
              if (rawSize.isNotEmpty) 'Size': rawSize,
              if (rawColor.isNotEmpty) 'Color': rawColor,
            },
      stockQty: asInt(map['stockQty']),
      isUnlimitedStock: asBool(map['isUnlimitedStock']),
      priceOverride: asDouble(map['priceOverride']),
      unitValue: asDouble(map['unitValue'] ?? map['unit']),
      unitType: map['unitType']?.toString() ?? '',
      size: rawSize,
      color: rawColor,
    );
  }

  Map<String, dynamic> toMap() => {
    'sku': sku,
    'title': title,
    'attributes': attributes,
    'stockQty': stockQty,
    'isUnlimitedStock': isUnlimitedStock,
    'priceOverride': priceOverride,
    'unitValue': unitValue,
    'unitType': unitType,
    'size': size,
    'color': color,
  };
}

/// Product model (Firestore: /products).
class Product {
  final String id;
  final String companyId;
  final String categoryId;
  final String name;
  final String details;
  final String type; // weight_based | quantity_based
  final double unit;
  final String unitType; // kg | grams | pieces | liters | etc.
  final double amount;
  final double discountAmt; // active selling price when discounted
  final String subDetails;
  final List<String> images;
  final List<ProductVariant> variants;
  final List<ProductOption> options;
  final List<ProductSpec> specifications;
  final String policy;
  final String sku;
  final String color;
  final int stockQty;
  final bool isUnlimitedStock;
  final bool isRecommended;

  const Product({
    required this.id,
    required this.companyId,
    required this.categoryId,
    required this.name,
    this.details = '',
    this.type = 'quantity_based',
    this.unit = 1,
    this.unitType = 'pieces',
    this.amount = 0,
    this.discountAmt = 0,
    this.subDetails = '',
    this.images = const [],
    this.variants = const [],
    this.options = const [],
    this.specifications = const [],
    this.policy = '',
    this.sku = '',
    this.color = '',
    this.stockQty = 0,
    this.isUnlimitedStock = false,
    this.isRecommended = false,
  });

  /// Effective selling price.
  double get price => discountAmt > 0 ? discountAmt : amount;

  double get discountPercent => amount > 0 && discountAmt > 0
      ? ((amount - discountAmt) / amount) * 100
      : 0;

  bool get isDiscounted => discountAmt > 0 && discountAmt < amount;

  bool get isInStock => isUnlimitedStock || stockQty > 0;

  /// True when stock tracking is on and the quantity is at or below [threshold].
  bool isLowStock({int threshold = 20}) =>
      !isUnlimitedStock && stockQty > 0 && stockQty <= threshold;

  /// Lower-cased haystack used by catalogue search.
  String get searchIndex => <String>[
    name,
    sku,
    details,
    subDetails,
    unitType,
    policy,
  ].join(' ').toLowerCase();

  /// Case-insensitive, multi-term search over [searchIndex].
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    for (final term in q.split(RegExp(r'\s+'))) {
      if (term.isEmpty) continue;
      if (!searchIndex.contains(term)) return false;
    }
    return true;
  }

  /// Primary image (empty string when the product has none).
  String get imageUrl => images.isNotEmpty ? images.first : '';

  /// Blank product pre-filled with the tenant/company it belongs to.
  factory Product.empty({String companyId = '', String categoryId = ''}) =>
      Product(
        id: '',
        companyId: companyId,
        categoryId: categoryId,
        name: '',
        unit: 1,
        unitType: 'pieces',
      );

  factory Product.fromMap(String id, Map<String, dynamic> map) => Product(
    id: id,
    companyId: asString(map['companyId']),
    categoryId: asString(map['categoryId']),
    name: asString(map['name']),
    details: asString(map['details']),
    type: ProductType.values.contains(map['type'])
        ? asString(map['type'])
        : ProductType.quantityBased,
    unit: asDouble(map['unit'], 1),
    unitType: asString(map['unitType'], 'pieces'),
    amount: asDouble(map['amount']),
    discountAmt: asDouble(map['discountAmt']),
    subDetails: asString(map['subDetails']),
    images: asStringList(map['images']),
    variants: asMapList(map['variants']).map(ProductVariant.fromMap).toList(),
    options: asMapList(map['options']).map(ProductOption.fromMap).toList(),
    specifications: asMapList(
      map['specifications'],
    ).map(ProductSpec.fromMap).toList(),
    policy: asString(map['policy']),
    sku: asString(map['sku']),
    color: asString(map['color']),
    stockQty: asInt(map['stockQty']),
    isUnlimitedStock: asBool(map['isUnlimitedStock']),
    isRecommended: asBool(map['isRecommended']),
  );

  Map<String, dynamic> toMap() => {
    'companyId': companyId,
    'categoryId': categoryId,
    'name': name,
    'details': details,
    'type': type,
    'unit': unit,
    'unitType': unitType,
    'amount': amount,
    'discountAmt': discountAmt,
    'subDetails': subDetails,
    'images': images,
    'variants': variants.map((e) => e.toMap()).toList(),
    'options': options.map((e) => e.toMap()).toList(),
    'specifications': specifications.map((e) => e.toMap()).toList(),
    'policy': policy,
    'sku': sku,
    'color': color,
    'stockQty': stockQty,
    'isUnlimitedStock': isUnlimitedStock,
    'isRecommended': isRecommended,
  };

  Product copyWith({
    String? id,
    String? companyId,
    String? categoryId,
    String? name,
    String? details,
    String? type,
    double? unit,
    String? unitType,
    double? amount,
    double? discountAmt,
    String? subDetails,
    List<String>? images,
    List<ProductVariant>? variants,
    List<ProductOption>? options,
    List<ProductSpec>? specifications,
    String? policy,
    String? sku,
    String? color,
    int? stockQty,
    bool? isUnlimitedStock,
    bool? isRecommended,
  }) {
    return Product(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      details: details ?? this.details,
      type: type ?? this.type,
      unit: unit ?? this.unit,
      unitType: unitType ?? this.unitType,
      amount: amount ?? this.amount,
      discountAmt: discountAmt ?? this.discountAmt,
      subDetails: subDetails ?? this.subDetails,
      images: images ?? this.images,
      variants: variants ?? this.variants,
      options: options ?? this.options,
      specifications: specifications ?? this.specifications,
      policy: policy ?? this.policy,
      sku: sku ?? this.sku,
      color: color ?? this.color,
      stockQty: stockQty ?? this.stockQty,
      isUnlimitedStock: isUnlimitedStock ?? this.isUnlimitedStock,
      isRecommended: isRecommended ?? this.isRecommended,
    );
  }
}
