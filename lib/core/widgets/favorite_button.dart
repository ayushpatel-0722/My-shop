import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/checkout/cart/wishlist_cubit.dart';
import '../models/product.dart';
import '../utils/favorite_actions.dart';

/// The heart that likes / unlikes [product]. Filled when it is liked.
///
/// All the rules (login, the 25 limit and its confirmation, saving) live in
/// [FavoriteActions]; this only shows the state and forwards the tap. Shows an
/// outline heart when there is no favourites list in scope.
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key, required this.product, this.size = 24});

  final Product product;
  final double size;

  @override
  Widget build(BuildContext context) {
    WishlistCubit? cubit;
    try {
      cubit = context.watch<WishlistCubit>();
    } catch (_) {}
    final liked = cubit?.state.contains(product.id) ?? false;
    return IconButton(
      key: Key('favorite-button-${product.id}'),
      tooltip: liked ? 'Unlike' : 'Like',
      onPressed: () => FavoriteActions.toggle(context, product),
      icon: Icon(
        liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        size: size,
        color: liked ? const Color(0xFFFF5247) : const Color(0xFF64748B),
      ),
    );
  }
}
