import '../domain/employee_roles.dart';
import 'customer.dart';
export 'customer.dart' show AddressEntry, Customer;

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

  /// Employee permission switches (canPack, canDispatch, ...). Empty for
  /// admins/shoppers and for legacy employees: see [EmployeeAccess].
  final Map<String, bool> permissions;
  final String authProvider; // google | phone | email
  final String googleId;
  final List<AddressEntry> addresses;

  const AppUser({
    required this.id,
    required this.name,
    this.companyId = '',
    this.companyName = '',
    this.email = '',
    this.mobileNumber = '',
    required this.role,
    this.employeeRole,
    this.permissions = const {},
    this.authProvider = '',
    this.googleId = '',
    this.addresses = const [],
  });

  bool get isAdmin => role == 'admin';
  bool get isEmployee => role == 'employee';
  bool get isUser => role == 'user';

  /// An employee with the Manager role: works the whole order pipeline and
  /// manages the other employees from the admin screens.
  bool get isManager => isEmployee && access.canManageOrders;
  EmployeeAccess get access => EmployeeAccess(permissions);
  String get phone => mobileNumber;

  /// Primary or default address for delivery
  AddressEntry? get defaultAddress {
    if (addresses.isEmpty) return null;
    return addresses.firstWhere(
      (a) => a.isDefault,
      orElse: () => addresses.first,
    );
  }

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
    id: map['id'] ?? '',
    companyId: map['companyId'] ?? '',
    companyName: map['companyName'] ?? '',
    name: map['name'] ?? '',
    email: map['email'] ?? '',
    mobileNumber: map['mobileNumber'] ?? '',
    role: map['role'] ?? 'user',
    employeeRole: map['employeeRole'],
    permissions: parsePermissions(map['permissions']),
    authProvider: map['authProvider'] ?? '',
    googleId: map['googleId'] ?? '',
    addresses: (map['addresses'] as List? ?? const [])
        .map((e) => AddressEntry.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );

  AppUser copyWith({
    String? id,
    String? companyId,
    String? companyName,
    String? name,
    String? email,
    String? mobileNumber,
    String? role,
    String? employeeRole,
    Map<String, bool>? permissions,
    String? authProvider,
    String? googleId,
    List<AddressEntry>? addresses,
  }) => AppUser(
    id: id ?? this.id,
    companyId: companyId ?? this.companyId,
    companyName: companyName ?? this.companyName,
    name: name ?? this.name,
    email: email ?? this.email,
    mobileNumber: mobileNumber ?? this.mobileNumber,
    role: role ?? this.role,
    employeeRole: employeeRole ?? this.employeeRole,
    permissions: permissions ?? this.permissions,
    authProvider: authProvider ?? this.authProvider,
    googleId: googleId ?? this.googleId,
    addresses: addresses ?? this.addresses,
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
    'permissions': permissions,
    'authProvider': authProvider,
    'googleId': googleId,
    'addresses': addresses.map((e) => e.toMap()).toList(),
  };
}
