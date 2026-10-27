import 'dart:async';
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
import '../../../core/services/service_locator.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../core/widgets/app_product_image.dart';
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
    try {
      final previous = await repo.orders(userId: userId).first;
      if (!mounted) return;
      setState(() => _previousOrderCount = previous.length);
    } catch (e) {
      debugPrint('[CheckoutScreen] Failed to load order history: $e');
    }
  }

  AddressEntry? _selectedAddress() =>
      _addresses.firstWhereOrNull((a) => a.id == _selectedAddressId);

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
    final l10n = AppLocalizations.of(context);
    final messages = <String>[];
    final updates = <CartItem>[];

    for (final item in items) {
      final latest = await repo.product(item.product.id);
      if (latest == null) {
        _unavailable.add(item.cartKey);
        messages.add(l10n.isUnavailable(item.product.name));
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
            l10n.isUnavailable2(item.product.name, item.variantLabel),
          );
          continue;
        }
        final snap = VariantSnapshot.fromVariant(latest, v);
        var qty = item.qty;
        if (!snap.isUnlimitedStock && snap.stock < qty) {
          qty = snap.stock < 0 ? 0 : snap.stock;
          if (qty == 0) {
            _unavailable.add(item.cartKey);
            messages.add(l10n.isOutOfStock(item.product.name));
            continue;
          }
          messages.add(
            l10n.quantityReducedToStock(item.product.name, qty.toString()),
          );
        }
        if ((snap.price - item.effectivePrice).abs() > 0.001) {
          messages.add(l10n.priceUpdatedFor(item.product.name));
        }
        if (qty != item.qty ||
            (snap.price - item.effectivePrice).abs() > 0.001) {
          updates.add(item.copyWith(qty: qty, variant: snap));
        }
      } else {
        final snap = VariantSnapshot.fromProduct(latest);
        var qty = item.qty;
        if (!snap.isUnlimitedStock && snap.stock < qty) {
          qty = snap.stock < 0 ? 0 : snap.stock;
          if (qty == 0) {
            _unavailable.add(item.cartKey);
            messages.add(l10n.isOutOfStock(item.product.name));
            continue;
          }
          messages.add(
            l10n.quantityReducedToStock(item.product.name, qty.toString()),
          );
        }
        if ((snap.price - item.effectivePrice).abs() > 0.001) {
          messages.add(l10n.priceUpdatedFor(item.product.name));
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
        _voucherError[companyId] = AppLocalizations.of(
          context,
        ).enterAVoucherCode;
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
    final address = _selectedAddress();

    // 1. Customer name & mobile are mandatory for every order.
    if (profile.name.trim().isEmpty || profile.mobile.trim().isEmpty) {
      _snack(
        AppLocalizations.of(
          context,
        ).pleaseCompleteYourProfileNameMobileBeforePlacingAnOrder,
      );
      return;
    }

    final effectiveName = profile.name.trim();
    final effectiveMobile = profile.mobile.trim();

    // 2. Address is required only for shops with Home Delivery.
    final needsAddress = state.byCompany.keys.any(
      (companyId) => _deliveryTypes[companyId] == DeliveryType.homeDelivery,
    );
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
        _snack(l10n.noOrderItemsAreAvailable);
        return;
      }

      final bills = _bills(CartState(items: latestItems));
      final placed = <Order>[];

      // Validate minimum order value for delivery per shop before placing orders
      for (final entry in CartState(items: latestItems).byCompany.entries) {
        final companyId = entry.key;
        final bill = bills[companyId];
        if (bill == null || bill.lines.isEmpty) continue;

        final company = await repo.company(companyId) ?? _companies[companyId];
        var deliveryType =
            _deliveryTypes[companyId] ?? DeliveryType.homeDelivery;
        if (deliveryType == DeliveryType.homeDelivery &&
            company != null &&
            !company.allowsHomeDelivery) {
          deliveryType = DeliveryType.selfPickup;
        }

        if (deliveryType == DeliveryType.homeDelivery &&
            company != null &&
            company.minOrderAmount > 0 &&
            bill.subtotal < company.minOrderAmount) {
          setState(() => _placing = false);
          _snack(
            'Minimum order value for delivery is ₹${company.minOrderAmount.toInt()}. Please add more products to continue.',
          );
          return;
        }
      }

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
          customerName: effectiveName,
          customerEmail: profile.email,
          customerPhone: effectiveMobile,
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
          paymentMethod: '',
          transactionRef: null,
        );
        placed.add(order);
      }

      if (placed.isEmpty) {
        setState(() => _placing = false);
        _snack(l10n.noOrderItemsAreAvailable);
        return;
      }

      // One write for every shop's order — never a half-saved checkout.
      final saved = await repo.placeOrders(placed);

      if (!mounted) return;
      if (!_isDirectBuy) {
        context.read<CartCubit>().clear();
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.orderPlaced)));
      if (saved.length == 1) {
        context.go(
          AppRoutes.orderPath(saved.first.id, companyId: saved.first.companyId),
        );
      } else {
        context.go(AppRoutes.orders);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _placing = false);
      _snack(AppLocalizations.of(context).couldNotPlaceTheOrder('$e'));
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

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go(AppRoutes.cart);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context).placeOrder),
          leading: BackButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(AppRoutes.cart);
              }
            },
          ),
        ),
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
            final total = bills.values.fold<double>(
              0,
              (sum, b) => sum + b.total,
            );

            final anyHomeDelivery = companies.any(
              (id) => _deliveryTypes[id] == DeliveryType.homeDelivery,
            );
            final anyUnavailable =
                cartState.items.any((e) => _unavailable.contains(e.cartKey)) ||
                _unavailable.isNotEmpty;

            if (context.screenWidth >= 1024) {
              return _buildDesktopLayout(
                context: context,
                cartState: cartState,
                companies: companies,
                bills: bills,
                profile: profile,
                subtotal: subtotal,
                discount: discount,
                delivery: delivery,
                total: total,
                anyHomeDelivery: anyHomeDelivery,
                anyUnavailable: anyUnavailable,
                l10n: l10n,
              );
            } else if (context.screenWidth >= 600) {
              return _buildTabletLayout(
                context: context,
                cartState: cartState,
                companies: companies,
                bills: bills,
                profile: profile,
                subtotal: subtotal,
                discount: discount,
                delivery: delivery,
                total: total,
                anyHomeDelivery: anyHomeDelivery,
                anyUnavailable: anyUnavailable,
                l10n: l10n,
              );
            }

            return _buildMobileLayout(
              context: context,
              cartState: cartState,
              companies: companies,
              bills: bills,
              profile: profile,
              subtotal: subtotal,
              discount: discount,
              delivery: delivery,
              total: total,
              anyHomeDelivery: anyHomeDelivery,
              anyUnavailable: anyUnavailable,
              l10n: l10n,
            );
          },
        ),
      ),
    );
  }

  Widget _sectionHeading({
    required BuildContext context,
    required String step,
    required String title,
    IconData? icon,
    String? badge,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              step,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (icon != null) ...[
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDesktopLayout({
    required BuildContext context,
    required CartState cartState,
    required List<String> companies,
    required Map<String, OrderBill> bills,
    required AppUserSnapshot profile,
    required double subtotal,
    required double discount,
    required double delivery,
    required double total,
    required bool anyHomeDelivery,
    required bool anyUnavailable,
    required AppLocalizations l10n,
  }) {
    final isUltrawide = context.screenWidth >= 1440;
    final hPad = isUltrawide
        ? 48.0
        : (context.screenWidth >= 1200 ? 32.0 : 24.0);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1600),
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 24),
          children: [
            // Breadcrumbs
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => context.go(AppRoutes.home),
                    child: Text(
                      l10n.home,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, size: 14, color: Colors.grey),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => context.go(AppRoutes.cart),
                    child: Text(
                      AppLocalizations.of(context).cart,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, size: 14, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context).placeOrder,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // Page Title & Item Count
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                children: [
                  Text(
                    l10n.placeOrder,
                    style: TextStyle(
                      fontSize: isUltrawide ? 30 : 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${cartState.items.length} ${cartState.items.length == 1 ? 'item' : 'items'}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Customer details, Address, Store checkout cards, Payment method
                Expanded(
                  flex: isUltrawide ? 8 : 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1: Customer Details & Delivery Address
                      _sectionHeading(
                        context: context,
                        step: '1',
                        title: anyHomeDelivery
                            ? l10n.deliveryAddress
                            : AppLocalizations.of(context).customerDetails,
                        icon: anyHomeDelivery
                            ? Icons.location_on_outlined
                            : Icons.person_pin_outlined,
                      ),
                      CustomerDetailsCard(
                        name: profile.name,
                        email: profile.email,
                        mobile: profile.mobile,
                      ),
                      if (anyHomeDelivery) ...[
                        const SizedBox(height: 14),
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
                      ],
                      const SizedBox(height: 28),

                      // Section 2: Store Items & Offers
                      _sectionHeading(
                        context: context,
                        step: '2',
                        title: 'Review Ordered Items & Store Delivery',
                        icon: Icons.shopping_bag_outlined,
                        badge:
                            '${cartState.items.length} items from ${companies.length} ${companies.length == 1 ? 'store' : 'stores'}',
                      ),
                      for (final companyId in companies) ...[
                        _StoreCheckoutCard(
                          key: Key('checkout-store-card-$companyId'),
                          companyId: companyId,
                          company: _companies[companyId],
                          items:
                              cartState.byCompany[companyId] ??
                              const <CartItem>[],
                          bill: bills[companyId],
                          deliveryType:
                              _deliveryTypes[companyId] ??
                              DeliveryType.homeDelivery,
                          onDeliveryTypeChanged: (type) {
                            setState(() => _deliveryTypes[companyId] = type);
                            _lookupDelivery([companyId]);
                          },
                          unavailableKeys: _unavailable,
                          voucherCtrl: _voucherCtrls[companyId]!,
                          voucherError: _voucherError[companyId],
                          onApply: () => _applyVoucher(
                            companyId,
                            cartState.byCompany[companyId] ??
                                const <CartItem>[],
                          ),
                          onRemove: () => _removeVoucher(companyId),
                          applyLabel: l10n.applyVoucher,
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (anyUnavailable)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            AppLocalizations.of(
                              context,
                            ).unavailableItemsAreExcludedFromTheTotal,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),

                      // Section 3: Payment
                      _sectionHeading(
                        context: context,
                        step: '3',
                        title: 'Payment',
                        icon: Icons.payments_outlined,
                      ),
                      _buildPaymentNoticeCard(context),
                    ],
                  ),
                ),
                SizedBox(width: isUltrawide ? 36 : 24),

                // Right Column: Order Summary card
                SizedBox(
                  width: isUltrawide ? 420 : 380,
                  child: Column(
                    children: [
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Order Summary',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                              ),
                              const SizedBox(height: 18),
                              _summaryRow(
                                l10n.subtotal,
                                formatCurrency(subtotal),
                              ),
                              if (discount > 0)
                                _summaryRow(
                                  l10n.discount,
                                  '− ${formatCurrency(discount)}',
                                  color: Colors.green.shade700,
                                ),
                              _summaryRow(
                                l10n.deliveryCharge,
                                delivery == 0
                                    ? 'FREE'
                                    : formatCurrency(delivery),
                                color: delivery == 0
                                    ? Colors.green.shade700
                                    : null,
                              ),
                              const Divider(height: 24),
                              _summaryRow(
                                l10n.totalAmount,
                                formatCurrency(total),
                                bold: true,
                              ),
                              const SizedBox(height: 22),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: FilledButton(
                                  key: const Key('checkout-place-order-button'),
                                  onPressed: _placing
                                      ? null
                                      : () => _placeOrder(cartState),
                                  style: FilledButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _placing
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          _isDirectBuy
                                              ? AppLocalizations.of(
                                                  context,
                                                ).placeDirectOrder(
                                                  formatCurrency(total),
                                                )
                                              : AppLocalizations.of(
                                                  context,
                                                ).confirmPlaceOrder(
                                                  formatCurrency(total),
                                                ),
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildTrustBadges(context),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletLayout({
    required BuildContext context,
    required CartState cartState,
    required List<String> companies,
    required Map<String, OrderBill> bills,
    required AppUserSnapshot profile,
    required double subtotal,
    required double discount,
    required double delivery,
    required double total,
    required bool anyHomeDelivery,
    required bool anyUnavailable,
    required AppLocalizations l10n,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            // Breadcrumbs
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => context.go(AppRoutes.home),
                    child: Text(
                      l10n.home,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, size: 14, color: Colors.grey),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => context.go(AppRoutes.cart),
                    child: Text(
                      AppLocalizations.of(context).cart,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, size: 14, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context).placeOrder,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // Page Title
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                children: [
                  Text(
                    l10n.placeOrder,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${cartState.items.length} ${cartState.items.length == 1 ? 'item' : 'items'}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Step 1: Delivery Address & Customer Details
            _sectionHeading(
              context: context,
              step: '1',
              title: anyHomeDelivery
                  ? l10n.deliveryAddress
                  : AppLocalizations.of(context).customerDetails,
              icon: anyHomeDelivery
                  ? Icons.location_on_outlined
                  : Icons.person_pin_outlined,
            ),
            CustomerDetailsCard(
              name: profile.name,
              email: profile.email,
              mobile: profile.mobile,
            ),
            if (anyHomeDelivery) ...[
              const SizedBox(height: 14),
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
            ],
            const SizedBox(height: 24),

            // Step 2: Review Ordered Items & Store Delivery
            _sectionHeading(
              context: context,
              step: '2',
              title: 'Review Ordered Items & Store Delivery',
              icon: Icons.shopping_bag_outlined,
              badge: '${cartState.items.length} items',
            ),
            for (final companyId in companies) ...[
              _StoreCheckoutCard(
                key: Key('checkout-store-card-$companyId'),
                companyId: companyId,
                company: _companies[companyId],
                items: cartState.byCompany[companyId] ?? const <CartItem>[],
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
              const SizedBox(height: 14),
            ],

            if (anyUnavailable)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  AppLocalizations.of(
                    context,
                  ).unavailableItemsAreExcludedFromTheTotal,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: 20),

            // Step 3: Payment
            _sectionHeading(
              context: context,
              step: '3',
              title: 'Payment',
              icon: Icons.payments_outlined,
            ),
            _buildPaymentNoticeCard(context),
            const SizedBox(height: 24),

            // Tablet Order Summary Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order Summary',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _summaryRow(l10n.subtotal, formatCurrency(subtotal)),
                    if (discount > 0)
                      _summaryRow(
                        l10n.discount,
                        '− ${formatCurrency(discount)}',
                        color: Colors.green.shade700,
                      ),
                    _summaryRow(
                      l10n.deliveryCharge,
                      delivery == 0 ? 'FREE' : formatCurrency(delivery),
                      color: delivery == 0 ? Colors.green.shade700 : null,
                    ),
                    const Divider(height: 24),
                    _summaryRow(
                      l10n.totalAmount,
                      formatCurrency(total),
                      bold: true,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        key: const Key('checkout-place-order-button'),
                        onPressed: _placing
                            ? null
                            : () => _placeOrder(cartState),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _placing
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isDirectBuy
                                    ? AppLocalizations.of(
                                        context,
                                      ).placeDirectOrder(formatCurrency(total))
                                    : AppLocalizations.of(
                                        context,
                                      ).confirmPlaceOrder(
                                        formatCurrency(total),
                                      ),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTrustBadges(context),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout({
    required BuildContext context,
    required CartState cartState,
    required List<String> companies,
    required Map<String, OrderBill> bills,
    required AppUserSnapshot profile,
    required double subtotal,
    required double discount,
    required double delivery,
    required double total,
    required bool anyHomeDelivery,
    required bool anyUnavailable,
    required AppLocalizations l10n,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: context.isDesktop ? 24 : 16,
            vertical: 16,
          ),
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
                items: cartState.byCompany[companyId] ?? const <CartItem>[],
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
                  AppLocalizations.of(
                    context,
                  ).unavailableItemsAreExcludedFromTheTotal,
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
                    _summaryRow(l10n.deliveryCharge, formatCurrency(delivery)),
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
            _buildPaymentNoticeCard(context),
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
                          ? AppLocalizations.of(
                              context,
                            ).placeDirectOrder(formatCurrency(total))
                          : AppLocalizations.of(
                              context,
                            ).confirmPlaceOrder(formatCurrency(total)),
                    ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentNoticeCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.payments_outlined,
              color: Colors.teal.shade800,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pay on Delivery / Pickup',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 3),
                Text(
                  'Pay via Cash or UPI when your order is delivered or at store counter. Store admin will verify and record the payment receipt upon delivery/pickup.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustBadges(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 16,
                color: Colors.green.shade700,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '100% Safe & Secure Checkout',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.local_shipping_outlined,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Trackable Direct Store Delivery',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Row(
            children: [
              Icon(Icons.store_outlined, size: 16, color: Color(0xFF3D38D9)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Verified Quality Products',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
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
        : (company?.name.isNotEmpty == true
              ? company!.name
              : AppLocalizations.of(context).store2);
    final isHome = deliveryType == DeliveryType.homeDelivery;
    final isDesktop = context.screenWidth >= 600;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 18 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.storefront,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    storeName,
                    key: Key('checkout-store-name-$companyId'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isDesktop ? 16 : 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            for (final item in items) _itemRow(context, item),
            const SizedBox(height: 12),

            // Per-shop delivery type, honouring the shop's settings.
            DeliveryTypeSelector(
              company: company,
              value: deliveryType,
              onChanged: onDeliveryTypeChanged,
            ),
            if (isHome &&
                company != null &&
                company!.minOrderAmount > 0 &&
                resolvedBill != null &&
                resolvedBill.subtotal < company!.minOrderAmount) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Minimum order value for delivery is ₹${company!.minOrderAmount.toInt()}. Please add more products to continue.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
              _row(
                AppLocalizations.of(context).items4,
                formatCurrency(resolvedBill.subtotal),
              ),
              if (resolvedBill.discount > 0)
                _row(
                  AppLocalizations.of(context).discount,
                  '− ${formatCurrency(resolvedBill.discount)}',
                  color: Colors.green.shade700,
                ),
              _row(
                AppLocalizations.of(context).delivery,
                formatCurrency(resolvedBill.deliveryCharge),
              ),
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
    final isDesktop = context.screenWidth >= 600;
    final imageSize = isDesktop ? 56.0 : 36.0;
    final label = item.variantLabel.isNotEmpty
        ? '${item.variantLabel} × ${item.qty}'
        : '× ${item.qty}';

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isDesktop ? 6 : 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: imageSize,
              height: imageSize,
              child: AppProductImage.product(
                product: item.product,
                fit: BoxFit.cover,
                fallback: Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.shopping_bag_outlined,
                    size: 20,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: TextStyle(
                    fontSize: isDesktop ? 15 : 13,
                    fontWeight: isDesktop ? FontWeight.w600 : FontWeight.normal,
                    decoration: unavailable ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      key: Key('checkout-item-variant-${item.cartKey}'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: isDesktop ? 12 : 11.5,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (isDesktop && item.qty > 1) ...[
                      const SizedBox(width: 8),
                      Text(
                        '(${formatCurrency(item.effectivePrice)} each)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ],
                ),
                if (unavailable)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      AppLocalizations.of(context).unavailable,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatCurrency(item.lineTotal),
            style: TextStyle(
              fontSize: isDesktop ? 15 : 13,
              fontWeight: FontWeight.bold,
            ),
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
