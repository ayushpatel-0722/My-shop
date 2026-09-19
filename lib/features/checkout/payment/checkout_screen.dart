import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../../../core/domain/order_pricing.dart';
import '../../../core/domain/voucher_evaluator.dart';
import '../../../core/models/cart_item.dart';
import '../../../core/models/order.dart';
import '../../../core/models/voucher.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/auth_cubit.dart';
import '../cart/cart_cubit.dart';

/// Checkout with per-store vouchers, pincode based delivery charges and a
/// single itemised bill (Sections 9 & 10).
///
/// What was broken before, and how it is fixed:
///  * the voucher was always validated against the hard-coded store
///    `c_organic` — now each store group validates its own code;
///  * only the **first** store in a multi-store cart was ordered and the rest
///    was silently dropped — now one order is placed per store;
///  * the persisted `totalAmount` ignored the discount **and** the delivery
///    fee, so customers were charged a different amount than the receipt —
///    now [OrderPricer] produces the bill and the order stores every line of
///    it (`subtotal`, `discountAmount`, `deliveryCharge`, `totalAmount`);
///  * voucher rules (min order, scope, per-user cap, global cap, first order
///    only, expiry) were never checked — now [VoucherEvaluator] decides and
///    explains the rejection.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _addressCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();

  /// Voucher code typed per store.
  final Map<String, TextEditingController> _voucherCtrls =
      <String, TextEditingController>{};

  /// Accepted voucher per store.
  final Map<String, Voucher?> _applied = <String, Voucher?>{};

  /// Why a code was rejected (per store), shown under the field.
  final Map<String, String> _voucherError = <String, String>{};

  /// Pincode fee per store.
  final Map<String, double> _deliveryCharges = <String, double>{};

  String _deliveryType = DeliveryType.homeDelivery;
  bool _placing = false;
  int _previousOrderCount = 0;

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
    }
    if (_pincodeCtrl.text.isNotEmpty) {
      _lookupDelivery(_companiesOf(context.read<CartCubit>().state));
    }
    _loadOrderHistory(user?.id ?? '');
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _pincodeCtrl.dispose();
    for (final c in _voucherCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _companiesOf(CartState? state) => state?.byCompany.keys.toList() ?? const <String>[];

  Future<void> _loadOrderHistory(String userId) async {
    if (userId.isEmpty) return;
    final previous = await repo.orders(userId: userId).first;
    if (!mounted) return;
    setState(() => _previousOrderCount = previous.length);
  }

  Future<void> _lookupDelivery(List<String> companyIds) async {
    final pincode = _pincodeCtrl.text.trim();
    final charges = <String, double>{};
    for (final companyId in companyIds) {
      final charge = await repo.deliveryCharge(pincode, companyId);
      charges[companyId] = charge?.charge ?? 0;
    }
    if (!mounted) return;
    setState(() => _deliveryCharges.addAll(charges));
  }

  Future<void> _applyVoucher(
    String companyId,
    List<CartItem> items,
  ) async {
    final controller = _voucherCtrls[companyId];
    final code = controller?.text.trim() ?? '';
    final l10n = AppLocalizations.of(context);

    if (code.isEmpty) {
      setState(() {
        _applied[companyId] = null;
        _voucherError[companyId] = 'Enter a voucher code.';
      });
      return;
    }

    final voucher = await repo.voucherByCode(companyId, code);
    final evaluation = const VoucherEvaluator().evaluate(
      voucher: voucher,
      items: items,
      context: VoucherContext(
        now: DateTime.now(),
        userId: context.read<AuthCubit>().currentUser?.id ?? '',
        previousOrderCount: _previousOrderCount,
      ),
      deliveryCharge: _deliveryCharges[companyId] ?? 0,
    );

    if (!mounted) return;

    if (!evaluation.isAccepted) {
      setState(() {
        _applied[companyId] = null;
        _voucherError[companyId] =
            voucher == null ? l10n.invalidCode : evaluation.message;
      });
      return;
    }

    setState(() {
      _applied[companyId] = voucher;
      _voucherError.remove(companyId);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.voucherApplied)),
    );
  }

  void _removeVoucher(String companyId) {
    setState(() {
      _applied[companyId] = null;
      _voucherCtrls[companyId]?.clear();
    });
  }

  /// Builds one bill per store from the current cart + state.
  Map<String, OrderBill> _bills(CartState state) {
    final bills = <String, OrderBill>{};
    for (final entry in state.byCompany.entries) {
      final items = entry.value;
      bills[entry.key] = const OrderPricer().price(
        companyId: entry.key,
        companyName: items.isNotEmpty ? items.first.companyName : '',
        items: items,
        voucher: _applied[entry.key],
        deliveryCharge: _deliveryCharges[entry.key] ?? 0,
        deliveryRequired: _deliveryType == DeliveryType.homeDelivery,
        context: VoucherContext(
          now: DateTime.now(),
          userId: context.read<AuthCubit>().currentUser?.id ?? '',
          previousOrderCount: _previousOrderCount,
        ),
      );
    }
    return bills;
  }

  Future<void> _placeOrder(CartState state) async {
    final l10n = AppLocalizations.of(context);

    if (state.items.isEmpty) return;

    final address = _addressCtrl.text.trim();
    final pincode = _pincodeCtrl.text.trim();

    if (address.isEmpty) {
      _snack('Please enter a delivery address.');
      return;
    }
    if (!RegExp(r'^\d{4,8}$').hasMatch(pincode)) {
      _snack('Please enter a valid pincode.');
      return;
    }

    // Critical write: refuse to continue when the device is offline.
    if (!await connectivity.isOnline()) {
      if (!mounted) return;
      _snack(l10n.noInternet);
      return;
    }

    setState(() => _placing = true);

    try {
      final user = context.read<AuthCubit>().currentUser;
      final bills = _bills(state);
      final placed = <Order>[];

      for (final entry in state.byCompany.entries) {
        final bill = bills[entry.key];
        if (bill == null) continue;

        final order = Order(
          id: '',
          userId: user?.id ?? 'guest',
          companyId: entry.key,
          companyName: bill.companyName,
          items: bill.lines
              .map(
                (line) => OrderItem(
                  productId: line.productId,
                  qty: line.qty,
                  unitPrice: line.unitPrice,
                  name: line.name,
                  image: line.image,
                ),
              )
              .toList(),
          subtotal: bill.subtotal,
          discountAmount: bill.discount,
          deliveryCharge: bill.deliveryCharge,
          totalAmount: bill.total,
          address: address,
          pincode: pincode,
          voucherId: bill.voucher?.id,
          voucherCode: bill.voucher?.code ?? '',
          deliveryType: _deliveryType,
        );
        placed.add(await repo.placeOrder(order));
      }

      if (!mounted) return;
      context.read<CartCubit>().clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.orderPlaced)),
      );
      if (placed.length == 1) {
        context.go(AppRoutes.orderPath(placed.first.id));
      } else {
        context.go(AppRoutes.orders);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _placing = false);
      _snack('Could not place the order: $e');
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.checkout)),
      body: BlocBuilder<CartCubit, CartState>(
        builder: (context, cartState) {
          if (cartState.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shopping_cart_outlined, size: 56),
                  const SizedBox(height: 12),
                  const Text('Your cart is empty'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.go(AppRoutes.home),
                    child: Text(l10n.home),
                  ),
                ],
              ),
            );
          }

          final companies = _companiesOf(cartState);
          for (final companyId in companies) {
            _voucherCtrls.putIfAbsent(companyId, TextEditingController.new);
          }
          final bills = _bills(cartState);

          final subtotal =
              bills.values.fold<double>(0, (sum, b) => sum + b.subtotal);
          final discount =
              bills.values.fold<double>(0, (sum, b) => sum + b.discount);
          final delivery = bills.values.fold<double>(
            0,
            (sum, b) => sum + b.deliveryCharge,
          );
          final total = bills.values.fold<double>(0, (sum, b) => sum + b.total);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                key: const Key('checkout-address-field'),
                controller: _addressCtrl,
                decoration: InputDecoration(labelText: l10n.address),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('checkout-pincode-field'),
                controller: _pincodeCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Pincode',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: 'Check delivery',
                    onPressed: () => _lookupDelivery(companies),
                  ),
                ),
                onChanged: (value) {
                  if (value.trim().length >= 4) {
                    _lookupDelivery(companies);
                  }
                },
              ),
              const SizedBox(height: 16),
              Text(
                l10n.deliveryCharge,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: DeliveryType.homeDelivery,
                    label: Text('Home delivery'),
                  ),
                  ButtonSegment(
                    value: DeliveryType.selfPickup,
                    label: Text('Self pickup'),
                  ),
                ],
                selected: {_deliveryType},
                onSelectionChanged: (s) =>
                    setState(() => _deliveryType = s.first),
              ),
              const SizedBox(height: 16),
              for (final companyId in companies) ...[
                _StoreCheckoutCard(
                  key: Key('checkout-store-card-$companyId'),
                  companyId: companyId,
                  items: cartState.byCompany[companyId] ?? const <CartItem>[],
                  bill: bills[companyId],
                  voucherCtrl: _voucherCtrls[companyId]!,
                  voucherError: _voucherError[companyId],
                  onApply: () => _applyVoucher(
                    companyId,
                    cartState.byCompany[companyId] ?? const <CartItem>[],
                  ),
                  onRemove: () => _removeVoucher(companyId),
                  applyLabel: l10n.applyVoucher,
                ),
                const SizedBox(height: 12),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      _summaryRow(l10n.subtotal, formatCurrency(subtotal)),
                      if (discount > 0)
                        _summaryRow(
                          l10n.discount,
                          '− ${formatCurrency(discount)}',
                          color: Colors.green.shade700,
                        ),
                      _summaryRow(
                        l10n.deliveryCharge,
                        formatCurrency(delivery),
                      ),
                      const Divider(height: 20),
                      _summaryRow(
                        l10n.totalAmount,
                        formatCurrency(total),
                        bold: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('checkout-place-order-button'),
                onPressed: _placing ? null : () => _placeOrder(cartState),
                child: _placing
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('${l10n.checkout} · ${formatCurrency(total)}'),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool bold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
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
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// One store's items, voucher box and bill.
class _StoreCheckoutCard extends StatelessWidget {
  final String companyId;
  final List<CartItem> items;
  final OrderBill? bill;
  final TextEditingController voucherCtrl;
  final String? voucherError;
  final VoidCallback onApply;
  final VoidCallback onRemove;
  final String applyLabel;

  const _StoreCheckoutCard({
    super.key,
    required this.companyId,
    required this.items,
    required this.bill,
    required this.voucherCtrl,
    required this.onApply,
    required this.onRemove,
    required this.applyLabel,
    this.voucherError,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedBill = bill;
    final storeName =
        items.isNotEmpty && items.first.companyName.isNotEmpty
            ? items.first.companyName
            : 'Store';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storefront, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    storeName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item.product.name} × ${item.qty}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      formatCurrency(item.lineTotal),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: Key('checkout-voucher-field-$companyId'),
                    controller: voucherCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: applyLabel,
                      isDense: true,
                      border: const OutlineInputBorder(),
                      errorText: voucherError,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  key: Key('checkout-apply-$companyId'),
                  onPressed: onApply,
                  child: const Text('Apply'),
                ),
              ],
            ),
            if (resolvedBill?.voucher != null) ...[
              const SizedBox(height: 8),
              Chip(
                avatar: const Icon(Icons.local_offer, size: 16),
                label: Text(
                  '${resolvedBill!.voucher!.normalizedCode} · '
                  '− ${formatCurrency(resolvedBill.discount)}',
                ),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: onRemove,
                backgroundColor: Colors.green.withValues(alpha: 0.12),
              ),
            ],
            if (resolvedBill != null) ...[
              const SizedBox(height: 10),
              _row('Items', formatCurrency(resolvedBill.subtotal)),
              if (resolvedBill.discount > 0)
                _row(
                  'Discount',
                  '− ${formatCurrency(resolvedBill.discount)}',
                  color: Colors.green.shade700,
                ),
              _row('Delivery', formatCurrency(resolvedBill.deliveryCharge)),
              const Divider(height: 14),
              _row(
                'Store total',
                formatCurrency(resolvedBill.total),
                bold: true,
                color: theme.colorScheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    bool bold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
