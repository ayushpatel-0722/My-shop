import '../../../app/routes/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/company.dart';
import '../../../core/models/voucher.dart';
import '../../../core/services/service_locator.dart';
import '../../auth/auth_cubit.dart';
import '../admin_shell.dart';

/// Voucher engine — create per-company codes (Section 9).
class AdminVouchersScreen extends StatelessWidget {
  const AdminVouchersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      showBack: true,
      backRoute: AppRoutes.admin,
      title: 'Vouchers',
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => _showCreateSheet(context),
        ),
      ],
      child: StreamBuilder<List<Voucher>>(
        stream: repo.vouchers(''),
        builder: (context, snap) {
          final list = snap.data ?? const <Voucher>[];
          if (list.isEmpty) {
            return const Center(child: Text('No vouchers'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, i) => _voucherTile(list[i]),
          );
        },
      ),
    );
  }

  Widget _voucherTile(Voucher v) {
    final label = v.discountType == 'percentage'
        ? '${v.discountValue}% OFF'
        : v.discountType == 'fixed_amount'
        ? '₹${v.discountValue} OFF'
        : 'Free Shipping';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.local_offer),
        title: Text(
          v.code,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '$label · min ₹${v.minOrderAmt} · expires ${v.expiryDate?.toLocal().toString().split(' ').first ?? '—'}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            v.isExpired
                ? const Chip(label: Text('Expired'))
                : const Chip(label: Text('Active')),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => repo.deleteVoucher(v.id),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateVoucherSheet(),
    );
  }
}

class _CreateVoucherSheet extends StatefulWidget {
  const _CreateVoucherSheet();

  @override
  State<_CreateVoucherSheet> createState() => _CreateVoucherSheetState();
}

class _CreateVoucherSheetState extends State<_CreateVoucherSheet> {
  final _codeCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  final _minCtrl = TextEditingController();
  String _type = 'percentage';
  String _appliesTo = 'all_categories';

  @override
  void dispose() {
    _codeCtrl.dispose();
    _valueCtrl.dispose();
    _minCtrl.dispose();
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Create Voucher',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _codeCtrl,
              decoration: const InputDecoration(labelText: 'Code'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _valueCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Value'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _minCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Min order amount'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Discount type'),
              items: const [
                DropdownMenuItem(
                  value: 'percentage',
                  child: Text('Percentage'),
                ),
                DropdownMenuItem(
                  value: 'fixed_amount',
                  child: Text('Fixed amount'),
                ),
                DropdownMenuItem(
                  value: 'free_shipping',
                  child: Text('Free shipping'),
                ),
              ],
              onChanged: (v) => setState(() => _type = v ?? 'percentage'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _appliesTo,
              decoration: const InputDecoration(labelText: 'Applies to'),
              items: const [
                DropdownMenuItem(
                  value: 'all_categories',
                  child: Text('All categories'),
                ),
                DropdownMenuItem(
                  value: 'specific_category',
                  child: Text('Specific category'),
                ),
                DropdownMenuItem(
                  value: 'specific_product',
                  child: Text('Specific product'),
                ),
              ],
              onChanged: (v) =>
                  setState(() => _appliesTo = v ?? 'all_categories'),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final companyId = context.read<AuthCubit>().currentUser?.companyId ?? '';
    final voucher = Voucher(
      id: '',
      companyId: companyId,
      code: _codeCtrl.text.trim().toUpperCase(),
      discountType: _type,
      discountValue: double.tryParse(_valueCtrl.text) ?? 0,
      appliesTo: _appliesTo,
      minOrderAmt: double.tryParse(_minCtrl.text) ?? 0,
      expiryDate: DateTime.now().add(const Duration(days: 30)),
    );
    await repo.saveVoucher(Company(id: companyId, name: '', slug: ''), voucher);
    if (!mounted) return;
    Navigator.pop(context);
  }
}
