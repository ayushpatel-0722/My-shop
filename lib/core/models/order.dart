import '../utils/type_utils.dart';

/// Order lifecycle statuses.
class OrderStatus {
  static const pending = 'pending';
  static const confirmed = 'confirmed';
  static const cancelled = 'cancelled';
  static const packing = 'packing';
  static const ready = 'ready';
  static const onTheWay = 'on_the_way';
  static const completed = 'completed';

  static const all = <String>[
    pending,
    confirmed,
    cancelled,
    packing,
    ready,
    onTheWay,
    completed,
  ];

  /// Order of stages for the pizza-tracker timeline.
  static const trackerChain = <String>[
    pending,
    confirmed,
    packing,
    ready,
    onTheWay,
    completed,
  ];

  /// True when [status] is a value the pipeline understands.
  static bool isValid(String status) => all.contains(status);
}

/// Payment statuses.
class PaymentStatus {
  static const pending = 'pending';
  static const done = 'done';

  static const all = <String>[pending, done];
}

/// Delivery modes.
class DeliveryType {
  static const homeDelivery = 'home_delivery';
  static const selfPickup = 'self_pickup';

  static const all = <String>[homeDelivery, selfPickup];
}

/// Snapshot of the shop the customer picks a self-pickup order up from.
class PickupShop {
  final String name;
  final String address;
  final String phone;
  final String timings;

  const PickupShop({
    this.name = '',
    this.address = '',
    this.phone = '',
    this.timings = '',
  });

  factory PickupShop.fromMap(Map<String, dynamic> map) => PickupShop(
    name: map['name']?.toString() ?? '',
    address: map['address']?.toString() ?? '',
    phone: map['phone']?.toString() ?? '',
    timings: map['timings']?.toString() ?? '',
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'address': address,
    'phone': phone,
    'timings': timings,
  };

  @override
  String toString() => 'PickupShop($name)';
}

/// One line of an order.
///
/// `name`, `image` and `unitPrice` are snapshots taken at checkout: editing or
/// deleting the product later must not rewrite a customer's past orders. The
/// variant snapshot (`variantLabel`, `unitValue`, `unitType`, `mrp`) is frozen
/// the same way so receipts always say "500g × 2" with the price of that
/// variant.
class OrderItem {
  final String productId;
  final int qty;
  final double unitPrice;
  final String name;
  final String image;

  /// Variant identity + display label (e.g. "500g").
  final String variantTitle;
  final String variantSku;
  final String variantLabel;

  /// Size of ONE unit of the variant (500 of "500 g").
  final double unitValue;
  final String unitType;

  /// List price (MRP) of the variant at order time.
  final double mrp;
  final Map<String, String> variantAttributes;

  const OrderItem({
    required this.productId,
    required this.qty,
    required this.unitPrice,
    this.name = '',
    this.image = '',
    this.variantTitle = '',
    this.variantSku = '',
    this.variantLabel = '',
    this.unitValue = 0,
    this.unitType = '',
    this.mrp = 0,
    this.variantAttributes = const {},
  });

  double get itemTotal => unitPrice * (qty < 0 ? 0 : qty);

  double get itemMrpTotal =>
      (mrp > 0 ? mrp : unitPrice) * (qty < 0 ? 0 : qty);

  /// "500g" — falls back to the variant title / sku.
  String get displayVariantLabel {
    if (variantLabel.isNotEmpty) return variantLabel;
    if (variantTitle.isNotEmpty) return variantTitle;
    return variantSku;
  }

