import 'package:flutter/material.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../core/domain/employee_roles.dart';

extension EmployeeRoleLabels on EmployeeRole {
  String label(AppLocalizations l10n) => switch (this) {
    EmployeeRole.manager => l10n.employeeRoleManager,
    EmployeeRole.orderPacker => l10n.employeeRoleOrderPacker,
    EmployeeRole.orderDelivery => l10n.employeeRoleOrderDelivery,
  };

  String description(AppLocalizations l10n) => switch (this) {
    EmployeeRole.manager => l10n.employeeRoleManagerDesc,
    EmployeeRole.orderPacker => l10n.employeeRoleOrderPackerDesc,
    EmployeeRole.orderDelivery => l10n.employeeRoleOrderDeliveryDesc,
  };

  MaterialColor get color => switch (this) {
    EmployeeRole.manager => Colors.purple,
    EmployeeRole.orderPacker => Colors.blue,
    EmployeeRole.orderDelivery => Colors.orange,
  };
}
