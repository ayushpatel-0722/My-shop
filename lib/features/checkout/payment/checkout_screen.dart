import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../../../core/domain/order_pricing.dart';
import '../../../core/domain/voucher_evaluator.dart';
import '../../../core/models/cart_item.dart';
import '../../../core/models/company.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/order.dart';
import '../../../core/models/voucher.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/services/email_service.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/auth_cubit.dart';
import '../cart/cart_cubit.dart';
import 'widgets/address_selector.dart';
import 'widgets/customer_details_card.dart';
import 'widgets/delivery_widgets.dart';

/// "Place Order" screen — used both for the cart checkout and for a direct
/// "Buy Now" order ([directItems]).
///
/// What it guarantees:
///  * one order document PER SHOP (shop-wise bills and delivery types);
///  * customer details are read-only snapshots from the user's profile;
///  * delivery address comes from the saved addresses (max 3) and is only
///    required when at least one shop uses Home Delivery;
///  * a shop that does not allow home delivery auto-selects Self Pickup and
///    shows a "Pickup From" card instead of an address;
///  * prices/stock are re-validated against the catalogue before the order
///    is written (price changes update the cart, short stock reduces the
///    quantity, deleted variants are excluded as "Unavailable");
///  * every order stores a variant snapshot per item.
class CheckoutScreen extends StatefulWidget {
  final List<CartItem>? directItems;
  const CheckoutScreen({super.key, this.directItems});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  /// Voucher code typed per store.
  final Map<String, TextEditingController> _voucherCtrls =
      <String, TextEditingController>{};

  /// Accepted voucher per store.
  final Map<String, Voucher?> _applied = <String, Voucher?>{};

  /// Why a code was rejected (per store), shown under the field.
  final Map<String, String> _voucherError = <String, String>{};

  /// Pincode fee per store.
  final Map<String, double> _deliveryCharges = <String, double>{};

  /// Delivery type per store.
  final Map<String, String> _deliveryTypes = <String, String>{};

  /// Shop documents, keyed by company id.
  final Map<String, Company> _companies = <String, Company>{};

  List<AddressEntry> _addresses = const [];
  String? _selectedAddressId;

  /// Cart lines that failed re-validation (deleted product/variant).
  final Set<String> _unavailable = <String>{};

  /// Local, mutable copy for direct ("Buy Now") orders.
  List<CartItem>? _directItems;

  bool _placing = false;
  bool _loading = true;
  int _previousOrderCount = 0;

  bool get _isDirectBuy =>
      widget.directItems != null && widget.directItems!.isNotEmpty;

  AuthCubit get _auth => context.read<AuthCubit>();

  AppUserSnapshot get _profile {
    final user = _auth.currentUser ?? AuthSession.currentUser;
    return AppUserSnapshot(
      id: user?.id ?? 'guest',
      name: user?.name ?? '',
      email: user?.email ?? '',
      mobile: (user?.phone.isNotEmpty ?? false)
          ? user!.phone
          : (user?.mobileNumber ?? ''),
    );
  }

  @override
  void initState() {
    super.initState();
    if (_isDirectBuy) {
      _directItems = List<CartItem>.from(widget.directItems!);
    }
    _loadAddresses();
    _bootstrap();
  }

