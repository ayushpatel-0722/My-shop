import 'package:flutter/material.dart';

/// Logs route transitions with clear screen class names and paths.
class AppRouteLogger extends NavigatorObserver {
  static const Map<String, String> _routeScreenMap = {
    '/': 'SplashScreen',
    '/role': 'RoleSelectionScreen',
    '/admin-login': 'AdminLoginScreen',
    '/employee-login': 'EmployeeLoginScreen',
    '/user-login': 'UserLoginScreen',
    '/user-signup': 'UserSignupScreen',
    '/admin-signup': 'AdminSignupScreen',
    '/company-onboarding': 'CompanyOnboardingScreen',
    '/home': 'HomeScreen',
    '/search': 'SearchScreen',
    '/cart': 'CartScreen',
    '/checkout': 'CheckoutScreen',
    '/orders': 'OrdersScreen',
    '/notifications': 'NotificationsScreen',
    '/admin': 'AdminDashboardScreen',
    '/admin/orders': 'AdminOrdersScreen',
    '/admin/products': 'AdminProductsScreen',
    '/admin/products/add': 'AdminAddProductScreen',
    '/admin/categories': 'AdminCategoriesScreen',
    '/admin/categories/add': 'AdminAddCategoryScreen',
    '/admin/categories/edit/:id': 'AdminEditCategoryScreen',
    '/admin/vouchers': 'AdminVouchersScreen',
    '/admin/employees': 'AdminEmployeesScreen',
    '/admin/employees/add': 'AdminAddEmployeeScreen',
    '/admin/employees/edit/:id': 'AdminAddEmployeeScreen',
    '/admin/admins': 'AdminAdminsScreen',
    '/admin/delivery-charges': 'AdminDeliveryChargesScreen',
    '/admin/delivery-charges/add': 'AdminAddDeliveryChargeScreen',
    '/admin/delivery-charges/edit/:pincode': 'AdminAddDeliveryChargeScreen',
    '/admin/banners': 'AdminBannersScreen',
    '/admin/reviews': 'AdminReviewsScreen',
    '/admin/recommendations': 'AdminRecommendationsScreen',
    '/admin/reports': 'AdminReportsScreen',
    '/admin/qr': 'AdminQrScreen',
    '/employee': 'EmployeeOrderQueueScreen',
    '/qr-scanner': 'QrScannerScreen',
  };

  static String _screenLabel(Route<dynamic>? route) {
    if (route == null) return '';
    final rawName = route.settings.name?.trim() ?? '';
    if (rawName.isEmpty) {
      final type = route.runtimeType.toString();
      return type != 'MaterialPageRoute<dynamic>' &&
              type != '_MaterialPageRoute<dynamic>'
          ? type
          : 'AppScreen';
    }

    final path = rawName.split('?').first;
    if (_routeScreenMap.containsKey(path)) {
      return '${_routeScreenMap[path]} ($rawName)';
    }

    if (path.startsWith('/company/')) {
      return 'CompanyStoreScreen ($rawName)';
    }
    if (path.startsWith('/category/')) {
      return 'CategoryViewScreen ($rawName)';
    }
    if (path.startsWith('/product/')) {
      return 'ProductDetailsScreen ($rawName)';
    }
    if (path.startsWith('/admin/employees/edit/')) {
      return 'AdminAddEmployeeScreen ($rawName)';
    }
    if (path.startsWith('/order/')) {
      return 'OrderTrackingScreen ($rawName)';
    }
    if (path.startsWith('/reviews/')) {
      return 'ReviewsScreen ($rawName)';
    }
    if (path.startsWith('/leave-review/')) {
      return 'LeaveReviewScreen ($rawName)';
    }
    if (path.startsWith('/employee/packing/')) {
      return 'PackingScreen ($rawName)';
    }

    return rawName;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final to = _screenLabel(route);
    final from = _screenLabel(previousRoute);
    if (from.isEmpty) {
      debugPrint('[ROUTE PUSH] -> $to');
    } else {
      debugPrint('[ROUTE PUSH] $from  --->  $to');
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final from = _screenLabel(route);
    final to = _screenLabel(previousRoute);
    if (to.isEmpty) {
      debugPrint('[ROUTE POP] Closed: $from');
    } else {
      debugPrint('[ROUTE POP] $from  <---  $to');
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final oldLabel = _screenLabel(oldRoute);
    final newLabel = _screenLabel(newRoute);
    debugPrint('[ROUTE REPLACE] $oldLabel  ===>  $newLabel');
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final removed = _screenLabel(route);
    if (removed.isNotEmpty) {
      debugPrint('[ROUTE REMOVE] $removed');
    }
  }
}
