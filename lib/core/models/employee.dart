/// Employee model (Firestore: /companies/{companyId}/employees/{id}, docId = Firebase Auth UID).
/// Conforms to Section 6.3 employees specification.
class Employee {
  final String id; // = Firebase Auth UID
  final String companyId; // Employer / tenant
  final String name; // Full name of staff member
  final String details; // Notes, emergency contact, qualifications
  final String address; // Residential address
  final String? dob; // Date of birth (formatted string / timestamp)
  final String gender; // male | female | other
  final String role; // Designation: Picker, Manufacturer, Manager, Dispatcher, etc.
  final String email; // Login email (unique)
  final Map<String, bool> permissions; // e.g. {canPack: true, canDispatch: false, ...}
  final bool shiftActive; // Gates login to scheduled hours
  final String? createdBy; // Admin who provisioned this account
  final double salary; // Salary amount
  final String salaryType; // monthly | yearly

  const Employee({
    required this.id,
    required this.companyId,
    required this.name,
    this.details = '',
    this.address = '',
    this.dob,
    this.gender = 'male',
    this.role = 'Picker',
    required this.email,
    this.permissions = const {
      'canPack': true,
      'canDispatch': false,
      'canManageInventory': false,
      'canViewReports': false,
    },
    this.shiftActive = true,
    this.createdBy,
    this.salary = 0.0,
    this.salaryType = 'monthly',
  });

  factory Employee.fromMap(String id, Map<String, dynamic> map) => Employee(
        id: id,
        companyId: map['companyId'] ?? '',
        name: map['name'] ?? '',
        details: map['details'] ?? '',
        address: map['address'] ?? '',
        dob: map['dob']?.toString(),
        gender: map['gender'] ?? 'male',
        role: map['role'] ?? 'Picker',
        email: map['email'] ?? '',
        permissions: (map['permissions'] as Map? ?? const {})
            .map((k, v) => MapEntry(k.toString(), v == true)),
        shiftActive: map['shiftActive'] ?? true,
        createdBy: map['createdBy'],
        salary: (map['salary'] ?? 0).toDouble(),
        salaryType: map['salaryType'] ?? 'monthly',
      );

  Employee copyWith({
    String? id,
    String? companyId,
    String? name,
    String? details,
    String? address,
    String? dob,
    String? gender,
    String? role,
    String? email,
    Map<String, bool>? permissions,
    bool? shiftActive,
    String? createdBy,
    double? salary,
    String? salaryType,
  }) {
    return Employee(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      details: details ?? this.details,
      address: address ?? this.address,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      role: role ?? this.role,
      email: email ?? this.email,
      permissions: permissions ?? this.permissions,
      shiftActive: shiftActive ?? this.shiftActive,
      createdBy: createdBy ?? this.createdBy,
      salary: salary ?? this.salary,
      salaryType: salaryType ?? this.salaryType,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'companyId': companyId,
        'name': name,
        'details': details,
        'address': address,
        'dob': dob,
        'gender': gender,
        'role': role,
        'email': email,
        'permissions': permissions,
        'shiftActive': shiftActive,
        'createdBy': createdBy,
        'salary': salary,
        'salaryType': salaryType,
      };
}
