import 'product.dart';

/// Frozen copy of the variant the shopper actually picked.
///
/// Cart rows, checkout and orders must NEVER read label/price/unit from
/// `product.defaultVariant`: the snapshot is written at "Add to Cart" time and
/// everything downstream (labels, prices, MRP, stock, stepper unit) reads from
/// it. Two rows of the same product with different variants stay separate
/// (`productId_variantId`), while repeating the same variant only bumps the
/// quantity.
class VariantSnapshot {
  final String variantId;
  final String label;
  final double unitValue;
  final String unitType;

  /// Selling price of THIS variant (in currency units).
  final double price;

  /// List price (MRP) of THIS variant; equal to [price] when not discounted.
  final double mrp;

  /// Units left; -1 means stock is not tracked (unlimited).
  final int stock;

  const VariantSnapshot({
    required this.variantId,
    this.label = '',
    this.unitValue = 0,
    this.unitType = '',
    required this.price,
    double? mrp,
    this.stock = -1,
  }) : mrp = mrp ?? price;

  bool get hasUnit => unitValue > 0 && unitType.isNotEmpty;

  /// "500 g" style pack size, falling back to the display label.
  String get unitLabel => hasUnit
      ? CartUnit.format(unitValue, unitType)
      : label;

  /// True when stock is not tracked at all.
  bool get isUnlimitedStock => stock < 0;

  bool get isInStock => isUnlimitedStock || stock > 0;

  /// Builds the snapshot of [variant] as sold with [product].
  ///
  /// The size of the pack comes from the variant's own `unitValue/unitType`;
  /// when older data only carries a label ("500g"), the measurement is parsed
  /// out of it. It never falls back to the product's default size, which is
  /// exactly the bug this snapshot exists to prevent.
  factory VariantSnapshot.fromVariant(Product product, ProductVariant variant) {
    final price = variant.priceOverride > 0
        ? variant.priceOverride
        : product.price;
    final mrpBase = variant.mrpOverride > 0
        ? variant.mrpOverride
        : product.mrp;
    var unitValue = variant.unitValue;
    var unitType = variant.unitType;
    if (unitValue <= 0 || unitType.isEmpty) {
      final parsed = CartUnit.tryParse(variant.label);
      if (parsed != null) {
        unitValue = parsed.value;
        unitType = parsed.unitType;
      } else {
        unitValue = 0;
        unitType = '';
      }
    }
    return VariantSnapshot(
      variantId: variant.variantId,
      label: variant.label,
      unitValue: unitValue,
      unitType: unitType,
      price: price,
      mrp: mrpBase < price ? price : mrpBase,
      stock: variant.isUnlimitedStock ? -1 : variant.stockQty,
    );
  }

  /// Snapshot of a product sold without any variant selection.
  factory VariantSnapshot.fromProduct(Product product) => VariantSnapshot(
    variantId: '',
    label: '',
    unitValue: product.unit,
    unitType: product.unitType,
    price: product.price,
    mrp: product.mrp,
    stock: product.isUnlimitedStock ? -1 : product.stockQty,
  );

  factory VariantSnapshot.fromMap(Map<String, dynamic> map) {
    final stock = (map['stock'] as num?)?.toInt() ?? -1;
    return VariantSnapshot(
      variantId: map['variantId']?.toString() ?? '',
      label: map['label']?.toString() ?? '',
      unitValue: (map['unitValue'] as num?)?.toDouble() ?? 0,
      unitType: map['unitType']?.toString() ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0,
      mrp: (map['mrp'] as num?)?.toDouble(),
      stock: stock,
    );
  }

  Map<String, dynamic> toMap() => {
    'variantId': variantId,
    'label': label,
    'unitValue': unitValue,
    'unitType': unitType,
    'price': price,
    'mrp': mrp,
    'stock': stock,
  };

  @override
  String toString() =>
      'VariantSnapshot($variantId [$label] $price/$unitLabel stock: $stock)';
}

/// Cart line item (client-side, grouped by company at checkout).
///
/// `variant` is the [VariantSnapshot] taken when the line was added — the cart,
/// checkout and order screens all derive labels and money from it.
class CartItem {
  final String companyId;
  final String companyName;
  final Product product;
  final VariantSnapshot? variant;
  final int qty;

