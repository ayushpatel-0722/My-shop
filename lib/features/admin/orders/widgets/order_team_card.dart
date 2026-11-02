import 'package:flutter/material.dart';
import 'package:myshop/core/widgets/app_toast.dart';

import '../../../../core/domain/employee_roles.dart';
import '../../../../core/models/employee.dart';
import '../../../../core/models/order.dart';
import '../../../../core/services/service_locator.dart';

/// Admin view of who is handling an order: assign it to a packer and see
/// whether the packer has finished.
///
/// Assignment only matters while the order is being packed; from `ready`
/// onwards dispatchers share it. Moving `packing -> ready` stays the admin's
/// own decision (the quality gate), so this card shows the packer's "packing
/// done" flag as a hint rather than forcing the move.
class OrderTeamCard extends StatefulWidget {
  final Order order;
  final String companyId;

  const OrderTeamCard({
    super.key,
    required this.order,
    required this.companyId,
  });

  @override
  State<OrderTeamCard> createState() => _OrderTeamCardState();
}

class _OrderTeamCardState extends State<OrderTeamCard> {
  bool _saving = false;

  bool get _assignable =>
      widget.order.orderStatus == OrderStatus.pending ||
      widget.order.orderStatus == OrderStatus.confirmed ||
      widget.order.orderStatus == OrderStatus.packing;

  Future<void> _assign(String employeeId) async {
    setState(() => _saving = true);
    try {
      await repo.assignEmployee(
        widget.order.id,
        employeeId,
        companyId: widget.order.companyId.isNotEmpty
            ? widget.order.companyId
            : widget.companyId,
      );
    } catch (e) {
      if (mounted) AppToast.error(context, 'Could not assign the order: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final order = widget.order;
    final companyId = order.companyId.isNotEmpty
        ? order.companyId
        : widget.companyId;

    return Card(
      key: const Key('order-team-card'),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<List<Employee>>(
          stream: repo.employees(companyId),
          builder: (context, snap) {
            final staff = snap.data ?? const <Employee>[];
            final packers = staff
                .where((e) => EmployeeAccess(e.permissions).canPack)
                .toList();
            final assigned = order.assignedEmployeeId ?? '';
            final assignedName = staff
                .where((e) => e.id == assigned)
                .map((e) => e.name)
                .firstOrNull;
            final value = packers.any((e) => e.id == assigned) ? assigned : '';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.groups_outlined, color: Colors.indigo.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'Fulfilment team',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_assignable)
                  DropdownButtonFormField<String>(
                    key: const Key('order-assign-packer'),
                    initialValue: value,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Assigned packer',
                      helperText:
                          'Unassigned orders can be packed by any packer.',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Unassigned (any packer)'),
                      ),
                      for (final e in packers)
                        DropdownMenuItem(
                          value: e.id,
                          child: Text('${e.name} · ${e.role}'),
                        ),
                    ],
                    onChanged: _saving ? null : (v) => _assign(v ?? ''),
                  )
                else
                  Text(
                    assigned.isEmpty
                        ? 'Packer: not assigned'
                        : 'Packer: ${assignedName ?? assigned}',
                    key: const Key('order-assigned-readonly'),
                  ),
                const SizedBox(height: 12),
                _PackingStatusChip(order: order),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PackingStatusChip extends StatelessWidget {
  final Order order;
  const _PackingStatusChip({required this.order});

  @override
  Widget build(BuildContext context) {
    final String? text;
    final Color color;
    if (order.orderStatus == OrderStatus.packing && order.employeePackingDone) {
      text = 'Packing done — ready for you to move this order to Ready';
      color = Colors.green.shade800;
    } else if (order.orderStatus == OrderStatus.packing) {
      text = 'Packing in progress';
      color = Colors.orange.shade800;
    } else if (order.orderStatus == OrderStatus.confirmed) {
      text = 'Waiting for a packer to start';
      color = Colors.blueGrey.shade700;
    } else {
      text = null;
      color = Colors.grey;
    }
    if (text == null) return const SizedBox.shrink();
    return Container(
      key: const Key('order-packing-chip'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12.5,
        ),
      ),
    );
  }
}
