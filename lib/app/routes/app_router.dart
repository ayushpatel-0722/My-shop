import 'package:go_router/go_router.dart';

import '../../core/models/category.dart';
import '../../core/models/employee.dart';
import '../../core/models/product.dart';
import '../../core/services/auth_session.dart';
import '../../core/utils/app_route_logger.dart';
import '../../features/admin/admins/admin_admins_screen.dart';
import '../../features/admin/banners/admin_banners_screen.dart';
import '../../features/admin/categories/admin_add_category_screen.dart';
import '../../features/admin/categories/admin_categories_screen.dart';
import '../../features/admin/dashboard/admin_dashboard_screen.dart';
import '../../features/admin/delivery_charges/admin_delivery_charges_screen.dart';
import '../../features/admin/employees/admin_add_employee_screen.dart';
import '../../features/admin/employees/admin_employees_screen.dart';
import '../../features/admin/orders/admin_orders_screen.dart';
import '../../features/admin/products/admin_add_product_screen.dart';
import '../../features/admin/products/admin_products_screen.dart';
import '../../features/admin/qr/admin_qr_screen.dart';
import '../../features/admin/recommendations/admin_recommendations_screen.dart';
import '../../features/admin/reports/admin_reports_screen.dart';
import '../../features/admin/reviews/admin_reviews_screen.dart';
import '../../features/admin/vouchers/admin_vouchers_screen.dart';
import '../../features/auth/admin_login/admin_login_screen.dart';
import '../../features/auth/employee_login/employee_login_screen.dart';
import '../../features/auth/signup/admin_signup_screen.dart';
import '../../features/auth/signup/user_signup_screen.dart';
import '../../features/auth/user_login/user_login_screen.dart';
import '../../features/checkout/cart/cart_screen.dart';
import '../../features/checkout/payment/checkout_screen.dart';
import '../../features/checkout/tracking/order_tracking_screen.dart';
import '../../features/checkout/tracking/orders_screen.dart';
import '../../features/company_onboarding/company_onboarding_screen.dart';
import '../../features/employee/order_queue/employee_order_queue_screen.dart';
import '../../features/employee/packing/packing_screen.dart';
import '../../features/marketplace/categories/categories_screen.dart';
import '../../features/marketplace/category_view/category_view_screen.dart';
import '../../features/marketplace/company_store/company_store_screen.dart';
import '../../features/marketplace/home/home_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/account/account_screen.dart';
import '../../features/product/details/product_details_screen.dart';
import '../../features/product/search/search_screen.dart';
import '../../features/qr/qr_scanner_screen.dart';
import '../../features/reviews/leave_review_screen.dart';
import '../../features/reviews/reviews_screen.dart';
import '../../features/splash/role_selection_screen.dart';
import '../../features/splash/splash_screen.dart';

/// Route path constants.
class AppRoutes {
  static const splash = '/';
  static const role = '/role';
  static const adminLogin = '/admin-login';
  static const employeeLogin = '/employee-login';
  static const userLogin = '/user-login';
  static const userSignup = '/user-signup';
  static const adminSignup = '/admin-signup';
  static const companyOnboarding = '/company-onboarding';
  static const home = '/home';
  static const categories = '/categories';
  static const account = '/account';
  static const companyStore = '/company/:slug';
  static const category = '/category/:id';
  static const product = '/product/:id';
  static const search = '/search';
  static const cart = '/cart';
  static const checkout = '/checkout';
  static const orders = '/orders';
  static const orderTracking = '/order/:id';
  static const reviews = '/reviews/:companyId';
  static const leaveReview = '/leave-review/:orderId';
  static const notifications = '/notifications';

