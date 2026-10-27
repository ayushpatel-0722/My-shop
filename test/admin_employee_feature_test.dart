import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/app/theme/app_theme.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/app_user.dart';
import 'package:myshop/core/models/employee.dart';
import 'package:myshop/core/services/auth_session.dart';
import 'package:myshop/core/services/service_locator.dart';
import 'package:myshop/features/admin/employees/admin_add_employee_screen.dart';
import 'package:myshop/features/admin/employees/admin_employees_screen.dart';

void main() {
  late MockAppRepository mockRepo;

  setUp(() {
    mockRepo = MockAppRepository();
    ServiceLocator.instance.repository = mockRepo;
    AuthSession.currentUser = const AppUser(
      id: 'a_1',
      companyId: 'c_organic',
      companyName: 'GreenLeaf Organics',
      name: 'Admin GreenLeaf',
      email: 'admin@greenleaf.in',
      role: 'admin',
    );
  });

  Widget buildTestableWidget(
    Widget child, {
    Size size = const Size(800, 2400),
  }) {
    return MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: child,
      ),
    );
  }

  testWidgets(
    'AdminEmployeesScreen lists employees with salary and permissions',
    (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const AdminEmployeesScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Employees'), findsOneWidget);
      expect(find.text('Ramesh Packer'), findsOneWidget);
      expect(find.text('Picker • packer@greenleaf.in'), findsOneWidget);
      expect(find.text('Active Shift'), findsOneWidget);
      expect(find.text('Pack'), findsOneWidget);
      expect(find.byIcon(Icons.person_add_outlined), findsOneWidget);
    },
  );

  testWidgets(
    'AdminAddEmployeeScreen validates required fields and creates employee',
    (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const AdminAddEmployeeScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Provision Employee'), findsOneWidget);
      expect(find.text('Basic Information'), findsOneWidget);
      expect(find.text('Compensation & Salary'), findsOneWidget);
      expect(find.text('Shift & Work Status'), findsOneWidget);
      expect(find.text('Operational Permissions'), findsOneWidget);

      // Verify company scope pill shows company name
      expect(find.text('GreenLeaf Organics'), findsOneWidget);

      // Attempt save with empty fields
      final saveButton = find.text('Provision Employee Account');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('Full name is required'), findsOneWidget);
      expect(find.text('Email is required'), findsOneWidget);

      // Enter valid details
      final nameField = find.widgetWithText(TextFormField, 'Full Name *');
      final emailField = find.widgetWithText(TextFormField, 'Login Email *');
      final passField = find.widgetWithText(
        TextFormField,
        'Initial Password *',
      );
      final salaryField = find.widgetWithText(
        TextFormField,
        'Salary Amount (₹)',
      );

      await tester.ensureVisible(nameField);
      await tester.enterText(nameField, 'Suresh Manager');

      await tester.ensureVisible(emailField);
      await tester.enterText(emailField, 'suresh@greenleaf.in');

      await tester.ensureVisible(passField);
      await tester.enterText(passField, 'secret123');

      await tester.ensureVisible(salaryField);
      await tester.enterText(salaryField, '35000');

      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Verify employee was created in repository
      final employees = await mockRepo.employees('c_organic').first;
      expect(employees.any((e) => e.email == 'suresh@greenleaf.in'), isTrue);
      final suresh = employees.firstWhere(
        (e) => e.email == 'suresh@greenleaf.in',
      );
      expect(suresh.name, 'Suresh Manager');
      expect(suresh.salary, 35000.0);
      expect(suresh.salaryType, 'monthly');
      expect(suresh.companyId, 'c_organic');
    },
  );

  testWidgets(
    'AdminAddEmployeeScreen pre-fills data in Edit Mode and updates employee',
    (tester) async {
      const existingEmployee = Employee(
        id: 'e_edit_1',
        companyId: 'c_organic',
        name: 'Pooja Dispatcher',
        email: 'pooja@greenleaf.in',
        role: 'Dispatcher',
        salary: 28000,
        salaryType: 'monthly',
        gender: 'female',
        shiftActive: true,
        permissions: {
          'canPack': false,
          'canDispatch': true,
          'canManageInventory': false,
          'canViewReports': false,
        },
      );
      await mockRepo.saveEmployee(existingEmployee);

      await tester.pumpWidget(
        buildTestableWidget(
          const AdminAddEmployeeScreen(employee: existingEmployee),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Employee'), findsOneWidget);
      expect(find.text('Pooja Dispatcher'), findsOneWidget);
      expect(find.text('pooja@greenleaf.in'), findsOneWidget);
      expect(find.text('28000'), findsOneWidget);

      // Initial password field should not be visible in edit mode
      expect(find.text('Initial Password *'), findsNothing);

      // Change salary and save
      final salaryField = find.widgetWithText(
        TextFormField,
        'Salary Amount (₹)',
      );
      await tester.ensureVisible(salaryField);
      await tester.enterText(salaryField, '32000');

      final saveButton = find.text('Save Changes');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      final updated = await mockRepo.employee(
        'e_edit_1',
        companyId: 'c_organic',
      );
      expect(updated?.salary, 32000.0);
    },
  );
}
