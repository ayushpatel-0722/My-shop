/// Product model (Firestore: /products).
class Product {
  final String id;
  final String companyId;
  final String categoryId;
  final String name;
  final String details;
  final String type; // weight_based | quantity_based
  final double unit;
  final String unitType; // kg | grams | pieces | liters
  final double amount;
  final double discountAmt; // active selling price when discounted
  final String subDetails;
  final List<String> images;
  final List<ProductVariant> variants;
  final int stockQty;
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
    this.stockQty = 0,
    this.isRecommended = false,
  });

  /// Effective selling price.
  double get price => discountAmt > 0 ? discountAmt : amount;

  double get discountPercent =>
      amount > 0 && discountAmt > 0 ? ((amount - discountAmt) / amount) * 100 : 0;

  bool get isDiscounted => discountAmt > 0 && discountAmt < amount;

  factory Product.fromMap(String id, Map<String, dynamic> map) => Product(
        id: id,
        companyId: map['companyId'] ?? '',
        categoryId: map['categoryId'] ?? '',
        name: map['name'] ?? '',
        details: map['details'] ?? '',
        type: map['type'] ?? 'quantity_based',
        unit: (map['unit'] ?? 1).toDouble(),
        unitType: map['unitType'] ?? 'pieces',
        amount: (map['amount'] ?? 0).toDouble(),
        discountAmt: (map['discountAmt'] ?? 0).toDouble(),
        subDetails: map['subDetails'] ?? '',
        images: List<String>.from(map['images'] ?? const []),
        variants: (map['variants'] as List? ?? const [])
            .map((e) => ProductVariant.fromMap(e))
            .toList(),
        stockQty: map['stockQty'] ?? 0,
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
        'stockQty': stockQty,
        'isRecommended': isRecommended,
      };
}

class ProductVariant {
  final String size;
  final String color;
  final String sku;
  final int stockQty;
  final double priceOverride;

  const ProductVariant({
    this.size = '',
    this.color = '',
    this.sku = '',
    this.stockQty = 0,
    this.priceOverride = 0,
  });

  factory ProductVariant.fromMap(Map<String, dynamic> map) => ProductVariant(
        size: map['size'] ?? '',
        color: map['color'] ?? '',
        sku: map['sku'] ?? '',
        stockQty: map['stockQty'] ?? 0,
        priceOverride: (map['priceOverride'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'size': size,
        'color': color,
        'sku': sku,
        'stockQty': stockQty,
        'priceOverride': priceOverride,
      };
}