  static const admin = '/admin';
  static const adminOrders = '/admin/orders';
  static const adminProducts = '/admin/products';
  static const adminAddProduct = '/admin/products/add';
  static const adminEditProduct = '/admin/products/edit/:id';
  static const adminCategories = '/admin/categories';
  static const adminAddCategory = '/admin/categories/add';
  static const adminEditCategory = '/admin/categories/edit/:id';
  static const adminVouchers = '/admin/vouchers';
  static const adminEmployees = '/admin/employees';
  static const adminAddEmployee = '/admin/employees/add';
  static const adminEditEmployee = '/admin/employees/edit/:id';
  static const adminAdmins = '/admin/admins';
  static const adminDelivery = '/admin/delivery-charges';
  static const adminBanners = '/admin/banners';
  static const adminReviews = '/admin/reviews';
  static const adminRecommendations = '/admin/recommendations';
  static const adminReports = '/admin/reports';
  static const adminQr = '/admin/qr';

  static const employeeHome = '/employee';
  static const packing = '/employee/packing/:orderId';
  static const qrScanner = '/qr-scanner';

  // Deep-link helper builders (Section 15).
  static String companyPath(String slug) => '/company/$slug';
  static String productPath(String id) => '/product/$id';
  static String categoryPath(String id) => '/category/$id';
  static String adminEditProductPath(String id) => '/admin/products/edit/$id';
  static String adminEditCategoryPath(String id) =>
      '/admin/categories/edit/$id';
  static String adminEditEmployeePath(String id) => '/admin/employees/edit/$id';
  static String orderPath(String id) => '/order/$id';
}

