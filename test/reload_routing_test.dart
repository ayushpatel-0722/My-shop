import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/app/routes/app_router.dart';
import 'package:myshop/core/models/app_user.dart';
import 'package:myshop/core/services/auth_session.dart';

void main() {
  setUp(() {
    AuthSession.currentUser = null;
    AuthSession.isRestoring = false;
    AuthSession.hasCompletedInitialBoot = false;
  });

  group('Reload and Boot Routing Rules', () {
    test('Unauthenticated user reloading /admin-login redirects to /role', () {
      AuthSession.currentUser = null;
      AuthSession.isRestoring = false;
      AuthSession.hasCompletedInitialBoot = false;

      // 1. Simulate reload arriving at /admin-login
      final reloadRedirect = appRouteRedirect('/admin-login');
      expect(reloadRedirect, equals(AppRoutes.role));
      expect(AuthSession.hasCompletedInitialBoot, isTrue);

      // 2. Subsequent in-app navigation to /admin-login from /role is allowed
      final inAppRedirect = appRouteRedirect('/admin-login');
      expect(inAppRedirect, isNull);
    });

    test(
      'LoggedIn Admin reloading any screen (/admin/products) moves to /admin',
      () {
        const admin = AppUser(
          id: 'adm_1',
          name: 'Admin Test',
          email: 'admin@myshop.com',
          role: 'admin',
          companyId: 'comp_1',
        );
        AuthSession.set(admin, restoring: false);
        AuthSession.hasCompletedInitialBoot = false;

        // 1. Simulate reload arriving at /admin/products
        final reloadRedirect = appRouteRedirect('/admin/products');
        expect(reloadRedirect, equals(AppRoutes.admin));
        expect(AuthSession.hasCompletedInitialBoot, isTrue);

        // 2. Subsequent in-app navigation to /admin/products is allowed
        final inAppRedirect = appRouteRedirect('/admin/products');
        expect(inAppRedirect, isNull);
      },
    );

    test('LoggedIn Shopper reloading any screen (/cart) moves to /home', () {
      const shopper = AppUser(
        id: 'user_1',
        name: 'Shopper Test',
        email: 'shopper@myshop.com',
        role: 'user',
        companyId: '',
      );
      AuthSession.set(shopper, restoring: false);
      AuthSession.hasCompletedInitialBoot = false;

      // 1. Simulate reload arriving at /cart
      final reloadRedirect = appRouteRedirect('/cart');
      expect(reloadRedirect, equals(AppRoutes.home));
      expect(AuthSession.hasCompletedInitialBoot, isTrue);

      // 2. Subsequent in-app navigation to /cart is allowed
      final inAppRedirect = appRouteRedirect('/cart');
      expect(inAppRedirect, isNull);
    });

    test('LoggedIn Employee reloading any screen moves to /employee', () {
      const employee = AppUser(
        id: 'emp_1',
        name: 'Employee Test',
        email: 'employee@myshop.com',
        role: 'employee',
        companyId: 'comp_1',
      );
      AuthSession.set(employee, restoring: false);
      AuthSession.hasCompletedInitialBoot = false;

      // 1. Simulate reload arriving at /employee/packing/123
      final reloadRedirect = appRouteRedirect('/employee/packing/123');
      expect(reloadRedirect, equals(AppRoutes.employeeHome));
      expect(AuthSession.hasCompletedInitialBoot, isTrue);

      // 2. Subsequent in-app navigation to /employee/packing/123 is allowed
      final inAppRedirect = appRouteRedirect('/employee/packing/123');
      expect(inAppRedirect, isNull);
    });

    test(
      'Unauthenticated user cannot access /admin area during in-app navigation',
      () {
        AuthSession.currentUser = null;
        AuthSession.isRestoring = false;
        AuthSession.hasCompletedInitialBoot = true;

        final inAppRedirect = appRouteRedirect('/admin/products');
        expect(inAppRedirect, equals(AppRoutes.role));
      },
    );
  });
}
