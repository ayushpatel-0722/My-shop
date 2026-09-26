import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/cart_item.dart';
import '../../../core/models/company.dart';
import '../../../core/models/product.dart';

class CartState {
  final List<CartItem> items;

  const CartState({this.items = const []});

  int get totalItems => items.fold(0, (sum, e) => sum + e.qty);
  double get totalAmount => items.fold(0.0, (sum, e) => sum + e.lineTotal);

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

  CartState copyWith({List<CartItem>? items}) =>
      CartState(items: items ?? this.items);
}

class CartCubit extends Cubit<CartState> {
  CartCubit() : super(const CartState());

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
    final targetSku = variant?.sku ?? '';
    final targetTitle = variant?.title ?? '';

    final i = items.indexWhere(
      (e) =>
          e.product.id == product.id &&
          e.companyId == resolvedCompanyId &&
          (e.variant?.sku ?? '') == targetSku &&
          (e.variant?.title ?? '') == targetTitle,
    );
    if (i != -1) {
      items[i] = items[i].copyWith(
        qty: items[i].qty + qty,
        variant: variant ?? items[i].variant,
      );
    } else {
      items.add(
        CartItem(
          companyId: resolvedCompanyId,
          companyName: resolvedCompanyName,
          product: product,
          variant: variant,
          qty: qty,
        ),
      );
    }
    emit(state.copyWith(items: items));
  }

  void increment(
    String companyId,
    String productId, {
    String variantSku = '',
    String variantTitle = '',
  }) {
    final items = state.items
        .map(
          (e) =>
              e.companyId == companyId &&
                  e.product.id == productId &&
                  (e.variant?.sku ?? '') == variantSku &&
                  (variantTitle.isEmpty ||
                      (e.variant?.title ?? '') == variantTitle)
              ? e.copyWith(qty: e.qty + 1)
              : e,
        )
        .toList();
    emit(state.copyWith(items: items));
  }

  void decrement(
    String companyId,
    String productId, {
    String variantSku = '',
    String variantTitle = '',
  }) {
    final items = <CartItem>[];
    for (final e in state.items) {
      if (e.companyId == companyId &&
          e.product.id == productId &&
          (e.variant?.sku ?? '') == variantSku &&
          (variantTitle.isEmpty || (e.variant?.title ?? '') == variantTitle)) {
        if (e.qty > 1) items.add(e.copyWith(qty: e.qty - 1));
      } else {
        items.add(e);
      }
    }
    emit(state.copyWith(items: items));
  }

  void remove(
    String companyId,
    String productId, {
    String variantSku = '',
    String variantTitle = '',
  }) {
    final items = state.items
        .where(
          (e) =>
              !(e.companyId == companyId &&
                  e.product.id == productId &&
                  (e.variant?.sku ?? '') == variantSku &&
                  (variantTitle.isEmpty ||
                      (e.variant?.title ?? '') == variantTitle)),
        )
        .toList();
    emit(state.copyWith(items: items));
  }

  void clear() => emit(const CartState());
}