  const CartItem({
    required this.companyId,
    required this.companyName,
    required this.product,
    this.variant,
    this.qty = 1,
  });

  /// Builds a line carrying a full snapshot of the selected variant.
  factory CartItem.fromSelection({
    required String companyId,
    required String companyName,
    required Product product,
    ProductVariant? selectedVariant,
    int qty = 1,
  }) {
    // No explicit selection on a VARIANT product resolves to the product's
    // default variant (product details preselects it: "1 kg" of a 1 kg
    // product, else the biggest pack). Snapshotting the product's own
    // price/unit for a variant product was the original bug — the line must
    // always carry one concrete variant's data.
    ProductVariant? resolved = selectedVariant;
    if (resolved == null && product.variants.isNotEmpty) {
      final idx = product.defaultVariantIndex;
      if (idx >= 0 && idx < product.variants.length) {
        resolved = product.variants[idx];
      }
    }
    return CartItem(
      companyId: companyId,
      companyName: companyName,
      product: product,
      variant: resolved != null
          ? VariantSnapshot.fromVariant(product, resolved)
          : VariantSnapshot.fromProduct(product),
      qty: qty < 1 ? 1 : qty,
    );
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    final variantMap = map['variant'];
    return CartItem(
      companyId: map['companyId']?.toString() ?? '',
      companyName: map['companyName']?.toString() ?? '',
      product: map['product'] is Map
          ? Product.fromMap(
              map['productId']?.toString() ?? '',
              Map<String, dynamic>.from(map['product'] as Map),
            )
          : Product(
              id: map['productId']?.toString() ?? '',
              companyId: map['companyId']?.toString() ?? '',
              categoryId: '',
              name: map['productName']?.toString() ?? '',
              images: [
                if ((map['image']?.toString() ?? '').isNotEmpty)
                  map['image'].toString(),
              ],
            ),
      variant: variantMap is Map
          ? VariantSnapshot.fromMap(Map<String, dynamic>.from(variantMap))
          : null,
      qty: (map['quantity'] as num?)?.toInt() ?? (map['qty'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toMap() => {
    'cartItemId': cartKey,
    'productId': product.id,
    'companyId': companyId,
    'companyName': companyName,
    'productName': product.name,
    'image': product.imageUrl,
    'variant': variant?.toMap(),
    'quantity': qty,
    'itemTotal': lineTotal,
    'itemMrpTotal': lineMrpTotal,
  };

  /// Effective unit price taking the variant snapshot into account.
  /// Variant id from the frozen snapshot ('' for no-variant products).
  /// Never falls back to a product default — the snapshot is what was sold.
  String get variantId => variant?.variantId ?? '';

  /// Pack size from the frozen snapshot (0 / '' when the line has no variant).
  double get unitValue => variant?.unitValue ?? 0;

  String get unitType => variant?.unitType ?? '';

  double get effectivePrice => variant?.price ?? product.price;

  /// Effective unit MRP (list price) of this line.
  double get effectiveMrp => variant?.mrp ?? product.mrp;

  double get lineTotal => effectivePrice * qty;

  /// `mrp × qty` — the pre-discount value of the line.
  double get lineMrpTotal => effectiveMrp * qty;

  /// MRP saved on this line (`0` when nothing was discounted).
  double get lineDiscount {
    final d = lineMrpTotal - lineTotal;
    return d > 0 ? d : 0;
  }

  /// Total measured amount of the line ("2 × 500g = 1000g").
  double get totalQuantityInUnit {
    if (variant != null && variant!.hasUnit) return variant!.unitValue * qty;
    return product.unit * qty;
  }

  /// Unique identifier key for cart grouping and item management.
  ///
  /// Same product + same variant merge into one row; different variants of the
  /// same product are separate rows.
  String get cartKey {
    final vid = variant?.variantId ?? '';
    return vid.isEmpty ? product.id : '${product.id}_$vid';
  }

  String get displayName =>
      variantLabel.isNotEmpty ? '${product.name} ($variantLabel)' : product.name;

  /// Display label of the variant snapshot ("500g"), or '' without a variant.
  String get variantLabel => variant?.label ?? '';

  /// Subtitle under the product name: the chosen variant when there is one,
  /// otherwise the pack size ("500 g", "1 piece").
  String get subLabel {
    if (variantLabel.isNotEmpty) return variantLabel;
    if (product.type == ProductType.weightBased && product.unit > 0) {
      return CartUnit.format(product.unit, product.unitType);
    }
    return '${product.unit == product.unit.roundToDouble() ? product.unit.toInt() : product.unit} ${product.unitType}';
  }

  /// True when this line is sold by weight/volume — either an explicitly
  /// selected variant with a measurable unit ("500g") or a weight-based
  /// product pack.
  bool get isMeasuredLine {
    final v = variant;
    if (v != null && v.variantId.isNotEmpty) {
      return v.hasUnit && CartUnit.isMeasured(v.unitType);
    }
    return product.type == ProductType.weightBased && product.unit > 0;
  }

  /// Unit used for "₹300 / 500g" — the variant's label first, then the pack.
  ///
  /// Returns '' for plain count products ("₹68 each").
  String get priceUnitLabel {
    if (variantLabel.isNotEmpty) return variantLabel;
    if (isMeasuredLine) {
      if (variant != null && variant!.hasUnit) return variant!.unitLabel;
      return CartUnit.format(product.unit, product.unitType);
    }
    return '';
  }

  /// "₹300 / 500g" (variant / weight products) or "₹68 each" (plain counts).
  String get unitPriceLine {
    final unit = priceUnitLabel;
    return unit.isEmpty ? 'each' : '/ $unit';
  }

  // ------------------------------------------------------------ Stock rules --

  /// Stock really remaining for this line (null when stock is untracked).
  int? get trackedStock {
    if (variant != null) {
      return variant!.isUnlimitedStock ? null : variant!.stock;
    }
    return product.isUnlimitedStock ? null : product.stockQty;
  }

  bool get isInStock => trackedStock == null || trackedStock! > 0;

  /// Largest quantity the stepper may reach (99 when stock is untracked).
  int get maxQty => trackedStock == null ? 99 : trackedStock!.clamp(1, 99);

  /// Amber chip text shown next to the stepper when stock is running out.
  ///
  /// Null while there is plenty left (or stock is not tracked) so the chip
  /// only appears "when relevant" instead of shouting on every row.
  String? stockWarningLabel({int threshold = 5}) {
    final left = trackedStock;
    if (left == null || left <= 0 || left > threshold) return null;
    return 'Only $left left';
  }

  // ----------------------------------------------------------- Stepper UI ---

  /// Small "× 500g" label beside the quantity stepper: ONE step = one pack.
  ///
  /// Only shown for measurable packs (weight/volume) — a "Black" colour
  /// variant or a 1-piece phone gets no unit chip.
  String get stepperUnitLabel {
    if (!isMeasuredLine) return '';
    if (variant != null && variant!.hasUnit) {
      final label = variantLabel.isNotEmpty ? variantLabel : variant!.unitLabel;
      return '× $label';
    }
    return '× ${CartUnit.format(product.unit, product.unitType)}';
  }

  /// True when the line is measured in weight/volume and a running total
  /// ("Total: 1 kg") makes sense.
  bool get hasMeasurableTotal => isMeasuredLine;

  /// "Total: 1 kg" — every pack of the line added up and converted for
  /// readability (≥1000g -> kg, ≥1000ml -> L). Empty for plain counts.
  String get totalUnitLabel {
    if (!hasMeasurableTotal) return '';
    final unitType = (variant != null && variant!.hasUnit)
        ? variant!.unitType
        : product.unitType;
    return CartUnit.format(totalQuantityInUnit, unitType);
  }

  /// Middle label of the "–  x  +" stepper: the quantity of packs.
  String get stepperLabel => '$qty';

  /// "500 grams" -> "500 g"; "1500 grams" -> "1.5 kg"; "2 pieces" -> "2 pieces".
  static String formatAmount(double amount, String unitType) =>
      CartUnit.format(amount, unitType);

  CartItem copyWith({int? qty, VariantSnapshot? variant}) => CartItem(
    companyId: companyId,
    companyName: companyName,
    product: product,
    variant: variant ?? this.variant,
    qty: qty ?? this.qty,
  );
}
