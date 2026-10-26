/// Review model (Firestore: /reviews).
class Review {
  final String id;
  final String orderId;
  final String userId;
  final String userName;
  final String companyId;
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
    rating: map['rating'] ?? 5,
    message: map['message'] ?? '',
    isVisible: map['isVisible'] ?? true,
    createdAt: map['createdAt'] != null
        ? DateTime.tryParse(map['createdAt'].toString())
        : null,
  );

  Map<String, dynamic> toMap() => {
    'orderId': orderId,
    'userId': userId,
    'userName': userName,
    'companyId': companyId,
    'rating': rating,
    'message': message,
    'isVisible': isVisible,
    'createdAt': createdAt?.toIso8601String(),
  };
}
