import 'package:flutter/material.dart';

import '../../core/domain/employee_roles.dart';
import '../../core/models/app_user.dart';
import '../../core/models/employee.dart';
import '../../core/services/service_locator.dart';

/// Builds with the employee's *current* permissions.
///
/// The session (and its encrypted cache) keeps the permissions the account
/// had at login, so a change the admin makes later - or an account saved
/// before permissions existed - would otherwise show or hide buttons
/// wrongly until the next login. This follows the employee's own profile
/// live and falls back to the session copy until the first snapshot.
class LiveEmployeeAccess extends StatefulWidget {
  final AppUser? user;
  final Widget Function(BuildContext context, EmployeeAccess access) builder;

  const LiveEmployeeAccess({
    super.key,
    required this.user,
    required this.builder,
  });

  @override
  State<LiveEmployeeAccess> createState() => _LiveEmployeeAccessState();
}

class _LiveEmployeeAccessState extends State<LiveEmployeeAccess> {
  Stream<List<Employee>>? _stream;
  String _company = '';

  void _sync() {
    final company = widget.user?.companyId ?? '';
    if (company.isEmpty) {
      _stream = null;
    } else if (company != _company || _stream == null) {
      _stream = repo.employees(company);
    }
    _company = company;
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant LiveEmployeeAccess oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final fallback = user?.access ?? const EmployeeAccess({});
    if (_stream == null || user == null) {
      return widget.builder(context, fallback);
    }
    return StreamBuilder<List<Employee>>(
      stream: _stream,
      builder: (context, snap) {
        final mine = (snap.data ?? const <Employee>[])
            .where((e) => e.id == user.id)
            .firstOrNull;
        return widget.builder(
          context,
          mine == null ? fallback : EmployeeAccess(mine.permissions),
        );
      },
    );
  }
}
