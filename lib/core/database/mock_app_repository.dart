import 'dart:async';

import 'package:collection/collection.dart';
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
import '../repositories/app_repository.dart';
import 'mock_data.dart';

/// In-memory implementation of [AppRepository].
///
/// Kept for UI-only demos and widget tests. The production backend is
/// [FirebaseAppRepository].
class MockAppRepository implements AppRepository {
  final _uuid = const Uuid();

  final List<Company> _companies = [...MockData.companies];
  final List<Category> _categories = [...MockData.categories];
  final List<Product> _products = [...MockData.products];
  final List<AdBanner> _adBanners = [...MockData.adBanners];
  final List<OfferBanner> _offerBanners = [...MockData.offerBanners];
  final List<Voucher> _vouchers = [...MockData.vouchers];
  final List<DeliveryCharge> _deliveryCharges = [...MockData.deliveryCharges];
  final List<Review> _reviews = [...MockData.reviews];
  final List<Order> _orders = [];
  final List<AppNotification> _notifications = [];
  final List<Recommendation> _recommendations = [];
  final Map<String, AppUser> _usersByMobile = {};
  final Map<String, AppUser> _admins = {};
  final Map<String, AppUser> _employees = {};

  final _companiesCtrl = StreamController<List<Company>>.broadcast();
  final _categoriesCtrl = StreamController<List<Category>>.broadcast();
  final _productsCtrl = StreamController<List<Product>>.broadcast();
  final _adBannersCtrl = StreamController<List<AdBanner>>.broadcast();
  final _offerBannersCtrl = StreamController<List<OfferBanner>>.broadcast();
  final _vouchersCtrl = StreamController<List<Voucher>>.broadcast();
  final _ordersCtrl = StreamController<List<Order>>.broadcast();
  final _reviewsCtrl = StreamController<List<Review>>.broadcast();
  final _notificationsCtrl =
      StreamController<List<AppNotification>>.broadcast();
  final _deliveryCtrl = StreamController<List<DeliveryCharge>>.broadcast();
  final _recommendationCtrl =
      StreamController<List<Recommendation>>.broadcast();
  final _employeesCtrl = StreamController<List<Employee>>.broadcast();

  final List<Employee> _mockEmployees = [];
  AppUser? _currentUser;

  MockAppRepository() {
    _usersByMobile['9876543210'] = AppUser(
      id: 'u_seed',
      name: 'Demo User',
      mobileNumber: '9876543210',
      role: 'user',
    );
    _admins['admin@greenleaf.in'] = AppUser(
      id: 'a_1',
      companyId: 'c_organic',
      name: 'Admin GreenLeaf',
      email: 'admin@greenleaf.in',
      role: 'admin',
    );
    _admins['admin@techtronics.in'] = AppUser(
      id: 'a_2',
      companyId: 'c_techtronics',
      name: 'Admin TechTronics',
      email: 'admin@techtronics.in',
      role: 'admin',
    );
    _employees['packer@greenleaf.in'] = AppUser(
      id: 'e_1',
      companyId: 'c_organic',
      name: 'Ramesh Packer',
      email: 'packer@greenleaf.in',
      role: 'employee',
      employeeRole: 'Picker',
    );
    _mockEmployees.add(
      const Employee(
        id: 'e_1',
        companyId: 'c_organic',
        name: 'Ramesh Packer',
        email: 'packer@greenleaf.in',
        role: 'Picker',
        details: 'Experienced warehouse staff',
        address: '123 Market Rd, Bangalore',
        dob: '1995-05-12',
        gender: 'male',
        salary: 22000.0,
        salaryType: 'monthly',
        shiftActive: true,
        permissions: {
          'canPack': true,
          'canDispatch': false,
          'canManageInventory': false,
          'canViewReports': false,
        },
      ),
    );
  }

  void _pushCompanies() => _companiesCtrl.add(List.unmodifiable(_companies));
  void _pushCategories() => _categoriesCtrl.add(List.unmodifiable(_categories));
  void _pushProducts() => _productsCtrl.add(List.unmodifiable(_products));
  void _pushBanners() => _offerBannersCtrl.add(List.unmodifiable(_offerBanners));
  void _pushOrders() => _ordersCtrl.add(List.unmodifiable(_orders));
  void _pushReviews() => _reviewsCtrl.add(List.unmodifiable(_reviews));
  void _pushNotifications() =>
      _notificationsCtrl.add(List.unmodifiable(_notifications));
  void _pushDelivery() =>
      _deliveryCtrl.add(List.unmodifiable(_deliveryCharges));
  void _pushRecommendations() =>
      _recommendationCtrl.add(List.unmodifiable(_recommendations));
  void _pushEmployees() =>
      _employeesCtrl.add(List.unmodifiable(_mockEmployees));

