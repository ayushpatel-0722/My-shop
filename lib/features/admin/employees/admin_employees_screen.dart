import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes/app_router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/employee.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/modern_card.dart';
import '../admin_shell.dart';

/// Employee management screen — list staff, view status & permissions, navigate to add/edit.
class AdminEmployeesScreen extends StatelessWidget {
  const AdminEmployeesScreen({super.key});

  Future<void> _confirmDelete(BuildContext context, Employee emp) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Employee Account'),
        content: Text(
          'Are you sure you want to remove "${emp.name}" (${emp.email}) from the company?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await repo.deleteEmployee(emp.companyId, emp.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Employee "${emp.name}" deleted.'),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete employee: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final companyId = AuthSession.currentUser?.companyId ?? '';

    return AdminShell(
      title: 'Employees',
      actions: [
        IconButton(
          icon: const Icon(Icons.person_add_outlined),
          tooltip: 'Provision Employee',
          onPressed: () => context.push(AppRoutes.adminAddEmployee),
        ),
      ],
      child: StreamBuilder<List<Employee>>(
        stream: repo.employees(companyId),
        builder: (context, snap) {
          final list = snap.data ?? const <Employee>[];
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.badge_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No employees provisioned',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Provision staff accounts with custom designations, salary, and operational access.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Provision Employee'),
                    onPressed: () => context.push(AppRoutes.adminAddEmployee),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final e = list[i];
              return ModernCard(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => context.push(
                      AppRoutes.adminEditEmployeePath(e.id),
                      extra: e,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                                foregroundColor: theme.colorScheme.primary,
                                child: Text(
                                  e.name.isNotEmpty ? e.name[0].toUpperCase() : 'E',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            e.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Shift Active status badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: e.shiftActive
                                                ? Colors.green.withValues(alpha: 0.15)
                                                : Colors.grey.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            e.shiftActive ? 'Active Shift' : 'Off Shift',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: e.shiftActive ? Colors.green.shade700 : Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${e.role} • ${e.email}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                tooltip: 'Edit Employee',
                                onPressed: () => context.push(
                                  AppRoutes.adminEditEmployeePath(e.id),
                                  extra: e,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                tooltip: 'Delete Employee',
                                onPressed: () => _confirmDelete(context, e),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 10),

                          // Salary & Permissions details row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Salary badge
                              if (e.salary > 0)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.currency_rupee, size: 14, color: theme.colorScheme.primary),
                                    Text(
                                      '${formatCurrency(e.salary)} / ${e.salaryType}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Text(
                                  'Salary: Not specified',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                                  ),
                                ),

                              // Permissions Chips
                              Wrap(
                                spacing: 4,
                                children: [
                                  if (e.permissions['canPack'] == true)
                                    _permissionChip('Pack', Colors.blue),
                                  if (e.permissions['canDispatch'] == true)
                                    _permissionChip('Dispatch', Colors.orange),
                                  if (e.permissions['canManageInventory'] == true)
                                    _permissionChip('Inventory', Colors.purple),
                                  if (e.permissions['canViewReports'] == true)
                                    _permissionChip('Reports', Colors.teal),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _permissionChip(String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color.shade700,
        ),
      ),
    );
  }
}