  @override
  void dispose() {
    for (final c in _voucherCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final initialItems = _effectiveItems(
      _isDirectBuy
          ? CartState(items: widget.directItems!)
          : (mounted ? context.read<CartCubit>().state : const CartState()),
    );
    await _loadCompanies(initialItems);
    await _revalidate(initialItems);
    final user = _auth.currentUser ?? AuthSession.currentUser;
    _loadOrderHistory(user?.id ?? '');
    if (mounted) setState(() => _loading = false);
  }

  void _loadAddresses() {
    final user = _auth.currentUser ?? AuthSession.currentUser;
    final addresses = List<AddressEntry>.from(user?.addresses ?? const []);
    final defaultAddr = addresses.firstWhereOrNull((a) => a.isDefault);
    setState(() {
      _addresses = addresses;
      _selectedAddressId = (defaultAddr ?? addresses.firstOrNull)?.id;
    });
  }

  List<CartItem> _effectiveItems(CartState state) {
    final source = _isDirectBuy ? (_directItems ?? const []) : state.items;
    return source.where((e) => !_unavailable.contains(e.cartKey)).toList();
  }

  CartState _effectiveCartState(CartState cubitState) =>
      CartState(items: _effectiveItems(cubitState));

  Future<void> _loadCompanies(List<CartItem> items) async {
    final companies = await repo.companies().first;
    if (!mounted) return;
    setState(() {
      for (final c in companies) {
        _companies[c.id] = c;
      }
      for (final item in items) {
        _deliveryTypes.putIfAbsent(item.companyId, () {
          final company = _companies[item.companyId];
          if (company != null && !company.allowsHomeDelivery) {
            return DeliveryType.selfPickup;
          }
          return DeliveryType.homeDelivery;
        });
      }
    });
    final addr = _selectedAddress();
    if (addr != null && addr.pincode.isNotEmpty) {
      await _lookupDelivery(_companiesOf(CartState(items: items)));
    }
  }

  Future<void> _loadOrderHistory(String userId) async {
    if (userId.isEmpty) return;
    final previous = await repo.orders(userId: userId).first;
    if (!mounted) return;
    setState(() => _previousOrderCount = previous.length);
  }

  AddressEntry? _selectedAddress() => _addresses
      .firstWhereOrNull((a) => a.id == _selectedAddressId);

  List<String> _companiesOf(CartState? state) =>
      state?.byCompany.keys.toList() ?? const <String>[];

  Future<void> _lookupDelivery(List<String> companyIds) async {
    final pincode = _selectedAddress()?.pincode ?? '';
    final charges = <String, double>{};
    for (final companyId in companyIds) {
      if (_deliveryTypes[companyId] != DeliveryType.homeDelivery) {
        charges[companyId] = 0;
        continue;
      }
      final charge = await repo.deliveryCharge(pincode, companyId);
      charges[companyId] = charge?.charge ?? 0;
    }
    if (!mounted) return;
    setState(() => _deliveryCharges.addAll(charges));
  }

  // ------------------------------------------------------- Re-validation --

  /// Pulls the latest price/stock for every line before checkout and before
  /// the order is placed (Fix 5).
  Future<void> _revalidate(List<CartItem> items) async {
    final messages = <String>[];
    final updates = <CartItem>[];

    for (final item in items) {
      final latest = await repo.product(item.product.id);
      if (latest == null) {
        _unavailable.add(item.cartKey);
        messages.add(AppLocalizations.of(context).isUnavailable('${item.product.name}'));
        continue;
      }

      final vid = item.variant?.variantId ?? '';
      if (vid.isNotEmpty) {
        final v = latest.variants.firstWhereOrNull(
          (v) => v.variantId == vid || v.sku == vid,
        );
        if (v == null) {
          _unavailable.add(item.cartKey);
          messages.add(
            AppLocalizations.of(context).isUnavailable2('${item.product.name}', '${item.variantLabel}'),
          );
          continue;
        }
        final snap = VariantSnapshot.fromVariant(latest, v);
        var qty = item.qty;
        if (!snap.isUnlimitedStock && snap.stock < qty) {
          qty = snap.stock < 0 ? 0 : snap.stock;
          if (qty == 0) {
            _unavailable.add(item.cartKey);
            messages.add(AppLocalizations.of(context).isOutOfStock('${item.product.name}'));
            continue;
          }
          messages.add(
            AppLocalizations.of(context).quantityReducedToStock('${item.product.name}', '${qty}'),
          );
        }
        if ((snap.price - item.effectivePrice).abs() > 0.001) {
          messages.add(AppLocalizations.of(context).priceUpdatedFor('${item.product.name}'));
        }
        if (qty != item.qty ||
            (snap.price - item.effectivePrice).abs() > 0.001) {
          updates.add(
            item.copyWith(qty: qty, variant: snap),
          );
        }
      } else {
        final snap = VariantSnapshot.fromProduct(latest);
        var qty = item.qty;
        if (!snap.isUnlimitedStock && snap.stock < qty) {
          qty = snap.stock < 0 ? 0 : snap.stock;
          if (qty == 0) {
            _unavailable.add(item.cartKey);
            messages.add(AppLocalizations.of(context).isOutOfStock('${item.product.name}'));
            continue;
          }
          messages.add(
            AppLocalizations.of(context).quantityReducedToStock('${item.product.name}', '${qty}'),
          );
        }
        if ((snap.price - item.effectivePrice).abs() > 0.001) {
          messages.add(AppLocalizations.of(context).priceUpdatedFor('${item.product.name}'));
        }
        if (qty != item.qty ||
            (snap.price - item.effectivePrice).abs() > 0.001) {
          updates.add(item.copyWith(qty: qty, variant: snap));
        }
      }
    }

    if (!mounted) return;
    if (updates.isNotEmpty) {
      if (_isDirectBuy) {
        setState(() {
          _directItems = [
            for (final e in _directItems ?? const <CartItem>[])
              updates.firstWhereOrNull((u) => u.cartKey == e.cartKey) ?? e,
          ];
        });
      } else {
        final cart = context.read<CartCubit>();
        for (final u in updates) {
          cart.replaceItem(u);
        }
      }
    }
    if (messages.isNotEmpty) {
      setState(() {});
      _snack(messages.join(' · '));
    }
  }

  // ------------------------------------------------------------- Vouchers --

  Future<void> _applyVoucher(String companyId, List<CartItem> items) async {
    final controller = _voucherCtrls[companyId];
    final code = controller?.text.trim() ?? '';
    final l10n = AppLocalizations.of(context);

    if (code.isEmpty) {
      setState(() {
        _applied[companyId] = null;
        _voucherError[companyId] = AppLocalizations.of(context).enterAVoucherCode;
      });
      return;
    }

    final userId = _profile.id;
    final voucher = await repo.voucherByCode(companyId, code);
    if (!mounted) return;

    final evaluation = const VoucherEvaluator().evaluate(
      voucher: voucher,
      items: items,
      context: VoucherContext(
        now: DateTime.now(),
        userId: userId,
        previousOrderCount: _previousOrderCount,
      ),
      deliveryCharge: _deliveryCharges[companyId] ?? 0,
    );

    if (!mounted) return;

    if (!evaluation.isAccepted) {
      setState(() {
        _applied[companyId] = null;
        _voucherError[companyId] = voucher == null
            ? l10n.invalidCode
            : evaluation.message;
      });
      return;
    }

    setState(() {
      _applied[companyId] = voucher;
      _voucherError.remove(companyId);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.voucherApplied)));
  }

