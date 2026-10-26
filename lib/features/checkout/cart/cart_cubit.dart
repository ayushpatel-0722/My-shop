import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/cart_item.dart';
import '../../../core/models/company.dart';
import '../../../core/models/product.dart';
import '../../../core/services/cart_storage.dart';

class CartState {
  final List<CartItem> items;
  final bool isLoading;

  const CartState({this.items = const [], this.isLoading = false});

  int get totalItems => items.fold(0, (sum, e) => sum + e.qty);
  double get totalAmount => items.fold(0.0, (sum, e) => sum + e.lineTotal);

  /// Sum of the (strikethrough) MRP totals of every line.
  double get totalMrpAmount =>
      items.fold(0.0, (sum, e) => sum + e.lineMrpTotal);

  /// Items grouped by company (Section 3 / multi-company cart).
  Map<String, List<CartItem>> get byCompany {
    final map = <String, List<CartItem>>{};
    for (final item in items) {
      map.putIfAbsent(item.companyId, () => []).add(item);
    }
    return map;
  }

  double subtotalFor(String companyId) => items
      .where((e) => e.companyId == companyId)
      .fold(0.0, (sum, e) => sum + e.lineTotal);

  CartState copyWith({List<CartItem>? items, bool? isLoading}) => CartState(
    items: items ?? this.items,
    isLoading: isLoading ?? this.isLoading,
  );
}

/// Cart state backed by local database (SharedPreferences via [CartStorage]).
///
/// The same product + variant merges into one row (quantity increases), while
/// two variants of one product are two rows. Quantities are always capped by
/// the variant's stock snapshot.
class CartCubit extends Cubit<CartState> {
  final CartStorage _storage;

  CartCubit([CartStorage? storage])
    : _storage = storage ?? CartStorage(),
      super(const CartState()) {
    loadFromStorage();
  }

  /// Restores cart lines saved in local persistent storage.
  Future<void> loadFromStorage() async {
    try {
      final saved = await _storage.loadCart();
      if (saved.isNotEmpty && state.items.isEmpty) {
        emit(state.copyWith(items: saved));
      }
    } catch (_) {}
  }

  void _persist(List<CartItem> items) {
    _storage.saveCart(items);
  }

  void add(
    Product product, {
    ProductVariant? variant,
    String? companyId,
    String? companyName,
    int qty = 1,
    Company? company,
  }) {
    final items = [...state.items];
    final resolvedCompanyId = companyId ?? company?.id ?? product.companyId;
    final resolvedCompanyName = companyName ?? company?.name ?? '';

    final line = CartItem.fromSelection(
      companyId: resolvedCompanyId,
      companyName: resolvedCompanyName,
      product: product,
      selectedVariant: variant,
      qty: qty,
    );

    final i = items.indexWhere(
      (e) => e.cartKey == line.cartKey && e.companyId == resolvedCompanyId,
    );
    if (i != -1) {
      // Same product + same variant: grow the quantity instead of duplicating.
      final existing = items[i];
      final maxQty = existing.maxQty;
      final next = existing.qty + qty;
      items[i] = existing.copyWith(qty: next > maxQty ? maxQty : next);
    } else {
      final maxQty = line.maxQty;
      items.add(line.copyWith(qty: qty > maxQty ? maxQty : qty));
    }
    _persist(items);
    emit(state.copyWith(items: items));
  }

  /// True when [cartKey] is not already a row of the cart.
  bool contains(String cartKey) => state.items.any((e) => e.cartKey == cartKey);

  CartItem? byKey(String cartKey) {
    for (final e in state.items) {
      if (e.cartKey == cartKey) return e;
    }
    return null;
  }

  /// +1 (clamped to the variant's stock).
  void incrementByCartKey(String cartKey) {
    final items = state.items
        .map(
          (e) => e.cartKey == cartKey && e.qty < e.maxQty
              ? e.copyWith(qty: e.qty + 1)
              : e,
        )
        .toList();
    _persist(items);
    emit(state.copyWith(items: items));
  }

  /// −1 (no-op at quantity 1 — removing is an explicit action).
  void decrementByCartKey(String cartKey) {
    final items = state.items
        .map(
          (e) => e.cartKey == cartKey && e.qty > 1
              ? e.copyWith(qty: e.qty - 1)
              : e,
        )
        .toList();
    _persist(items);
    emit(state.copyWith(items: items));
  }

  void removeByCartKey(String cartKey) {
    final remaining = state.items.where((e) => e.cartKey != cartKey).toList();
    _persist(remaining);
    emit(state.copyWith(items: remaining));
  }

  /// Replaces one line with [updated] (same cart key) — used by the checkout
  /// price/stock re-validation to sync the cart with the latest catalogue.
  void replaceItem(CartItem updated) {
    final items = state.items
        .map((e) => e.cartKey == updated.cartKey ? updated : e)
        .toList();
    _persist(items);
    emit(state.copyWith(items: items));
  }

  void increment(
    String companyId,
    String productId, {
    String variantSku = '',
    String variantTitle = '',
  }) {
    final key = _resolveKey(companyId, productId, variantSku, variantTitle);
    if (key != null) incrementByCartKey(key);
  }

  void decrement(
    String companyId,
    String productId, {
    String variantSku = '',
    String variantTitle = '',
  }) {
    final key = _resolveKey(companyId, productId, variantSku, variantTitle);
    if (key != null) decrementByCartKey(key);
  }

  void remove(
    String companyId,
    String productId, {
    String variantSku = '',
    String variantTitle = '',
  }) {
    final key = _resolveKey(companyId, productId, variantSku, variantTitle);
    if (key != null) {
      removeByCartKey(key);
    } else {
      // Fallback: remove every row of that product in the company.
      final remaining = state.items
          .where(
            (e) => !(e.companyId == companyId && e.product.id == productId),
          )
          .toList();
      _persist(remaining);
      emit(state.copyWith(items: remaining));
    }
  }

  String? _resolveKey(
    String companyId,
    String productId,
    String variantSku,
    String variantTitle,
  ) {
    for (final e in state.items) {
      if (e.companyId != companyId || e.product.id != productId) continue;
      if (variantSku.isEmpty && variantTitle.isEmpty) return e.cartKey;
      final id = e.variant?.variantId ?? '';
      final label = e.variant?.label ?? '';
      if ((variantSku.isEmpty || id == variantSku) &&
          (variantTitle.isEmpty || label == variantTitle)) {
        return e.cartKey;
      }
    }
    return null;
  }

  void clear() {
    _storage.clearCart();
    emit(const CartState());
  }
}
