import 'dart:convert';

import '../../app/l10n/l10n_service.dart';
import '../utils/type_utils.dart';

/// How a product is measured and sold.
class ProductType {
  /// Sold by weight (kg / g / l ...).
  static const weightBased = 'weight_based';

  /// Sold by count (pieces / packs ...).
  static const quantityBased = 'quantity_based';

  static const values = <String>[weightBased, quantityBased];

  static String label(String type) => type == weightBased
      ? L10n.current.weightBased
      : L10n.current.quantityBased;
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

// ---------------------------------------------------------------------------
// Structured product content (Flipkart style: Highlights + All Details)
// ---------------------------------------------------------------------------

/// One "Product Highlights" row (Title + Value), e.g. RAM / 8 GB.
class HighlightItem {
  final String id;
  final String title;
  final String value;
  final int order;

  const HighlightItem({
    this.id = '',
    this.title = '',
    this.value = '',
    this.order = 0,
  });

  bool get isEmpty => title.trim().isEmpty && value.trim().isEmpty;

  /// Usable for saving: the value carries the content. The title is optional
  /// because migrated legacy highlights land as value-only rows.
  bool get isUsable => value.trim().isNotEmpty;

  /// A row someone started (title typed) but did not finish (no value).
  bool get isHalfWritten => title.trim().isNotEmpty && value.trim().isEmpty;

  bool get isComplete => title.trim().isNotEmpty && value.trim().isNotEmpty;

  factory HighlightItem.fromMap(Map<String, dynamic> map) => HighlightItem(
    id: asString(map['id']),
    title: asString(map['title']),
    value: asString(map['value']),
    order: asInt(map['order']),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'value': value,
    'order': order,
  };

  HighlightItem copyWith({
    String? id,
    String? title,
    String? value,
    int? order,
  }) => HighlightItem(
    id: id ?? this.id,
    title: title ?? this.title,
    value: value ?? this.value,
    order: order ?? this.order,
  );

  @override
  String toString() => 'HighlightItem($title: $value)';
}

/// Section types allowed inside "All Details".
class DetailSectionType {
  /// A plain paragraph of text.
  static const text = 'text';

  /// A repeatable list of Title/Value rows.
  static const keyValue = 'keyValue';

  static const values = <String>[text, keyValue];

  static bool isValid(String type) => values.contains(type);
}

/// One Title/Value row inside a [DetailSectionType.keyValue] section.
class DetailItem {
  final String id;
  final String title;
  final String value;
  final int order;

  const DetailItem({
    this.id = '',
    this.title = '',
    this.value = '',
    this.order = 0,
  });

  bool get isEmpty => title.trim().isEmpty && value.trim().isEmpty;
  bool get isComplete => title.trim().isNotEmpty && value.trim().isNotEmpty;

  factory DetailItem.fromMap(Map<String, dynamic> map) => DetailItem(
    id: asString(map['id']),
    title: asString(map['title']),
    value: asString(map['value']),
    order: asInt(map['order']),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'value': value,
    'order': order,
  };

  DetailItem copyWith({String? id, String? title, String? value, int? order}) =>
      DetailItem(
        id: id ?? this.id,
        title: title ?? this.title,
        value: value ?? this.value,
        order: order ?? this.order,
      );

  @override
  String toString() => 'DetailItem($title: $value)';
}

/// One section of "All Details" (a heading + its content).
///
/// A `text` section stores only [text]; a `keyValue` section stores only
/// [items]. Everything lives inside the product document (no subcollection) so
/// the product loads in one read.
class DetailSection {
  final String id;
  final String title;

  /// Exactly [DetailSectionType.text] or [DetailSectionType.keyValue].
  final String type;
  final String text;
  final List<DetailItem> items;
  final int order;

  const DetailSection({
    this.id = '',
    this.title = '',
    this.type = DetailSectionType.text,
    this.text = '',
    this.items = const <DetailItem>[],
    this.order = 0,
  });

  bool get isText => type == DetailSectionType.text;
  bool get isKeyValue => type == DetailSectionType.keyValue;

  /// True when the section carries nothing worth showing.
  bool get isEmptyContent =>
      isText ? text.trim().isEmpty : items.every((e) => e.isEmpty);

  /// Sorted copy of [items] by their `order` field.
  List<DetailItem> get sortedItems {
    final copy = [...items];
    copy.sort((a, b) => a.order.compareTo(b.order));
    return copy;
  }

  factory DetailSection.fromMap(Map<String, dynamic> map) {
    final rawType = asString(map['type']);
    return DetailSection(
      id: asString(map['id']),
      title: asString(map['title']),
      type: DetailSectionType.isValid(rawType)
          ? rawType
          : DetailSectionType.text,
      text: asString(map['text']),
      items: asMapList(map['items']).map(DetailItem.fromMap).toList(),
      order: asInt(map['order']),
    );
  }

