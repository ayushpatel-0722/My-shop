import '../../../app/routes/app_router.dart';
import 'package:flutter/material.dart';

import '../../../core/models/delivery_charge.dart';
import '../../../core/services/service_locator.dart';
import '../admin_shell.dart';

/// Pincode → flat-rate delivery mapping (Section 10), with CSV bulk import and
/// per-pincode CRUD.
class AdminDeliveryChargesScreen extends StatelessWidget {
  const AdminDeliveryChargesScreen({super.key});

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
          onPressed: () => _showAddSheet(context),
        ),
      ],
      child: StreamBuilder<List<DeliveryCharge>>(
        stream: repo.deliveryCharges(),
        builder: (context, snap) {
          final list = snap.data ?? const <DeliveryCharge>[];
          if (list.isEmpty) {
            return const Center(child: Text('No pincodes configured'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final c = list[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.pin_drop),
                  title: Text(c.pincode),
                  trailing: Text('₹${c.charge}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _importCsv(BuildContext context) {
    // CSV format: `pincode,charge` (one per line).
    final csv = '380003,50\n380004,45\n380006,35';
    final charges = csv.split('\n').map((line) {
      final parts = line.split(',');
      return DeliveryCharge(
        pincode: parts[0].trim(),
        charge: double.tryParse(parts[1].trim()) ?? 0,
      );
    }).toList();
    repo.importDeliveryCharges(charges);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Imported ${charges.length} pincodes')),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddPincodeSheet(),
    );
  }
}

class _AddPincodeSheet extends StatefulWidget {
  const _AddPincodeSheet();

  @override
  State<_AddPincodeSheet> createState() => _AddPincodeSheetState();
}

class _AddPincodeSheetState extends State<_AddPincodeSheet> {
  final _pincodeCtrl = TextEditingController();
  final _chargeCtrl = TextEditingController();

  @override
  void dispose() {
    _pincodeCtrl.dispose();
    _chargeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
              controller: _pincodeCtrl,
              decoration: const InputDecoration(labelText: 'Pincode')),
          const SizedBox(height: 12),
          TextField(
              controller: _chargeCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Charge (₹)')),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              repo.saveDeliveryCharge(DeliveryCharge(
                pincode: _pincodeCtrl.text.trim(),
                charge: double.tryParse(_chargeCtrl.text) ?? 0,
              ));
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
