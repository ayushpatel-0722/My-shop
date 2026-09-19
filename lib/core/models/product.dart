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
  final String size;
  final String color;

  const ProductVariant({
    this.sku = '',
    this.title = '',
    this.attributes = const {},
    this.stockQty = 0,
    this.isUnlimitedStock = false,
    this.priceOverride = 0,
    this.size = '',
    this.color = '',
  });

  bool get isInStock => isUnlimitedStock || stockQty > 0;

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
      stockQty: (map['stockQty'] as num?)?.toInt() ?? 0,
      isUnlimitedStock: map['isUnlimitedStock'] as bool? ?? false,
      priceOverride: (map['priceOverride'] as num?)?.toDouble() ?? 0.0,
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

  factory Product.fromMap(String id, Map<String, dynamic> map) => Product(
    id: id,
    companyId: map['companyId']?.toString() ?? '',
    categoryId: map['categoryId']?.toString() ?? '',
    name: map['name']?.toString() ?? '',
    details: map['details']?.toString() ?? '',
    type: map['type']?.toString() ?? 'quantity_based',
    unit: (map['unit'] as num?)?.toDouble() ?? 1.0,
    unitType: map['unitType']?.toString() ?? 'pieces',
    amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
    discountAmt: (map['discountAmt'] as num?)?.toDouble() ?? 0.0,
    subDetails: map['subDetails']?.toString() ?? '',
    images: (map['images'] as List? ?? const [])
        .map((e) => e.toString())
        .toList(),
    variants: (map['variants'] as List? ?? const [])
        .map((e) => ProductVariant.fromMap(e as Map<String, dynamic>))
        .toList(),
    options: (map['options'] as List? ?? const [])
        .map((e) => ProductOption.fromMap(e as Map<String, dynamic>))
        .toList(),
    specifications: (map['specifications'] as List? ?? const [])
        .map((e) => ProductSpec.fromMap(e as Map<String, dynamic>))
        .toList(),
    policy: map['policy']?.toString() ?? '',
    sku: map['sku']?.toString() ?? '',
    stockQty: (map['stockQty'] as num?)?.toInt() ?? 0,
    isUnlimitedStock: map['isUnlimitedStock'] as bool? ?? false,
    isRecommended: map['isRecommended'] ?? false,
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
      stockQty: stockQty ?? this.stockQty,
      isUnlimitedStock: isUnlimitedStock ?? this.isUnlimitedStock,
      isRecommended: isRecommended ?? this.isRecommended,
    );
  }
}