  Map<String, dynamic> toMap() {
    // A "text" section stores only "text"; a "keyValue" section only "items".
    return {
      'id': id,
      'title': title,
      'type': type,
      if (isText) 'text': text,
      if (isKeyValue) 'items': items.map((e) => e.toMap()).toList(),
      'order': order,
    };
  }

  DetailSection copyWith({
    String? id,
    String? title,
    String? type,
    String? text,
    List<DetailItem>? items,
    int? order,
  }) => DetailSection(
    id: id ?? this.id,
    title: title ?? this.title,
    type: type ?? this.type,
    text: text ?? this.text,
    items: items ?? this.items,
    order: order ?? this.order,
  );

  @override
  String toString() => 'DetailSection($title, $type)';
}

// ---------------------------------------------------------------------------

/// Product variant model representing a distinct combination of attributes.
class ProductVariant {
  /// Stable identity used for cart keys (`productId_variantId`) and orders.
  /// Falls back to sku / title when the data predates the id field.
  final String id;
  final String sku;
  final String title;
  final Map<String, String> attributes;
  final int stockQty;
  final bool isUnlimitedStock;
  final double priceOverride;

  /// List price (MRP) of THIS variant; 0 means "derive from the product".
  final double mrpOverride;
  final double unitValue;
  final String unitType;
  final String size;
  final String color;

  const ProductVariant({
    this.id = '',
    this.sku = '',
    this.title = '',
    this.attributes = const {},
    this.stockQty = 0,
    this.isUnlimitedStock = false,
    this.priceOverride = 0,
    this.mrpOverride = 0,
    this.unitValue = 0,
    this.unitType = '',
    this.size = '',
    this.color = '',
  });

  bool get isInStock => isUnlimitedStock || stockQty > 0;

  /// Identity used inside cart keys and order snapshots.
  String get variantId {
    if (id.isNotEmpty) return id;
    if (sku.isNotEmpty) return sku;
    if (title.isNotEmpty) return title;
    if (size.isNotEmpty || color.isNotEmpty) return '${size}_$color';
    return attributes.values.join('_');
  }

  /// Human label ("500g", "Black", ...).
  String get label {
    if (title.isNotEmpty) return title;
    if (attributes.isNotEmpty) return attributes.values.join(' / ');
    final parts = [size, color].where((s) => s.isNotEmpty).join(' / ');
    return parts.isNotEmpty ? parts : sku;
  }

  /// "500 g" style label of the pack size, or '' when unknown.
  String get unitLabel {
    if (unitValue > 0 && unitType.isNotEmpty) {
      return CartUnit.format(unitValue, unitType);
    }
    return '';
  }