  // ---- Auth ----
  @override
  Future<void> sendOtp(String mobileNumber) async {}

  @override
  Future<AppUser?> verifyOtp(String mobileNumber, String otp) async {
    final user = _usersByMobile[mobileNumber];
    _currentUser = user;
    return user;
  }

  @override
  Future<bool> userExists(String mobileNumber) async =>
      _usersByMobile.containsKey(mobileNumber);

  @override
  Future<AppUser?> adminLogin({
    required String companyName,
    required String companyPassword,
    required String email,
    required String password,
  }) async {
    final user = _admins[email.toLowerCase()];
    _currentUser = user;
    return user;
  }

  @override
  Future<AppUser?> employeeLogin({
    required String companyName,
    required String email,
    required String password,
  }) async {
    final user = _employees[email.toLowerCase()];
    _currentUser = user;
    return user;
  }

  @override
  Future<void> createUserAccount(String name, String mobileNumber) async {
    final user = AppUser(
      id: _uuid.v4(),
      name: name,
      mobileNumber: mobileNumber,
      role: 'user',
    );
    _usersByMobile[mobileNumber] = user;
    _currentUser = user;
  }

  @override
  Future<Company> createCompany(Company company) async {
    final c = company.id.isEmpty
        ? Company(
            id: 'c_${company.name.toLowerCase().replaceAll(' ', '_')}',
            name: company.name,
            slug: company.slug,
            logoUrl: company.logoUrl,
            details: company.details,
          )
        : company;
    _companies.add(c);
    _pushCompanies();
    return c;
  }

  @override
  Future<Admin> createAdminAccount(
    Admin admin, {
    required String password,
  }) async {
    _admins[admin.email.toLowerCase()] = AppUser(
      id: admin.id.isEmpty ? _uuid.v4() : admin.id,
      companyId: admin.companyId,
      name: admin.name,
      email: admin.email,
      mobileNumber: admin.mobileNumber,
      role: 'admin',
    );
    _currentUser = _admins[admin.email.toLowerCase()];
    return admin;
  }

  @override
  Future<Employee> createEmployeeAccount(
    Employee employee, {
    required String password,
  }) async {
    final uid = employee.id.isEmpty ? _uuid.v4() : employee.id;
    final newEmp = employee.copyWith(id: uid);
    _employees[employee.email.toLowerCase()] = AppUser(
      id: uid,
      companyId: employee.companyId,
      name: employee.name,
      email: employee.email,
      role: 'employee',
      employeeRole: employee.role,
    );
    final i = _mockEmployees.indexWhere((e) => e.id == uid);
    if (i == -1) {
      _mockEmployees.add(newEmp);
    } else {
      _mockEmployees[i] = newEmp;
    }
    _pushEmployees();
    return newEmp;
  }

  @override
  Future<void> signOut() async => _currentUser = null;

  @override
  Future<AppUser?> resolveCurrentUser() async => _currentUser;

  // ---- Reads ----
  @override
  Stream<List<Company>> companies() {
    _pushCompanies();
    return _companiesCtrl.stream;
  }

  @override
  Future<Company?> company(String id) async =>
      _companies.firstWhereOrNull((c) => c.id == id);

  @override
  Stream<List<Category>> categories({String companyId = ''}) {
    _pushCategories();
    return _categoriesCtrl.stream.map(
      (list) => list
          .where(
            (c) =>
                companyId.isEmpty ||
                c.companyId == companyId ||
                c.companyId.isEmpty,
          )
          .toList(),
    );
  }

