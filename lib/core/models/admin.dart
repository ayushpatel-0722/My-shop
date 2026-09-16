/// Admin model (Firestore: /admins, docId = Firebase Auth UID).
class Admin {
  final String id; // = Firebase Auth UID
  final String companyId;
  final String name;
  final String email;
  final String mobileNumber;
  final String address;
  final String gender; // male | female | other
  final String? createdBy; // admin who created this account
  final bool emailVerified;

  const Admin({
    required this.id,
    required this.companyId,
    required this.name,
    required this.email,
    this.mobileNumber = '',
    this.address = '',
    this.gender = 'other',
    this.createdBy,
    this.emailVerified = false,
  });

  factory Admin.fromMap(String id, Map<String, dynamic> map) => Admin(
        id: id,
        companyId: map['companyId'] ?? '',
        name: map['name'] ?? '',
        email: map['email'] ?? '',
        mobileNumber: map['mobileNumber'] ?? '',
        address: map['address'] ?? '',
        gender: map['gender'] ?? 'other',
        createdBy: map['createdBy'],
        emailVerified: map['emailVerified'] ?? false,
      );

  Map<String, dynamic> toMap() => {
        'companyId': companyId,
        'name': name,
        'email': email,
        'mobileNumber': mobileNumber,
        'address': address,
        'gender': gender,
        'createdBy': createdBy,
        'emailVerified': emailVerified,
      };
}
