import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes/app_router.dart';
import '../../../core/models/delivery_charge.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../core/widgets/modern_card.dart';
import '../../../core/widgets/modern_shimmer.dart';
import '../admin_shell.dart';

/// Pincode → delivery charge mapping, with full-screen CRUD and bulk CSV import.
class AdminDeliveryChargesScreen extends StatefulWidget {
  const AdminDeliveryChargesScreen({super.key});

  @override
  State<AdminDeliveryChargesScreen> createState() =>
      _AdminDeliveryChargesScreenState();
}

class _AdminDeliveryChargesScreenState
    extends State<AdminDeliveryChargesScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _companyId => AuthSession.currentUser?.companyId ?? '';

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      showBack: true,
      backRoute: AppRoutes.admin,
      title: 'Delivery Charges',
      actions: [
        TextButton.icon(
          onPressed: () => _importCsv(context),
          icon: const Icon(Icons.upload_file),
          label: const Text('Import CSV'),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: 'Add Delivery Charge',
          onPressed: () => context.push(AppRoutes.adminAddDelivery),
        ),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                labelText: 'Search pincode',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<DeliveryCharge>>(
              stream: repo.deliveryCharges(companyId: _companyId),
              builder: (context, snap) {
                final list = snap.data ?? const <DeliveryCharge>[];

                if (snap.connectionState == ConnectionState.waiting &&
                    list.isEmpty) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: 5,
                    itemBuilder: (_, _) => const M3ListTileSkeleton(),
                  );
                }

                if (list.isEmpty) {
                  return _EmptyDeliveryCharges(
                    onAdd: () => context.push(AppRoutes.adminAddDelivery),
                  );
                }

                final query = _searchCtrl.text.trim();
                final filtered = query.isEmpty
                    ? list
                    : list.where((c) => c.pincode.contains(query)).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Text('No delivery charges match this pincode'),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final item = filtered[i];
                    return _DeliveryChargeTile(
                      charge: item,
                      onEdit: () => context.push(
                        AppRoutes.adminEditDeliveryPath(item.pincode),
                        extra: item,
                      ),
                      onDelete: () => _confirmDelete(item),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _importCsv(BuildContext context) {
    // CSV format: `pincode,charge` or `pincode,charge,minOrderAmount,freeAboveAmount`
    final csv = '380003,50\n380004,45\n380006,0';
    final charges = csv.split('\n').map((line) {
      final parts = line.split(',');
      final pincode = parts[0].trim();
      final chargeVal = double.tryParse(parts[1].trim()) ?? 0;
      final isFree = chargeVal == 0;
      return DeliveryCharge(
        pincode: pincode,
        companyId: _companyId,
        charge: chargeVal,
        isFree: isFree,
      );
    }).toList();

    repo.importDeliveryCharges(charges);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Imported ${charges.length} pincodes successfully'),
      ),
    );
  }

  Future<void> _confirmDelete(DeliveryCharge charge) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Delivery Charge'),
        content: Text(
          'Are you sure you want to remove delivery mapping for pincode "${charge.pincode}"?',
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

    if (confirmed != true || !mounted) return;

    try {
      await repo.deleteDeliveryCharge(charge.pincode, companyId: _companyId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delivery charge for "${charge.pincode}" deleted.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete delivery charge: $e')),
      );
    }
  }
}

class _DeliveryChargeTile extends StatelessWidget {
  final DeliveryCharge charge;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DeliveryChargeTile({
    required this.charge,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (context.isMobile) {
      return _buildMobileCard(context);
    }
    return _buildDesktopCard(context);
  }

  Widget _buildMobileCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ModernCard(
      key: Key('delivery-tile-${charge.pincode}'),
      padding: const EdgeInsets.all(12),
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.pin_drop,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Pincode: ${charge.pincode}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: charge.isServiceable
                                ? Colors.green.withValues(alpha: 0.12)
                                : Colors.red.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            charge.isServiceable ? 'Serviceable' : 'Suspended',
                            style: TextStyle(
                              color: charge.isServiceable
                                  ? Colors.green
                                  : Colors.redAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (charge.isFree || charge.charge == 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'FREE DELIVERY',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          )
                        else
                          Text(
                            formatCurrency(charge.charge),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (charge.freeAboveAmount > 0 ||
              charge.minOrderAmount > 0 ||
              charge.estimatedDays.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (charge.freeAboveAmount > 0 && !charge.isFree)
                  _detailPill(
                    context,
                    Icons.card_giftcard,
                    'Free on > ${formatCurrency(charge.freeAboveAmount)}',
                    isDark,
                  ),
                if (charge.minOrderAmount > 0)
                  _detailPill(
                    context,
                    Icons.shopping_bag_outlined,
                    'Min: ${formatCurrency(charge.minOrderAmount)}',
                    isDark,
                  ),
                if (charge.estimatedDays.isNotEmpty)
                  _detailPill(
                    context,
                    Icons.timer_outlined,
                    charge.estimatedDays,
                    isDark,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Divider(
            height: 1,
            thickness: 0.5,
            color: theme.dividerColor.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 20,
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit Delivery Charge',
                onPressed: onEdit,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 20,
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                tooltip: 'Delete Delivery Charge',
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopCard(BuildContext context) {
    final theme = Theme.of(context);

    return ModernCard(
      key: Key('delivery-tile-${charge.pincode}'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: onEdit,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.pin_drop,
              color: theme.colorScheme.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Pincode: ${charge.pincode}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: charge.isServiceable
                            ? Colors.green.withValues(alpha: 0.12)
                            : Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        charge.isServiceable ? 'Serviceable' : 'Suspended',
                        style: TextStyle(
                          color: charge.isServiceable
                              ? Colors.green
                              : Colors.redAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (charge.isFree || charge.charge == 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'FREE DELIVERY',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      )
                    else
                      Text(
                        'Charge: ${formatCurrency(charge.charge)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (charge.freeAboveAmount > 0 && !charge.isFree)
                      Text(
                        '• Free on > ${formatCurrency(charge.freeAboveAmount)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    if (charge.minOrderAmount > 0)
                      Text(
                        '• Min order: ${formatCurrency(charge.minOrderAmount)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    if (charge.estimatedDays.isNotEmpty)
                      Text(
                        '• ETA: ${charge.estimatedDays}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: 'Edit Delivery Charge',
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              size: 20,
              color: Colors.redAccent,
            ),
            tooltip: 'Delete Delivery Charge',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  Widget _detailPill(
    BuildContext context,
    IconData icon,
    String label,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _EmptyDeliveryCharges extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyDeliveryCharges({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.local_shipping_outlined,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No delivery pincodes configured',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add pincodes to define delivery fees, free delivery rules, or minimum order limits.',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Delivery Charge'),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}