  @override
  Future<Category?> category(String id, {String companyId = ''}) async {
    try {
      return _categories.firstWhere(
        (c) =>
            c.id == id &&
            (companyId.isEmpty ||
                c.companyId == companyId ||
                c.companyId.isEmpty),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<List<Product>> products({
    String companyId = '',
    String categoryId = '',
    String search = '',
  }) {
    _pushProducts();
    return _productsCtrl.stream.map(
      (list) => list.where((p) {
        if (companyId.isNotEmpty && p.companyId != companyId) return false;
        if (categoryId.isNotEmpty && p.categoryId != categoryId) return false;
        if (search.isNotEmpty &&
            !p.name.toLowerCase().contains(search.toLowerCase())) {
          return false;
        }
        return true;
      }).toList(),
    );
  }

  @override
  Future<Product?> product(String id) async =>
      _products.firstWhereOrNull((p) => p.id == id);

  @override
  Stream<List<AdBanner>> adBanners() {
    _adBannersCtrl.add(List.unmodifiable(_adBanners));
    return _adBannersCtrl.stream;
  }

  @override
  Stream<List<OfferBanner>> offerBanners(String companyId) {
    _offerBannersCtrl.add(
      _offerBanners.where((b) => b.companyId == companyId).toList(),
    );
    return _offerBannersCtrl.stream.map(
      (list) => list.where((b) => b.companyId == companyId).toList(),
    );
  }

  @override
  Stream<List<Voucher>> vouchers(String companyId) {
    _vouchersCtrl.add(
      _vouchers.where((v) => v.companyId == companyId).toList(),
    );
    return _vouchersCtrl.stream.map(
      (list) => list.where((v) => v.companyId == companyId).toList(),
    );
  }

  @override
  Future<Voucher?> voucherByCode(String companyId, String code) async =>
      _vouchers.firstWhereOrNull(
        (v) =>
            v.companyId == companyId &&
            v.code.toLowerCase() == code.toLowerCase(),
      );

  @override
  Future<DeliveryCharge?> deliveryCharge(
    String pincode,
    String companyId,
  ) async => _deliveryCharges.firstWhereOrNull((d) => d.pincode == pincode);

  @override
  Stream<List<DeliveryCharge>> deliveryCharges({String companyId = ''}) {
    _pushDelivery();
    return _deliveryCtrl.stream;
  }

  @override
  Stream<List<Order>> orders({String userId = '', String companyId = ''}) {
    _pushOrders();
    return _ordersCtrl.stream.map(
      (list) => list.where((o) {
        if (userId.isNotEmpty && o.userId != userId) return false;
        if (companyId.isNotEmpty && o.companyId != companyId) return false;
        return true;
      }).toList(),
    );
  }

  @override
  Stream<List<Review>> reviews(String companyId) {
    _pushReviews();
    return _reviewsCtrl.stream.map(
      (list) => list.where((r) => r.companyId == companyId).toList(),
    );
  }

  @override
  Stream<List<AppNotification>> notifications(String recipientId) {
    _pushNotifications();
    return _notificationsCtrl.stream.map(
      (list) => list.where((n) => n.recipientId == recipientId).toList(),
    );
  }

  @override
  Stream<List<Employee>> employees(String companyId) async* {
    yield _mockEmployees
        .where((e) => companyId.isEmpty || e.companyId == companyId)
        .toList();
    yield* _employeesCtrl.stream.map(
      (list) => list
          .where((e) => companyId.isEmpty || e.companyId == companyId)
          .toList(),
    );
  }

  @override
  Future<Employee?> employee(String id, {String companyId = ''}) async =>
      _mockEmployees.firstWhereOrNull(
        (e) =>
            e.id == id &&
            (companyId.isEmpty || e.companyId == companyId),
      );

  @override
  Stream<List<Admin>> admins(String companyId) => Stream.value(
    _admins.values
        .where((a) => a.companyId == companyId)
        .map(
          (a) => Admin(
            id: a.id,
            companyId: a.companyId,
            name: a.name,
            email: a.email,
            mobileNumber: a.mobileNumber,
          ),
        )
        .toList(),
  );

  @override
  Future<List<Product>> recommendations({String companyId = ''}) async {
    final rec = _products.where((p) => p.isRecommended).toList();
    return companyId.isEmpty
        ? rec
        : rec.where((p) => p.companyId == companyId).toList();
  }

  @override
  Stream<List<Recommendation>> recommendationRecords({String companyId = ''}) {
    _pushRecommendations();
    return _recommendationCtrl.stream.map(
      (list) => companyId.isEmpty
          ? list
          : list.where((r) => r.companyId == companyId).toList(),
    );
  }

  // ---- Writes ----
  @override
  Future<Order> placeOrder(Order order) async {
    final doc = Order(
      id: order.id.isEmpty ? _uuid.v4() : order.id,
      userId: order.userId,
      companyId: order.companyId,
      companyName: order.companyName,
      items: order.items,
      totalAmount: order.totalAmount,
      address: order.address,
      pincode: order.pincode,
      voucherId: order.voucherId,
      paymentStatus: order.paymentStatus,
      orderStatus: order.orderStatus,
      deliveryType: order.deliveryType,
      createdAt: DateTime.now(),
    );
    _orders.add(doc);
    _pushOrders();
    return doc;
  }

  @override
  Future<void> updateOrderStatus(String orderId, String status) async {
    final i = _orders.indexWhere((o) => o.id == orderId);
    if (i == -1) return;
    _orders[i] = _orders[i].copyWith(orderStatus: status);
    _pushOrders();
  }

  @override
  Future<void> togglePaymentStatus(String orderId) async {
    final i = _orders.indexWhere((o) => o.id == orderId);
    if (i == -1) return;
    final o = _orders[i];
    _orders[i] = o.copyWith(
      paymentStatus: o.paymentStatus == 'pending' ? 'done' : 'pending',
    );
    _pushOrders();
  }

  @override
  Future<void> setEmployeePackingDone(String orderId, bool done) async {
    final i = _orders.indexWhere((o) => o.id == orderId);
    if (i == -1) return;
    _orders[i] = _orders[i].copyWith(employeePackingDone: done);
    _pushOrders();
  }

  @override
  Future<void> assignEmployee(String orderId, String employeeId) async {
    final i = _orders.indexWhere((o) => o.id == orderId);
    if (i == -1) return;
    _orders[i] = _orders[i].copyWith(assignedEmployeeId: employeeId);
    _pushOrders();
  }

  @override
  Future<void> submitReview(Review review) async {
    _reviews.add(
      Review(
        id: review.id.isEmpty ? _uuid.v4() : review.id,
        orderId: review.orderId,
        userId: review.userId,
        userName: review.userName,
        companyId: review.companyId,
        rating: review.rating,
        message: review.message,
        createdAt: DateTime.now(),
      ),
    );
    _pushReviews();
  }

  @override
  Future<void> markNotificationRead(String id) async {}

  @override
  Future<void> saveVoucher(Company company, Voucher voucher) async {
    _vouchers.add(
      Voucher(
        id: voucher.id.isEmpty ? _uuid.v4() : voucher.id,
        companyId: company.id,
        code: voucher.code,
        discountType: voucher.discountType,
        discountValue: voucher.discountValue,
        appliesTo: voucher.appliesTo,
        productIds: voucher.productIds,
        categoryIds: voucher.categoryIds,
        minOrderAmt: voucher.minOrderAmt,
        expiryDate: voucher.expiryDate,
      ),
    );
    _vouchersCtrl.add(
      _vouchers.where((v) => v.companyId == company.id).toList(),
    );
  }

  @override
  Future<void> deleteVoucher(String voucherId) async {
    _vouchers.removeWhere((v) => v.id == voucherId);
  }

  @override
  Future<void> saveProduct(Product product) async {
    final i = _products.indexWhere((p) => p.id == product.id);
    if (i == -1) {
      _products.add(product);
    } else {
      _products[i] = product;
    }
    _pushProducts();
  }

  @override
  Future<void> deleteProduct(String productId) async {
    _products.removeWhere((p) => p.id == productId);
    _pushProducts();
  }

  @override
  Future<void> saveCategory(Category category) async {
    final i = _categories.indexWhere((c) => c.id == category.id);
    if (i == -1) {
      _categories.add(category);
    } else {
      _categories[i] = category;
    }
    _pushCategories();
  }

  @override
  Future<void> deleteCategory(String categoryId, {String companyId = ''}) async {
    _categories.removeWhere(
      (c) =>
          c.id == categoryId &&
          (companyId.isEmpty || c.companyId == companyId || c.companyId.isEmpty),
    );
    _pushCategories();
  }

  @override
  Future<void> saveEmployee(Employee employee) async {
    final i = _mockEmployees.indexWhere((e) => e.id == employee.id);
    if (i == -1) {
      _mockEmployees.add(employee);
    } else {
      _mockEmployees[i] = employee;
    }
    _pushEmployees();
  }

  @override
  Future<void> deleteEmployee(String companyId, String employeeId) async {
    _mockEmployees.removeWhere(
      (e) =>
          e.id == employeeId &&
          (companyId.isEmpty || e.companyId == companyId),
    );
    _pushEmployees();
  }

  @override
  Future<void> saveDeliveryCharge(DeliveryCharge charge) async {
    final i = _deliveryCharges.indexWhere((d) => d.pincode == charge.pincode);
    if (i == -1) {
      _deliveryCharges.add(charge);
    } else {
      _deliveryCharges[i] = charge;
    }
    _pushDelivery();
  }

  @override
  Future<void> importDeliveryCharges(List<DeliveryCharge> charges) async {
    _deliveryCharges.addAll(charges);
    _pushDelivery();
  }

  @override
  Future<void> setReviewVisibility(String reviewId, bool visible) async {
    final i = _reviews.indexWhere((r) => r.id == reviewId);
    if (i == -1) return;
    final r = _reviews[i];
    _reviews[i] = Review(
      id: r.id,
      orderId: r.orderId,
      userId: r.userId,
      userName: r.userName,
      companyId: r.companyId,
      rating: r.rating,
      message: r.message,
      isVisible: visible,
      createdAt: r.createdAt,
    );
    _pushReviews();
  }

  @override
  Future<void> saveRecommendation(Recommendation rec) async {
    _recommendations.add(rec);
    _pushRecommendations();
  }

  @override
  Future<void> saveBanner(OfferBanner banner) async {
    _offerBanners.add(banner);
  }

  @override
  Future<void> saveAdBanner(AdBanner banner) async {
    _adBanners.add(banner);
  }

  @override
  Future<void> registerFcmToken(String userId, String token) async {}
}