  /// "500g × 2" style summary used by history / admin views.
  String get variantQtyLabel {
    final label = displayVariantLabel;
    final q = qty < 0 ? 0 : qty;
    if (label.isEmpty) return '× $q';
    return '$label × $q';
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    final rawAttrs = map['variantAttributes'];
    final attrs = <String, String>{};
    if (rawAttrs is Map) {
      rawAttrs.forEach((k, v) {
        if (k != null && v != null) attrs[k.toString()] = v.toString();
      });
    }

    return OrderItem(
      productId: asString(map['productId']),
      qty: asInt(map['qty'], 1),
      unitPrice: asDouble(map['unitPrice']),
      name: asString(map['name']),
      image: asString(map['image']),
      variantTitle: asString(map['variantTitle']),
      variantSku: asString(map['variantSku'] ?? map['variantId']),
      variantLabel: asString(map['variantLabel'] ?? map['variantTitle']),
      unitValue: asDouble(map['unitValue']),
      unitType: asString(map['unitType']),
      mrp: asDouble(map['mrp'] ?? map['unitMrp']),
      variantAttributes: attrs,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'productId': productId,
    'qty': qty,
    'unitPrice': unitPrice,
    'name': name,
    'image': image,
    'itemTotal': itemTotal,
    'variantId': variantSku,
    'variantTitle': variantTitle,
    'variantSku': variantSku,
    'variantLabel': displayVariantLabel,
    'unitValue': unitValue,
    'unitType': unitType,
    'price': unitPrice,
    'mrp': mrp,
    'quantity': qty,
    'variantAttributes': variantAttributes,
  };

  OrderItem copyWith({
    int? qty,
    double? unitPrice,
    String? name,
    String? image,
    String? variantTitle,
    String? variantSku,
    String? variantLabel,
    double? unitValue,
    String? unitType,
    double? mrp,
    Map<String, String>? variantAttributes,
  }) => OrderItem(
    productId: productId,
    qty: qty ?? this.qty,
    unitPrice: unitPrice ?? this.unitPrice,
    name: name ?? this.name,
    image: image ?? this.image,
    variantTitle: variantTitle ?? this.variantTitle,
    variantSku: variantSku ?? this.variantSku,
    variantLabel: variantLabel ?? this.variantLabel,
    unitValue: unitValue ?? this.unitValue,
    unitType: unitType ?? this.unitType,
    mrp: mrp ?? this.mrp,
    variantAttributes: variantAttributes ?? this.variantAttributes,
  );

  @override
  String toString() =>
      'OrderItem($productId x$qty @ $unitPrice${displayVariantLabel.isNotEmpty ? " [$displayVariantLabel]" : ""})';
}

/// Order model (Firestore: `/companies/{companyId}/orders/{orderId}` plus
/// an `items` sub-collection).
///
/// The money fields are stored explicitly so the receipt, the admin pipeline
/// and the reports all agree:
///
///   `subtotal` - `discountAmount` + `deliveryCharge` = `totalAmount`
class Order {
  final String id;
  final String userId;
  final String customerName;
  final String customerEmail;
  final String customerPhone;
  final String companyId;
  final String companyName;
  final List<OrderItem> items;

  /// Sum of `itemTotal` over [items] before any discount.
  final double subtotal;

  /// Voucher discount applied to the items.
  final double discountAmount;

  /// Delivery fee actually charged (0 after a free-shipping voucher).
  final double deliveryCharge;

  /// Amount the customer pays.
  final double totalAmount;

  final String address;
  final String pincode;

  /// Snapshot of the pickup shop for `self_pickup` orders (null otherwise).
  final PickupShop? pickupShop;
  final String? voucherId;

  /// Denormalised so the receipt still shows the code if the voucher is deleted.
  final String voucherCode;

  final String paymentStatus;
  final String orderStatus;
  final String deliveryType;
  final String? assignedEmployeeId;
  final bool employeePackingDone;
  final String? reviewId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? cancelledAt;

  Order({
    required this.id,
    required this.userId,
    this.customerName = '',
    this.customerEmail = '',
    this.customerPhone = '',
    required this.companyId,
    this.companyName = '',
    this.items = const <OrderItem>[],
    double? subtotal,
    this.discountAmount = 0,
    this.deliveryCharge = 0,
    double? totalAmount,
    this.address = '',
    this.pincode = '',
    this.pickupShop,
    this.voucherId,
    this.voucherCode = '',
    this.paymentStatus = PaymentStatus.pending,
    this.orderStatus = OrderStatus.pending,
    this.deliveryType = DeliveryType.homeDelivery,
    this.assignedEmployeeId,
    this.employeePackingDone = false,
    this.reviewId,
    this.createdAt,
    this.updatedAt,
    this.cancelledAt,
  }) : subtotal = subtotal ?? itemsTotalOf(items),
       totalAmount = totalAmount ?? itemsTotalOf(items);

