import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/app/routes/app_router.dart';
import 'package:myshop/core/domain/employee_roles.dart';
import 'package:myshop/core/models/app_user.dart';
import 'package:myshop/core/services/auth_session.dart';

AppUser _employee(EmployeeRole role) => AppUser(
  id: 'e1',
  name: 'E',
  companyId: 'c1',
  role: 'employee',
  employeeRole: role.id,
  permissions: role.fullPermissions,
);

void main() {
  tearDown(() => AuthSession.set(null));

  test('only the Manager role is a manager', () {
    expect(_employee(EmployeeRole.manager).isManager, isTrue);
    expect(_employee(EmployeeRole.orderPacker).isManager, isFalse);
    expect(_employee(EmployeeRole.orderDelivery).isManager, isFalse);
    // A legacy profile with no permissions saved is never a manager.
    const legacy = AppUser(id: 'l', name: 'L', role: 'employee');
    expect(legacy.isManager, isFalse);
  });

  test('every employee lands on the shared orders pipeline', () {
    for (final role in EmployeeRole.values) {
      expect(employeeHomeFor(_employee(role)), AppRoutes.adminOrders);
    }
  });

  group('admin area guard', () {
    setUp(() {
      AuthSession.hasCompletedInitialBoot = true;
    });

    test('every employee role may open orders and the employee list only', () {
      for (final role in EmployeeRole.values) {
        AuthSession.set(_employee(role));
        expect(appRouteRedirect(AppRoutes.adminOrders), isNull);
        expect(appRouteRedirect('${AppRoutes.adminOrders}/o1'), isNull);
        expect(appRouteRedirect(AppRoutes.adminEmployees), isNull);
        // Adding / editing employees is admin-only.
        expect(
          appRouteRedirect(AppRoutes.adminAddEmployee),
          AppRoutes.adminOrders,
        );
        expect(
          appRouteRedirect(AppRoutes.adminEditEmployeePath('e2')),
          AppRoutes.adminOrders,
        );
        expect(appRouteRedirect(AppRoutes.admin), AppRoutes.adminOrders);
        expect(
          appRouteRedirect(AppRoutes.adminProducts),
          AppRoutes.adminOrders,
        );
      }
    });
  });
}
