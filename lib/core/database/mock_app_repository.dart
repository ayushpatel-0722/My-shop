import 'dart:async';

import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';

import '../domain/category_tree.dart';
import '../domain/order_status.dart';
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
import '../repositories/app_repository.dart';
import '../services/auth_session.dart';
import 'mock_data.dart';
import '../../app/l10n/l10n_service.dart';

/// In-memory implementation of [AppRepository].
///
/// Used for UI demos and for the widget/unit test suite. It mirrors the
/// guarantees the Firestore implementation provides, so a behaviour verified
/// here holds in production:
///
/// * **Tenancy** — every read is filtered by `companyId` when one is supplied.
/// * **Referential integrity** — deleting a product removes it from every
///   category; deleting a category re-parents its children (and its products)
///   instead of leaving orphans behind.
/// * **Voucher bookkeeping** — placing an order records the redemption so
///   per-user and global caps are enforced.
/// * **Order lifecycle** — status changes are validated by
///   [OrderStatusRules]; illegal transitions throw instead of corrupting data.
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
  final List<Order> _orders = <Order>[];
  final List<AppNotification> _notifications = <AppNotification>[];
  final List<Recommendation> _recommendations = <Recommendation>[];
  final List<HomeExploreCategory> _homeExploreCategories =
      <HomeExploreCategory>[];
  final List<HomeTrendingItem> _homeTrendingItems = <HomeTrendingItem>[];
  final Map<String, AppUser> _usersByMobile = <String, AppUser>{};
  final Map<String, AppUser> _admins = <String, AppUser>{};
  final Map<String, AppUser> _employees = <String, AppUser>{};

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
  final _homeExploreCtrl =
      StreamController<List<HomeExploreCategory>>.broadcast();
  final _homeTrendingCtrl =
      StreamController<List<HomeTrendingItem>>.broadcast();

  final List<Employee> _mockEmployees = <Employee>[];
  AppUser? _currentUser;

  MockAppRepository() {
    _usersByMobile['9876543210'] = AppUser(
      id: 'u_seed',
      name: 'Demo User',
      mobileNumber: '9876543210',
      role: 'user',
      addresses: [
        AddressEntry(
          id: 'addr_1',
          name: 'Demo User',
          phone: '9876543210',
          houseNo: 'Flat 402, Shivalik Heights',
          address: 'Near Vastrapur Lake',
          city: 'Ahmedabad',
          state: 'Gujarat',
          pincode: '380015',
          label: L10n.current.home,
          isDefault: true,
        ),
        AddressEntry(
          id: 'addr_2',
          name: 'Demo User',
          phone: '9876543210',
          houseNo: 'Floor 3, Tech Park',
          address: 'SG Highway, Bodakdev',
          city: 'Ahmedabad',
          state: 'Gujarat',
          pincode: '380054',
          label: 'Work',
          isDefault: false,
        ),
      ],
    );
    _admins['admin@greenleaf.in'] = const AppUser(
      id: 'a_1',
      companyId: 'c_organic',
      name: 'Admin GreenLeaf',
      email: 'admin@greenleaf.in',
      role: 'admin',
    );
    _admins['admin@techtronics.in'] = const AppUser(
      id: 'a_2',
      companyId: 'c_techtronics',
      name: 'Admin TechTronics',
      email: 'admin@techtronics.in',
      role: 'admin',
    );
    _employees['packer@greenleaf.in'] = const AppUser(
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

  // -------------------------------------------------------------- Push ----

  void _pushCompanies() => _companiesCtrl.add(List.unmodifiable(_companies));
  void _pushCategories() => _categoriesCtrl.add(List.unmodifiable(_categories));
  void _pushProducts() => _productsCtrl.add(List.unmodifiable(_products));
  void _pushBanners() =>
      _offerBannersCtrl.add(List.unmodifiable(_offerBanners));
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
  void _pushVouchers() => _vouchersCtrl.add(List.unmodifiable(_vouchers));

  /// Emits the current value immediately, then every later change.
  ///
  /// A plain broadcast controller silently drops the value pushed before the
  /// first listener subscribes, which makes `stream.first` hang.
  Stream<List<T>> _live<T>(
    StreamController<List<T>> ctrl,
    List<T> Function() read,
  ) {
    return _liveGenerator(ctrl, read).asBroadcastStream();
  }

  Stream<List<T>> _liveGenerator<T>(
    StreamController<List<T>> ctrl,
    List<T> Function() read,
  ) async* {
    yield read();
    yield* ctrl.stream.map((_) => read());
  }

  List<Product> _readProducts({
    String companyId = '',
    String categoryId = '',
    String search = '',
  }) => _products.where((p) {
    if (companyId.isNotEmpty && p.companyId != companyId) return false;
    if (categoryId.isNotEmpty && p.categoryId != categoryId) return false;
    if (search.isNotEmpty && !p.matches(search)) return false;
    return true;
  }).toList();

  List<Category> _readCategories({String companyId = ''}) => _categories
      .where(
        (c) =>
            companyId.isEmpty ||
            c.companyId == companyId ||
            c.companyId.isEmpty,
      )
      .toList();

  List<Voucher> _readVouchers({String companyId = ''}) => _vouchers
      .where((v) => companyId.isEmpty || v.companyId == companyId)
      .toList();

  List<Order> _readOrders({String userId = '', String companyId = ''}) {
    final list = _orders.where((o) {
      if (userId.isNotEmpty && o.userId != userId) return false;
      if (companyId.isNotEmpty && o.companyId != companyId) return false;
      return true;
    }).toList();
    list.sort((a, b) {
      final at = b.createdAt;
      final bt = a.createdAt;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return at.compareTo(bt);
    });
    return list;
  }

  // ---- Auth ----
  @override
  Future<void> sendOtp(String mobileNumber) async {}

  @override
  Future<AppUser?> verifyOtp(String mobileNumber, String otp) async {
    var user = _usersByMobile[mobileNumber];
    if (user == null) {
      user = AppUser(
        id: 'mock_${mobileNumber.replaceAll(RegExp(r'\D'), '')}',
        name: 'Customer',
        mobileNumber: mobileNumber,
        role: 'user',
      );
      _usersByMobile[mobileNumber] = user;
    }
    _currentUser = user;
    return user;
  }

  @override
  Future<bool> userExists(String mobileNumber) async => true;

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
  Future<void> createUserAccount(
    String name,
    String mobileNumber, {
    String email = '',
    String authProvider = '',
    String googleId = '',
    List<AddressEntry> addresses = const [],
  }) async {
    final user = AppUser(
      id: googleId.isNotEmpty ? googleId : _uuid.v4(),
      name: name,
      email: email,
      mobileNumber: mobileNumber,
      role: 'user',
      authProvider: authProvider,
      googleId: googleId,
      addresses: addresses,
    );
    if (mobileNumber.isNotEmpty) {
      _usersByMobile[mobileNumber] = user;
    }
    _currentUser = user;
  }

  @override
  Future<void> updateUserMobile(String userId, String mobileNumber) async {
    if (_currentUser != null) {
      final updated = _currentUser!.copyWith(mobileNumber: mobileNumber);
      _currentUser = updated;
      _usersByMobile[mobileNumber] = updated;
    }
  }

  @override
  Future<void> saveUserAddress(String userId, AddressEntry address) async {
    if (_currentUser != null) {
      final list = List<AddressEntry>.from(_currentUser!.addresses);
      final id = address.id.isEmpty
          ? 'addr_${DateTime.now().millisecondsSinceEpoch}'
          : address.id;
      final entry = address.copyWith(id: id);

      if (entry.isDefault || list.isEmpty) {
        for (var i = 0; i < list.length; i++) {
          list[i] = list[i].copyWith(isDefault: false);
        }
      }

      final existingIndex = list.indexWhere((a) => a.id == id);
      if (existingIndex >= 0) {
        list[existingIndex] = entry;
      } else {
        list.add(entry);
      }

      final updated = _currentUser!.copyWith(addresses: list);
      _currentUser = updated;
      if (updated.mobileNumber.isNotEmpty) {
        _usersByMobile[updated.mobileNumber] = updated;
      }
    }
  }

  @override
  Future<void> deleteUserAddress(String userId, String addressId) async {
    if (_currentUser != null) {
      final list = List<AddressEntry>.from(_currentUser!.addresses);
      list.removeWhere((a) => a.id == addressId);
      if (list.isNotEmpty && !list.any((a) => a.isDefault)) {
        list[0] = list[0].copyWith(isDefault: true);
      }
      final updated = _currentUser!.copyWith(addresses: list);
      _currentUser = updated;
      if (updated.mobileNumber.isNotEmpty) {
        _usersByMobile[updated.mobileNumber] = updated;
      }
    }
  }

  @override
  Future<void> setDefaultAddress(String userId, String addressId) async {
    if (_currentUser != null) {
      final list = List<AddressEntry>.from(_currentUser!.addresses);
      for (var i = 0; i < list.length; i++) {
        list[i] = list[i].copyWith(isDefault: list[i].id == addressId);
      }
      final updated = _currentUser!.copyWith(addresses: list);
      _currentUser = updated;
      if (updated.mobileNumber.isNotEmpty) {
        _usersByMobile[updated.mobileNumber] = updated;
      }
    }
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
  Stream<List<Company>> companies() =>
      _live(_companiesCtrl, () => List.unmodifiable(_companies));

  @override
  Future<Company?> company(String id) async =>
      _companies.firstWhereOrNull((c) => c.id == id);

  @override
  Stream<List<Category>> categories({String companyId = ''}) =>
      _live(_categoriesCtrl, () => _readCategories(companyId: companyId));

  @override
  Future<Category?> category(String id, {String companyId = ''}) async =>
      _categories.firstWhereOrNull(
        (c) =>
            c.id == id &&
            (companyId.isEmpty ||
                c.companyId == companyId ||
                c.companyId.isEmpty),
      );

  @override
  Stream<List<Product>> products({
    String companyId = '',
    String categoryId = '',
    String search = '',
  }) => _live(
    _productsCtrl,
    () => _readProducts(
      companyId: companyId,
      categoryId: categoryId,
      search: search,
    ),
  );

  @override
  Future<Product?> product(String id) async =>
      _products.firstWhereOrNull((p) => p.id == id);

  @override
  Stream<List<AdBanner>> adBanners() =>
      _live(_adBannersCtrl, () => List.unmodifiable(_adBanners));

  @override
  Stream<List<OfferBanner>> offerBanners(String companyId) => _live(
    _offerBannersCtrl,
    () => _offerBanners.where((b) => b.companyId == companyId).toList(),
  );

  @override
  Stream<List<Voucher>> vouchers(String companyId) =>
      _live(_vouchersCtrl, () => _readVouchers(companyId: companyId));

  @override
  Future<Voucher?> voucherByCode(String companyId, String code) async {
    final wanted = Voucher.normalizeCode(code);
    if (wanted.isEmpty) return null;
    return _vouchers.firstWhereOrNull(
      (v) =>
          (companyId.isEmpty || v.companyId == companyId) &&
          v.normalizedCode == wanted,
    );
  }

  @override
  Future<DeliveryCharge?> deliveryCharge(
    String pincode,
    String companyId,
  ) async => _deliveryCharges.firstWhereOrNull(
    (d) =>
        d.pincode == pincode &&
        (companyId.isEmpty || d.companyId == companyId || d.companyId.isEmpty),
  );

  @override
  Stream<List<DeliveryCharge>> deliveryCharges({String companyId = ''}) =>
      _live(
        _deliveryCtrl,
        () => _deliveryCharges
            .where(
              (d) =>
                  companyId.isEmpty ||
                  d.companyId == companyId ||
                  d.companyId.isEmpty,
            )
            .toList(),
      );

  @override
  Stream<List<Order>> orders({String userId = '', String companyId = ''}) =>
      _live(
        _ordersCtrl,
        () => _readOrders(userId: userId, companyId: companyId),
      );

  @override
  Future<Order?> order(String orderId, {String companyId = ''}) async =>
      _orders.firstWhereOrNull(
        (o) =>
            o.id == orderId && (companyId.isEmpty || o.companyId == companyId),
      );

  @override
  Stream<Order?> watchOrder(String orderId, {String companyId = ''}) => orders(
    companyId: companyId,
  ).map((list) => list.firstWhereOrNull((o) => o.id == orderId));

  @override
  Stream<List<Review>> reviews(String companyId) => _live(
    _reviewsCtrl,
    () => _reviews.where((r) => r.companyId == companyId).toList(),
  );

  @override
  Stream<List<AppNotification>> notifications(String recipientId) => _live(
    _notificationsCtrl,
    () => _notifications.where((n) => n.recipientId == recipientId).toList(),
  );

  @override
  Stream<List<Employee>> employees(String companyId) => _live(
    _employeesCtrl,
    () => _mockEmployees
        .where((e) => companyId.isEmpty || e.companyId == companyId)
        .toList(),
  );

  @override
  Future<Employee?> employee(String id, {String companyId = ''}) async =>
      _mockEmployees.firstWhereOrNull(
        (e) => e.id == id && (companyId.isEmpty || e.companyId == companyId),
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
  Stream<List<Recommendation>> recommendationRecords({String companyId = ''}) =>
      _live(
        _recommendationCtrl,
        () => companyId.isEmpty
            ? List.unmodifiable(_recommendations)
            : _recommendations.where((r) => r.companyId == companyId).toList(),
      );

  // ---- Writes ----

  /// Validates the move, then applies it together with the audit timestamps.
  Order _applyStatus(
    Order order,
    String status, {
    DateTime? now,
    String? cancellationReason,
    String? note,
  }) {
    OrderStatusRules.ensureValidStatus(status);
    OrderStatusRules.ensureTransition(order.orderStatus, status);
    final timestamp = now ?? DateTime.now();
    final newHistory = List<OrderStatusHistoryEntry>.from(order.statusHistory)
      ..add(
        OrderStatusHistoryEntry(
          status: status,
          note:
              note ??
              (status == OrderStatus.cancelled
                  ? (cancellationReason ?? 'Cancelled')
                  : 'Status changed to $status'),
          timestamp: timestamp,
        ),
      );
    return order.copyWith(
      orderStatus: status,
      updatedAt: timestamp,
      cancelledAt: status == OrderStatus.cancelled ? timestamp : null,
      clearCancelledAt: status != OrderStatus.cancelled,
      cancellationReason: status == OrderStatus.cancelled
          ? (cancellationReason ?? order.cancellationReason)
          : null,
      statusHistory: newHistory,
    );
  }

  @override
  Future<Order> placeOrder(Order order) async {
    final saved = await placeOrders([order]);
    return saved.first;
  }

  @override
  Future<List<Order>> placeOrders(List<Order> orders) async {
    if (orders.isEmpty) return const <Order>[];
    final saved = <Order>[];

    for (final order in orders) {
      if (order.companyId.isEmpty) {
        throw ArgumentError('An order must belong to a company.');
      }
      if (order.items.isEmpty) {
        throw ArgumentError('Cannot place an order with no items.');
      }

      final now = DateTime.now();
      final id = order.id.isEmpty ? _uuid.v4() : order.id;

      // Freeze the bill so later catalogue edits cannot rewrite the receipt.
      final subtotal = Order.itemsTotalOf(order.items);
      final doc = Order(
        id: id,
        userId: order.userId,
        customerName: order.customerName,
        customerEmail: order.customerEmail,
        customerPhone: order.customerPhone,
        companyId: order.companyId,
        companyName: order.companyName,
        items: order.items,
        subtotal: order.subtotal != subtotal && order.subtotal > 0
            ? order.subtotal
            : subtotal,
        discountAmount: order.discountAmount,
        deliveryCharge: order.deliveryCharge,
        totalAmount: order.totalAmount > 0
            ? order.totalAmount
            : (order.subtotal > 0 ? order.subtotal : subtotal) -
                  order.discountAmount +
                  order.deliveryCharge,
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
        amountPaid: order.amountPaid,
        paidAt: order.paidAt,
        paymentVerifiedBy: order.paymentVerifiedBy,
        paymentVerifiedAt: order.paymentVerifiedAt,
        orderStatus: order.orderStatus,
        deliveryType: order.deliveryType,
        cancellationReason: order.cancellationReason,
        cancelledAt: order.cancelledAt,
        reviewId: order.reviewId,
        statusHistory: [
          OrderStatusHistoryEntry(
            status: order.orderStatus,
            note: 'Order placed',
            timestamp: now,
          ),
        ],
        stockRestored: false,
        createdAt: now,
        updatedAt: now,
      );

      saved.add(doc);
    }

    // All docs are written together (batch semantics) before bookkeeping.
    _orders.addAll(saved);

    for (final doc in saved) {
      _decrementStock(doc);
      if (doc.voucherId != null && doc.voucherId!.isNotEmpty) {
        _recordVoucherUsage(doc);
      }
    }

    _pushOrders();
    return saved;
  }

  void _decrementStock(Order order) {
    for (final item in order.items) {
      final i = _products.indexWhere((p) => p.id == item.productId);
      if (i == -1) continue;
      final p = _products[i];
      if (p.isUnlimitedStock) continue;
      final remaining = p.stockQty - (item.qty < 0 ? 0 : item.qty);
      _products[i] = p.copyWith(stockQty: remaining < 0 ? 0 : remaining);
    }
    _pushProducts();
  }

  void _restoreStock(Order order) {
    for (final item in order.items) {
      final i = _products.indexWhere((p) => p.id == item.productId);
      if (i == -1) continue;
      final p = _products[i];
      if (p.isUnlimitedStock) continue;
      final restored = p.stockQty + (item.qty < 0 ? 0 : item.qty);
      _products[i] = p.copyWith(stockQty: restored);
    }
    _pushProducts();
  }

  void _recordVoucherUsage(Order order) {
    final i = _vouchers.indexWhere((v) => v.id == order.voucherId);
    if (i == -1) return;
    _vouchers[i] = _vouchers[i].registerUsage(
      orderId: order.id,
      userId: order.userId,
    );
    _pushVouchers();
  }

  void _releaseVoucherUsage(Order order) {
    final i = _vouchers.indexWhere((v) => v.id == order.voucherId);
    if (i == -1) return;
    _vouchers[i] = _vouchers[i].releaseUsage(
      orderId: order.id,
      userId: order.userId,
    );
    _pushVouchers();
  }

  @override
  Future<void> updateOrderStatus(
    String orderId,
    String status, {
    String companyId = '',
    String? cancellationReason,
  }) async {
    final i = _orders.indexWhere(
      (o) => o.id == orderId && (companyId.isEmpty || o.companyId == companyId),
    );
    if (i == -1) return;
    _orders[i] = _applyStatus(
      _orders[i],
      status,
      cancellationReason: cancellationReason,
    );
    _pushOrders();
  }

  @override
  Future<void> cancelOrder(
    String orderId, {
    String companyId = '',
    String? reason,
    String? userId,
  }) async {
    final i = _orders.indexWhere(
      (o) => o.id == orderId && (companyId.isEmpty || o.companyId == companyId),
    );
    if (i == -1) throw Exception('Order not found');

    final order = _orders[i];
    if (userId != null && userId.isNotEmpty) {
      if (order.userId != userId) {
        throw StateError('You are not authorized to cancel this order.');
      }
      if (!OrderStatusRules.isCustomerCancellable(order.orderStatus)) {
        final ineligibleMsg =
            OrderStatusRules.customerCancellationIneligibleReason(
              order.orderStatus,
            );
        throw StateError(
          ineligibleMsg ?? 'This order can no longer be cancelled.',
        );
      }
    } else {
      OrderStatusRules.ensureTransition(
        order.orderStatus,
        OrderStatus.cancelled,
      );
    }

    final cancellationReason =
        reason ??
        (userId != null ? 'Cancelled by customer' : 'Cancelled by admin');
    final updated = _applyStatus(
      order,
      OrderStatus.cancelled,
      cancellationReason: cancellationReason,
      note: cancellationReason,
    );

    final wasStockRestored = order.stockRestored;
    _orders[i] = updated.copyWith(stockRestored: true);

    if (!wasStockRestored) {
      _restoreStock(order);
      if (order.voucherId != null && order.voucherId!.isNotEmpty) {
        _releaseVoucherUsage(order);
      }
    }

    _pushOrders();
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
    final i = _orders.indexWhere(
      (o) => o.id == orderId && (companyId.isEmpty || o.companyId == companyId),
    );
    if (i == -1) return;
    final o = _orders[i];

    // Idempotent guard: already paid and trying to mark paid again
    if (o.isPaid && paymentStatus == PaymentStatus.done) {
      return;
    }

    final now = DateTime.now();
    final effectivePaid = amountPaid ?? o.amountPaid ?? o.totalAmount;
    final effectiveVerifiedBy =
        verifiedBy ??
        AuthSession.currentUser?.email ??
        AuthSession.currentUser?.id ??
        'Admin';
    final effectiveMethod = (paymentMethod != null && paymentMethod.isNotEmpty)
        ? paymentMethod
        : o.paymentMethod;

    final historyList = List<OrderStatusHistoryEntry>.from(o.statusHistory);
    final historyNote =
        note ??
        (paymentStatus == PaymentStatus.done
            ? 'Payment of ₹${effectivePaid.toStringAsFixed(0)} verified (${PaymentMethod.displayName(effectiveMethod)}) by $effectiveVerifiedBy'
            : 'Payment status changed to $paymentStatus');
    historyList.add(
      OrderStatusHistoryEntry(
        status: o.orderStatus,
        note: historyNote,
        timestamp: now,
      ),
    );

    _orders[i] = o.copyWith(
      paymentMethod: effectiveMethod,
      paymentStatus: paymentStatus,
      paidAt: paymentStatus == PaymentStatus.done ? now : o.paidAt,
      paymentVerifiedAt: paymentStatus == PaymentStatus.done
          ? now
          : o.paymentVerifiedAt,
      paymentVerifiedBy: paymentStatus == PaymentStatus.done
          ? effectiveVerifiedBy
          : o.paymentVerifiedBy,
      amountPaid: paymentStatus == PaymentStatus.done
          ? effectivePaid
          : o.amountPaid,
      transactionRef: transactionRef ?? o.transactionRef,
      statusHistory: historyList,
      updatedAt: now,
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
    _orders[i] = _orders[i].copyWith(
      assignedEmployeeId: employeeId.isEmpty ? null : employeeId,
      clearAssignedEmployee: employeeId.isEmpty,
    );
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
    final oi = _orders.indexWhere((o) => o.id == review.orderId);
    if (oi != -1) {
      _orders[oi] = _orders[oi].copyWith(reviewId: review.id);
      _pushOrders();
    }
    _pushReviews();
  }

  @override
  Future<void> markNotificationRead(String id) async {
    final i = _notifications.indexWhere((n) => n.id == id);
    if (i == -1) return;
    final n = _notifications[i];
    _notifications[i] = AppNotification(
      id: n.id,
      recipientId: n.recipientId,
      role: n.role,
      type: n.type,
      title: n.title,
      body: n.body,
      deepLink: n.deepLink,
      isRead: true,
      createdAt: n.createdAt,
    );
    _pushNotifications();
  }

  @override
  Future<void> saveVoucher(Voucher voucher) async {
    if (voucher.companyId.isEmpty) {
      throw ArgumentError('A voucher must belong to a company.');
    }
    final normalized = voucher.copyWith(code: voucher.normalizedCode);

    if (normalized.id.isNotEmpty) {
      final byId = _vouchers.indexWhere((v) => v.id == normalized.id);
      if (byId != -1) {
        _vouchers[byId] = normalized;
      } else {
        _vouchers.add(normalized);
      }
    } else {
      // Editing by code (documents created before an id existed).
      final byCode = _vouchers.indexWhere(
        (v) =>
            v.companyId == normalized.companyId &&
            v.normalizedCode == normalized.normalizedCode,
      );
      if (byCode != -1) {
        _vouchers[byCode] = normalized.copyWith(id: _vouchers[byCode].id);
      } else {
        _vouchers.add(normalized.copyWith(id: _uuid.v4()));
      }
    }
    _pushVouchers();
  }

  @override
  Future<void> deleteVoucher(String voucherId, {String companyId = ''}) async {
    _vouchers.removeWhere(
      (v) =>
          v.id == voucherId && (companyId.isEmpty || v.companyId == companyId),
    );
    _pushVouchers();
  }

  @override
  Future<void> saveProduct(Product product) async {
    if (product.companyId.isEmpty) {
      throw ArgumentError('A product must belong to a company.');
    }
    final id = product.id.isEmpty ? _uuid.v4() : product.id;
    final saved = product.copyWith(id: id);
    final i = _products.indexWhere((p) => p.id == id);
    if (i == -1) {
      _products.add(saved);
    } else {
      _products[i] = saved;
    }

    // Keep the category assignment list in sync with `product.categoryId`.
    if (saved.categoryId.isNotEmpty) {
      final ci = _categories.indexWhere((c) => c.id == saved.categoryId);
      if (ci != -1) {
        _categories[ci] = _categories[ci].withProduct(id);
      }
    }
    _pushProducts();
    if (saved.categoryId.isNotEmpty) _pushCategories();
  }

  @override
  Future<void> deleteProduct(String productId, {String companyId = ''}) async {
    final targetShopId = companyId.isNotEmpty
        ? companyId
        : (_products
                  .where((p) => p.id == productId)
                  .map((p) => p.companyId)
                  .firstOrNull ??
              '');

    _products.removeWhere(
      (p) =>
          p.id == productId && (companyId.isEmpty || p.companyId == companyId),
    );

    // Referential integrity: drop it from every category that listed it.
    var touched = false;
    for (var i = 0; i < _categories.length; i++) {
      if (_categories[i].productList.contains(productId)) {
        _categories[i] = _categories[i].withoutProduct(productId);
        touched = true;
      }
    }
    _pushProducts();
    if (touched) _pushCategories();

    if (targetShopId.isNotEmpty) {
      await removeProductFromTrendingNow(
        shopId: targetShopId,
        productId: productId,
      );
    }
  }

  @override
  Future<void> saveCategory(Category category) async {
    final isNew = category.id.isEmpty;
    final id = isNew ? _uuid.v4() : category.id;
    var saved = category.copyWith(id: id);

    // Never let an admin build a loop: a cycle would hang the tree builder.
    if (saved.parentId != null &&
        CategoryHierarchy.wouldCreateCycle(
          categoryId: id,
          newParentId: saved.parentId,
          all: _categories,
        )) {
      throw ArgumentError(
        'Cannot move "${saved.name}" under one of its own sub-categories.',
      );
    }

    final i = _categories.indexWhere((c) => c.id == id);
    final existing = i == -1 ? null : _categories[i];
    final parentChanged =
        existing != null && (existing.parentId ?? '') != (saved.parentId ?? '');

    // New categories (and moves to another parent) go to the END of their
    // sibling list; plain edits keep their manual position.
    if (isNew || existing == null || parentChanged) {
      final parentKey = saved.parentId ?? '';
      var maxOrder = -1;
      for (final c in _categories) {
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

    if (i == -1) {
      _categories.add(saved);
    } else {
      _categories[i] = saved;
    }
    _pushCategories();
  }

  @override
  Future<void> reorderCategories(List<Category> orderedSiblings) async {
    for (var i = 0; i < orderedSiblings.length; i++) {
      final cat = orderedSiblings[i];
      if (cat.sortOrder == i) continue;
      final idx = _categories.indexWhere((c) => c.id == cat.id);
      if (idx != -1 && _categories[idx].sortOrder != i) {
        _categories[idx] = _categories[idx].copyWith(sortOrder: i);
      }
    }
    _pushCategories();
  }

  @override
  Future<void> backfillCategorySortOrder({String companyId = ''}) async {
    final byParent = <String, List<Category>>{};
    for (final c in _categories) {
      if (companyId.isNotEmpty &&
          c.companyId.isNotEmpty &&
          c.companyId != companyId) {
        continue;
      }
      byParent.putIfAbsent(c.parentId ?? '', () => []).add(c);
    }

    for (final entry in byParent.entries) {
      final siblings = entry.value;
      // Only groups with colliding values (legacy data has no sortOrder) are
      // migrated; an already ordered group is left untouched so a second run
      // can never clobber the admin's manual arrangement.
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
        final idx = _categories.indexWhere((c) => c.id == siblings[i].id);
        if (idx != -1 && _categories[idx].sortOrder != i) {
          _categories[idx] = _categories[idx].copyWith(sortOrder: i);
        }
      }
    }
    _pushCategories();
  }

  @override
  Future<void> deleteCategory(
    String categoryId, {
    String companyId = '',
  }) async {
    final i = _categories.indexWhere(
      (c) =>
          c.id == categoryId &&
          (companyId.isEmpty ||
              c.companyId == companyId ||
              c.companyId.isEmpty),
    );
    if (i == -1) return;

    final removed = _categories[i];
    final newParent = removed.parentId;

    // Children move up one level instead of being orphaned.
    for (var j = 0; j < _categories.length; j++) {
      if (_categories[j].parentId == categoryId) {
        _categories[j] = _categories[j].copyWith(
          parentId: newParent,
          clearParentId: newParent == null || newParent.isEmpty,
        );
      }
    }

    // Products fall back to the parent category (or become uncategorised).
    final orphans = <String>[...removed.productList];
    for (var j = 0; j < _products.length; j++) {
      if (_products[j].categoryId == categoryId) {
        orphans.add(_products[j].id);
        _products[j] = _products[j].copyWith(categoryId: newParent ?? '');
      }
    }

    _categories.removeAt(i);

    if (newParent != null && newParent.isNotEmpty) {
      final pi = _categories.indexWhere((c) => c.id == newParent);
      if (pi != -1) {
        var parent = _categories[pi];
        for (final productId in orphans) {
          parent = parent.withProduct(productId);
        }
        _categories[pi] = parent;
      }
    }

    _pushCategories();
    if (orphans.isNotEmpty) _pushProducts();
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
          e.id == employeeId && (companyId.isEmpty || e.companyId == companyId),
    );
    _pushEmployees();
  }

  @override
  Future<void> saveDeliveryCharge(DeliveryCharge charge) async {
    final i = _deliveryCharges.indexWhere(
      (d) =>
          d.pincode == charge.pincode &&
          (charge.companyId.isEmpty ||
              d.companyId.isEmpty ||
              d.companyId == charge.companyId),
    );
    if (i == -1) {
      _deliveryCharges.add(charge);
    } else {
      _deliveryCharges[i] = charge;
    }
    _pushDelivery();
  }

  @override
  Future<void> deleteDeliveryCharge(
    String pincode, {
    String companyId = '',
  }) async {
    _deliveryCharges.removeWhere(
      (d) =>
          d.pincode == pincode &&
          (companyId.isEmpty ||
              d.companyId.isEmpty ||
              d.companyId == companyId),
    );
    _pushDelivery();
  }

  @override
  Future<void> importDeliveryCharges(List<DeliveryCharge> charges) async {
    for (final c in charges) {
      await saveDeliveryCharge(c);
    }
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
    final i = _offerBanners.indexWhere((b) => b.id == banner.id);
    if (i == -1) {
      _offerBanners.add(banner);
    } else {
      _offerBanners[i] = banner;
    }
    _pushBanners();
  }

  @override
  Future<void> saveAdBanner(AdBanner banner) async {
    final i = _adBanners.indexWhere((b) => b.id == banner.id);
    if (i == -1) {
      _adBanners.add(banner);
    } else {
      _adBanners[i] = banner;
    }
    _pushBanners();
  }

  @override
  Future<void> deleteBanner(String id, {String companyId = ''}) async {
    _offerBanners.removeWhere(
      (b) => b.id == id && (companyId.isEmpty || b.companyId == companyId),
    );
    _adBanners.removeWhere((b) => b.id == id);
    _pushBanners();
  }

  @override
  Future<void> registerFcmToken(String userId, String token) async {}

  void _pushHomeExplore() {
    _homeExploreCtrl.add([..._homeExploreCategories]);
  }

  void _pushHomeTrending() {
    _homeTrendingCtrl.add([..._homeTrendingItems]);
  }

  @override
  Stream<List<HomeExploreCategory>> homeExploreCategories({
    String shopId = '',
    bool activeOnly = false,
  }) {
    Stream<List<HomeExploreCategory>> stream = _homeExploreCtrl.stream;
    final initial = _filterHomeExplore(shopId: shopId, activeOnly: activeOnly);
    return Stream<List<HomeExploreCategory>>.multi((controller) {
      controller.add(initial);
      final sub = stream.listen((all) {
        controller.add(
          _filterHomeExplore(shopId: shopId, activeOnly: activeOnly),
        );
      });
      controller.onCancel = sub.cancel;
    });
  }

  List<HomeExploreCategory> _filterHomeExplore({
    required String shopId,
    required bool activeOnly,
  }) {
    return _homeExploreCategories
        .where(
          (c) =>
              (shopId.isEmpty || c.shopId == shopId) &&
              (!activeOnly || c.isActive),
        )
        .sortedBy<num>((c) => c.displayOrder);
  }

  @override
  Future<void> saveHomeExploreCategory(HomeExploreCategory entry) async {
    final id = entry.id.isNotEmpty
        ? entry.id
        : (entry.shopId.isNotEmpty && entry.categoryId.isNotEmpty
              ? '${entry.shopId}_${entry.categoryId}'
              : _uuid.v4());

    final now = DateTime.now();
    final toSave = entry.copyWith(
      id: id,
      createdAt: entry.createdAt ?? now,
      updatedAt: now,
    );
    final i = _homeExploreCategories.indexWhere((c) => c.id == id);
    if (i == -1) {
      _homeExploreCategories.add(toSave);
    } else {
      _homeExploreCategories[i] = toSave;
    }
    _pushHomeExplore();
  }

  @override
  Future<void> deleteHomeExploreCategory(String id) async {
    _homeExploreCategories.removeWhere((c) => c.id == id);
    _pushHomeExplore();
  }

  @override
  Future<void> reorderHomeExploreCategories(
    List<HomeExploreCategory> orderedEntries,
  ) async {
    final now = DateTime.now();
    for (var i = 0; i < orderedEntries.length; i++) {
      final item = orderedEntries[i];
      final idx = _homeExploreCategories.indexWhere((c) => c.id == item.id);
      if (idx != -1) {
        _homeExploreCategories[idx] = _homeExploreCategories[idx].copyWith(
          displayOrder: i,
          updatedAt: now,
        );
      }
    }
    _pushHomeExplore();
  }

  @override
  Stream<List<HomeTrendingItem>> homeTrendingNow({
    String shopId = '',
    bool activeOnly = false,
  }) {
    Stream<List<HomeTrendingItem>> stream = _homeTrendingCtrl.stream;
    final initial = _filterHomeTrending(shopId: shopId, activeOnly: activeOnly);
    return Stream<List<HomeTrendingItem>>.multi((controller) {
      controller.add(initial);
      final sub = stream.listen((all) {
        controller.add(
          _filterHomeTrending(shopId: shopId, activeOnly: activeOnly),
        );
      });
      controller.onCancel = sub.cancel;
    });
  }

  List<HomeTrendingItem> _filterHomeTrending({
    required String shopId,
    required bool activeOnly,
  }) {
    return _homeTrendingItems
        .where(
          (t) =>
              (shopId.isEmpty || t.shopId == shopId) &&
              (!activeOnly || t.isActive),
        )
        .sortedBy<num>((t) => t.displayOrder);
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
              : _uuid.v4());

    final now = DateTime.now();
    final toSave = entry.copyWith(
      id: id,
      createdAt: entry.createdAt ?? now,
      updatedAt: now,
    );
    final i = _homeTrendingItems.indexWhere((t) => t.id == id);
    if (i == -1) {
      _homeTrendingItems.add(toSave);
    } else {
      _homeTrendingItems[i] = toSave;
    }
    _pushHomeTrending();
  }

  @override
  Future<void> deleteHomeTrendingItem(String id) async {
    _homeTrendingItems.removeWhere((t) => t.id == id);
    _pushHomeTrending();
  }

  @override
  Future<void> reorderHomeTrendingItems(
    List<HomeTrendingItem> orderedEntries,
  ) async {
    final now = DateTime.now();
    for (var i = 0; i < orderedEntries.length; i++) {
      final item = orderedEntries[i];
      final idx = _homeTrendingItems.indexWhere((t) => t.id == item.id);
      if (idx != -1) {
        _homeTrendingItems[idx] = _homeTrendingItems[idx].copyWith(
          displayOrder: i,
          updatedAt: now,
        );
      }
    }
    _pushHomeTrending();
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

    final toRemove = _homeTrendingItems
        .where(
          (t) =>
              t.shopId == cleanShopId &&
              t.isProduct &&
              t.productId == cleanProductId,
        )
        .toList();

    if (toRemove.isEmpty) return 0;

    _homeTrendingItems.removeWhere(
      (t) =>
          t.shopId == cleanShopId &&
          t.isProduct &&
          t.productId == cleanProductId,
    );
    _pushHomeTrending();
    return toRemove.length;
  }

  @override
  Future<bool> isProductInTrendingNow({
    required String shopId,
    required String productId,
  }) async {
    final cleanShopId = shopId.trim();
    final cleanProductId = productId.trim();
    if (cleanShopId.isEmpty || cleanProductId.isEmpty) return false;

    return _homeTrendingItems.any(
      (t) =>
          t.shopId == cleanShopId &&
          t.isProduct &&
          t.productId == cleanProductId,
    );
  }
}