  /// Sum of the line totals, used as the default for [subtotal].
  static double itemsTotalOf(List<OrderItem> items) =>
      items.fold<double>(0, (sum, e) => sum + e.itemTotal);

  // -------------------------------------------------------------- Derived --

  double get itemsTotal => itemsTotalOf(items);

  int get itemCount =>
      items.fold<int>(0, (sum, e) => sum + (e.qty < 0 ? 0 : e.qty));

  /// Sum of item discount + shipping saved, for the receipt.
  double get totalSavings => discountAmount;

  bool get isCancelled => orderStatus == OrderStatus.cancelled;
  bool get isCompleted => orderStatus == OrderStatus.completed;
  bool get isPending => orderStatus == OrderStatus.pending;

  /// Still flowing through the pipeline (neither delivered nor cancelled).
  bool get isOpen => !isCancelled && !isCompleted;

  bool get isPaid => paymentStatus == PaymentStatus.done;
  bool get isSelfPickup => deliveryType == DeliveryType.selfPickup;

  /// Compact, always-safe label for chips and titles (`#A1B2C3`).
  String get reference => '#${shortId(id, 6)}';

  /// True when the stored money fields add up (guards against bad writes).
  bool get isBalanced {
    final expected = subtotal - discountAmount + deliveryCharge;
    return (expected - totalAmount).abs() < 0.01;
  }

  // -------------------------------------------------------------- Parsing --

