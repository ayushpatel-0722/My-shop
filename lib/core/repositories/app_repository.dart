import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:firebase_database/firebase_database.dart';

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

/// Central repository contract. Two implementations are provided:
///  - [FirebaseAppRepository]  (real Firestore/Auth/Storage — default)
///  - MockAppRepository        (in-memory, for UI-only demos)
abstract class AppRepository {
  // ------------------------------------------------------------------ Auth --
  /// Sends a one-time password to [mobileNumber] via Firebase Phone Auth.
  Future<void> sendOtp(String mobileNumber);

  /// Verifies [otp] and signs the user in. Returns the signed-in user, or
  /// null when the code is invalid.
  Future<AppUser?> verifyOtp(String mobileNumber, String otp);

  /// True when a customer with [mobileNumber] already exists.
  Future<bool> userExists(String mobileNumber);

  /// Two-step Admin login: company credential, then personal credential.
  Future<AppUser?> adminLogin({
    required String companyName,
    required String companyPassword,
    required String email,
    required String password,
  });

  /// Single-step Employee login.
  Future<AppUser?> employeeLogin({
    required String companyName,
    required String email,
    required String password,
  });

  Future<void> createUserAccount(
    String name,
    String mobileNumber, {
    String email = '',
    String authProvider = '',
    String googleId = '',
    List<AddressEntry> addresses = const [],
  });
  Future<void> updateUserMobile(String userId, String mobileNumber);
  Future<void> saveUserAddress(String userId, AddressEntry address);
  Future<Company> createCompany(Company company);
  Future<Admin> createAdminAccount(Admin admin, {required String password});
  Future<Employee> createEmployeeAccount(
    Employee employee, {
    required String password,
  });
  Future<void> signOut();

  /// Resolves the currently signed-in Firebase Auth user to an [AppUser] by
  /// looking up their profile in /admins, /employees, or /users.
  /// Returns null when no user is signed in.
  Future<AppUser?> resolveCurrentUser();

  // ----------------------------------------------------------------- Reads --
  Stream<List<Company>> companies();
  Future<Company?> company(String id);
  Stream<List<Category>> categories({String companyId = ''});
  Future<Category?> category(String id, {String companyId = ''});
  Stream<List<Product>> products({
    String companyId = '',
    String categoryId = '',
    String search = '',
  });
  Future<Product?> product(String id);
  Stream<List<AdBanner>> adBanners();
  Stream<List<OfferBanner>> offerBanners(String companyId);
  Stream<List<Voucher>> vouchers(String companyId);
  /// Case-insensitive lookup of a live voucher code inside [companyId].
  Future<Voucher?> voucherByCode(String companyId, String code);
  Future<DeliveryCharge?> deliveryCharge(String pincode, String companyId);
  Stream<List<DeliveryCharge>> deliveryCharges({String companyId = ''});
  Stream<List<Order>> orders({String userId = '', String companyId = ''});

  /// A single order, or null when it does not exist.
  Future<Order?> order(String orderId);

  /// Live view of one order (used by tracking / packing screens) so they never
  /// subscribe to every order of every company.
  Stream<Order?> watchOrder(String orderId);
  Stream<List<Review>> reviews(String companyId);
  Stream<List<AppNotification>> notifications(String recipientId);
  Stream<List<Employee>> employees(String companyId);
  Future<Employee?> employee(String id, {String companyId = ''});
  Stream<List<Admin>> admins(String companyId);

  /// Resolved recommendation products (pinned product, else linked, else
  /// best-sellers) for the feed.
  Future<List<Product>> recommendations({String companyId = ''});

  /// Raw recommendation documents, for the Admin manager.
  Stream<List<Recommendation>> recommendationRecords({String companyId = ''});

  // ---------------------------------------------------------------- Writes --
  /// Persists an order and performs the bookkeeping that belongs to it:
  /// stock decrement and voucher redemption counters.
  ///
  /// Throws [ArgumentError] when the order has no company or no items.
  Future<Order> placeOrder(Order order);

  /// Moves an order to [status]. Throws [ArgumentError] on an illegal
  /// transition (see `OrderStatusRules`).
  Future<void> updateOrderStatus(String orderId, String status);

  /// Cancels an order when its current status still allows it.
  Future<void> cancelOrder(String orderId);

  Future<void> togglePaymentStatus(String orderId);
  Future<void> setEmployeePackingDone(String orderId, bool done);
  Future<void> assignEmployee(String orderId, String employeeId);
  Future<void> submitReview(Review review);
  Future<void> markNotificationRead(String id);

  /// Creates **or** updates a voucher (matched by id, then by code).
  Future<void> saveVoucher(Voucher voucher);

  Future<void> deleteVoucher(String voucherId, {String companyId = ''});

  /// Creates or updates a product and keeps its category assignment in sync.
  Future<void> saveProduct(Product product);

  /// Deletes a product and removes it from every category that listed it.
  Future<void> deleteProduct(String productId, {String companyId = ''});

  /// Creates or updates a category, refusing to build a hierarchy cycle.
  Future<void> saveCategory(Category category);

  /// Deletes a category, re-parenting its children and its products.
  Future<void> deleteCategory(String categoryId, {String companyId = ''});
  Future<void> saveEmployee(Employee employee);
  Future<void> deleteEmployee(String companyId, String employeeId);
  Future<void> saveDeliveryCharge(DeliveryCharge charge);
  Future<void> importDeliveryCharges(List<DeliveryCharge> charges);
  Future<void> setReviewVisibility(String reviewId, bool visible);
  Future<void> saveRecommendation(Recommendation rec);
  Future<void> saveBanner(OfferBanner banner);
  Future<void> saveAdBanner(AdBanner banner);

  /// Registers an FCM push token against a customer.
  Future<void> registerFcmToken(String userId, String token);
}

/// Helper used when storing external media URLs instead of uploaded files.
class MediaUrlPayload {
  final String id;
  final String imageUrl;
  final String videoUrl;
  final String updatedAt;

  const MediaUrlPayload({
    required this.id,
    required this.imageUrl,
    required this.videoUrl,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'imageUrl': imageUrl,
    'videoUrl': videoUrl,
    'updatedAt': updatedAt,
  };
}

String? sanitizeMediaUrl(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;

  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return null;
  }

  return uri.toString();
}

Future<void> saveMediaToFirestore(MediaUrlPayload media) async {
  await firestore.FirebaseFirestore.instance
      .collection('media_links')
      .doc(media.id)
      .set(media.toMap(), firestore.SetOptions(merge: true));
}

Future<void> saveMediaToRealtimeDatabase(MediaUrlPayload media) async {
  await FirebaseDatabase.instance
      .ref()
      .child('media_links')
      .child(media.id)
      .set(media.toMap());
}
