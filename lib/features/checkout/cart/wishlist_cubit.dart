import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/cart_item.dart';
import '../../../core/models/product.dart';

/// Items the shopper saved for later instead of buying right now.
///
/// The cart's swipe-to-remove action offers "Move to Wishlist" as the
/// alternative to fully deleting a line, so a mis-swipe never loses a
/// product the shopper deliberately chose.
class WishlistState {
  final List<Product> items;

  const WishlistState({this.items = const <Product>[]});

  bool contains(String productId) =>
      items.any((p) => p.id == productId);

  int get count => items.length;

  WishlistState copyWith({List<Product>? items}) =>
      WishlistState(items: items ?? this.items);
}

class WishlistCubit extends Cubit<WishlistState> {
  WishlistCubit() : super(const WishlistState());

  /// Adds [product] unless it is already saved (a wishlist has no quantity).
  void add(Product product) {
    if (product.id.isEmpty || state.contains(product.id)) {
      emit(WishlistState(items: [...state.items]));
      return;
    }
    emit(WishlistState(items: [...state.items, product]));
  }

  /// Saves a whole cart line (used by the swipe-remove alternative action).
  void addFromCart(CartItem item) => add(item.product);

  void remove(String productId) {
    emit(
      WishlistState(
        items: state.items.where((p) => p.id != productId).toList(),
      ),
    );
  }

  void toggle(Product product) {
    if (state.contains(product.id)) {
      remove(product.id);
    } else {
      add(product);
    }
  }

  void clear() => emit(const WishlistState());
}