  factory Order.fromMap(String id, Map<String, dynamic> map) {
    final items = asMapList(map['items']).map(OrderItem.fromMap).toList();
    final subtotal = asDouble(map['subtotal'], itemsTotalOf(items));
    return Order(
      id: id,
      userId: asString(map['userId']),
      customerName: asString(map['customerName']),
      customerEmail: asString(map['customerEmail']),
      customerPhone: asString(map['customerPhone']),
      companyId: asString(map['companyId']),
      companyName: asString(map['companyName']),
      items: items,
      subtotal: subtotal,
      discountAmount: asDouble(
        map['discountAmount'],
        asDouble(map['discount']),
      ),
      deliveryCharge: asDouble(map['deliveryCharge']),
      // Legacy orders only stored `totalAmount`; keep it when the new fields
      // are missing instead of silently zeroing the receipt.
      totalAmount: asDouble(map['totalAmount'], subtotal),
      address: asString(map['address']),
      pincode: asString(map['pincode']),
      pickupShop: map['pickupShop'] is Map
          ? PickupShop.fromMap(
              Map<String, dynamic>.from(map['pickupShop'] as Map),
            )
          : null,
      voucherId: map['voucherId'] == null
          ? null
          : asString(map['voucherId']).isNotEmpty
          ? asString(map['voucherId'])
          : null,
      voucherCode: asString(map['voucherCode']),
      paymentStatus: PaymentStatus.all.contains(map['paymentStatus'])
          ? asString(map['paymentStatus'])
          : PaymentStatus.pending,
      orderStatus: OrderStatus.isValid(asString(map['orderStatus']))
          ? asString(map['orderStatus'])
          : OrderStatus.pending,
      deliveryType: DeliveryType.all.contains(map['deliveryType'])
          ? asString(map['deliveryType'])
          : DeliveryType.homeDelivery,
      assignedEmployeeId: map['assignedEmployeeId'] == null
          ? null
          : asString(map['assignedEmployeeId']).isNotEmpty
          ? asString(map['assignedEmployeeId'])
          : null,
      employeePackingDone: asBool(map['employeePackingDone']),
      reviewId: map['reviewId'] == null
          ? null
          : asString(map['reviewId']).isNotEmpty
          ? asString(map['reviewId'])
          : null,
      createdAt: asDateTime(map['createdAt']),
      updatedAt: asDateTime(map['updatedAt']),
      cancelledAt: asDateTime(map['cancelledAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'userId': userId,
    'customerName': customerName,
    'customerEmail': customerEmail,
    'customerPhone': customerPhone,
    'companyId': companyId,
    'companyName': companyName,
    'items': items.map((e) => e.toMap()).toList(),
    'subtotal': subtotal,
    'discountAmount': discountAmount,
    'deliveryCharge': deliveryCharge,
    'totalAmount': totalAmount,
    'address': address,
    'pincode': pincode,
    'pickupShop': pickupShop?.toMap(),
    'voucherId': voucherId,
    'voucherCode': voucherCode,
    'paymentStatus': paymentStatus,
    'orderStatus': orderStatus,
    'deliveryType': deliveryType,
    'assignedEmployeeId': assignedEmployeeId,
    'employeePackingDone': employeePackingDone,
    'reviewId': reviewId,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'cancelledAt': cancelledAt?.toIso8601String(),
  };

  // ------------------------------------------------------------- Mutation --

  Order copyWith({
    String? id,
    String? customerName,
    String? customerEmail,
    String? customerPhone,
    String? orderStatus,
    String? paymentStatus,
    String? assignedEmployeeId,
    bool clearAssignedEmployee = false,
    bool? employeePackingDone,
    String? reviewId,
    String? address,
    String? pincode,
    String? companyName,
    String? voucherId,
    String? voucherCode,
    double? subtotal,
    double? discountAmount,
    double? deliveryCharge,
    double? totalAmount,
    DateTime? updatedAt,
    DateTime? cancelledAt,
    bool clearCancelledAt = false,
  }) => Order(
    id: id ?? this.id,
    userId: userId,
    customerName: customerName ?? this.customerName,
    customerEmail: customerEmail ?? this.customerEmail,
    customerPhone: customerPhone ?? this.customerPhone,
    companyId: companyId,
    companyName: companyName ?? this.companyName,
    items: items,
    subtotal: subtotal ?? this.subtotal,
    discountAmount: discountAmount ?? this.discountAmount,
    deliveryCharge: deliveryCharge ?? this.deliveryCharge,
    totalAmount: totalAmount ?? this.totalAmount,
    address: address ?? this.address,
    pincode: pincode ?? this.pincode,
    pickupShop: pickupShop,
    voucherId: voucherId ?? this.voucherId,
    voucherCode: voucherCode ?? this.voucherCode,
    paymentStatus: paymentStatus ?? this.paymentStatus,
    orderStatus: orderStatus ?? this.orderStatus,
    deliveryType: deliveryType,
    assignedEmployeeId: clearAssignedEmployee
        ? null
        : (assignedEmployeeId ?? this.assignedEmployeeId),
    employeePackingDone: employeePackingDone ?? this.employeePackingDone,
    reviewId: reviewId ?? this.reviewId,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    cancelledAt: clearCancelledAt ? null : (cancelledAt ?? this.cancelledAt),
  );

  Order copyWithItems(List<OrderItem> newItems, {double? subtotal}) => Order(
    id: id,
    userId: userId,
    customerName: customerName,
    customerEmail: customerEmail,
    customerPhone: customerPhone,
    companyId: companyId,
    companyName: companyName,
    items: newItems,
    subtotal: subtotal ?? this.subtotal,
    discountAmount: discountAmount,
    deliveryCharge: deliveryCharge,
    totalAmount: totalAmount,
    address: address,
    pincode: pincode,
    pickupShop: pickupShop,
    voucherId: voucherId,
    voucherCode: voucherCode,
    paymentStatus: paymentStatus,
    orderStatus: orderStatus,
    deliveryType: deliveryType,
    assignedEmployeeId: assignedEmployeeId,
    employeePackingDone: employeePackingDone,
    reviewId: reviewId,
    createdAt: createdAt,
    updatedAt: updatedAt,
    cancelledAt: cancelledAt,
  );

  /// Applies a status change and stamps the audit timestamps.
  Order withStatus(String status, {DateTime? now, bool? paid}) {
    final timestamp = now ?? DateTime.now();
    return copyWith(
      orderStatus: status,
      updatedAt: timestamp,
      cancelledAt: status == OrderStatus.cancelled ? timestamp : null,
      clearCancelledAt: status != OrderStatus.cancelled,
      paymentStatus: status == OrderStatus.cancelled
          ? PaymentStatus.pending
          : (paid == true ? PaymentStatus.done : PaymentStatus.pending),
    );
  }

  @override
  String toString() =>
      'Order($reference, ${orderStatus.toUpperCase()}, total: $totalAmount)';
}
