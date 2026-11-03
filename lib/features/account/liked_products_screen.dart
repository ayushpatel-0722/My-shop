import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/routes/app_router.dart';
import '../../core/models/favorite.dart';
import '../../core/models/product.dart';
import '../../core/services/service_locator.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_product_image.dart';
import '../../core/widgets/favorite_button.dart';
import '../checkout/cart/wishlist_cubit.dart';

/// Every product the shopper has liked, newest first. Opened from Settings.
///
/// The list itself comes from [WishlistCubit] (saved per account); the products
/// are read from the shop once each and kept, so liking or unliking in here
/// changes the list at once without reloading the rest.
class LikedProductsScreen extends StatefulWidget {
  const LikedProductsScreen({super.key});

  @override
  State<LikedProductsScreen> createState() => _LikedProductsScreenState();
}

class _LikedProductsScreenState extends State<LikedProductsScreen> {
  // productId -> the product, or null once we know it is gone.
  final Map<String, Product?> _products = {};
  final Set<String> _requested = {};
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    // Make sure the saved list is loaded (it is bound to the signed-in user).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await context.read<WishlistCubit>().prepare();
      } catch (_) {
        if (mounted) setState(() => _loadFailed = true);
      }
    });
  }

  /// Reads the products we do not have yet; ones already read are reused.
  void _fetchMissing(List<FavoriteEntry> entries) {
    for (final e in entries) {
      if (!_requested.add(e.productId)) continue;
      repo
          .product(e.productId)
          .then((p) {
            if (mounted) setState(() => _products[e.productId] = p);
          })
          .catchError((_) {
            // Not a reason to hide the row: leave it loading, retry on reopen.
            _requested.remove(e.productId);
          });
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.account);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _back),
        title: Text(l10n.likedProductsTitle),
      ),
      body: BlocBuilder<WishlistCubit, WishlistState>(
        builder: (context, state) {
          if (!state.loaded && !_loadFailed) {
            return const Center(
              key: Key('liked-loading'),
              child: CircularProgressIndicator(),
            );
          }
          final entries = state.entries.reversed.toList(); // newest first
          if (entries.isEmpty) return _empty(context);
          _fetchMissing(entries);
          return ListView.separated(
            key: const Key('liked-list'),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _row(context, entries[i]),
          );
        },
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      key: const Key('liked-empty'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_border_rounded,
              size: 56,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.likedProductsEmpty,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              l10n.likedProductsEmptyHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, FavoriteEntry entry) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final known = _products.containsKey(entry.productId);
    final product = _products[entry.productId];

    // Still being read.
    if (!known) {
      return const Card(
        key: Key('liked-row-loading'),
        child: SizedBox(
          height: 88,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    // The shop removed it: say so, and let the shopper drop it from the list.
    if (product == null) {
      return Card(
        key: Key('liked-row-gone-${entry.productId}'),
        child: ListTile(
          leading: const Icon(Icons.remove_shopping_cart_outlined),
          title: Text(l10n.likedProductUnavailable),
          trailing: IconButton(
            tooltip: l10n.likedProductRemove,
            icon: const Icon(Icons.close),
            onPressed: () =>
                context.read<WishlistCubit>().unlike(entry.productId),
          ),
        ),
      );
    }

    const symbol = '₹';
    return Card(
      key: Key('liked-row-${product.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.productPath(product.id)),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              AppProductImage.product(
                product: product,
                width: 68,
                height: 68,
                borderRadius: BorderRadius.circular(10),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          formatCurrency(product.price, symbol: symbol),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (product.isDiscounted) ...[
                          const SizedBox(width: 6),
                          Text(
                            formatCurrency(product.mrp, symbol: symbol),
                            style: theme.textTheme.bodySmall?.copyWith(
                              decoration: TextDecoration.lineThrough,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // The same heart as everywhere: tap to unlike.
              FavoriteButton(product: product),
            ],
          ),
        ),
      ),
    );
  }
}