/// Handles global routing guards, role protection, and browser reload policies:
/// 1. While session is restoring on startup / reload: holds route.
/// 2. On initial app boot / browser reload:
///    - If user is NOT logged in: navigates to the main screen to choose role (/role).
///    - If user IS logged in: navigates to their respective home screen (/admin, /employee, or /home).
/// 3. In-app navigation after boot: enforces role-based access control.
String? appRouteRedirect(String loc) {
  // While session is restoring on startup / browser reload, hold route
  if (AuthSession.isRestoring) {
    return null;
  }

  // On app startup or browser reload:
  // 1. If user is NOT logged in: land on Home Screen (/home) by default, or stay on public deep link.
  // 2. If user IS logged in: any screen reload preserves/moves to respective home.
  if (!AuthSession.hasCompletedInitialBoot) {
    AuthSession.markBootCompleted();
    if (AuthSession.currentUser == null) {
      final allowedExact = {
        AppRoutes.role,
        AppRoutes.adminLogin,
        AppRoutes.employeeLogin,
        AppRoutes.userLogin,
        AppRoutes.userSignup,
        AppRoutes.adminSignup,
        AppRoutes.companyOnboarding,
        AppRoutes.home,
        AppRoutes.search,
        AppRoutes.cart,
      };

      final allowedPrefixes = [
        '/company/', // company store
        '/product/',
        '/category/',
        '/reviews/',
      ];

      var allowed = allowedExact.contains(loc);
      if (!allowed) {
        for (final p in allowedPrefixes) {
          if (loc.startsWith(p)) {
            allowed = true;
            break;
          }
        }
      }

      if (!allowed) return AppRoutes.home;
    } else {
      if (AuthSession.isAdmin) {
        if (loc != AppRoutes.admin) return AppRoutes.admin;
      } else if (AuthSession.isEmployee) {
        if (loc != AppRoutes.employeeHome) return AppRoutes.employeeHome;
      } else {
        if (loc != AppRoutes.home) return AppRoutes.home;
      }
    }
    return null;
  }

  // If user is authenticated, redirect away from auth selection & login screens
  if (AuthSession.currentUser != null) {
    if (loc == AppRoutes.role ||
        loc == AppRoutes.userLogin ||
        loc == AppRoutes.userSignup ||
        loc == AppRoutes.adminLogin ||
        loc == AppRoutes.employeeLogin) {
      if (AuthSession.isAdmin) return AppRoutes.admin;
      if (AuthSession.isEmployee) return AppRoutes.employeeHome;
      return AppRoutes.home;
    }
  }

  // Protect only the admin area ("/admin" and its subpaths), not the
  // admin-login route. Similarly protect only the employee area.
  if ((loc == AppRoutes.admin || loc.startsWith('${AppRoutes.admin}/')) &&
      !AuthSession.isAdmin) {
    return AppRoutes.role;
  }
  if ((loc == AppRoutes.employeeHome ||
          loc.startsWith('${AppRoutes.employeeHome}/')) &&
      !AuthSession.isEmployee) {
    return AppRoutes.role;
  }
  return null;
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  refreshListenable: AuthSession.instance,
  observers: [AppRouteLogger()],
  redirect: (context, state) => appRouteRedirect(state.matchedLocation),
  routes: [
    GoRoute(path: AppRoutes.splash, builder: (_, s) => const SplashScreen()),
    GoRoute(
      path: AppRoutes.role,
      builder: (_, s) => const RoleSelectionScreen(),
    ),
    GoRoute(
      path: AppRoutes.adminLogin,
      builder: (_, s) => const AdminLoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.employeeLogin,
      builder: (_, s) => const EmployeeLoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.userLogin,
      builder: (_, s) => const UserLoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.userSignup,
      builder: (_, s) => const UserSignupScreen(),
    ),
    GoRoute(
      path: AppRoutes.adminSignup,
      builder: (_, state) => AdminSignupScreen(
        companyId: state.uri.queryParameters['companyId'] ?? '',
        companyName: state.uri.queryParameters['companyName'] ?? '',
      ),
    ),
    GoRoute(
      path: AppRoutes.companyOnboarding,
      builder: (_, s) => const CompanyOnboardingScreen(),
    ),
    GoRoute(path: AppRoutes.home, builder: (_, s) => const HomeScreen()),
    GoRoute(
      path: AppRoutes.categories,
      builder: (_, s) => const CategoriesScreen(),
    ),
    GoRoute(
      path: AppRoutes.companyStore,
      builder: (_, state) =>
          CompanyStoreScreen(slug: state.pathParameters['slug'] ?? ''),
    ),
    GoRoute(
      path: AppRoutes.category,
      builder: (_, state) => CategoryViewScreen(
        categoryId: state.pathParameters['id'] ?? '',
        categoryName: state.uri.queryParameters['name'] ?? '',
        companyId: state.uri.queryParameters['companyId'] ?? '',
      ),
    ),
    GoRoute(
      path: AppRoutes.product,
      builder: (_, state) =>
          ProductDetailsScreen(productId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: AppRoutes.search,
      builder: (_, state) => SearchScreen(
        companyId: state.uri.queryParameters['companyId'] ?? '',
        companyName: state.uri.queryParameters['name'] ?? '',
      ),
    ),
    GoRoute(path: AppRoutes.cart, builder: (_, s) => const CartScreen()),
    GoRoute(
      path: AppRoutes.checkout,
      builder: (_, s) => const CheckoutScreen(),
    ),
    GoRoute(path: AppRoutes.orders, builder: (_, s) => const OrdersScreen()),
    GoRoute(path: AppRoutes.account, builder: (_, s) => const AccountScreen()),
    GoRoute(
      path: AppRoutes.orderTracking,
      builder: (_, state) =>
          OrderTrackingScreen(orderId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: AppRoutes.reviews,
      builder: (_, state) =>
          ReviewsScreen(companyId: state.pathParameters['companyId'] ?? ''),
    ),
    GoRoute(
      path: AppRoutes.leaveReview,
      builder: (_, state) => LeaveReviewScreen(
        orderId: state.pathParameters['orderId'] ?? '',
        orderCompanyId: state.uri.queryParameters['companyId'] ?? '',
        initialRating:
            int.tryParse(state.uri.queryParameters['rating'] ?? '') ?? 5,
      ),
    ),
    GoRoute(
      path: AppRoutes.notifications,
      builder: (_, s) => const NotificationsScreen(),
    ),

    // Admin
    GoRoute(
      path: AppRoutes.admin,
      builder: (_, s) => const AdminDashboardScreen(),
    ),
    GoRoute(
      path: AppRoutes.adminOrders,
      builder: (_, s) => const AdminOrdersScreen(),
    ),
    GoRoute(
      path: AppRoutes.adminProducts,
      builder: (_, s) => const AdminProductsScreen(),
    ),
    GoRoute(
      path: AppRoutes.adminAddProduct,
      builder: (_, state) => AdminAddProductScreen(
        product: state.extra is Product ? state.extra as Product : null,
      ),
    ),
    GoRoute(
      path: AppRoutes.adminEditProduct,
      builder: (_, state) {
        final id = state.pathParameters['id'];
        final product = state.extra is Product ? state.extra as Product : null;
        return AdminAddProductScreen(product: product, productId: id);
      },
    ),
    GoRoute(
      path: AppRoutes.adminCategories,
      builder: (_, s) => const AdminCategoriesScreen(),
    ),
    GoRoute(
      path: AppRoutes.adminAddCategory,
      builder: (_, state) => AdminAddCategoryScreen(
        category: state.extra is Category ? state.extra as Category : null,
      ),
    ),
    GoRoute(
      path: AppRoutes.adminEditCategory,
      builder: (_, state) {
        final id = state.pathParameters['id'];
        final category = state.extra is Category
            ? state.extra as Category
            : null;
        return AdminAddCategoryScreen(category: category, categoryId: id);
      },
    ),
    GoRoute(
      path: AppRoutes.adminVouchers,
      builder: (_, s) => const AdminVouchersScreen(),
    ),
    GoRoute(
      path: AppRoutes.adminEmployees,
      builder: (_, s) => const AdminEmployeesScreen(),
    ),
    GoRoute(
      path: AppRoutes.adminAddEmployee,
      builder: (_, state) => AdminAddEmployeeScreen(
        employee: state.extra is Employee ? state.extra as Employee : null,
      ),
    ),
    GoRoute(
      path: AppRoutes.adminEditEmployee,
      builder: (_, state) {
        final id = state.pathParameters['id'];
        final employee = state.extra is Employee
            ? state.extra as Employee
            : null;
        return AdminAddEmployeeScreen(employee: employee, employeeId: id);
      },
    ),
    GoRoute(
      path: AppRoutes.adminAdmins,
      builder: (_, s) => const AdminAdminsScreen(),
    ),
    GoRoute(
      path: AppRoutes.adminDelivery,
      builder: (_, s) => const AdminDeliveryChargesScreen(),
    ),
    GoRoute(
      path: AppRoutes.adminBanners,
      builder: (_, s) => const AdminBannersScreen(),
    ),
    GoRoute(
      path: AppRoutes.adminReviews,
      builder: (_, s) => const AdminReviewsScreen(),
    ),
    GoRoute(
      path: AppRoutes.adminRecommendations,
      builder: (_, s) => const AdminRecommendationsScreen(),
    ),
    GoRoute(
      path: AppRoutes.adminReports,
      builder: (_, s) => const AdminReportsScreen(),
    ),
    GoRoute(path: AppRoutes.adminQr, builder: (_, s) => const AdminQrScreen()),

    // Employee
    GoRoute(
      path: AppRoutes.employeeHome,
      builder: (_, s) => const EmployeeOrderQueueScreen(),
    ),
    GoRoute(
      path: AppRoutes.packing,
      builder: (_, state) =>
          PackingScreen(orderId: state.pathParameters['orderId'] ?? ''),
    ),

    // QR scanner (shared by Employee packing + Shopper scan)
    GoRoute(
      path: AppRoutes.qrScanner,
      builder: (_, s) => const QrScannerScreen(),
    ),
  ],
);
