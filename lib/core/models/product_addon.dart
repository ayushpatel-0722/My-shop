import '../utils/type_utils.dart';

/// How a product's add-ons are chosen: any number of them, or just one.
class AddOnSelectionType {
  const AddOnSelectionType._();

  static const String checkbox = 'checkbox';
  static const String radio = 'radio';
  static const List<String> values = [checkbox, radio];

  /// Anything unknown (older products, bad data) behaves as [checkbox].
  static String normalize(Object? raw) =>
      raw?.toString() == radio ? radio : checkbox;
}

/// Money in whole paise, so sums of add-on prices never pick up float noise.
int toPaise(double value) => (value * 100).round();

double fromPaise(int paise) => paise / 100;

/// An optional extra a shopper can buy together with a product — assembly,
/// delivery to a floor, installation, gift wrap and so on.
///
/// Stored inside the product document (`addOns`), so it is saved, loaded and
/// secured together with the product. Prices follow the product convention:
/// [amount] is the regular price, [discountAmt] the selling price when it is
/// discounted (0 = no discount). An add-on is an additional charge on top of
/// the product price, never a replacement for it.
class ProductAddOn {
  /// Stable identity used by carts and orders. Never reused for another add-on.
  final String id;
  final String title;
  final String description;

  /// Optional picture (http/https URL, like product images).
  final String imageUrl;

  /// Regular price per unit of the product.
  final double amount;

  /// Selling price when discounted; 0 when there is no discount.
  final double discountAmt;

  /// Disabled add-ons stay on the product but cannot be bought.
  final bool isActive;

  const ProductAddOn({
    required this.id,
    required this.title,
    this.description = '',
    this.imageUrl = '',
    this.amount = 0,
    this.discountAmt = 0,
    this.isActive = true,
  });

  /// What the shopper pays for it, per unit of the product.
  double get price => isDiscounted ? discountAmt : amount;

  /// Regular price (equal to [price] when not discounted).
  double get mrp => amount;

  bool get isDiscounted => discountAmt > 0 && discountAmt < amount;

  double get discountPercent =>
      isDiscounted ? ((amount - discountAmt) / amount) * 100 : 0;

  bool get hasImage => imageUrl.trim().isNotEmpty;

  /// True when a shopper may pick it: enabled, named and priced sanely.
  bool get isAvailable =>
      isActive && id.isNotEmpty && title.trim().isNotEmpty && amount >= 0;

  factory ProductAddOn.fromMap(Map<String, dynamic> map) => ProductAddOn(
    id: asString(map['id']),
    title: asString(map['title']),
    description: asString(map['description']),
    imageUrl: asString(map['imageUrl']),
    amount: asDouble(map['amount']),
    discountAmt: asDouble(map['discountAmt']),
    isActive: map.containsKey('isActive') ? asBool(map['isActive']) : true,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'imageUrl': imageUrl,
    'amount': amount,
    'discountAmt': discountAmt,
    'isActive': isActive,
  };

  ProductAddOn copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    double? amount,
    double? discountAmt,
    bool? isActive,
  }) => ProductAddOn(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    imageUrl: imageUrl ?? this.imageUrl,
    amount: amount ?? this.amount,
    discountAmt: discountAmt ?? this.discountAmt,
    isActive: isActive ?? this.isActive,
  );

  @override
  String toString() => 'ProductAddOn($id "$title" $price)';
}

/// What the shopper chose, frozen when it was added to the cart.
///
/// Like the variant snapshot, cart rows, checkout and orders read name and
/// price from here, so a later catalogue edit cannot silently change a line
/// that is already in a cart (checkout re-validates against the catalogue).
class AddOnSnapshot {
  final String addOnId;
  final String title;

  /// Selling price per unit of the product.
  final double price;

  /// Regular price per unit (equal to [price] when not discounted).
  final double mrp;

  const AddOnSnapshot({
    required this.addOnId,
    required this.title,
    required this.price,
    double? mrp,
  }) : mrp = mrp ?? price;

  factory AddOnSnapshot.from(ProductAddOn addOn) => AddOnSnapshot(
    addOnId: addOn.id,
    title: addOn.title.trim(),
    price: addOn.price,
    mrp: addOn.mrp < addOn.price ? addOn.price : addOn.mrp,
  );

  factory AddOnSnapshot.fromMap(Map<String, dynamic> map) {
    final price = asDouble(map['price']);
    return AddOnSnapshot(
      addOnId: asString(map['addOnId'] ?? map['id']),
      title: asString(map['title'] ?? map['name']),
      price: price,
      mrp: map['mrp'] == null ? null : asDouble(map['mrp']),
    );
  }

  Map<String, dynamic> toMap() => {
    'addOnId': addOnId,
    'title': title,
    'price': price,
    'mrp': mrp,
  };

  @override
  bool operator ==(Object other) =>
      other is AddOnSnapshot &&
      other.addOnId == addOnId &&
      other.title == title &&
      toPaise(other.price) == toPaise(price) &&
      toPaise(other.mrp) == toPaise(mrp);

  @override
  int get hashCode => Object.hash(addOnId, title, toPaise(price), toPaise(mrp));

  @override
  String toString() => 'AddOnSnapshot($addOnId "$title" $price)';
}

/// Per-unit totals of a set of add-ons, exact to the paisa.
class AddOnTotals {
  const AddOnTotals._();

  static double price(Iterable<AddOnSnapshot> addOns) =>
      fromPaise(addOns.fold(0, (s, a) => s + toPaise(a.price)));

  static double mrp(Iterable<AddOnSnapshot> addOns) => fromPaise(
    addOns.fold(0, (s, a) => s + toPaise(a.mrp < a.price ? a.price : a.mrp)),
  );
}
