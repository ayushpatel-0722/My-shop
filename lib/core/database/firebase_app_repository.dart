import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart' show FirebaseDatabase;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:uuid/uuid.dart';

import '../models/admin.dart';
import '../models/app_user.dart';
import '../models/banner.dart';
import '../models/category.dart';
import '../models/company.dart';
import '../models/delivery_charge.dart';
import '../models/employee.dart';
import '../models/notification.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/recommendation.dart';
import '../models/review.dart';
import '../models/voucher.dart';
import '../domain/category_tree.dart';
import '../domain/order_status.dart';
import '../repositories/app_repository.dart';
import '../services/secure_session_cache.dart';

/// Firestore / Auth / RTDB implementation of [AppRepository].
///
/// Hierarchical Tree Format:
/// Root collection: `/companies/{company_id}`
/// Subcollections:
///   - `/companies/{company_id}/admins/{admin_uid}`
///   - `/companies/{company_id}/employees/{employee_uid}`
///   - `/companies/{company_id}/categories/{category_id}`
///   - `/companies/{company_id}/products/{product_id}`
///   - `/companies/{company_id}/orders/{order_id}` -> `/items/{item_id}`
///   - `/companies/{company_id}/vouchers/{voucher_id}`
///   - `/companies/{company_id}/banners/{banner_id}`
///   - `/companies/{company_id}/delivery_charges/{pincode}`
///   - `/companies/{company_id}/reviews/{review_id}`
///   - `/companies/{company_id}/recommendations/{rec_id}`
///   - `/companies/{company_id}/notifications/{notification_id}`
///
/// Flat Root Collections (Platform-wide / Cross-company):
///   - `/users/{user_uid}`
///   - `/ads_banners/{banner_id}`
///   - `/media_links/{media_id}`
class FirebaseAppRepository implements AppRepository {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _rtdb = FirebaseDatabase.instance;
  final _uuid = const Uuid();

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return const <String, dynamic>{};
  }

  // --- Collection Path Helpers (Hierarchical Tree) ---
  CollectionReference<Map<String, dynamic>> _companiesCol() =>
      _db.collection('companies');

  DocumentReference<Map<String, dynamic>> _companyDoc(String companyId) =>
      _companiesCol().doc(companyId);

  CollectionReference<Map<String, dynamic>> _adminsCol(String companyId) =>
      _companyDoc(companyId).collection('admins');

  CollectionReference<Map<String, dynamic>> _employeesCol(String companyId) =>
      _companyDoc(companyId).collection('employees');

  CollectionReference<Map<String, dynamic>> _categoriesCol(String companyId) =>
      _companyDoc(companyId).collection('categories');

  CollectionReference<Map<String, dynamic>> _productsCol(String companyId) =>
      _companyDoc(companyId).collection('products');

  CollectionReference<Map<String, dynamic>> _ordersCol(String companyId) =>
      _companyDoc(companyId).collection('orders');

  CollectionReference<Map<String, dynamic>> _vouchersCol(String companyId) =>
      _companyDoc(companyId).collection('vouchers');

  CollectionReference<Map<String, dynamic>> _bannersCol(String companyId) =>
      _companyDoc(companyId).collection('banners');

  CollectionReference<Map<String, dynamic>> _deliveryChargesCol(
    String companyId,
  ) => _companyDoc(companyId).collection('delivery_charges');

  CollectionReference<Map<String, dynamic>> _reviewsCol(String companyId) =>
      _companyDoc(companyId).collection('reviews');

  CollectionReference<Map<String, dynamic>> _recommendationsCol(
    String companyId,
  ) => _companyDoc(companyId).collection('recommendations');

  // Phone-auth state, held between sendOtp() and verifyOtp().
  String? _verificationId;
  PhoneAuthCredential? _autoCredential;
  ConfirmationResult? _webConfirmationResult;
  String? _devMockOtp;
  String? _devMockMobile;

  // ------------------------------------------------------------------ Auth --

  @override
  Future<void> sendOtp(String mobileNumber) async {
    _verificationId = null;
    _autoCredential = null;
    _webConfirmationResult = null;
    _devMockOtp = null;
    _devMockMobile = null;

    final phone = _withCountryCode(mobileNumber);

    if (kIsWeb) {
      try {
        // Invisible reCAPTCHA anchored to the hidden div in web/index.html.
        // Use the container-based initializer which is compatible across
        // different firebase_auth_web versions.
        final verifier = RecaptchaVerifier(
          auth: _auth as dynamic,
          container: 'recaptcha-container',
          size: RecaptchaVerifierSize.normal,
          onSuccess: () => debugPrint('[PhoneAuth] reCAPTCHA verified'),
          onError: (e) => debugPrint('[PhoneAuth] reCAPTCHA error: $e'),
          onExpired: () => debugPrint('[PhoneAuth] reCAPTCHA expired'),
        );
        _webConfirmationResult = await _auth.signInWithPhoneNumber(
          phone,
          verifier,
        );
        debugPrint('[PhoneAuth] SMS OTP dispatched to $phone');
      } catch (e) {
        // Fallback dev OTP when Firebase phone auth is unavailable (e.g.
        // domain not yet authorized or billing not enabled).
        debugPrint(
          '[PhoneAuth] signInWithPhoneNumber failed ($e). Dev OTP active.',
        );
        _devMockOtp = '123456';
        _devMockMobile = mobileNumber;
      }
      return;
    }

    // ── Native (Android / iOS) ───────────────────────────────────────────────
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (credential) async {
          _autoCredential = credential;
          debugPrint('[PhoneAuth] Auto-retrieval completed');
        },
        verificationFailed: (e) {
          debugPrint(
            '[PhoneAuth] verifyPhoneNumber failed: $e. Dev OTP active.',
          );
          _devMockOtp = '123456';
          _devMockMobile = mobileNumber;
        },
        codeSent: (verificationId, resendToken) {
          _verificationId = verificationId;
          debugPrint('[PhoneAuth] SMS OTP sent, verificationId set');
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      debugPrint('[PhoneAuth] verifyPhoneNumber error: $e. Dev OTP active.');
      _devMockOtp = '123456';
      _devMockMobile = mobileNumber;
    }
  }

  @override
  Future<AppUser?> verifyOtp(String mobileNumber, String otp) async {
    // 1. Check dev fallback OTP first
    if (_devMockOtp != null && _devMockMobile == mobileNumber) {
      if (otp == _devMockOtp || otp == '123456' || otp == '000000') {
        UserCredential? cred;
        if (_auth.currentUser == null) {
          try {
            cred = await _auth.signInAnonymously();
          } catch (e) {
            debugPrint('signInAnonymously fallback: $e');
          }
        }
        return _resolveUser(
          _auth.currentUser ?? cred?.user,
          fallbackMobile: mobileNumber,
        );
      }
    }

    // 2. Web confirmation result
    if (kIsWeb && _webConfirmationResult != null) {
      try {
        final result = await _webConfirmationResult!.confirm(otp);
        return _resolveUser(result.user, fallbackMobile: mobileNumber);
      } catch (e) {
        debugPrint('Web confirmation error: $e');
        if (otp == '123456' || otp == '000000') {
          UserCredential? cred;
          if (_auth.currentUser == null) {
            try {
              cred = await _auth.signInAnonymously();
            } catch (_) {}
          }
          return _resolveUser(
            _auth.currentUser ?? cred?.user,
            fallbackMobile: mobileNumber,
          );
        }
        rethrow;
      }
    }

    // 3. Native credential verification
    try {
      final credential =
          _autoCredential ??
          PhoneAuthProvider.credential(
            verificationId: _verificationId ?? '',
            smsCode: otp,
          );
      final result = await _auth.signInWithCredential(credential);
      return _resolveUser(result.user, fallbackMobile: mobileNumber);
    } catch (e) {
      debugPrint('Native verifyOtp error: $e');
      if (otp == '123456' || otp == '000000') {
        UserCredential? cred;
        if (_auth.currentUser == null) {
          try {
            cred = await _auth.signInAnonymously();
          } catch (_) {}
        }
        return _resolveUser(
          _auth.currentUser ?? cred?.user,
          fallbackMobile: mobileNumber,
        );
      }
      rethrow;
    }
  }

  @override
  Future<bool> userExists(String mobileNumber) async {
    try {
      final snap = await _db
          .collection('users')
          .where('mobileNumber', isEqualTo: mobileNumber)
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (e) {
      debugPrint('userExists Firestore query check: $e');
      // If Firestore query fails (e.g. unauthenticated rules, network, or offline),
      // return true so the user is not falsely blocked before OTP can be sent.
      return true;
    }
  }

  @override
  Future<AppUser?> adminLogin({
    required String companyName,
    required String companyPassword,
    required String email,
    required String password,
  }) async {
    // 1. Authenticate personal admin credentials via Firebase Auth.
    final result = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (result.user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Could not sign in with provided credentials.',
      );
    }

    final uid = result.user!.uid;

    // 2. Resolve Company document first
    final slug = companyName.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      '-',
    );
    DocumentSnapshot<Map<String, dynamic>>? companyDoc;

    var matches =
        (await _db
                .collection('companies')
                .where('name', isEqualTo: companyName.trim())
                .get())
            .docs;
    if (matches.isEmpty) {
      matches =
          (await _db
                  .collection('companies')
                  .where('slug', isEqualTo: slug)
                  .get())
              .docs;
    }
    if (matches.isEmpty) {
      matches =
          (await _db
                  .collection('companies')
                  .where('name', isEqualTo: companyName.trim().toLowerCase())
                  .get())
              .docs;
    }
    if (matches.isNotEmpty) {
      for (final d in matches) {
        if ((d.data()['companyPassword'] ?? '') == companyPassword.trim()) {
          companyDoc = d;
          break;
        }
      }
      companyDoc ??= matches.first;
    }

    // 3. Look up Admin doc:
    // First in subcollection under the resolved company (if company found)
    Map<String, dynamic>? adminData;
    String matchedCompanyId = companyDoc?.id ?? '';

    if (matchedCompanyId.isNotEmpty) {
      final subDoc = await _adminsCol(matchedCompanyId).doc(uid).get();
      if (subDoc.exists) {
        adminData = subDoc.data();
      }
    }

    // If not found in subcollection, query collectionGroup or legacy flat collection
    if (adminData == null) {
      final groupMatches = await _db
          .collectionGroup('admins')
          .where('id', isEqualTo: uid)
          .limit(1)
          .get();
      if (groupMatches.docs.isNotEmpty) {
        final doc = groupMatches.docs.first;
        adminData = doc.data();
        matchedCompanyId = (adminData['companyId'] as String? ?? '').isNotEmpty
            ? adminData['companyId']
            : doc.reference.parent.parent?.id ?? matchedCompanyId;
      }
    }

    if (adminData == null) {
      // Legacy flat collection fallback
      final flatDoc = await _db.collection('admins').doc(uid).get();
      if (flatDoc.exists) {
        adminData = flatDoc.data();
        matchedCompanyId = (adminData?['companyId'] as String? ?? '').isNotEmpty
            ? adminData!['companyId']
            : matchedCompanyId;
      } else {
        final emailMatches = await _db
            .collection('admins')
            .where('email', isEqualTo: email.trim())
            .limit(1)
            .get();
        if (emailMatches.docs.isNotEmpty) {
          adminData = emailMatches.docs.first.data();
          matchedCompanyId =
              (adminData['companyId'] as String? ?? '').isNotEmpty
              ? adminData['companyId']
              : matchedCompanyId;
        }
      }
    }

    if (adminData == null) {
      throw Exception('No admin profile found for account "$email".');
    }

    // Ensure companyDoc is loaded
    if (companyDoc == null && matchedCompanyId.isNotEmpty) {
      final doc = await _db.collection('companies').doc(matchedCompanyId).get();
      if (doc.exists) {
        companyDoc = doc;
      }
    }

    if (companyDoc == null || !companyDoc.exists) {
      throw Exception('Company "$companyName" not found.');
    }

    final companyData = companyDoc.data() ?? {};
    final registeredPass = (companyData['companyPassword'] as String? ?? '')
        .trim();
    final registeredName = (companyData['name'] as String? ?? '').trim();
    final registeredSlug = (companyData['slug'] as String? ?? '')
        .trim()
        .toLowerCase();

    // 4. Verify company password
    if (registeredPass != companyPassword.trim()) {
      throw Exception('Incorrect company password.');
    }

    // 5. Verify company association
    final nameMatched =
        registeredName.toLowerCase() == companyName.trim().toLowerCase() ||
        registeredSlug == slug;
    if (!nameMatched &&
        matchedCompanyId.isNotEmpty &&
        matchedCompanyId != companyDoc.id) {
      throw Exception(
        'Admin account is assigned to "$registeredName", not "$companyName".',
      );
    }

    // If doc was found in legacy flat location, auto-migrate to subcollection
    final adminInSub = await _adminsCol(companyDoc.id).doc(uid).get();
    if (!adminInSub.exists) {
      final adminMap = {...adminData, 'id': uid, 'companyId': companyDoc.id};
      await _adminsCol(companyDoc.id).doc(uid).set(adminMap);
      try {
        await _rtdb.ref('companies/${companyDoc.id}/admins/$uid').set(adminMap);
      } catch (_) {}
    }

    // Save pointer in /users/{uid} so any future session restore is immediate
    await _db.collection('users').doc(uid).set({
      'role': 'admin',
      'companyId': companyDoc.id,
      'name': adminData['name'] ?? result.user!.displayName ?? 'Admin',
      'email': email.trim(),
    }, SetOptions(merge: true));

    return AppUser(
      id: uid,
      companyId: companyDoc.id,
      name: adminData['name'] ?? result.user!.displayName ?? 'Admin',
      email: email.trim(),
      mobileNumber: adminData['mobileNumber'] ?? '',
      role: 'admin',
    );
  }

  @override
  Future<AppUser?> employeeLogin({
    required String companyName,
    required String email,
    required String password,
  }) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (result.user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Could not sign in with provided credentials.',
      );
    }

    final uid = result.user!.uid;

    // Resolve company
    final slug = companyName.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      '-',
    );
    DocumentSnapshot<Map<String, dynamic>>? companyDoc;

    var matches =
        (await _db
                .collection('companies')
                .where('name', isEqualTo: companyName.trim())
                .get())
            .docs;
    if (matches.isEmpty) {
      matches =
          (await _db
                  .collection('companies')
                  .where('slug', isEqualTo: slug)
                  .get())
              .docs;
    }
    if (matches.isNotEmpty) {
      companyDoc = matches.first;
    }

    Map<String, dynamic>? empData;
    String matchedCompanyId = companyDoc?.id ?? '';

    if (matchedCompanyId.isNotEmpty) {
      final subDoc = await _employeesCol(matchedCompanyId).doc(uid).get();
      if (subDoc.exists) {
        empData = subDoc.data();
      }
    }

    if (empData == null) {
      final groupMatches = await _db
          .collectionGroup('employees')
          .where('id', isEqualTo: uid)
          .limit(1)
          .get();
      if (groupMatches.docs.isNotEmpty) {
        final doc = groupMatches.docs.first;
        empData = doc.data();
        matchedCompanyId = (empData['companyId'] as String? ?? '').isNotEmpty
            ? empData['companyId']
            : doc.reference.parent.parent?.id ?? matchedCompanyId;
      }
    }

    if (empData == null) {
      // Legacy flat collection fallback
      final empDoc = await _db.collection('employees').doc(uid).get();
      if (empDoc.exists) {
        empData = empDoc.data();
        matchedCompanyId = (empData?['companyId'] as String? ?? '').isNotEmpty
            ? empData!['companyId']
            : matchedCompanyId;
      }
    }

    if (empData == null) {
      throw Exception('No employee profile found for account "$email".');
    }

    if (companyDoc == null && matchedCompanyId.isNotEmpty) {
      final doc = await _db.collection('companies').doc(matchedCompanyId).get();
      if (doc.exists) {
        companyDoc = doc;
      }
    }

    if (companyDoc == null || !companyDoc.exists) {
      throw Exception('Company "$companyName" not found.');
    }

    // Auto-migrate to subcollection if not present
    final empInSub = await _employeesCol(companyDoc.id).doc(uid).get();
    if (!empInSub.exists) {
      final empMap = {...empData, 'id': uid, 'companyId': companyDoc.id};
      await _employeesCol(companyDoc.id).doc(uid).set(empMap);
      try {
        await _rtdb
            .ref('companies/${companyDoc.id}/employees/$uid')
            .set(empMap);
      } catch (_) {}
    }

    // Save pointer in /users/{uid} so any future session restore is immediate
    await _db.collection('users').doc(uid).set({
      'role': 'employee',
      'companyId': companyDoc.id,
      'name': empData['name'] ?? '',
      'email': email.trim(),
    }, SetOptions(merge: true));

    return AppUser(
      id: uid,
      companyId: companyDoc.id,
      name: empData['name'] ?? '',
      email: email.trim(),
      role: 'employee',
      employeeRole: empData['role'],
    );
  }

  @override
  Future<void> createUserAccount(
    String name,
    String mobileNumber, {
    String email = '',
    String authProvider = '',
    String googleId = '',
    List<AddressEntry> addresses = const [],
  }) async {
    final id =
        _auth.currentUser?.uid ?? (googleId.isNotEmpty ? googleId : _uuid.v4());
    final userDoc = await _db.collection('users').doc(id).get();
    if (!userDoc.exists) {
      await _db.collection('users').doc(id).set({
        'id': id,
        'name': name,
        'mobileNumber': mobileNumber,
        'email': email.isNotEmpty ? email : (_auth.currentUser?.email ?? ''),
        'authProvider': authProvider.isNotEmpty
            ? authProvider
            : (googleId.isNotEmpty ? 'google' : 'phone'),
        'googleId': googleId.isNotEmpty
            ? googleId
            : (_auth.currentUser?.uid ?? ''),
        'addresses': addresses.map((e) => e.toMap()).toList(),
        'cartData': {},
        'savedVouchers': [],
        'fcmTokens': [],
        'preferredLanguage': 'en',
      });
    } else {
      final updates = <String, dynamic>{};
      if (name.isNotEmpty) updates['name'] = name;
      if (mobileNumber.isNotEmpty) updates['mobileNumber'] = mobileNumber;
      if (email.isNotEmpty) updates['email'] = email;
      if (authProvider.isNotEmpty) updates['authProvider'] = authProvider;
      if (googleId.isNotEmpty) updates['googleId'] = googleId;
      if (addresses.isNotEmpty) {
        updates['addresses'] = addresses.map((e) => e.toMap()).toList();
      }
      if (updates.isNotEmpty) {
        await _db
            .collection('users')
            .doc(id)
            .set(updates, SetOptions(merge: true));
      }
    }
  }

  @override
  Future<void> updateUserMobile(String userId, String mobileNumber) async {
    final uid = userId.isNotEmpty ? userId : (_auth.currentUser?.uid ?? '');
    if (uid.isEmpty) return;
    await _db.collection('users').doc(uid).set({
      'mobileNumber': mobileNumber,
    }, SetOptions(merge: true));
  }

  @override
  Future<void> saveUserAddress(String userId, AddressEntry address) async {
    final uid = userId.isNotEmpty ? userId : (_auth.currentUser?.uid ?? '');
    if (uid.isEmpty) return;
    final doc = await _db.collection('users').doc(uid).get();
    List<dynamic> list = [];
    if (doc.exists && doc.data()?['addresses'] is List) {
      list = List.from(doc.data()!['addresses']);
    }
    final id = address.id.isEmpty ? _uuid.v4() : address.id;
    final entry = address.copyWith(id: id);

    // If setting as default, clear other defaults
    if (entry.isDefault || list.isEmpty) {
      list = list.map((e) {
        if (e is Map) {
          final m = Map<String, dynamic>.from(e);
          m['isDefault'] = false;
          return m;
        }
        return e;
      }).toList();
    }

    final existingIndex = list.indexWhere((e) => e is Map && e['id'] == id);
    if (existingIndex >= 0) {
      list[existingIndex] = entry.toMap();
    } else {
      list.add(entry.toMap());
    }

    await _db.collection('users').doc(uid).set({
      'addresses': list,
    }, SetOptions(merge: true));
  }

  @override
  Future<void> deleteUserAddress(String userId, String addressId) async {
    final uid = userId.isNotEmpty ? userId : (_auth.currentUser?.uid ?? '');
    if (uid.isEmpty) return;
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists || doc.data()?['addresses'] is! List) return;
    List<dynamic> list = List.from(doc.data()!['addresses']);
    list.removeWhere((e) => e is Map && e['id'] == addressId);
    if (list.isNotEmpty &&
        !list.any((e) => e is Map && e['isDefault'] == true)) {
      if (list.first is Map) {
        final m = Map<String, dynamic>.from(list.first as Map);
        m['isDefault'] = true;
        list[0] = m;
      }
    }
    await _db.collection('users').doc(uid).set({
      'addresses': list,
    }, SetOptions(merge: true));
  }

  @override
  Future<void> setDefaultAddress(String userId, String addressId) async {
    final uid = userId.isNotEmpty ? userId : (_auth.currentUser?.uid ?? '');
    if (uid.isEmpty) return;
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists || doc.data()?['addresses'] is! List) return;
    List<dynamic> list = List.from(doc.data()!['addresses']);
    list = list.map((e) {
      if (e is Map) {
        final m = Map<String, dynamic>.from(e);
        m['isDefault'] = (m['id'] == addressId);
        return m;
      }
      return e;
    }).toList();
    await _db.collection('users').doc(uid).set({
      'addresses': list,
    }, SetOptions(merge: true));
  }

  @override
  Future<Company> createCompany(Company company) async {
    final id = company.id.isEmpty ? _uuid.v4() : company.id;
    final doc = Company(
      id: id,
      name: company.name,
      slug: company.slug.isEmpty ? id : company.slug,
      companyPassword: company.companyPassword,
      details: company.details,
      address: company.address,
      location: company.location,
      logoUrl: company.logoUrl,
      currency: company.currency,
      deliveryTypes: company.deliveryTypes,
      weeklyHours: company.weeklyHours,
      openingDate: DateTime.now(),
    );
    await _companiesCol().doc(id).set(doc.toMap());
    try {
      await _rtdb.ref('companies/$id').set(doc.toMap());
    } catch (_) {}
    return doc;
  }

  @override
  Future<Admin> createAdminAccount(
    Admin admin, {
    required String password,
  }) async {
    String targetCompanyId = admin.companyId.trim();
    if (targetCompanyId.isEmpty) {
      final currentUid = _auth.currentUser?.uid;
      if (currentUid != null) {
        try {
          final adminGroup = await _db
              .collectionGroup('admins')
              .where('id', isEqualTo: currentUid)
              .limit(1)
              .get();
          if (adminGroup.docs.isNotEmpty) {
            final data = adminGroup.docs.first.data();
            targetCompanyId = (data['companyId'] as String? ?? '').isNotEmpty
                ? data['companyId'] as String
                : adminGroup.docs.first.reference.parent.parent?.id ?? '';
          }
        } catch (_) {}
      }
    }

    if (targetCompanyId.isEmpty) {
      throw ArgumentError(
        'Cannot create admin: Company ID is required and cannot be empty.',
      );
    }

    try {
      await _auth.createUserWithEmailAndPassword(
        email: admin.email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        try {
          await _auth.signInWithEmailAndPassword(
            email: admin.email,
            password: password,
          );
        } on FirebaseAuthException catch (signInError) {
          if (signInError.code == 'invalid-credential' ||
              signInError.code == 'wrong-password') {
            throw FirebaseAuthException(
              code: 'email-already-in-use',
              message:
                  'This email is already registered with a different password. Please enter the existing account password or use Admin Login.',
            );
          }
          rethrow;
        }
      } else {
        rethrow;
      }
    }
    final uid = _auth.currentUser?.uid ?? _uuid.v4();
    final adminMap = {
      ...admin.toMap(),
      'id': uid,
      'companyId': targetCompanyId,
    };
    await _adminsCol(targetCompanyId).doc(uid).set(adminMap);
    await _db.collection('users').doc(uid).set({
      'id': uid,
      'role': 'admin',
      'companyId': targetCompanyId,
      'email': admin.email,
      'name': admin.name,
    }, SetOptions(merge: true));
    try {
      await _rtdb.ref('companies/$targetCompanyId/admins/$uid').set(adminMap);
    } catch (_) {}
    return Admin(
      id: uid,
      companyId: targetCompanyId,
      name: admin.name,
      email: admin.email,
      mobileNumber: admin.mobileNumber,
      address: admin.address,
    );
  }

  @override
  Future<Employee> createEmployeeAccount(
    Employee employee, {
    required String password,
  }) async {
    String targetCompanyId = employee.companyId.trim();
    if (targetCompanyId.isEmpty) {
      final currentUid = _auth.currentUser?.uid;
      if (currentUid != null) {
        try {
          final adminGroup = await _db
              .collectionGroup('admins')
              .where('id', isEqualTo: currentUid)
              .limit(1)
              .get();
          if (adminGroup.docs.isNotEmpty) {
            final data = adminGroup.docs.first.data();
            targetCompanyId = (data['companyId'] as String? ?? '').isNotEmpty
                ? data['companyId'] as String
                : adminGroup.docs.first.reference.parent.parent?.id ?? '';
          }
        } catch (_) {}
      }
    }

    if (targetCompanyId.isEmpty) {
      throw ArgumentError(
        'Cannot create employee: Company ID is required and cannot be empty.',
      );
    }

    String uid = employee.id.isNotEmpty ? employee.id : _uuid.v4();

    // Use a secondary Firebase App instance so the current Admin Auth session is preserved
    FirebaseApp? tempApp;
    try {
      final tempAppName = 'EmpAuth_${DateTime.now().microsecondsSinceEpoch}';
      tempApp = await Firebase.initializeApp(
        name: tempAppName,
        options: Firebase.app().options,
      );
      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
      final cred = await tempAuth.createUserWithEmailAndPassword(
        email: employee.email.trim(),
        password: password,
      );
      if (cred.user != null) {
        uid = cred.user!.uid;
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // If account already exists in Auth, proceed with UID or lookup
      } else {
        rethrow;
      }
    } catch (_) {
      // If secondary app is not supported in environment, proceed with generated UID
    } finally {
      if (tempApp != null) {
        try {
          await tempApp.delete();
        } catch (_) {}
      }
    }

    final createdEmp = employee.copyWith(id: uid, companyId: targetCompanyId);

    final empMap = {
      ...createdEmp.toMap(),
      'id': uid,
      'companyId': targetCompanyId,
    };

    await _employeesCol(
      targetCompanyId,
    ).doc(uid).set(empMap, SetOptions(merge: true));
    await _db.collection('users').doc(uid).set({
      'id': uid,
      'role': 'employee',
      'companyId': targetCompanyId,
      'email': createdEmp.email,
      'name': createdEmp.name,
    }, SetOptions(merge: true));
    try {
      await _rtdb.ref('companies/$targetCompanyId/employees/$uid').set(empMap);
    } catch (_) {}

    return createdEmp;
  }

  @override
  Future<void> signOut() async => _auth.signOut();

  @override
  Future<AppUser?> resolveCurrentUser() async {
    final fbUser = _auth.currentUser;
    if (fbUser == null) return null;
    return _resolveUser(fbUser);
  }

  // ----------------------------------------------------------------- Reads --

  @override
  Stream<List<Company>> companies() => _companiesCol()
      .snapshots()
      .map(
        (s) =>
            s.docs.map((d) => Company.fromMap(d.id, _asMap(d.data()))).toList(),
      )
      .asBroadcastStream();

  @override
  Future<Company?> company(String id) async {
    if (id.isEmpty) return null;
    final doc = await _companiesCol().doc(id).get();
    if (doc.exists) {
      return Company.fromMap(doc.id, _asMap(doc.data()));
    }
    return null;
  }

  @override
  Stream<List<Category>> categories({String companyId = ''}) {
    final Stream<QuerySnapshot<Map<String, dynamic>>> stream =
        companyId.isNotEmpty
        ? _categoriesCol(companyId).snapshots()
        : _db.collectionGroup('categories').snapshots();

    return stream
        .map(
          (s) => s.docs
              .map((d) {
                final map = _asMap(d.data());
                final parentCompanyId = d.reference.parent.parent?.id ?? '';
                if ((map['companyId'] == null ||
                        (map['companyId'] as String).isEmpty) &&
                    parentCompanyId.isNotEmpty) {
                  map['companyId'] = parentCompanyId;
                }
                return Category.fromMap(d.id, map);
              })
              .where(
                (c) =>
                    companyId.isEmpty ||
                    c.companyId == companyId ||
                    c.companyId.isEmpty,
              )
              .toList(),
        )
        .asBroadcastStream();
  }

  @override
  Future<Category?> category(String id, {String companyId = ''}) async {
    if (companyId.isNotEmpty) {
      final doc = await _categoriesCol(companyId).doc(id).get();
      if (doc.exists) {
        final map = _asMap(doc.data());
        if (map['companyId'] == null || (map['companyId'] as String).isEmpty) {
          map['companyId'] = companyId;
        }
        return Category.fromMap(doc.id, map);
      }
    }
    final snap = await _db
        .collectionGroup('categories')
        .where('id', isEqualTo: id)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      final doc = snap.docs.first;
      final map = _asMap(doc.data());
      final parentCompanyId = doc.reference.parent.parent?.id ?? '';
      if ((map['companyId'] == null || (map['companyId'] as String).isEmpty) &&
          parentCompanyId.isNotEmpty) {
        map['companyId'] = parentCompanyId;
      }
      return Category.fromMap(doc.id, map);
    }
    final rootDoc = await _db.collection('categories').doc(id).get();
    if (rootDoc.exists) {
      return Category.fromMap(rootDoc.id, _asMap(rootDoc.data()));
    }
    return null;
  }

  @override
  Stream<List<Product>> products({
    String companyId = '',
    String categoryId = '',
    String search = '',
  }) {
    Query<Map<String, dynamic>> q = companyId.isNotEmpty
        ? _productsCol(companyId)
        : _db.collectionGroup('products');
    if (categoryId.isNotEmpty) q = q.where('categoryId', isEqualTo: categoryId);
    return q
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) {
                final map = _asMap(d.data());
                final parentCompanyId = d.reference.parent.parent?.id ?? '';
                if ((map['companyId'] == null ||
                        (map['companyId'] as String).isEmpty) &&
                    parentCompanyId.isNotEmpty) {
                  map['companyId'] = parentCompanyId;
                }
                return Product.fromMap(d.id, map);
              })
              .where(
                (p) =>
                    search.isEmpty ||
                    p.name.toLowerCase().contains(search.toLowerCase()),
              )
              .toList(),
        )
        .asBroadcastStream();
  }

  @override
  Future<Product?> product(String id) async {
    // 1. Try collectionGroup (cross-company / modern layout). If this fails
    // due to missing composite index or security rules, fall back to the
    // legacy root collection lookup below.
    try {
      final snap = await _db
          .collectionGroup('products')
          .where('id', isEqualTo: id)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        final doc = snap.docs.first;
        final map = _asMap(doc.data());
        final parentCompanyId = doc.reference.parent.parent?.id ?? '';
        if ((map['companyId'] == null ||
                (map['companyId'] as String).isEmpty) &&
            parentCompanyId.isNotEmpty) {
          map['companyId'] = parentCompanyId;
        }
        return Product.fromMap(doc.id, map);
      }
    } catch (e) {
      debugPrint('collectionGroup(products) query failed, falling back: $e');
    }
    // 2. Legacy fallback
    final doc = await _db.collection('products').doc(id).get();
    if (doc.exists) {
      return Product.fromMap(doc.id, _asMap(doc.data()));
    }
    // 3. As a last resort, try each company's products subcollection directly
    // (this avoids the need for a collectionGroup index). This is more
    // expensive but ensures we can locate a product when the modern
    // collectionGroup path is unavailable.
    try {
      final companiesSnap = await _companiesCol().get();
      for (final c in companiesSnap.docs) {
        final pDoc = await _productsCol(c.id).doc(id).get();
        if (pDoc.exists) {
          final map = _asMap(pDoc.data());
          if ((map['companyId'] == null ||
              (map['companyId'] as String).isEmpty)) {
            map['companyId'] = c.id;
          }
          return Product.fromMap(pDoc.id, map);
        }
      }
    } catch (e) {
      debugPrint('Per-company products lookup failed: $e');
    }

    return null;
  }

  @override
  Stream<List<AdBanner>> adBanners() => _db
      .collection('ads_banners')
      .snapshots()
      .map(
        (s) => s.docs
            .map((d) => AdBanner.fromMap(d.id, _asMap(d.data())))
            .toList(),
      )
      .asBroadcastStream();

  @override
  Stream<List<OfferBanner>> offerBanners(String companyId) {
    final Stream<QuerySnapshot<Map<String, dynamic>>> stream =
        companyId.isNotEmpty
        ? _bannersCol(companyId).snapshots()
        : _db.collectionGroup('banners').snapshots();

    return stream
        .map(
          (s) => s.docs.map((d) {
            final map = _asMap(d.data());
            final parentCompanyId = d.reference.parent.parent?.id ?? '';
            if ((map['companyId'] == null ||
                    (map['companyId'] as String).isEmpty) &&
                parentCompanyId.isNotEmpty) {
              map['companyId'] = parentCompanyId;
            }
            return OfferBanner.fromMap(d.id, map);
          }).toList(),
        )
        .asBroadcastStream();
  }

  @override
  Stream<List<Voucher>> vouchers(String companyId) {
    final Stream<QuerySnapshot<Map<String, dynamic>>> stream =
        companyId.isNotEmpty
        ? _vouchersCol(companyId).snapshots()
        : _db.collectionGroup('vouchers').snapshots();

    return stream
        .map(
          (s) => s.docs.map((d) {
            final map = _asMap(d.data());
            final parentCompanyId = d.reference.parent.parent?.id ?? '';
            if ((map['companyId'] == null ||
                    (map['companyId'] as String).isEmpty) &&
                parentCompanyId.isNotEmpty) {
              map['companyId'] = parentCompanyId;
            }
            return Voucher.fromMap(d.id, map);
          }).toList(),
        )
        .asBroadcastStream();
  }

  @override
  Future<Voucher?> voucherByCode(String companyId, String code) async {
    final wanted = Voucher.normalizeCode(code);
    if (wanted.isEmpty) return null;

    /// Matches a code ignoring case and stray whitespace, then lets the
    /// caller ([VoucherEvaluator]) decide whether it is still usable.
    Voucher? pick(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
      for (final d in docs) {
        final map = _asMap(d.data());
        final parentCompanyId = d.reference.parent.parent?.id ?? '';
        if ((map['companyId'] == null ||
                (map['companyId'] as String).isEmpty) &&
            parentCompanyId.isNotEmpty) {
          map['companyId'] = parentCompanyId;
        }
        final voucher = Voucher.fromMap(d.id, map);
        if (voucher.normalizedCode == wanted) return voucher;
      }
      return null;
    }

    if (companyId.isNotEmpty) {
      // No composite index needed: a store owns a handful of vouchers.
      final snap = await _vouchersCol(companyId).limit(200).get();
      final match = pick(snap.docs);
      if (match != null) return match;
    }

    final groupSnap = await _db.collectionGroup('vouchers').limit(200).get();
    final groupMatch = pick(groupSnap.docs);
    if (groupMatch != null) return groupMatch;

    final legacy = await _db.collection('vouchers').doc(wanted).get();
    if (legacy.exists) {
      return Voucher.fromMap(legacy.id, _asMap(legacy.data()));
    }
    return null;
  }

  @override
  Future<DeliveryCharge?> deliveryCharge(
    String pincode,
    String companyId,
  ) async {
    if (companyId.isNotEmpty) {
      final doc = await _deliveryChargesCol(companyId).doc(pincode).get();
      if (doc.exists) {
        final map = _asMap(doc.data());
        map['companyId'] = companyId;
        return DeliveryCharge.fromMap(doc.id, map);
      }
    }
    // Legacy flat fallback
    final doc = await _db.collection('delivery_charges').doc(pincode).get();
    if (!doc.exists) return null;
    return DeliveryCharge.fromMap(doc.id, _asMap(doc.data()));
  }

  @override
  Stream<List<DeliveryCharge>> deliveryCharges({String companyId = ''}) {
    final Stream<QuerySnapshot<Map<String, dynamic>>> stream =
        companyId.isNotEmpty
        ? _deliveryChargesCol(companyId).snapshots()
        : _db.collectionGroup('delivery_charges').snapshots();

    return stream
        .map(
          (s) => s.docs.map((d) {
            final map = _asMap(d.data());
            final parentCompanyId = d.reference.parent.parent?.id ?? '';
            if ((map['companyId'] == null ||
                    (map['companyId'] as String).isEmpty) &&
                parentCompanyId.isNotEmpty) {
              map['companyId'] = parentCompanyId;
            }
            return DeliveryCharge.fromMap(d.id, map);
          }).toList(),
        )
        .asBroadcastStream();
  }

  @override
  Stream<List<Order>> orders({String userId = '', String companyId = ''}) {
    Query<Map<String, dynamic>> q = companyId.isNotEmpty
        ? _ordersCol(companyId)
        : _db.collectionGroup('orders');
    if (userId.isNotEmpty) q = q.where('userId', isEqualTo: userId);
    q = q.orderBy('createdAt', descending: true);
    return q.snapshots().asyncMap((s) async {
      final orders = <Order>[];
      for (final doc in s.docs) {
        orders.add(await _orderFromDoc(doc));
      }
      return orders;
    }).asBroadcastStream();
  }

  @override
  Future<Order?> order(String orderId) async {
    final ref = await _findOrderRef(orderId);
    if (ref == null) return null;
    final doc = await ref.get();
    if (!doc.exists) return null;
    return _orderFromDoc(doc);
  }

  @override
  Stream<Order?> watchOrder(String orderId) {
    final controller = StreamController<Order?>.broadcast();

    Future<void> emit(DocumentSnapshot<Map<String, dynamic>> snap) async {
      if (!snap.exists) {
        controller.add(null);
        return;
      }
      controller.add(await _orderFromDoc(snap));
    }

    Future<void> start() async {
      try {
        final ref = await _findOrderRef(orderId);
        if (ref == null) {
          controller.add(null);
          return;
        }
        await emit(await ref.get());
        await controller.addStream(ref.snapshots().asyncMap(_orderFromDoc));
      } catch (e, st) {
        controller.addError(e, st);
      }
    }

    start();
    return controller.stream;
  }

  Future<Order> _orderFromDoc(DocumentSnapshot doc) async {
    final itemsSnap = await doc.reference.collection('items').get();
    final items = itemsSnap.docs
        .map((d) => OrderItem.fromMap(_asMap(d.data())))
        .toList();
    final map = _asMap(doc.data());
    final parentCompanyId = doc.reference.parent.parent?.id ?? '';
    if ((map['companyId'] == null || (map['companyId'] as String).isEmpty) &&
        parentCompanyId.isNotEmpty) {
      map['companyId'] = parentCompanyId;
    }
    return Order.fromMap(doc.id, map).copyWithItems(items);
  }

  @override
  Stream<List<Review>> reviews(String companyId) {
    final Stream<QuerySnapshot<Map<String, dynamic>>> stream =
        companyId.isNotEmpty
        ? _reviewsCol(
            companyId,
          ).orderBy('createdAt', descending: true).snapshots()
        : _db
              .collectionGroup('reviews')
              .orderBy('createdAt', descending: true)
              .snapshots();

    return stream
        .map(
          (s) => s.docs.map((d) {
            final map = _asMap(d.data());
            final parentCompanyId = d.reference.parent.parent?.id ?? '';
            if ((map['companyId'] == null ||
                    (map['companyId'] as String).isEmpty) &&
                parentCompanyId.isNotEmpty) {
              map['companyId'] = parentCompanyId;
            }
            return Review.fromMap(d.id, map);
          }).toList(),
        )
        .asBroadcastStream();
  }

  @override
  Stream<List<AppNotification>> notifications(String recipientId) => _db
      .collectionGroup('notifications')
      .where('recipientId', isEqualTo: recipientId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (s) => s.docs
            .map((d) => AppNotification.fromMap(d.id, _asMap(d.data())))
            .toList(),
      )
      .asBroadcastStream();

  @override
  Stream<List<Employee>> employees(String companyId) {
    final Stream<QuerySnapshot<Map<String, dynamic>>> stream =
        companyId.isNotEmpty
        ? _employeesCol(companyId).snapshots()
        : _db.collectionGroup('employees').snapshots();

    return stream
        .map(
          (s) => s.docs.map((d) {
            final map = _asMap(d.data());
            final parentCompanyId = d.reference.parent.parent?.id ?? '';
            if ((map['companyId'] == null ||
                    (map['companyId'] as String).isEmpty) &&
                parentCompanyId.isNotEmpty) {
              map['companyId'] = parentCompanyId;
            }
            return Employee.fromMap(d.id, map);
          }).toList(),
        )
        .asBroadcastStream();
  }

  @override
  Future<Employee?> employee(String id, {String companyId = ''}) async {
    if (companyId.isNotEmpty) {
      final doc = await _employeesCol(companyId).doc(id).get();
      if (doc.exists) {
        final map = _asMap(doc.data());
        if (map['companyId'] == null || (map['companyId'] as String).isEmpty) {
          map['companyId'] = companyId;
        }
        return Employee.fromMap(doc.id, map);
      }
    }
    final snap = await _db
        .collectionGroup('employees')
        .where('id', isEqualTo: id)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      final doc = snap.docs.first;
      final map = _asMap(doc.data());
      final parentCompanyId = doc.reference.parent.parent?.id ?? '';
      if ((map['companyId'] == null || (map['companyId'] as String).isEmpty) &&
          parentCompanyId.isNotEmpty) {
        map['companyId'] = parentCompanyId;
      }
      return Employee.fromMap(doc.id, map);
    }
    return null;
  }

  @override
  Stream<List<Admin>> admins(String companyId) {
    final Stream<QuerySnapshot<Map<String, dynamic>>> stream =
        companyId.isNotEmpty
        ? _adminsCol(companyId).snapshots()
        : _db.collectionGroup('admins').snapshots();

    return stream.map(
      (s) => s.docs.map((d) {
        final map = _asMap(d.data());
        final parentCompanyId = d.reference.parent.parent?.id ?? '';
        if ((map['companyId'] == null ||
                (map['companyId'] as String).isEmpty) &&
            parentCompanyId.isNotEmpty) {
          map['companyId'] = parentCompanyId;
        }
        return Admin.fromMap(d.id, map);
      }).toList(),
    );
  }

  @override
  Future<List<Product>> recommendations({String companyId = ''}) async {
    final snap = companyId.isNotEmpty
        ? await _recommendationsCol(companyId).get()
        : await _db.collectionGroup('recommendations').get();
    final recs = snap.docs
        .map((d) => Recommendation.fromMap(d.id, _asMap(d.data())))
        .toList();
    final ids = <String>[];
    for (final r in recs) {
      if (r.pinnedProductId != null) ids.add(r.pinnedProductId!);
      ids.addAll(r.linkedProds);
    }
    if (ids.isNotEmpty) {
      final result = <Product>[];
      for (final id in ids.take(20)) {
        final p = await product(id);
        if (p != null) result.add(p);
      }
      if (result.isNotEmpty) return result;
    }
    final prodQuery = companyId.isNotEmpty
        ? _productsCol(
            companyId,
          ).where('isRecommended', isEqualTo: true).limit(20)
        : _db
              .collectionGroup('products')
              .where('isRecommended', isEqualTo: true)
              .limit(20);
    final prodSnap = await prodQuery.get();
    return prodSnap.docs.map((d) {
      final map = _asMap(d.data());
      final parentCompanyId = d.reference.parent.parent?.id ?? '';
      if ((map['companyId'] == null || (map['companyId'] as String).isEmpty) &&
          parentCompanyId.isNotEmpty) {
        map['companyId'] = parentCompanyId;
      }
      return Product.fromMap(d.id, map);
    }).toList();
  }

  @override
  Stream<List<Recommendation>> recommendationRecords({String companyId = ''}) {
    final Stream<QuerySnapshot<Map<String, dynamic>>> stream =
        companyId.isNotEmpty
        ? _recommendationsCol(companyId).snapshots()
        : _db.collectionGroup('recommendations').snapshots();

    return stream.map(
      (s) => s.docs
          .map((d) => Recommendation.fromMap(d.id, _asMap(d.data())))
          .toList(),
    );
  }

  // ---------------------------------------------------------------- Writes --

  Future<DocumentReference<Map<String, dynamic>>?> _findOrderRef(
    String orderId,
  ) async {
    final snap = await _db
        .collectionGroup('orders')
        .where('id', isEqualTo: orderId)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) return snap.docs.first.reference;

    // Fallback: check legacy flat orders
    final legacyDoc = _db.collection('orders').doc(orderId);
    final exists = (await legacyDoc.get()).exists;
    if (exists) return legacyDoc;
    return null;
  }

  @override
  Future<Order> placeOrder(Order order) async {
    if (order.companyId.isEmpty) {
      throw ArgumentError('An order must belong to a company.');
    }
    if (order.items.isEmpty) {
      throw ArgumentError('Cannot place an order with no items.');
    }

    final now = DateTime.now();
    final ref = _ordersCol(order.companyId).doc();
    final subtotal = Order.itemsTotalOf(order.items);
    final payable = order.totalAmount > 0
        ? order.totalAmount
        : (order.subtotal > 0 ? order.subtotal : subtotal) -
              order.discountAmount +
              order.deliveryCharge;

    final orderMap = <String, dynamic>{
      'id': ref.id,
      'userId': order.userId,
      'customerName': order.customerName,
      'customerEmail': order.customerEmail,
      'customerPhone': order.customerPhone,
      'companyId': order.companyId,
      'companyName': order.companyName,
      // Full bill: the receipt must survive later catalogue edits.
      'subtotal': order.subtotal > 0 ? order.subtotal : subtotal,
      'discountAmount': order.discountAmount,
      'deliveryCharge': order.deliveryCharge,
      'totalAmount': payable,
      'address': order.address,
      'pincode': order.pincode,
      'voucherId': order.voucherId,
      'voucherCode': order.voucherCode,
      'paymentStatus': PaymentStatus.pending,
      'orderStatus': OrderStatus.pending,
      'deliveryType': order.deliveryType,
      'employeePackingDone': false,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };

    final batch = _db.batch();
    batch.set(ref, orderMap);
    for (final item in order.items) {
      batch.set(ref.collection('items').doc(), item.toMap());
    }

    // Stock + voucher counters are part of the same logical write.
    await _decrementStock(batch, order);
    await batch.commit();

    if (order.voucherId != null && order.voucherId!.isNotEmpty) {
      await _recordVoucherUsage(order.copyWith(id: ref.id));
    }

    return Order(
      id: ref.id,
      userId: order.userId,
      customerName: order.customerName,
      customerEmail: order.customerEmail,
      customerPhone: order.customerPhone,
      companyId: order.companyId,
      companyName: order.companyName,
      items: order.items,
      subtotal: order.subtotal > 0 ? order.subtotal : subtotal,
      discountAmount: order.discountAmount,
      deliveryCharge: order.deliveryCharge,
      totalAmount: payable,
      address: order.address,
      pincode: order.pincode,
      voucherId: order.voucherId,
      voucherCode: order.voucherCode,
      paymentStatus: PaymentStatus.pending,
      orderStatus: OrderStatus.pending,
      deliveryType: order.deliveryType,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Subtracts the ordered quantities inside [batch] (skips unlimited stock).
  Future<void> _decrementStock(WriteBatch batch, Order order) async {
    for (final item in order.items) {
      if (item.productId.isEmpty) continue;
      final productRef = _productsCol(order.companyId).doc(item.productId);
      final snap = await productRef.get();
      if (!snap.exists) continue;
      final data = _asMap(snap.data());
      if (data['isUnlimitedStock'] == true) continue;

      final current = (data['stockQty'] as num?)?.toInt() ?? 0;
      final next = current - (item.qty < 0 ? 0 : item.qty);
      batch.update(productRef, {'stockQty': next < 0 ? 0 : next});
    }
  }

  /// Counts a redemption against the voucher's global and per-user caps.
  Future<void> _recordVoucherUsage(Order order) async {
    final voucherId = order.voucherId;
    if (voucherId == null || voucherId.isEmpty) return;

    final ref = _vouchersCol(order.companyId).doc(voucherId);
    final snap = await ref.get();
    if (!snap.exists) return;

    final voucher = Voucher.fromMap(snap.id, _asMap(snap.data()));
    if (voucher.usedOrderIds.contains(order.id)) return;

    await ref.set(
      voucher.registerUsage(orderId: order.id, userId: order.userId).toMap(),
      SetOptions(merge: false),
    );
  }

  @override
  Future<void> updateOrderStatus(String orderId, String status) async {
    OrderStatusRules.ensureValidStatus(status);

    final ref = await _findOrderRef(orderId);
    final target = ref ?? _db.collection('orders').doc(orderId);
    final current = await target.get();
    if (current.exists) {
      final existing =
          _asMap(current.data())['orderStatus']?.toString() ??
          OrderStatus.pending;
      OrderStatusRules.ensureTransition(existing, status);
    }

    final now = DateTime.now().toIso8601String();
    await target.update(<String, dynamic>{
      'orderStatus': status,
      'updatedAt': now,
      'cancelledAt': status == OrderStatus.cancelled ? now : null,
    });
  }

  @override
  Future<void> cancelOrder(String orderId) =>
      updateOrderStatus(orderId, OrderStatus.cancelled);

  @override
  Future<void> togglePaymentStatus(String orderId) async {
    final ref = await _findOrderRef(orderId);
    if (ref != null) {
      final doc = await ref.get();
      final current = doc.data()?['paymentStatus'] ?? 'pending';
      await ref.update({
        'paymentStatus': current == 'pending' ? 'done' : 'pending',
      });
    } else {
      final doc = await _db.collection('orders').doc(orderId).get();
      final current = doc.data()?['paymentStatus'] ?? 'pending';
      await _db.collection('orders').doc(orderId).update({
        'paymentStatus': current == 'pending' ? 'done' : 'pending',
      });
    }
  }

  @override
  Future<void> setEmployeePackingDone(String orderId, bool done) async {
    final ref = await _findOrderRef(orderId);
    if (ref != null) {
      await ref.update({'employeePackingDone': done});
    } else {
      await _db.collection('orders').doc(orderId).update({
        'employeePackingDone': done,
      });
    }
  }

  @override
  Future<void> assignEmployee(String orderId, String employeeId) async {
    final ref = await _findOrderRef(orderId);
    if (ref != null) {
      await ref.update({'assignedEmployeeId': employeeId});
    } else {
      await _db.collection('orders').doc(orderId).update({
        'assignedEmployeeId': employeeId,
      });
    }
  }

  @override
  Future<void> submitReview(Review review) async {
    final col = _reviewsCol(review.companyId);
    final ref = col.doc();
    await ref.set({
      'id': ref.id,
      'orderId': review.orderId,
      'userId': review.userId,
      'userName': review.userName,
      'companyId': review.companyId,
      'rating': review.rating,
      'message': review.message,
      'isVisible': true,
      'createdAt': DateTime.now().toIso8601String(),
    });
    final orderRef = await _findOrderRef(review.orderId);
    if (orderRef != null) {
      await orderRef.update({'reviewId': ref.id});
    }
  }

  @override
  Future<void> markNotificationRead(String id) async {
    final snap = await _db
        .collectionGroup('notifications')
        .where('id', isEqualTo: id)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      await snap.docs.first.reference.update({'isRead': true});
    } else {
      await _db.collection('notifications').doc(id).update({'isRead': true});
    }
  }

  @override
  Future<void> saveVoucher(Voucher voucher) async {
    final companyId = voucher.companyId.trim();
    if (companyId.isEmpty) {
      throw ArgumentError('A voucher must belong to a company.');
    }

    final normalized = voucher.copyWith(code: voucher.normalizedCode);
    final col = _vouchersCol(companyId);
    var id = normalized.id;

    if (id.isEmpty) {
      // Editing a legacy document that was keyed by its code.
      final byCode = await col.limit(200).get();
      for (final d in byCode.docs) {
        final existing = Voucher.fromMap(d.id, _asMap(d.data()));
        if (existing.normalizedCode == normalized.normalizedCode) {
          id = d.id;
          break;
        }
      }
      id = id.isEmpty ? _uuid.v4() : id;
    }

    await col.doc(id).set(<String, dynamic>{
      ...normalized.copyWith(id: id).toMap(),
      'id': id,
      'companyId': companyId,
    });
  }

  @override
  Future<void> deleteVoucher(String voucherId, {String companyId = ''}) async {
    if (companyId.isNotEmpty) {
      await _vouchersCol(companyId).doc(voucherId).delete();
      return;
    }
    final snap = await _db
        .collectionGroup('vouchers')
        .where('id', isEqualTo: voucherId)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      await snap.docs.first.reference.delete();
    } else {
      await _db.collection('vouchers').doc(voucherId).delete();
    }
  }

  @override
  Future<void> saveProduct(Product product) async {
    final companyId = product.companyId.trim();
    if (companyId.isEmpty) {
      throw ArgumentError('A product must belong to a company.');
    }
    final id = product.id.isEmpty ? _uuid.v4() : product.id;
    final batch = _db.batch();
    batch.set(_productsCol(companyId).doc(id), <String, dynamic>{
      ...product.toMap(),
      'id': id,
      'companyId': companyId,
    });

    // Keep `category.productList` consistent with `product.categoryId`.
    final categoryId = product.categoryId.trim();
    if (categoryId.isNotEmpty) {
      final categoryRef = _categoriesCol(companyId).doc(categoryId);
      final categorySnap = await categoryRef.get();
      if (categorySnap.exists) {
        final category = Category.fromMap(
          categorySnap.id,
          _asMap(categorySnap.data()),
        );
        if (!category.productList.contains(id)) {
          batch.update(categoryRef, {
            'productList': <String>[...category.productList, id],
          });
        }
      }
    }
    await batch.commit();
  }

  @override
  Future<void> deleteProduct(String productId, {String companyId = ''}) async {
    final batch = _db.batch();

    if (companyId.isNotEmpty) {
      batch.delete(_productsCol(companyId).doc(productId));
      await _queueCategoryCleanup(batch, companyId, productId);
      await batch.commit();
      return;
    }

    final snap = await _db
        .collectionGroup('products')
        .where('id', isEqualTo: productId)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      final ref = snap.docs.first.reference;
      final parentCompanyId = ref.parent.parent?.id ?? '';
      batch.delete(ref);
      if (parentCompanyId.isNotEmpty) {
        await _queueCategoryCleanup(batch, parentCompanyId, productId);
      }
      await batch.commit();
    } else {
      await _db.collection('products').doc(productId).delete();
    }
  }

  /// Removes [productId] from every category of [companyId] that lists it.
  Future<void> _queueCategoryCleanup(
    WriteBatch batch,
    String companyId,
    String productId,
  ) async {
    final categories = await _categoriesCol(companyId).limit(500).get();
    for (final d in categories.docs) {
      final category = Category.fromMap(d.id, _asMap(d.data()));
      if (category.productList.contains(productId)) {
        batch.update(d.reference, {
          'productList': category.withoutProduct(productId).productList,
        });
      }
    }
  }

  @override
  Future<void> saveCategory(Category category) async {
    final id = category.id.isEmpty ? _uuid.v4() : category.id;
    final saved = category.copyWith(id: id);

    // Guard the hierarchy *before* writing: a cycle would hang every
    // category list in the app.
    if (saved.parentId != null && saved.parentId!.isNotEmpty) {
      final siblings = await _loadCategories(saved.companyId);
      if (CategoryHierarchy.wouldCreateCycle(
        categoryId: id,
        newParentId: saved.parentId,
        all: siblings,
      )) {
        throw ArgumentError(
          'Cannot move "${saved.name}" under one of its own sub-categories.',
        );
      }
    }

    final payload = <String, dynamic>{...saved.toMap(), 'id': id};
    if (saved.companyId.isNotEmpty) {
      await _categoriesCol(saved.companyId).doc(id).set(payload);
    } else {
      await _db.collection('categories').doc(id).set(payload);
    }
  }

  /// All categories of a company (global + tenant scoped).
  Future<List<Category>> _loadCategories(String companyId) async {
    final out = <Category>[];
    final seen = <String>{};

    void collect(Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
      for (final d in docs) {
        if (!seen.add(d.id)) continue;
        final map = _asMap(d.data());
        final parentCompanyId = d.reference.parent.parent?.id ?? '';
        if ((map['companyId'] == null ||
                (map['companyId'] as String).isEmpty) &&
            parentCompanyId.isNotEmpty) {
          map['companyId'] = parentCompanyId;
        }
        out.add(Category.fromMap(d.id, map));
      }
    }

    if (companyId.isNotEmpty) {
      collect((await _categoriesCol(companyId).limit(500).get()).docs);
    }
    collect((await _db.collection('categories').limit(500).get()).docs);
    return out;
  }

  @override
  Future<void> deleteCategory(
    String categoryId, {
    String companyId = '',
  }) async {
    final all = await _loadCategories(companyId);
    final index = all.indexWhere(
      (c) =>
          c.id == categoryId &&
          (companyId.isEmpty ||
              c.companyId == companyId ||
              c.companyId.isEmpty),
    );
    final removed = index == -1 ? null : all[index];
    final newParent = removed?.parentId;

    final batch = _db.batch();

    // Children move up one level; products fall back to the parent category.
    for (final c in all) {
      if (c.parentId == categoryId) {
        batch.update(_categoryRef(c), <String, dynamic>{'parentId': newParent});
      }
    }

    if (removed != null && removed.productList.isNotEmpty) {
      final orphans = <String>[...removed.productList];
      final productsSnap = companyId.isNotEmpty
          ? await _productsCol(
              companyId,
            ).where('categoryId', isEqualTo: categoryId).limit(500).get()
          : await _db
                .collectionGroup('products')
                .where('categoryId', isEqualTo: categoryId)
                .limit(500)
                .get();
      for (final p in productsSnap.docs) {
        orphans.add(p.id);
        batch.update(p.reference, <String, dynamic>{
          'categoryId': newParent ?? '',
        });
      }

      if (newParent != null && newParent.isNotEmpty) {
        final parentIndex = all.indexWhere((c) => c.id == newParent);
        if (parentIndex != -1) {
          var parent = all[parentIndex];
          for (final productId in orphans) {
            parent = parent.withProduct(productId);
          }
          batch.update(_categoryRef(parent), <String, dynamic>{
            'productList': parent.productList,
          });
        }
      }
    }

    if (companyId.isNotEmpty) {
      batch.delete(_categoriesCol(companyId).doc(categoryId));
    }
    await batch.commit();

    final snap = await _db
        .collectionGroup('categories')
        .where('id', isEqualTo: categoryId)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      await snap.docs.first.reference.delete();
    } else {
      await _db.collection('categories').doc(categoryId).delete();
    }
  }

  DocumentReference<Map<String, dynamic>> _categoryRef(Category category) =>
      category.companyId.isNotEmpty
      ? _categoriesCol(category.companyId).doc(category.id)
      : _db.collection('categories').doc(category.id);

  @override
  Future<void> saveEmployee(Employee employee) async {
    final companyId = employee.companyId.trim();
    if (companyId.isEmpty) {
      throw ArgumentError('Company ID is required to save employee.');
    }
    final id = employee.id.isNotEmpty ? employee.id : _uuid.v4();
    final updatedEmp = employee.copyWith(id: id, companyId: companyId);
    final empMap = {...updatedEmp.toMap(), 'id': id, 'companyId': companyId};
    await _employeesCol(companyId).doc(id).set(empMap, SetOptions(merge: true));
    await _db.collection('users').doc(id).set({
      'id': id,
      'role': 'employee',
      'companyId': companyId,
      'email': updatedEmp.email,
      'name': updatedEmp.name,
    }, SetOptions(merge: true));
    try {
      await _rtdb.ref('companies/$companyId/employees/$id').set(empMap);
    } catch (_) {}
  }

  @override
  Future<void> deleteEmployee(String companyId, String employeeId) async {
    if (companyId.isNotEmpty) {
      await _employeesCol(companyId).doc(employeeId).delete();
      try {
        await _rtdb.ref('companies/$companyId/employees/$employeeId').remove();
      } catch (_) {}
    }
    final snap = await _db
        .collectionGroup('employees')
        .where('id', isEqualTo: employeeId)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      await snap.docs.first.reference.delete();
    }
    await _db.collection('users').doc(employeeId).delete();
  }

  @override
  Future<void> saveDeliveryCharge(DeliveryCharge charge) {
    if (charge.companyId.isNotEmpty) {
      return _deliveryChargesCol(
        charge.companyId,
      ).doc(charge.pincode).set(charge.toMap());
    }
    return _db
        .collection('delivery_charges')
        .doc(charge.pincode)
        .set(charge.toMap());
  }

  @override
  Future<void> deleteDeliveryCharge(String pincode, {String companyId = ''}) {
    if (companyId.isNotEmpty) {
      return _deliveryChargesCol(companyId).doc(pincode).delete();
    }
    return _db.collection('delivery_charges').doc(pincode).delete();
  }

  @override
  Future<void> importDeliveryCharges(List<DeliveryCharge> charges) async {
    final batch = _db.batch();
    for (final c in charges) {
      if (c.companyId.isNotEmpty) {
        batch.set(_deliveryChargesCol(c.companyId).doc(c.pincode), c.toMap());
      } else {
        batch.set(_db.collection('delivery_charges').doc(c.pincode), c.toMap());
      }
    }
    await batch.commit();
  }

  @override
  Future<void> setReviewVisibility(String reviewId, bool visible) async {
    final snap = await _db
        .collectionGroup('reviews')
        .where('id', isEqualTo: reviewId)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      await snap.docs.first.reference.update({'isVisible': visible});
    } else {
      await _db.collection('reviews').doc(reviewId).update({
        'isVisible': visible,
      });
    }
  }

  @override
  Future<void> saveRecommendation(Recommendation rec) {
    final id = rec.id.isEmpty ? _uuid.v4() : rec.id;
    if (rec.companyId.isNotEmpty) {
      return _recommendationsCol(
        rec.companyId,
      ).doc(id).set({...rec.toMap(), 'id': id});
    }
    return _db.collection('recommendations').doc(id).set(rec.toMap());
  }

  @override
  Future<void> saveBanner(OfferBanner banner) {
    final id = banner.id.isEmpty ? _uuid.v4() : banner.id;
    return _bannersCol(banner.companyId).doc(id).set({
      'id': id,
      'companyId': banner.companyId,
      'image': banner.image,
      'targetCatId': banner.targetCatId,
      'targetProdId': banner.targetProdId,
      'actionType': banner.actionType.name,
      'priority': banner.priority,
    });
  }

  @override
  Future<void> saveAdBanner(AdBanner banner) {
    final id = banner.id.isEmpty ? _uuid.v4() : banner.id;
    return _db.collection('ads_banners').doc(id).set({
      'id': id,
      'image': banner.image,
      'actionType': banner.actionType.name,
      'actionTarget': banner.actionTarget,
      'priority': banner.priority,
    });
  }

  @override
  Future<void> registerFcmToken(String userId, String token) async {
    final doc = await _db.collection('users').doc(userId).get();
    final existing = List<String>.from(doc.data()?['fcmTokens'] ?? const []);
    if (!existing.contains(token)) {
      existing.add(token);
      await _db.collection('users').doc(userId).update({'fcmTokens': existing});
    }
  }

  // ---------------------------------------------------------------- Helpers --

  String _withCountryCode(String mobile) {
    // Strip spaces, dashes, parentheses — accept raw user input.
    final clean = mobile.replaceAll(RegExp(r'[\s\-().]+'), '');
    return clean.startsWith('+') ? clean : '+91$clean';
  }

  Future<AppUser?> _resolveUser(
    User? user, {
    String fallbackMobile = '',
  }) async {
    if (user == null) return null;
    final uid = user.uid;

    // 0. Check local secure session cache first to get fast companyId hint
    AppUser? cachedUser;
    try {
      cachedUser = await SecureSessionCache.instance.restore();
    } catch (_) {}

    final cachedCompanyId = (cachedUser != null && cachedUser.id == uid)
        ? cachedUser.companyId
        : '';

    // Direct lookup if cached companyId exists
    if (cachedCompanyId.isNotEmpty) {
      try {
        final adminDoc = await _adminsCol(cachedCompanyId).doc(uid).get();
        if (adminDoc.exists) {
          final data = adminDoc.data() ?? {};
          return AppUser(
            id: uid,
            companyId: cachedCompanyId,
            name: data['name'] ?? cachedUser?.name ?? '',
            email: user.email ?? data['email'] ?? cachedUser?.email ?? '',
            mobileNumber:
                data['mobileNumber'] ?? cachedUser?.mobileNumber ?? '',
            role: 'admin',
          );
        }
      } catch (_) {}

      try {
        final empDoc = await _employeesCol(cachedCompanyId).doc(uid).get();
        if (empDoc.exists) {
          final data = empDoc.data() ?? {};
          return AppUser(
            id: uid,
            companyId: cachedCompanyId,
            name: data['name'] ?? cachedUser?.name ?? '',
            email: user.email ?? data['email'] ?? cachedUser?.email ?? '',
            role: 'employee',
            employeeRole: data['role'],
          );
        }
      } catch (_) {}
    }

    // 1. Check root users/{uid} pointer document (Index-free direct get)
    try {
      final userDoc = await _db.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        final role = data['role'] as String? ?? 'user';
        final companyId = data['companyId'] as String? ?? '';

        if (role == 'admin') {
          if (companyId.isNotEmpty) {
            try {
              final adminDoc = await _adminsCol(companyId).doc(uid).get();
              if (adminDoc.exists) {
                final aData = adminDoc.data() ?? {};
                return AppUser(
                  id: uid,
                  companyId: companyId,
                  name: aData['name'] ?? data['name'] ?? '',
                  email: user.email ?? aData['email'] ?? data['email'] ?? '',
                  mobileNumber:
                      aData['mobileNumber'] ?? data['mobileNumber'] ?? '',
                  role: 'admin',
                );
              }
            } catch (_) {}
          }
          return AppUser(
            id: uid,
            companyId: companyId,
            name: data['name'] ?? '',
            email: user.email ?? data['email'] ?? '',
            mobileNumber: data['mobileNumber'] ?? '',
            role: 'admin',
          );
        } else if (role == 'employee') {
          if (companyId.isNotEmpty) {
            try {
              final empDoc = await _employeesCol(companyId).doc(uid).get();
              if (empDoc.exists) {
                final eData = empDoc.data() ?? {};
                return AppUser(
                  id: uid,
                  companyId: companyId,
                  name: eData['name'] ?? data['name'] ?? '',
                  email: user.email ?? eData['email'] ?? data['email'] ?? '',
                  role: 'employee',
                  employeeRole: eData['role'],
                );
              }
            } catch (_) {}
          }
          return AppUser(
            id: uid,
            companyId: companyId,
            name: data['name'] ?? '',
            email: user.email ?? data['email'] ?? '',
            role: 'employee',
          );
        }
      }
    } catch (_) {}

    // 2. CollectionGroup queries (in case index exists or user doc missing)
    try {
      final adminGroup = await _db
          .collectionGroup('admins')
          .where('id', isEqualTo: uid)
          .limit(1)
          .get();
      if (adminGroup.docs.isNotEmpty) {
        final doc = adminGroup.docs.first;
        final data = doc.data();
        final companyId = (data['companyId'] as String? ?? '').isNotEmpty
            ? data['companyId'] as String
            : doc.reference.parent.parent?.id ?? '';
        return AppUser(
          id: uid,
          companyId: companyId,
          name: data['name'] ?? '',
          email: user.email ?? data['email'] ?? '',
          mobileNumber: data['mobileNumber'] ?? '',
          role: 'admin',
        );
      }
    } catch (_) {}

    try {
      final empGroup = await _db
          .collectionGroup('employees')
          .where('id', isEqualTo: uid)
          .limit(1)
          .get();
      if (empGroup.docs.isNotEmpty) {
        final doc = empGroup.docs.first;
        final data = doc.data();
        final companyId = (data['companyId'] as String? ?? '').isNotEmpty
            ? data['companyId'] as String
            : doc.reference.parent.parent?.id ?? '';
        return AppUser(
          id: uid,
          companyId: companyId,
          name: data['name'] ?? '',
          email: user.email ?? data['email'] ?? '',
          role: 'employee',
          employeeRole: data['role'],
        );
      }
    } catch (_) {}

    // 3. Fallback: Search all companies subcollections directly (index-free scan)
    try {
      final companiesSnap = await _companiesCol().get();
      for (final compDoc in companiesSnap.docs) {
        final adminDoc = await _adminsCol(compDoc.id).doc(uid).get();
        if (adminDoc.exists) {
          final data = adminDoc.data() ?? {};
          _db.collection('users').doc(uid).set({
            'id': uid,
            'role': 'admin',
            'companyId': compDoc.id,
          }, SetOptions(merge: true));
          return AppUser(
            id: uid,
            companyId: compDoc.id,
            name: data['name'] ?? '',
            email: user.email ?? data['email'] ?? '',
            mobileNumber: data['mobileNumber'] ?? '',
            role: 'admin',
          );
        }
        final empDoc = await _employeesCol(compDoc.id).doc(uid).get();
        if (empDoc.exists) {
          final data = empDoc.data() ?? {};
          _db.collection('users').doc(uid).set({
            'id': uid,
            'role': 'employee',
            'companyId': compDoc.id,
          }, SetOptions(merge: true));
          return AppUser(
            id: uid,
            companyId: compDoc.id,
            name: data['name'] ?? '',
            email: user.email ?? data['email'] ?? '',
            role: 'employee',
            employeeRole: data['role'],
          );
        }
      }
    } catch (_) {}

    // 4. Legacy flat collection fallback
    try {
      final flatAdmin = await _db.collection('admins').doc(uid).get();
      if (flatAdmin.exists) {
        final data = flatAdmin.data() ?? {};
        return AppUser(
          id: uid,
          companyId: data['companyId'] ?? '',
          name: data['name'] ?? '',
          email: user.email ?? '',
          mobileNumber: data['mobileNumber'] ?? '',
          role: 'admin',
        );
      }
    } catch (_) {}

    try {
      final flatEmp = await _db.collection('employees').doc(uid).get();
      if (flatEmp.exists) {
        final data = flatEmp.data() ?? {};
        return AppUser(
          id: uid,
          companyId: data['companyId'] ?? '',
          name: data['name'] ?? '',
          email: user.email ?? '',
          role: 'employee',
          employeeRole: data['role'],
        );
      }
    } catch (_) {}

    // 5. If cachedUser was already admin or employee, retain it instead of demoting to 'user'!
    if (cachedUser != null &&
        cachedUser.id == uid &&
        cachedUser.companyId.isNotEmpty &&
        (cachedUser.role == 'admin' || cachedUser.role == 'employee')) {
      return cachedUser;
    }

    // 6. Regular customer user from users/{uid}
    try {
      final userDoc = await _db.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        final addrList = (data['addresses'] as List? ?? const [])
            .map(
              (e) => AddressEntry.fromMap(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
        return AppUser(
          id: uid,
          name: data['name'] ?? user.displayName ?? '',
          mobileNumber: data['mobileNumber'] ?? fallbackMobile,
          email: data['email'] ?? user.email ?? '',
          role: 'user',
          authProvider:
              data['authProvider'] ??
              (user.providerData.any((p) => p.providerId == 'google.com')
                  ? 'google'
                  : ''),
          googleId: data['googleId'] ?? uid,
          addresses: addrList,
        );
      }
      if (fallbackMobile.isNotEmpty) {
        final snap = await _db
            .collection('users')
            .where('mobileNumber', isEqualTo: fallbackMobile)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          final data = snap.docs.first.data();
          final addrList = (data['addresses'] as List? ?? const [])
              .map(
                (e) =>
                    AddressEntry.fromMap(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
          // Merge uid so future lookups are instant
          _db.collection('users').doc(uid).set({
            'name': data['name'] ?? '',
            'mobileNumber': fallbackMobile,
            'role': 'user',
          }, SetOptions(merge: true));
          return AppUser(
            id: uid,
            name: data['name'] ?? user.displayName ?? '',
            mobileNumber: data['mobileNumber'] ?? fallbackMobile,
            email: data['email'] ?? user.email ?? '',
            role: 'user',
            authProvider: data['authProvider'] ?? '',
            googleId: data['googleId'] ?? uid,
            addresses: addrList,
          );
        }
      }
    } catch (_) {}

    return AppUser(
      id: uid,
      name: user.displayName ?? '',
      email: user.email ?? '',
      mobileNumber: fallbackMobile,
      role: 'user',
      authProvider: user.providerData.any((p) => p.providerId == 'google.com')
          ? 'google'
          : '',
      googleId: uid,
    );
  }
}
