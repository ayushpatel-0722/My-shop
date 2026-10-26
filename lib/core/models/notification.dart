/// In-app notification model (Firestore: /notifications).
class AppNotification {
  final String id;
  final String recipientId;
  final String role; // admin | employee | user
  final String type;
  final String title;
  final String body;
  final String deepLink;
  final bool isRead;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.recipientId,
    required this.role,
    required this.type,
    required this.title,
    this.body = '',
    this.deepLink = '',
    this.isRead = false,
    this.createdAt,
  });

  factory AppNotification.fromMap(String id, Map<String, dynamic> map) =>
      AppNotification(
        id: id,
        recipientId: map['recipientId'] ?? '',
        role: map['role'] ?? 'user',
        type: map['type'] ?? 'system',
        title: map['title'] ?? '',
        body: map['body'] ?? '',
        deepLink: map['deepLink'] ?? '',
        isRead: map['isRead'] ?? false,
        createdAt: map['createdAt'] != null
            ? DateTime.tryParse(map['createdAt'].toString())
            : null,
      );

  Map<String, dynamic> toMap() => {
    'recipientId': recipientId,
    'role': role,
    'type': type,
    'title': title,
    'body': body,
    'deepLink': deepLink,
    'isRead': isRead,
    'createdAt': createdAt?.toIso8601String(),
  };
}