  ProductVariant copyWith({
    String? id,
    String? sku,
    String? title,
    Map<String, String>? attributes,
    int? stockQty,
    bool? isUnlimitedStock,
    double? priceOverride,
    double? mrpOverride,
    double? unitValue,
    String? unitType,
    String? size,
    String? color,
  }) {
    return ProductVariant(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      title: title ?? this.title,
      attributes: attributes ?? this.attributes,
      stockQty: stockQty ?? this.stockQty,
      isUnlimitedStock: isUnlimitedStock ?? this.isUnlimitedStock,
      priceOverride: priceOverride ?? this.priceOverride,
      mrpOverride: mrpOverride ?? this.mrpOverride,
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

    final rawSize = map['size']?.toString() ?? attrs[L10n.current.size] ?? '';
    final rawColor =
        map['color']?.toString() ?? attrs[L10n.current.color] ?? '';
    final rawTitle = map['title']?.toString() ?? '';

    return ProductVariant(
      id: asString(map['id'] ?? map['variantId']),
      sku: map['sku']?.toString() ?? '',
      title: rawTitle.isNotEmpty
          ? rawTitle
          : (attrs.isNotEmpty
                ? attrs.values.join(' / ')
                : ([rawSize, rawColor].where((s) => s.isNotEmpty).join(' / '))),
      attributes: attrs.isNotEmpty
          ? attrs
          : {
              if (rawSize.isNotEmpty) L10n.current.size: rawSize,
              if (rawColor.isNotEmpty) L10n.current.color: rawColor,
            },
      stockQty: asInt(map['stockQty']),
      isUnlimitedStock: asBool(map['isUnlimitedStock']),
      priceOverride: asDouble(map['priceOverride']),
      mrpOverride: asDouble(map['mrpOverride'] ?? map['mrp']),
      unitValue: asDouble(map['unitValue'] ?? map['unit']),
      unitType: map['unitType']?.toString() ?? '',
      size: rawSize,
      color: rawColor,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'sku': sku,
    'title': title,
    'attributes': attributes,
    'stockQty': stockQty,
    'isUnlimitedStock': isUnlimitedStock,
    'priceOverride': priceOverride,
    'mrpOverride': mrpOverride,
    'unitValue': unitValue,
    'unitType': unitType,
    'size': size,
    'color': color,
  };
}

/// Unit formatting shared by cart lines, order snapshots and pack labels.
///
/// "500 grams" -> "500 g"; "1500 grams" -> "1.5 kg"; "2 pieces" -> "2 pieces".
class CartUnit {
  const CartUnit._();

  /// Parses a trailing measurement out of a label ("500g", "1 kg", "250 ml").
  ///
  /// Returns `null` when the text carries no recognised unit.
  static ({double value, String unitType})? tryParse(String text) {
    final m = RegExp(
      r'(\d+(?:\.\d+)?)\s*(kg|kgs|kilograms?|g|gm|grams?|ml|l|litres?|liters?)\b',
      caseSensitive: false,
    ).firstMatch(text.trim());
    if (m == null) return null;
    final value = double.tryParse(m.group(1) ?? '') ?? 0;
    if (value <= 0) return null;
    var unit = (m.group(2) ?? '').toLowerCase();
    if (unit == 'gm' || unit == 'gram' || unit == 'grams') unit = 'g';
    if (unit == 'kgs' || unit == 'kilogram' || unit == 'kilograms') {
      unit = 'kg';
    }
    if (unit == 'litre' ||
        unit == 'litres' ||
        unit == 'liter' ||
        unit == 'liters') {
      unit = 'l';
    }
    // Normalise to the smallest sensible unit so maths never mixes kg and g.
    if (unit == 'kg') return (value: value * 1000, unitType: 'g');
    if (unit == 'l') return (value: value * 1000, unitType: 'ml');
    return (value: value, unitType: unit);
  }

  static String format(double amount, String unitType) {
    final unit = unitType.trim().toLowerCase();
    var value = amount;
    var suffix = unitType.isEmpty ? 'unit' : unitType;

    if (unit == 'grams' || unit == 'gram' || unit == 'g' || unit == 'gm') {
      if (amount >= 1000) {
        value = amount / 1000;
        suffix = 'kg';
      } else {
        suffix = 'g';
      }
    } else if (unit == 'ml' ||
        unit == 'millilitre' ||
        unit == 'millilitres' ||
        unit == 'milliliters' ||
        unit == 'millilitres') {
      if (amount >= 1000) {
        value = amount / 1000;
        suffix = 'L';
      } else {
        suffix = 'ml';
      }
    } else if (unit == 'kg' || unit == 'kgs' || unit == 'kilogram') {
      suffix = 'kg';
    } else if (unit == 'l' || unit == 'litre' || unit == 'liters') {
      suffix = 'L';
    }

    final rounded = value == value.roundToDouble()
        ? value.toInt().toString()
        : (value * 10).roundToDouble() == value * 10
        ? value.toStringAsFixed(1)
        : value.toStringAsFixed(2);
    return '$rounded $suffix';
  }

  /// True for weight/volume measures ("g", "kg", "ml", "l", ...).
  static bool isMeasured(String unitType) {
    final t = unitType.trim().toLowerCase();
    return t == 'g' ||
        t == 'gm' ||
        t == 'gram' ||
        t == 'grams' ||
        t == 'kg' ||
        t == 'kgs' ||
        t == 'kilogram' ||
        t == 'ml' ||
        t == 'millilitre' ||
        t == 'millilitres' ||
        t == 'milliliters' ||
        t == 'l' ||
        t == 'litre' ||
        t == 'litres' ||
        t == 'liters';
  }
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

  /// Structured "Product Highlights" rows (Flipkart style).
  final List<HighlightItem> highlights;

  /// Structured "All Details" sections (text | keyValue).
  final List<DetailSection> allDetails;
  final String policy;
  final String sku;
  final String color;
  final int stockQty;
  final bool isUnlimitedStock;
  final bool isRecommended;

  const Product({
    required this.id,
    required this.companyId,
    this.categoryId = '',
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
    this.highlights = const [],
    this.allDetails = const [],
    this.policy = '',
    this.sku = '',
    this.color = '',
    this.stockQty = 0,
    this.isUnlimitedStock = false,
    this.isRecommended = false,
  });

  /// Effective selling price.
  double get price => discountAmt > 0 ? discountAmt : amount;

  /// List price (MRP) of the base product.
  double get mrp => amount > 0 ? amount : price;

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
    categoryId,
    categoryId.replaceAll('cat_', '').replaceAll('_', ' ').replaceAll('-', ' '),
    details,
    subDetails,
    unitType,
    policy,
    ...highlights.map((h) => '${h.title} ${h.value}'),
    ...allDetails.map((s) => '${s.title} ${s.text}'),
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

  /// Highlights sorted by their `order` field.
  List<HighlightItem> get sortedHighlights {
    final copy = [...highlights];
    copy.sort((a, b) => a.order.compareTo(b.order));
    return copy;
  }

  /// All-details sections sorted by their `order` field.
  List<DetailSection> get sortedAllDetails {
    final copy = [...allDetails];
    copy.sort((a, b) => a.order.compareTo(b.order));
    return copy;
  }

  /// Selling price of [variant] (falls back to the product price).
  double priceOf(ProductVariant? variant) =>
      (variant != null && variant.priceOverride > 0)
      ? variant.priceOverride
      : price;

  /// List price (MRP) of [variant] (falls back to the product MRP).
  double mrpOf(ProductVariant? variant) {
    final base = (variant != null && variant.mrpOverride > 0)
        ? variant.mrpOverride
        : mrp;
    final price = priceOf(variant);
    // A list price below the selling price makes no sense — never show a
    // strikethrough that is lower than the actual price.
    return base < price ? price : base;
  }

  /// Index of the variant pre-selected on the product page.
  ///
  /// Prefers the variant matching the product's own pack size ("1 kg" of a
  /// 1 kg product), then the biggest pack, then the first one.
  int get defaultVariantIndex {
    if (variants.isEmpty) return -1;
    for (var i = 0; i < variants.length; i++) {
      final v = variants[i];
      if (v.unitValue > 0 &&
          unit > 0 &&
          (v.unitValue - unit).abs() < 0.0001 &&
          _sameUnitType(v.unitType, unitType)) {
        return i;
      }
    }
    // Biggest pack first (1kg over 500g over 250g).
    var best = 0;
    for (var i = 1; i < variants.length; i++) {
      if (variants[i].unitValue > variants[best].unitValue) best = i;
    }
    if (variants[best].unitValue > 0) return best;
    return 0;
  }

  static bool _sameUnitType(String a, String b) {
    String norm(String s) {
      final t = s.trim().toLowerCase();
      if (t == 'gram' || t == 'grams' || t == 'gm') return 'g';
      if (t == 'kgs') return 'kg';
      if (t == 'litre' || t == 'liters') return 'l';
      return t;
    }

    return norm(a) == norm(b);
  }

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

  static List<String> _parseProductImages(Map<String, dynamic> map) {
    final list = <String>[];
    void add(dynamic val) {
      if (val == null) return;
      if (val is Iterable) {
        for (final item in val) {
          add(item);
        }
      } else if (val is String) {
        final trimmed = val.trim();
        if (trimmed.isEmpty) return;
        if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
          try {
            final decoded = jsonDecode(trimmed);
            if (decoded is Iterable) {
              for (final d in decoded) {
                add(d);
              }
              return;
            }
          } catch (_) {}
        }
        if (!list.contains(trimmed)) {
          list.add(trimmed);
        }
      }
    }

    add(map['images']);
    add(map['imageUrls']);
    add(map['imageUrl']);
    add(map['image']);
    add(map['productImage']);
    add(map['photoUrl']);
    add(map['thumbnailUrl']);
    add(map['picture']);

    return List<String>.unmodifiable(list);
  }

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
    images: _parseProductImages(map),
    variants: asMapList(map['variants']).map(ProductVariant.fromMap).toList(),
    options: asMapList(map['options']).map(ProductOption.fromMap).toList(),
    specifications: asMapList(
      map['specifications'],
    ).map(ProductSpec.fromMap).toList(),
    highlights: asMapList(
      map['highlights'],
    ).map(HighlightItem.fromMap).toList(),
    allDetails: asMapList(
      map['allDetails'],
    ).map(DetailSection.fromMap).toList(),
    policy: asString(map['policy']),
    sku: asString(map['sku']),
    color: asString(map['color']),
    stockQty: asInt(map['stockQty']),
    isUnlimitedStock: asBool(map['isUnlimitedStock']),
    isRecommended: asBool(map['isRecommended']),
  );

  Map<String, dynamic> toMap() => {
    'companyId': companyId,
    if (categoryId.isNotEmpty) 'categoryId': categoryId,
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
    'highlights': highlights.map((e) => e.toMap()).toList(),
    'allDetails': allDetails.map((e) => e.toMap()).toList(),
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
    List<HighlightItem>? highlights,
    List<DetailSection>? allDetails,
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
      highlights: highlights ?? this.highlights,
      allDetails: allDetails ?? this.allDetails,
      policy: policy ?? this.policy,
      sku: sku ?? this.sku,
      color: color ?? this.color,
      stockQty: stockQty ?? this.stockQty,
      isUnlimitedStock: isUnlimitedStock ?? this.isUnlimitedStock,
      isRecommended: isRecommended ?? this.isRecommended,
    );
  }
}
