/// A signed-in actor in the system (Admin, Employee or Shopper).
/// Mirrors /admins, /employees and /users plus the Firebase Auth token.
class AppUser {
  final String id; // = Firebase Auth UID
  final String companyId; // empty for shoppers (null tenant)
  final String companyName;
  final String name;
  final String email;
  final String mobileNumber;
  final String role; // admin | employee | user
  final String? employeeRole; // e.g. Picker, Dispatcher

  const AppUser({
    required this.id,
    required this.name,
    this.companyId = '',
    this.companyName = '',
    this.email = '',
    this.mobileNumber = '',
    required this.role,
    this.employeeRole,
  });

  bool get isAdmin => role == 'admin';
  bool get isEmployee => role == 'employee';
  bool get isUser => role == 'user';

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
        id: map['id'] ?? '',
        companyId: map['companyId'] ?? '',
        companyName: map['companyName'] ?? '',
        name: map['name'] ?? '',
        email: map['email'] ?? '',
        mobileNumber: map['mobileNumber'] ?? '',
        role: map['role'] ?? 'user',
        employeeRole: map['employeeRole'],
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'companyId': companyId,
        'companyName': companyName,
        'name': name,
        'email': email,
        'mobileNumber': mobileNumber,
        'role': role,
        'employeeRole': employeeRole,
      };
}