  void _removeVoucher(String companyId) {
    setState(() {
      _applied[companyId] = null;
      _voucherCtrls[companyId]?.clear();
    });
  }

  // ---------------------------------------------------------------- Bills --

  /// Builds one bill per store from the current items + state.
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
        deliveryRequired:
            _deliveryTypes[entry.key] == DeliveryType.homeDelivery,
        context: VoucherContext(
          now: DateTime.now(),
          userId: _profile.id,
          previousOrderCount: _previousOrderCount,
        ),
      );
    }
    return bills;
  }

  // ------------------------------------------------------------ Placing ---

  Future<void> _placeOrder(CartState state) async {
    final l10n = AppLocalizations.of(context);
    if (state.items.isEmpty || _placing) return;

    final profile = _profile;

    // 1. Customer name & mobile are mandatory for every order.
    if (profile.name.trim().isEmpty || profile.mobile.trim().isEmpty) {
      _snack(
        AppLocalizations.of(context).pleaseCompleteYourProfileNameMobileBeforePlacingAnOrder,
      );
      return;
    }

    // 2. Address is required only for shops with Home Delivery.
    final needsAddress = state.byCompany.keys.any(
      (companyId) =>
          _deliveryTypes[companyId] == DeliveryType.homeDelivery,
    );
    final address = _selectedAddress();
    if (needsAddress && address == null) {
      _snack(AppLocalizations.of(context).pleaseSelectADeliveryAddress);
      return;
    }

    // Critical write: refuse to continue when the device is offline.
    final isOnline = await connectivity.isOnline();
    if (!mounted) return;
    if (!isOnline) {
      _snack(l10n.noInternet);
      return;
    }

    setState(() => _placing = true);

    try {
      // 3. Re-check prices/stock and the shop delivery settings at submit.
      await _revalidate(state.items);
      if (!mounted) return;
      final latestItems = _effectiveItems(state);
      if (latestItems.isEmpty) {
        setState(() => _placing = false);
        _snack(AppLocalizations.of(context).noOrderItemsAreAvailable);
        return;
      }

      final bills = _bills(CartState(items: latestItems));
      final placed = <Order>[];

      for (final entry in CartState(items: latestItems).byCompany.entries) {
        final companyId = entry.key;
        final bill = bills[companyId];
        if (bill == null || bill.lines.isEmpty) continue;

        // The shop may have changed its delivery settings since load.
        final company = await repo.company(companyId) ?? _companies[companyId];
        var deliveryType =
            _deliveryTypes[companyId] ?? DeliveryType.homeDelivery;
        if (deliveryType == DeliveryType.homeDelivery &&
            company != null &&
            !company.allowsHomeDelivery) {
          deliveryType = DeliveryType.selfPickup;
        }

        final isHome = deliveryType == DeliveryType.homeDelivery;
        final pickupCard = isHome
            ? null
            : (company != null
                  ? PickupShopCard.fromCompany(company)
                  : PickupShopCard(
                      shopName: bill.companyName,
                      address: '',
                      phone: '',
                      timings: '',
                    ));

        final order = Order(
          id: '',
          userId: profile.id,
          customerName: profile.name,
          customerEmail: profile.email,
          customerPhone: profile.mobile,
          companyId: companyId,
          companyName: bill.companyName,
          items: bill.lines
              .map(
                (line) => OrderItem(
                  productId: line.productId,
                  qty: line.qty,
                  unitPrice: line.unitPrice,
                  name: line.name,
                  image: line.image,
                  variantTitle: line.variantTitle,
                  variantSku: line.variantSku,
                  variantLabel: line.displayLabel,
                  unitValue: line.unitValue,
                  unitType: line.unitType,
                  mrp: line.mrp,
                ),
              )
              .toList(),
          subtotal: bill.subtotal,
          discountAmount: bill.discount,
          deliveryCharge: bill.deliveryCharge,
          totalAmount: bill.total,
          // Address snapshot for home delivery; nothing for self pickup.
          address: isHome ? (address?.formattedAddress ?? '') : '',
          pincode: isHome ? (address?.pincode ?? '') : '',
          pickupShop: pickupCard?.toSnapshot(),
          voucherId: bill.voucher?.id,
          voucherCode: bill.voucher?.code ?? '',
          paymentStatus: PaymentStatus.pending,
          orderStatus: OrderStatus.pending,
          deliveryType: deliveryType,
        );
        placed.add(order);
      }

      if (placed.isEmpty) {
        setState(() => _placing = false);
        _snack(AppLocalizations.of(context).noOrderItemsAreAvailable);
        return;
      }

      // One write for every shop's order — never a half-saved checkout.
      final saved = await repo.placeOrders(placed);
      for (final savedOrder in saved) {
        // Send / trigger order placed email notification.
        EmailService.sendOrderPlacedEmail(order: savedOrder);
      }

      if (!mounted) return;
      if (!_isDirectBuy) {
        context.read<CartCubit>().clear();
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.orderPlaced)));
      if (saved.length == 1) {
        context.go(AppRoutes.orderPath(saved.first.id));
      } else {
        context.go(AppRoutes.orders);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _placing = false);
      _snack(AppLocalizations.of(context).couldNotPlaceTheOrder('${e}'));
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------------------------------------------------------- UI ----

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).placeOrder)),
      body: BlocBuilder<CartCubit, CartState>(
        builder: (context, cubitState) {
          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final cartState = _effectiveCartState(cubitState);
          if (cartState.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shopping_cart_outlined, size: 56),
                  const SizedBox(height: 12),
                  Text(AppLocalizations.of(context).yourCartIsEmpty),
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
          final profile = _profile;

          final subtotal = bills.values.fold<double>(
            0,
            (sum, b) => sum + b.subtotal,
          );
          final discount = bills.values.fold<double>(
            0,
            (sum, b) => sum + b.discount,
          );
          final delivery = bills.values.fold<double>(
            0,
            (sum, b) => sum + b.deliveryCharge,
          );
          final total = bills.values.fold<double>(0, (sum, b) => sum + b.total);

          final anyHomeDelivery = companies.any(
            (id) => _deliveryTypes[id] == DeliveryType.homeDelivery,
          );
          final anyUnavailable = cartState.items.any(
            (e) => _unavailable.contains(e.cartKey),
          ) || _unavailable.isNotEmpty;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ------------------------------------------- Customer details
              CustomerDetailsCard(
                name: profile.name,
                email: profile.email,
                mobile: profile.mobile,
              ),
              const SizedBox(height: 16),

              // --------------------------------------------- Saved addresses
              if (anyHomeDelivery) ...[
                AddressSelector(
                  addresses: _addresses,
                  selectedAddressId: _selectedAddressId,
                  onSelected: (address) {
                    setState(() => _selectedAddressId = address.id);
                    _lookupDelivery(companies);
                  },
                  onEdit: (address) async {
                    await showAddressForm(context, initial: address);
                    if (!mounted) return;
                    _loadAddresses();
                  },
                  onAddNew: () async {
                    await showAddressForm(context);
                    if (!mounted) return;
                    _loadAddresses();
                  },
                ),
                const SizedBox(height: 16),
              ],

              // ------------------------------------------- Shop-wise blocks
              for (final companyId in companies) ...[
                _StoreCheckoutCard(
                  key: Key('checkout-store-card-$companyId'),
                  companyId: companyId,
                  company: _companies[companyId],
                  items:
                      cartState.byCompany[companyId] ?? const <CartItem>[],
                  bill: bills[companyId],
                  deliveryType:
                      _deliveryTypes[companyId] ?? DeliveryType.homeDelivery,
                  onDeliveryTypeChanged: (type) {
                    setState(() => _deliveryTypes[companyId] = type);
                    _lookupDelivery([companyId]);
                  },
                  unavailableKeys: _unavailable,
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

              if (anyUnavailable)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    AppLocalizations.of(context).unavailableItemsAreExcludedFromTheTotal,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),

              // --------------------------------------------------- Summary
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
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.amber.shade700.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.payments_outlined,
                      color: Colors.amber.shade900,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context).manualOfflinePayment,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.amber.shade900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppLocalizations.of(context).payDirectlyCashUpiOnDeliveryOrPickupPaymentStatusWillDefaultToPendingAndCanBeMarkedAsDoneByTheAdmin,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade800,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                    : Text(
                        _isDirectBuy
                            ? AppLocalizations.of(context).placeDirectOrder('${formatCurrency(total)}')
                            : AppLocalizations.of(context).confirmPlaceOrder('${formatCurrency(total)}'),
                      ),
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

/// Lightweight profile snapshot used while ordering.
class AppUserSnapshot {
  final String id;
  final String name;
  final String email;
  final String mobile;

  const AppUserSnapshot({
    required this.id,
    required this.name,
    required this.email,
    required this.mobile,
  });
}

/// One store's items, delivery type, voucher box and bill.
class _StoreCheckoutCard extends StatelessWidget {
  final String companyId;
  final Company? company;
  final List<CartItem> items;
  final OrderBill? bill;
  final String deliveryType;
  final ValueChanged<String> onDeliveryTypeChanged;
  final Set<String> unavailableKeys;
  final TextEditingController voucherCtrl;
  final String? voucherError;
  final VoidCallback onApply;
  final VoidCallback onRemove;
  final String applyLabel;

  const _StoreCheckoutCard({
    super.key,
    required this.companyId,
    required this.company,
    required this.items,
    required this.bill,
    required this.deliveryType,
    required this.onDeliveryTypeChanged,
    required this.unavailableKeys,
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
    final storeName = items.isNotEmpty && items.first.companyName.isNotEmpty
        ? items.first.companyName
        : (company?.name.isNotEmpty == true ? company!.name : AppLocalizations.of(context).store2);
    final isHome = deliveryType == DeliveryType.homeDelivery;

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
                    key: Key('checkout-store-name-$companyId'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            for (final item in items) _itemRow(context, item),
            const SizedBox(height: 12),

            // Per-shop delivery type, honouring the shop's settings.
            DeliveryTypeSelector(
              company: company,
              value: deliveryType,
              onChanged: onDeliveryTypeChanged,
            ),
            const SizedBox(height: 12),

            // Self pickup: no address needed — where to collect instead.
            if (!isHome && company != null)
              PickupShopCard.fromCompany(company!)
            else if (!isHome)
              PickupShopCard(
                shopName: AppLocalizations.of(context).store2,
                address: '',
                phone: '',
                timings: '',
              ),
            if (!isHome) const SizedBox(height: 12),

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
                  child: Text(AppLocalizations.of(context).apply),
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
              _row(AppLocalizations.of(context).items4, formatCurrency(resolvedBill.subtotal)),
              if (resolvedBill.discount > 0)
                _row(
                  AppLocalizations.of(context).discount,
                  '− ${formatCurrency(resolvedBill.discount)}',
                  color: Colors.green.shade700,
                ),
              _row(AppLocalizations.of(context).delivery, formatCurrency(resolvedBill.deliveryCharge)),
              const Divider(height: 14),
              _row(
                AppLocalizations.of(context).storeTotal,
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

  /// One order line: image, name, variant label ("500g × 2") and price.
  Widget _itemRow(BuildContext context, CartItem item) {
    final unavailable = unavailableKeys.contains(item.cartKey);
    final label = item.variantLabel.isNotEmpty
        ? '${item.variantLabel} × ${item.qty}'
        : '× ${item.qty}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (item.product.images.isNotEmpty &&
              item.product.images.first.trim().isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                item.product.images.first.trim(),
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.shopping_bag_outlined,
                  size: 18,
                  color: Colors.grey,
                ),
              ),
            )
          else
            const Icon(
              Icons.shopping_bag_outlined,
              size: 18,
              color: Colors.grey,
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: TextStyle(
                    fontSize: 13,
                    decoration: unavailable
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                Text(
                  label,
                  key: Key('checkout-item-variant-${item.cartKey}'),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                if (unavailable)
                  Text(
                    AppLocalizations.of(context).unavailable,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            formatCurrency(item.lineTotal),
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false, Color? color}) {
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
