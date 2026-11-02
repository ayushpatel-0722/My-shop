/// Review model (Firestore: /reviews).
class Review {
  final String id;
  final String orderId;
  final String userId;
  final String userName;
  final String companyId;

  /// The product this review is about ('' for an older whole-order review).
  final String productId;
  final String productName;
  final int rating; // 1-5
  final String message;
  final bool isVisible;
  final DateTime? createdAt;

  const Review({
    required this.id,
    required this.orderId,
    required this.userId,
    this.userName = '',
    required this.companyId,
    this.productId = '',
    this.productName = '',
    required this.rating,
    this.message = '',
    this.isVisible = true,
    this.createdAt,
  });

  factory Review.fromMap(String id, Map<String, dynamic> map) => Review(
    id: id,
    orderId: map['orderId'] ?? '',
    userId: map['userId'] ?? '',
    userName: map['userName'] ?? '',
    companyId: map['companyId'] ?? '',
    productId: map['productId'] ?? '',
    productName: map['productName'] ?? '',
    rating: (map['rating'] as num?)?.toInt() ?? 5,
    message: map['message'] ?? '',
    isVisible: map['isVisible'] ?? true,
    createdAt: map['createdAt'] != null
        ? DateTime.tryParse(map['createdAt'].toString())
        : null,
  );

  /// Stable id: one review per product per order (or per order for an older
  /// whole-order review). Saving again edits it instead of adding a second.
  static String idFor({required String orderId, String productId = ''}) =>
      productId.isEmpty ? orderId : '${orderId}_$productId';

  Map<String, dynamic> toMap() => {
    'orderId': orderId,
    'userId': userId,
    'userName': userName,
    'companyId': companyId,
    'productId': productId,
    'productName': productName,
    'rating': rating,
    'message': message,
    'isVisible': isVisible,
    'createdAt': createdAt?.toIso8601String(),
  };
}
