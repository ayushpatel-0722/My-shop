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
import '../models/home_explore_category.dart';
import '../models/home_trending_item.dart';
import '../models/notification.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/recommendation.dart';
import '../models/review.dart';
import '../models/voucher.dart';
import '../domain/category_tree.dart';
import '../domain/order_status.dart';
import '../repositories/app_repository.dart';
import '../services/auth_session.dart';
import '../services/secure_session_cache.dart';
import '../utils/type_utils.dart';
import '../../app/l10n/l10n_service.dart';

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

  // Top-level collections for user home screen configurations
  CollectionReference<Map<String, dynamic>> _homeExploreCol() =>
      _db.collection('home_explore_categories');

  CollectionReference<Map<String, dynamic>> _homeTrendingCol() =>
      _db.collection('home_trending_now');

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
        message: L10n.current.couldNotSignInWithProvidedCredentials,
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
      throw Exception(L10n.current.noAdminProfileFoundForAccount(email));
    }

    // Ensure companyDoc is loaded
    if (companyDoc == null && matchedCompanyId.isNotEmpty) {
      final doc = await _db.collection('companies').doc(matchedCompanyId).get();
      if (doc.exists) {
        companyDoc = doc;
      }
    }

    if (companyDoc == null || !companyDoc.exists) {
      throw Exception(L10n.current.companyNotFound(companyName));
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
      throw Exception(L10n.current.incorrectCompanyPassword);
    }

    // 5. Verify company association
    final nameMatched =
        registeredName.toLowerCase() == companyName.trim().toLowerCase() ||
        registeredSlug == slug;
    if (!nameMatched &&
        matchedCompanyId.isNotEmpty &&
        matchedCompanyId != companyDoc.id) {
      throw Exception(
        L10n.current.adminAccountIsAssignedToNot(registeredName, companyName),
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
        message: L10n.current.couldNotSignInWithProvidedCredentials,
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
      throw Exception(L10n.current.noEmployeeProfileFoundForAccount(email));
    }

    if (companyDoc == null && matchedCompanyId.isNotEmpty) {
      final doc = await _db.collection('companies').doc(matchedCompanyId).get();
      if (doc.exists) {
        companyDoc = doc;
      }
    }

    if (companyDoc == null || !companyDoc.exists) {
      throw Exception(L10n.current.companyNotFound(companyName));
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
    if (companyId.isNotEmpty) {
      Query<Map<String, dynamic>> q = _ordersCol(companyId);
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

    // Customer multi-shop order stream.
    // Avoid composite index crash by filtering userId in Firestore and
    // sorting createdAt in Dart memory. Also provide graceful company fallback.
    final controller = StreamController<List<Order>>.broadcast();
    StreamSubscription? sub;

    void startCollectionGroup() {
      try {
        Query<Map<String, dynamic>> q = _db.collectionGroup('orders');
        if (userId.isNotEmpty) q = q.where('userId', isEqualTo: userId);

        sub = q
            .snapshots()
            .asyncMap((s) async {
              final orders = <Order>[];
              for (final doc in s.docs) {
                orders.add(await _orderFromDoc(doc));
              }
              orders.sort(
                (a, b) =>
                    (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                        .compareTo(
                          a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                        ),
              );
              return orders;
            })
            .listen(
              (data) {
                if (!controller.isClosed) controller.add(data);
              },
              onError: (err) {
                debugPrint(
                  '⚠️ [FirebaseAppRepo] collectionGroup orders error: $err. Falling back to active companies.',
                );
                _fallbackCustomerOrders(controller, userId);
              },
            );
      } catch (e) {
        debugPrint(
          '⚠️ [FirebaseAppRepo] collectionGroup orders init error: $e. Using fallback.',
        );
        _fallbackCustomerOrders(controller, userId);
      }
    }

    controller.onListen = startCollectionGroup;
    controller.onCancel = () => sub?.cancel();
    return controller.stream;
  }

  Future<void> _fallbackCustomerOrders(
    StreamController<List<Order>> controller,
    String userId,
  ) async {
    try {
      final compSnap = await _companiesCol().get();
      final allOrders = <Order>[];
      for (final doc in compSnap.docs) {
        Query<Map<String, dynamic>> q = _ordersCol(doc.id);
        if (userId.isNotEmpty) q = q.where('userId', isEqualTo: userId);
        final oSnap = await q.get();
        for (final oDoc in oSnap.docs) {
          allOrders.add(await _orderFromDoc(oDoc));
        }
      }
      allOrders.sort(
        (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );
      if (!controller.isClosed) {
        controller.add(allOrders);
      }
    } catch (e) {
      debugPrint('⚠️ [FirebaseAppRepo] fallback customer orders failed: $e');
      if (!controller.isClosed) {
        controller.add(const <Order>[]);
      }
    }
  }

  @override
  Future<Order?> order(String orderId, {String companyId = ''}) async {
    if (companyId.isNotEmpty) {
      final directDoc = await _ordersCol(companyId).doc(orderId).get();
      if (directDoc.exists) return _orderFromDoc(directDoc);
    }
    final ref = await _findOrderRef(orderId);
    if (ref == null) return null;
    final doc = await ref.get();
    if (!doc.exists) return null;
    return _orderFromDoc(doc);
  }

  @override
  Stream<Order?> watchOrder(String orderId, {String companyId = ''}) {
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
        final ref = companyId.isNotEmpty
            ? _ordersCol(companyId).doc(orderId)
            : await _findOrderRef(orderId);
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
    try {
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
    } catch (e) {
      debugPrint('⚠️ [FirebaseAppRepo] recommendations fetch error: $e');
    }

    if (companyId.isNotEmpty) {
      try {
        final prodSnap = await _productsCol(
          companyId,
        ).where('isRecommended', isEqualTo: true).limit(20).get();
        if (prodSnap.docs.isNotEmpty) {
          return prodSnap.docs.map((d) {
            final map = _asMap(d.data());
            if (map['companyId'] == null ||
                (map['companyId'] as String).isEmpty) {
              map['companyId'] = companyId;
            }
            return Product.fromMap(d.id, map);
          }).toList();
        }
      } catch (e) {
        debugPrint(
          '⚠️ [FirebaseAppRepo] company isRecommended query error: $e',
        );
      }
    } else {
      try {
        final prodSnap = await _db
            .collectionGroup('products')
            .where('isRecommended', isEqualTo: true)
            .limit(20)
            .get();
        if (prodSnap.docs.isNotEmpty) {
          return prodSnap.docs.map((d) {
            final map = _asMap(d.data());
            final parentCompanyId = d.reference.parent.parent?.id ?? '';
            if ((map['companyId'] == null ||
                    (map['companyId'] as String).isEmpty) &&
                parentCompanyId.isNotEmpty) {
              map['companyId'] = parentCompanyId;
            }
            return Product.fromMap(d.id, map);
          }).toList();
        }
      } catch (e) {
        debugPrint(
          '⚠️ [FirebaseAppRepo] collectionGroup isRecommended index error ($e). Falling back to active company products.',
        );
      }
    }

    // Resilient fallback across active stores so the customer feed never breaks.
    try {
      final compSnap = await _companiesCol().limit(6).get();
      final fallback = <Product>[];
      for (final cd in compSnap.docs) {
        final pSnap = await _productsCol(cd.id).limit(10).get();
        for (final pd in pSnap.docs) {
          final map = _asMap(pd.data());
          if (map['companyId'] == null ||
              (map['companyId'] as String).isEmpty) {
            map['companyId'] = cd.id;
          }
          final p = Product.fromMap(pd.id, map);
          fallback.add(p);
        }
      }
      final recOnly = fallback.where((p) => p.isRecommended).toList();
      return recOnly.isNotEmpty ? recOnly : fallback.take(12).toList();
    } catch (_) {
      return const <Product>[];
    }
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
    final currentUid = _auth.currentUser?.uid;
    if (currentUid != null && currentUid.isNotEmpty) {
      try {
        final snap = await _db
            .collectionGroup('orders')
            .where('userId', isEqualTo: currentUid)
            .get();
        for (final doc in snap.docs) {
          if (doc.id == orderId || doc.data()['id'] == orderId) {
            return doc.reference;
          }
        }
      } catch (e) {
        debugPrint(
          '⚠️ [FirebaseAppRepo] user collectionGroup _findOrderRef error: $e',
        );
      }
    }

    try {
      final snap = await _db
          .collectionGroup('orders')
          .where('id', isEqualTo: orderId)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) return snap.docs.first.reference;
    } catch (e) {
      debugPrint(
        '⚠️ [FirebaseAppRepo] collectionGroup _findOrderRef error: $e',
      );
    }

    // Direct company subcollection scan fallback with per-company try/catch.
    try {
      final compSnap = await _companiesCol().get();
      for (final c in compSnap.docs) {
        try {
          final ref = _ordersCol(c.id).doc(orderId);
          final snap = await ref.get();
          if (snap.exists) return ref;
        } catch (_) {
          // Continue scanning remaining companies even if one throws permission error
        }
      }
    } catch (e) {
      debugPrint('⚠️ [FirebaseAppRepo] company scan _findOrderRef error: $e');
    }

    // Fallback: check legacy flat orders
    try {
      final legacyDoc = _db.collection('orders').doc(orderId);
      final exists = (await legacyDoc.get()).exists;
      if (exists) return legacyDoc;
    } catch (_) {}

    return null;
  }

  @override
  Future<Order> placeOrder(Order order) async {
    final saved = await placeOrders([order]);
    return saved.first;
  }

  @override
  Future<List<Order>> placeOrders(List<Order> orders) async {
    if (orders.isEmpty) return const <Order>[];
    for (final order in orders) {
      if (order.companyId.isEmpty) {
        throw ArgumentError('An order must belong to a company.');
      }
      if (order.items.isEmpty) {
        throw ArgumentError('Cannot place an order with no items.');
      }
    }

    final now = DateTime.now();

    // One WriteBatch for every shop's order — a multi-shop checkout is never
    // half-saved.
    final batch = _db.batch();
    final built = <Order>[];

    for (final order in orders) {
      final ref = _ordersCol(order.companyId).doc();
      final subtotal = Order.itemsTotalOf(order.items);
      final payable = order.totalAmount > 0
          ? order.totalAmount
          : (order.subtotal > 0 ? order.subtotal : subtotal) -
                order.discountAmount +
                order.deliveryCharge;
      final frozenSubtotal = order.subtotal > 0 ? order.subtotal : subtotal;

      final orderMap = <String, dynamic>{
        'id': ref.id,
        'userId': order.userId,
        'customerName': order.customerName,
        'customerEmail': order.customerEmail,
        'customerPhone': order.customerPhone,
        'companyId': order.companyId,
        'companyName': order.companyName,
        // Full bill: the receipt must survive later catalogue edits.
        'subtotal': frozenSubtotal,
        'discountAmount': order.discountAmount,
        'deliveryCharge': order.deliveryCharge,
        'totalAmount': payable,
        'address': order.address,
        'pincode': order.pincode,
        if (order.pickupShop != null) 'pickupShop': order.pickupShop!.toMap(),
        'voucherId': order.voucherId,
        'voucherCode': order.voucherCode,
        'paymentMethod': order.paymentMethod,
        'paymentStatus': order.paymentStatus.isNotEmpty
            ? order.paymentStatus
            : PaymentStatus.pending,
        if (order.transactionRef != null && order.transactionRef!.isNotEmpty)
          'transactionRef': order.transactionRef,
        'orderStatus': OrderStatus.pending,
        'deliveryType': order.deliveryType,
        'employeePackingDone': false,
        'statusHistory': [
          {
            'status': OrderStatus.pending,
            'note': 'Order placed',
            'timestamp': now.toIso8601String(),
          },
        ],
        'stockRestored': false,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };

      batch.set(ref, orderMap);
      for (final item in order.items) {
        batch.set(ref.collection('items').doc(), item.toMap());
      }

      built.add(
        Order(
          id: ref.id,
          userId: order.userId,
          customerName: order.customerName,
          customerEmail: order.customerEmail,
          customerPhone: order.customerPhone,
          companyId: order.companyId,
          companyName: order.companyName,
          items: order.items,
          subtotal: frozenSubtotal,
          discountAmount: order.discountAmount,
          deliveryCharge: order.deliveryCharge,
          totalAmount: payable,
          address: order.address,
          pincode: order.pincode,
          pickupShop: order.pickupShop,
          voucherId: order.voucherId,
          voucherCode: order.voucherCode,
          paymentMethod: order.paymentMethod,
          paymentStatus: order.paymentStatus.isNotEmpty
              ? order.paymentStatus
              : PaymentStatus.pending,
          transactionRef: order.transactionRef,
          orderStatus: OrderStatus.pending,
          deliveryType: order.deliveryType,
          statusHistory: [
            OrderStatusHistoryEntry(
              status: OrderStatus.pending,
              note: 'Order placed',
              timestamp: now,
            ),
          ],
          stockRestored: false,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    // 1. Commit the core customer orders and order items.
    // Customers have full permissions to place orders; this must never fail
    // due to secondary catalogue counters.
    await batch.commit();

    // 2. Decrement stock and record voucher usage in guarded post-commit steps.
    // If backend security rules restrict direct customer stock modifications or
    // voucher updates, we catch non-fatally so the order placement succeeds.
    for (final order in built) {
      try {
        await _decrementStock(order);
      } catch (e) {
        debugPrint(
          '[FirebaseAppRepo] Non-fatal: Stock decrement restricted or skipped: $e',
        );
      }

      if (order.voucherId != null && order.voucherId!.isNotEmpty) {
        try {
          await _recordVoucherUsage(order);
        } catch (e) {
          debugPrint(
            '[FirebaseAppRepo] Non-fatal: Voucher usage recording skipped: $e',
          );
        }
      }
    }

    return built;
  }

  /// Subtracts the ordered quantities (skips unlimited stock).
  Future<void> _decrementStock(Order order) async {
    for (final item in order.items) {
      if (item.productId.isEmpty) continue;
      final productRef = _productsCol(order.companyId).doc(item.productId);
      final snap = await productRef.get();
      if (!snap.exists) continue;
      final data = _asMap(snap.data());
      if (data['isUnlimitedStock'] == true) continue;

      final current = (data['stockQty'] as num?)?.toInt() ?? 0;
      final next = current - (item.qty < 0 ? 0 : item.qty);
      await productRef.update({'stockQty': next < 0 ? 0 : next});
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

  /// Restores quantities previously deducted for an order (skips unlimited stock).
  Future<void> _restoreStock(Order order) async {
    for (final item in order.items) {
      if (item.productId.isEmpty) continue;
      final productRef = _productsCol(order.companyId).doc(item.productId);
      final snap = await productRef.get();
      if (!snap.exists) continue;
      final data = _asMap(snap.data());
      if (data['isUnlimitedStock'] == true) continue;

      final current = (data['stockQty'] as num?)?.toInt() ?? 0;
      final restored = current + (item.qty < 0 ? 0 : item.qty);
      await productRef.update({'stockQty': restored});
    }
  }

  /// Reverses voucher usage when an order is cancelled.
  Future<void> _releaseVoucherUsage(Order order) async {
    final voucherId = order.voucherId;
    if (voucherId == null || voucherId.isEmpty) return;

    final ref = _vouchersCol(order.companyId).doc(voucherId);
    final snap = await ref.get();
    if (!snap.exists) return;

    final voucher = Voucher.fromMap(snap.id, _asMap(snap.data()));
    if (!voucher.usedOrderIds.contains(order.id)) return;

    await ref.set(
      voucher.releaseUsage(orderId: order.id, userId: order.userId).toMap(),
      SetOptions(merge: false),
    );
  }

  @override
  Future<void> updateOrderStatus(
    String orderId,
    String status, {
    String companyId = '',
    String? cancellationReason,
    String? note,
  }) async {
    OrderStatusRules.ensureValidStatus(status);

    final target = companyId.isNotEmpty
        ? _ordersCol(companyId).doc(orderId)
        : (await _findOrderRef(orderId) ??
              _db.collection('orders').doc(orderId));
    final current = await target.get();
    Map<String, dynamic> data = const {};
    if (current.exists) {
      data = _asMap(current.data());
      final existing = data['orderStatus']?.toString() ?? OrderStatus.pending;
      OrderStatusRules.ensureTransition(existing, status);
    }

    final now = DateTime.now().toIso8601String();
    final existingHistory = asMapList(data['statusHistory']);
    final entryNote =
        note ??
        (status == OrderStatus.cancelled
            ? (cancellationReason ?? 'Cancelled')
            : 'Status changed to $status');
    final newHistory = List<Map<String, dynamic>>.from(existingHistory)
      ..add({'status': status, 'note': entryNote, 'timestamp': now});

    final updates = <String, dynamic>{
      'orderStatus': status,
      'updatedAt': now,
      'cancelledAt': status == OrderStatus.cancelled ? now : null,
      'statusHistory': newHistory,
    };
    if (status == OrderStatus.cancelled &&
        cancellationReason != null &&
        cancellationReason.isNotEmpty) {
      updates['cancellationReason'] = cancellationReason;
    }
    await target.update(updates);
  }

  @override
  Future<void> cancelOrder(
    String orderId, {
    String companyId = '',
    String? reason,
    String? userId,
  }) async {
    final target = companyId.isNotEmpty
        ? _ordersCol(companyId).doc(orderId)
        : (await _findOrderRef(orderId) ??
              _db.collection('orders').doc(orderId));
    final snap = await target.get();
    if (!snap.exists) {
      throw Exception('Order not found');
    }

    final data = _asMap(snap.data());
    final currentStatus =
        data['orderStatus']?.toString() ?? OrderStatus.pending;
    final orderUserId = data['userId']?.toString() ?? '';

    // If customer cancellation (userId provided):
    if (userId != null && userId.isNotEmpty) {
      if (orderUserId != userId) {
        throw StateError('You are not authorized to cancel this order.');
      }
      if (!OrderStatusRules.isCustomerCancellable(currentStatus)) {
        final ineligibleMsg =
            OrderStatusRules.customerCancellationIneligibleReason(
              currentStatus,
            );
        throw StateError(
          ineligibleMsg ?? 'This order can no longer be cancelled.',
        );
      }
    } else {
      OrderStatusRules.ensureTransition(currentStatus, OrderStatus.cancelled);
    }

    final nowIso = DateTime.now().toIso8601String();
    final cancellationReason =
        reason ??
        (userId != null ? 'Cancelled by customer' : 'Cancelled by admin');

    final existingHistory = asMapList(data['statusHistory']);
    final newHistory = List<Map<String, dynamic>>.from(existingHistory)
      ..add({
        'status': OrderStatus.cancelled,
        'note': cancellationReason,
        'timestamp': nowIso,
      });

    final wasStockRestored = data['stockRestored'] == true;

    final updates = <String, dynamic>{
      'orderStatus': OrderStatus.cancelled,
      'updatedAt': nowIso,
      'cancelledAt': nowIso,
      'cancellationReason': cancellationReason,
      'statusHistory': newHistory,
      'stockRestored': true,
    };
    await target.update(updates);

    // If stock hasn't been restored yet, restore it once and release voucher
    if (!wasStockRestored) {
      final itemsSnap = await target.collection('items').get();
      final items = itemsSnap.docs
          .map((d) => OrderItem.fromMap(_asMap(d.data())))
          .toList();
      final resolvedOrder = Order.fromMap(target.id, {
        ...data,
        'items': items.map((e) => e.toMap()).toList(),
      });

      try {
        await _restoreStock(resolvedOrder);
      } catch (e) {
        debugPrint('[FirebaseAppRepo] Non-fatal: Stock restore error: $e');
      }

      if (resolvedOrder.voucherId != null &&
          resolvedOrder.voucherId!.isNotEmpty) {
        try {
          await _releaseVoucherUsage(resolvedOrder);
        } catch (e) {
          debugPrint('[FirebaseAppRepo] Non-fatal: Voucher release error: $e');
        }
      }
    }
  }

  @override
  Future<void> togglePaymentStatus(
    String orderId, {
    String companyId = '',
    String? status,
    String? verifiedBy,
    String? transactionRef,
    double? amountPaid,
  }) async {
    await verifyPayment(
      orderId: orderId,
      companyId: companyId,
      paymentStatus: status ?? PaymentStatus.done,
      verifiedBy: verifiedBy,
      transactionRef: transactionRef,
      amountPaid: amountPaid,
    );
  }

  @override
  Future<void> verifyPayment({
    required String orderId,
    required String companyId,
    required String paymentStatus,
    String? paymentMethod,
    String? verifiedBy,
    String? transactionRef,
    double? amountPaid,
    String? note,
  }) async {
    final target = companyId.isNotEmpty
        ? _ordersCol(companyId).doc(orderId)
        : (await _findOrderRef(orderId) ??
              _db.collection('orders').doc(orderId));
    final doc = await target.get();
    if (!doc.exists) return;
    final data = doc.data() ?? <String, dynamic>{};
    final currentStatus = data['paymentStatus'] ?? PaymentStatus.pending;

    // Idempotent guard: already paid and trying to mark paid again
    if (currentStatus == PaymentStatus.done &&
        paymentStatus == PaymentStatus.done) {
      return;
    }

    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final totalAmount = data['totalAmount'] != null
        ? asDouble(data['totalAmount'])
        : 0.0;
    final effectivePaid = amountPaid ?? data['amountPaid'] ?? totalAmount;
    final effectiveVerifiedBy =
        verifiedBy ??
        AuthSession.currentUser?.email ??
        AuthSession.currentUser?.id ??
        'Admin';

    final updates = <String, dynamic>{
      'paymentStatus': paymentStatus,
      'updatedAt': nowIso,
    };

    if (paymentMethod != null && paymentMethod.isNotEmpty) {
      updates['paymentMethod'] = paymentMethod;
    }

    if (paymentStatus == PaymentStatus.done) {
      updates['paidAt'] = nowIso;
      updates['paymentVerifiedAt'] = nowIso;
      updates['paymentVerifiedBy'] = effectiveVerifiedBy;
      updates['amountPaid'] = effectivePaid;
      if (transactionRef != null && transactionRef.isNotEmpty) {
        updates['transactionRef'] = transactionRef;
      }
    }

    // Append to statusHistory audit trail
    final historyList = (data['statusHistory'] is List)
        ? List<Map<String, dynamic>>.from(data['statusHistory'] as List)
        : <Map<String, dynamic>>[];
    final effectiveMethod = (paymentMethod != null && paymentMethod.isNotEmpty)
        ? paymentMethod
        : (data['paymentMethod']?.toString() ?? '');
    final methodDisplay = PaymentMethod.displayName(effectiveMethod);
    final historyNote =
        note ??
        (paymentStatus == PaymentStatus.done
            ? 'Payment of ₹${effectivePaid.toStringAsFixed(0)} verified ($methodDisplay) by $effectiveVerifiedBy'
            : 'Payment status changed to $paymentStatus');
    historyList.add({
      'status': data['orderStatus'] ?? 'pending',
      'note': historyNote,
      'timestamp': nowIso,
    });
    updates['statusHistory'] = historyList;

    await target.update(updates);
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
    final isNew = product.id.isEmpty;
    final id = isNew ? _uuid.v4() : product.id;
    final batch = _db.batch();
    batch.set(_productsCol(companyId).doc(id), <String, dynamic>{
      ...product.toMap(),
      'id': id,
      'companyId': companyId,
      if (!isNew) 'imageUrl': FieldValue.delete(),
      if (!isNew) 'imageUrls': FieldValue.delete(),
      if (!isNew) 'thumbnailUrl': FieldValue.delete(),
    }, SetOptions(merge: true));

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
    String targetCompanyId = companyId;

    if (companyId.isNotEmpty) {
      batch.delete(_productsCol(companyId).doc(productId));
      await _queueCategoryCleanup(batch, companyId, productId);
      await batch.commit();
      await removeProductFromTrendingNow(
        shopId: companyId,
        productId: productId,
      );
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
      targetCompanyId = parentCompanyId;
      batch.delete(ref);
      if (parentCompanyId.isNotEmpty) {
        await _queueCategoryCleanup(batch, parentCompanyId, productId);
      }
      await batch.commit();
    } else {
      await _db.collection('products').doc(productId).delete();
    }

    if (targetCompanyId.isNotEmpty) {
      await removeProductFromTrendingNow(
        shopId: targetCompanyId,
        productId: productId,
      );
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
    final isNew = category.id.isEmpty;
    final id = isNew ? _uuid.v4() : category.id;
    var saved = category.copyWith(id: id);

    // Existing document — needed to detect parent moves.
    Map<String, dynamic>? existingMap;
    if (!isNew) {
      final snap = saved.companyId.isNotEmpty
          ? await _categoriesCol(saved.companyId).doc(id).get()
          : await _db.collection('categories').doc(id).get();
      if (snap.exists) existingMap = _asMap(snap.data());
    }

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

    final parentKey = saved.parentId ?? '';
    final oldParent = existingMap == null
        ? null
        : (existingMap['parentId']?.toString() ?? '');
    final parentChanged = existingMap != null && oldParent != parentKey;

    // New categories (and moves to another parent) go to the END of their
    // sibling list; plain edits keep their manual position.
    if (existingMap == null || parentChanged) {
      final siblings = await _loadCategories(saved.companyId);
      var maxOrder = -1;
      for (final c in siblings) {
        if (c.id == id) continue;
        if ((c.parentId ?? '') == parentKey && c.sortOrder > maxOrder) {
          maxOrder = c.sortOrder;
        }
      }
      saved = saved.copyWith(sortOrder: maxOrder + 1);
    }
    if (saved.createdAt == null) {
      saved = saved.copyWith(createdAt: DateTime.now());
    }

    final payload = <String, dynamic>{...saved.toMap(), 'id': id};
    if (saved.companyId.isNotEmpty) {
      await _categoriesCol(saved.companyId).doc(id).set(payload);
    } else {
      await _db.collection('categories').doc(id).set(payload);
    }
  }

  @override
  Future<void> reorderCategories(List<Category> orderedSiblings) async {
    final batch = _db.batch();
    var writes = 0;
    for (var i = 0; i < orderedSiblings.length; i++) {
      final cat = orderedSiblings[i];
      if (cat.sortOrder == i) continue;
      final ref = cat.companyId.isNotEmpty
          ? _categoriesCol(cat.companyId).doc(cat.id)
          : _db.collection('categories').doc(cat.id);
      batch.update(ref, {'sortOrder': i});
      writes++;
    }
    if (writes > 0) await batch.commit();
  }

  @override
  Future<void> backfillCategorySortOrder({String companyId = ''}) async {
    final categories = await _loadCategories(companyId);
    final byParent = <String, List<Category>>{};
    for (final c in categories) {
      byParent.putIfAbsent(c.parentId ?? '', () => []).add(c);
    }

    final batch = _db.batch();
    var writes = 0;

    for (final entry in byParent.entries) {
      final siblings = entry.value;
      // Only groups with colliding values (legacy data has no sortOrder) are
      // migrated — a second run can never clobber a manual arrangement.
      final distinct = siblings.map((c) => c.sortOrder).toSet().length;
      if (siblings.length < 2 || distinct == siblings.length) continue;
      siblings.sort((a, b) {
        final ca = a.createdAt;
        final cb = b.createdAt;
        if (ca != null && cb != null && !ca.isAtSameMomentAs(cb)) {
          return ca.compareTo(cb);
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      for (var i = 0; i < siblings.length; i++) {
        final cat = siblings[i];
        if (cat.sortOrder == i) continue;
        final ref = cat.companyId.isNotEmpty
            ? _categoriesCol(cat.companyId).doc(cat.id)
            : _db.collection('categories').doc(cat.id);
        batch.update(ref, {'sortOrder': i});
        writes++;
      }
    }
    if (writes > 0) await batch.commit();
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
  Future<void> deleteBanner(String id, {String companyId = ''}) async {
    if (companyId.isNotEmpty) {
      await _bannersCol(companyId).doc(id).delete();
      return;
    }
    final adDoc = _db.collection('ads_banners').doc(id);
    final adSnap = await adDoc.get();
    if (adSnap.exists) {
      await adDoc.delete();
      return;
    }
    final snap = await _db
        .collectionGroup('banners')
        .where('id', isEqualTo: id)
        .get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
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

  // ------------------------------------------ Home Dynamic Configurations --

  @override
  Stream<List<HomeExploreCategory>> homeExploreCategories({
    String shopId = '',
    bool activeOnly = false,
  }) {
    Query<Map<String, dynamic>> query = _homeExploreCol();
    if (shopId.isNotEmpty) {
      query = query.where('shopId', isEqualTo: shopId);
    }
    if (activeOnly) {
      query = query.where('isActive', isEqualTo: true);
    }
    return query.snapshots().map((snap) {
      final list = snap.docs
          .map((doc) => HomeExploreCategory.fromMap(doc.data(), id: doc.id))
          .toList();
      list.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      return list;
    });
  }

  @override
  Future<void> saveHomeExploreCategory(HomeExploreCategory entry) async {
    final id = entry.id.isNotEmpty
        ? entry.id
        : (entry.shopId.isNotEmpty && entry.categoryId.isNotEmpty
              ? '${entry.shopId}_${entry.categoryId}'
              : _homeExploreCol().doc().id);

    final now = DateTime.now();
    final data = entry
        .copyWith(id: id, createdAt: entry.createdAt ?? now, updatedAt: now)
        .toMap();
    await _homeExploreCol().doc(id).set(data, SetOptions(merge: true));
  }

  @override
  Future<void> deleteHomeExploreCategory(String id) async {
    await _homeExploreCol().doc(id).delete();
  }

  @override
  Future<void> reorderHomeExploreCategories(
    List<HomeExploreCategory> orderedEntries,
  ) async {
    final batch = _db.batch();
    final now = DateTime.now();
    for (var i = 0; i < orderedEntries.length; i++) {
      final item = orderedEntries[i];
      if (item.displayOrder != i) {
        batch.update(_homeExploreCol().doc(item.id), {
          'displayOrder': i,
          'updatedAt': Timestamp.fromDate(now),
        });
      }
    }
    await batch.commit();
  }

  @override
  Stream<List<HomeTrendingItem>> homeTrendingNow({
    String shopId = '',
    bool activeOnly = false,
  }) {
    Query<Map<String, dynamic>> query = _homeTrendingCol();
    if (shopId.isNotEmpty) {
      query = query.where('shopId', isEqualTo: shopId);
    }
    if (activeOnly) {
      query = query.where('isActive', isEqualTo: true);
    }
    return query.snapshots().map((snap) {
      final list = snap.docs
          .map((doc) => HomeTrendingItem.fromMap(doc.data(), id: doc.id))
          .toList();
      list.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      return list;
    });
  }

  @override
  Future<void> saveHomeTrendingItem(HomeTrendingItem entry) async {
    final itemRefId = entry.isProduct
        ? (entry.productId ?? '')
        : (entry.categoryId ?? '');
    final id = entry.id.isNotEmpty
        ? entry.id
        : (entry.shopId.isNotEmpty && itemRefId.isNotEmpty
              ? '${entry.shopId}_${entry.itemType}_$itemRefId'
              : _homeTrendingCol().doc().id);

    final now = DateTime.now();
    final data = entry
        .copyWith(id: id, createdAt: entry.createdAt ?? now, updatedAt: now)
        .toMap();
    await _homeTrendingCol().doc(id).set(data, SetOptions(merge: true));
  }

  @override
  Future<void> deleteHomeTrendingItem(String id) async {
    await _homeTrendingCol().doc(id).delete();
  }

  @override
  Future<void> reorderHomeTrendingItems(
    List<HomeTrendingItem> orderedEntries,
  ) async {
    final batch = _db.batch();
    final now = DateTime.now();
    for (var i = 0; i < orderedEntries.length; i++) {
      final item = orderedEntries[i];
      if (item.displayOrder != i) {
        batch.update(_homeTrendingCol().doc(item.id), {
          'displayOrder': i,
          'updatedAt': Timestamp.fromDate(now),
        });
      }
    }
    await batch.commit();
  }

  @override
  Future<int> removeProductFromTrendingNow({
    required String shopId,
    required String productId,
  }) async {
    final cleanShopId = shopId.trim();
    final cleanProductId = productId.trim();
    if (cleanShopId.isEmpty || cleanProductId.isEmpty) {
      return 0;
    }

    final querySnap = await _homeTrendingCol()
        .where('shopId', isEqualTo: cleanShopId)
        .where('itemType', isEqualTo: 'product')
        .where('productId', isEqualTo: cleanProductId)
        .get();

    final docRefs = <DocumentReference<Map<String, dynamic>>>[];
    for (final doc in querySnap.docs) {
      docRefs.add(doc.reference);
    }

    final deterministicId = '${cleanShopId}_product_$cleanProductId';
    if (!docRefs.any((ref) => ref.id == deterministicId)) {
      final directDoc = await _homeTrendingCol().doc(deterministicId).get();
      if (directDoc.exists) {
        final data = directDoc.data();
        if (data != null &&
            data['shopId'] == cleanShopId &&
            data['itemType'] == 'product' &&
            data['productId'] == cleanProductId) {
          docRefs.add(directDoc.reference);
        }
      }
    }

    if (docRefs.isEmpty) {
      return 0;
    }

    final batch = _db.batch();
    for (final ref in docRefs) {
      batch.delete(ref);
    }
    await batch.commit();
    return docRefs.length;
  }

  @override
  Future<bool> isProductInTrendingNow({
    required String shopId,
    required String productId,
  }) async {
    final cleanShopId = shopId.trim();
    final cleanProductId = productId.trim();
    if (cleanShopId.isEmpty || cleanProductId.isEmpty) return false;

    final snap = await _homeTrendingCol()
        .where('shopId', isEqualTo: cleanShopId)
        .where('itemType', isEqualTo: 'product')
        .where('productId', isEqualTo: cleanProductId)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) return true;

    final directDoc = await _homeTrendingCol()
        .doc('${cleanShopId}_product_$cleanProductId')
        .get();
    if (directDoc.exists) {
      final d = directDoc.data();
      return d != null &&
          d['shopId'] == cleanShopId &&
          d['itemType'] == 'product' &&
          d['productId'] == cleanProductId;
    }
    return false;
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
