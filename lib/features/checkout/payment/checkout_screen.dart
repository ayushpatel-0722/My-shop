import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../../../core/models/order.dart';
import '../../../core/models/voucher.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/auth_cubit.dart';
import '../cart/cart_cubit.dart';

/// Checkout with per-company voucher validation and pincode-based delivery
/// charge (Sections 9 & 10).
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _pincodeCtrl = TextEditingController(text: '380001');
  final _voucherCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String _deliveryType = 'home_delivery';
  Voucher? _appliedVoucher;
  double _deliveryCharge = 0;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthCubit>().currentUser;
    final defaultAddr = user?.defaultAddress;
    if (defaultAddr != null) {
      _addressCtrl.text = defaultAddr.formattedAddress;
      if (defaultAddr.pincode.isNotEmpty) {
        _pincodeCtrl.text = defaultAddr.pincode;
      }
    } else {
      _addressCtrl.text = '12 Market Street';
    }
  }

  @override
  void dispose() {
    _pincodeCtrl.dispose();
    _voucherCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookupDelivery() async {
    final charge = await repo.deliveryCharge(_pincodeCtrl.text.trim(), '');
    if (mounted) {
      setState(() => _deliveryCharge = charge?.charge ?? 0);
    }
  }

  Future<void> _applyVoucher(String companyId) async {
    final v = await repo.voucherByCode(companyId, _voucherCtrl.text.trim());
    if (!mounted) return;
    if (v == null || v.isExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).invalidCode)),
      );
      return;
    }
    setState(() => _appliedVoucher = v);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).voucherApplied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.checkout)),
      body: BlocBuilder<CartCubit, CartState>(
        builder: (context, cartState) {
          final subtotal = cartState.totalAmount;
          final discount = _appliedVoucher?.computeDiscount(subtotal) ?? 0.0;
          final total =
              subtotal -
              discount +
              (_deliveryType == 'home_delivery' ? _deliveryCharge : 0);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _field(l10n.address, _addressCtrl),
              const SizedBox(height: 12),
              _field(
                'Pincode',
                _pincodeCtrl,
                suffix: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _lookupDelivery,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.deliveryCharge,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'home_delivery', label: Text('Home')),
                  ButtonSegment(value: 'self_pickup', label: Text('Pickup')),
                ],
                selected: {_deliveryType},
                onSelectionChanged: (s) =>
                    setState(() => _deliveryType = s.first),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _field(l10n.applyVoucher, _voucherCtrl)),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: () => _applyVoucher('c_organic'),
                    child: const Text('Apply'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _summaryRow(l10n.subtotal, subtotal),
              _summaryRow(
                l10n.deliveryCharge,
                _deliveryType == 'home_delivery' ? _deliveryCharge : 0,
              ),
              _summaryRow(l10n.discount, discount),
              const Divider(height: 24),
              _summaryRow(l10n.totalAmount, total, bold: true),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => _placeOrder(cartState),
                child: Text('${l10n.checkout} · ${formatCurrency(total)}'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {Widget? suffix}) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(labelText: label, suffixIcon: suffix),
    );
  }

  Widget _summaryRow(String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            formatCurrency(value),
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _placeOrder(CartState cartState) async {
    // Connectivity gate on the critical write (Section 20).
    if (!await connectivity.isOnline()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).noInternet)),
      );
      return;
    }
    if (!mounted) return;
    final user = context.read<AuthCubit>().currentUser;
    if (cartState.items.isEmpty) return;
    final group = cartState.byCompany.entries.first;
    final items = group.value
        .map(
          (e) => OrderItem(
            productId: e.product.id,
            qty: e.qty,
            unitPrice: e.product.price,
            name: e.product.name,
          ),
        )
        .toList();
    final order = Order(
      id: '',
      userId: user?.id ?? 'guest',
      companyId: group.key,
      companyName: group.value.first.companyName,
      items: items,
      totalAmount: items.fold(0.0, (s, e) => s + e.itemTotal),
      address: _addressCtrl.text,
      pincode: _pincodeCtrl.text.trim(),
      voucherId: _appliedVoucher?.id,
      deliveryType: _deliveryType,
    );
    final placed = await repo.placeOrder(order);
    if (!mounted) return;
    context.read<CartCubit>().clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).orderPlaced)),
    );
    context.go(AppRoutes.orderPath(placed.id));
  }
}
