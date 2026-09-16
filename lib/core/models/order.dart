/// Order + order-item models (Firestore: /orders + /orders/{id}/items).
class OrderStatus {
  static const pending = 'pending';
  static const confirmed = 'confirmed';
  static const cancelled = 'cancelled';
  static const packing = 'packing';
  static const ready = 'ready';
  static const onTheWay = 'on_the_way';
  static const completed = 'completed';

  static const all = [
    pending,
    confirmed,
    cancelled,
    packing,
    ready,
    onTheWay,
    completed,
  ];

  /// Order of stages for the pizza-tracker timeline.
  static const trackerChain = [
    pending,
    confirmed,
    packing,
    ready,
    onTheWay,
    completed,
  ];
}

class OrderItem {
  final String productId;
  final int qty;
  final double unitPrice;
  final String name;
  final String image;

  const OrderItem({
    required this.productId,
    required this.qty,
    required this.unitPrice,
    this.name = '',
    this.image = '',
  });

  double get itemTotal => qty * unitPrice;

  factory OrderItem.fromMap(Map<String, dynamic> map) => OrderItem(
        productId: map['productId'] ?? '',
        qty: map['qty'] ?? 1,
        unitPrice: (map['unitPrice'] ?? 0).toDouble(),
        name: map['name'] ?? '',
        image: map['image'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'qty': qty,
        'unitPrice': unitPrice,
        'name': name,
        'image': image,
      };
}

class Order {
  final String id;
  final String userId;
  final String companyId;
  final String companyName;
  final List<OrderItem> items;
  final double totalAmount;
  final String address;
  final String pincode;
  final String? voucherId;
  final String paymentStatus; // pending | done
  final String orderStatus;
  final String deliveryType; // self_pickup | home_delivery
  final String? assignedEmployeeId;
  final bool employeePackingDone;
  final String? reviewId;
  final DateTime? createdAt;

  const Order({
    required this.id,
    required this.userId,
    required this.companyId,
    this.companyName = '',
    this.items = const [],
    this.totalAmount = 0,
    this.address = '',
    this.pincode = '',
    this.voucherId,
    this.paymentStatus = 'pending',
    this.orderStatus = OrderStatus.pending,
    this.deliveryType = 'home_delivery',
    this.assignedEmployeeId,
    this.employeePackingDone = false,
    this.reviewId,
    this.createdAt,
  });

  factory Order.fromMap(String id, Map<String, dynamic> map) => Order(
        id: id,
        userId: map['userId'] ?? '',
        companyId: map['companyId'] ?? '',
        companyName: map['companyName'] ?? '',
        items: (map['items'] as List? ?? const [])
            .map((e) => OrderItem.fromMap(e))
            .toList(),
        totalAmount: (map['totalAmount'] ?? 0).toDouble(),
        address: map['address'] ?? '',
        pincode: map['pincode'] ?? '',
        voucherId: map['voucherId'],
        paymentStatus: map['paymentStatus'] ?? 'pending',
        orderStatus: map['orderStatus'] ?? OrderStatus.pending,
        deliveryType: map['deliveryType'] ?? 'home_delivery',
        assignedEmployeeId: map['assignedEmployeeId'],
        employeePackingDone: map['employeePackingDone'] ?? false,
        reviewId: map['reviewId'],
        createdAt: map['createdAt'] != null
            ? DateTime.tryParse(map['createdAt'].toString())
            : null,
      );

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'companyId': companyId,
        'companyName': companyName,
        'items': items.map((e) => e.toMap()).toList(),
        'totalAmount': totalAmount,
        'address': address,
        'pincode': pincode,
        'voucherId': voucherId,
        'paymentStatus': paymentStatus,
        'orderStatus': orderStatus,
        'deliveryType': deliveryType,
        'assignedEmployeeId': assignedEmployeeId,
        'employeePackingDone': employeePackingDone,
        'reviewId': reviewId,
        'createdAt': createdAt?.toIso8601String(),
      };

  Order copyWith({
    String? orderStatus,
    String? paymentStatus,
    String? assignedEmployeeId,
    bool? employeePackingDone,
    String? reviewId,
  }) =>
      Order(
        id: id,
        userId: userId,
        companyId: companyId,
        companyName: companyName,
        items: items,
        totalAmount: totalAmount,
        address: address,
        pincode: pincode,
        voucherId: voucherId,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        orderStatus: orderStatus ?? this.orderStatus,
        deliveryType: deliveryType,
        assignedEmployeeId: assignedEmployeeId ?? this.assignedEmployeeId,
        employeePackingDone: employeePackingDone ?? this.employeePackingDone,
        reviewId: reviewId ?? this.reviewId,
        createdAt: createdAt,
      );

  Order copyWithItems(List<OrderItem> newItems) => Order(
        id: id,
        userId: userId,
        companyId: companyId,
        companyName: companyName,
        items: newItems,
        totalAmount: totalAmount,
        address: address,
        pincode: pincode,
        voucherId: voucherId,
        paymentStatus: paymentStatus,
        orderStatus: orderStatus,
        deliveryType: deliveryType,
        assignedEmployeeId: assignedEmployeeId,
        employeePackingDone: employeePackingDone,
        reviewId: reviewId,
        createdAt: createdAt,
      );
}
