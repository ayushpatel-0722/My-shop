import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myshop/core/widgets/app_toast.dart';

import '../../app/l10n/app_localizations.dart';
import '../../features/checkout/cart/wishlist_cubit.dart';
import '../models/favorite.dart';
import '../models/product.dart';
import 'auth_guard.dart';

/// The one place that decides what a tap on a product's heart does.
///
///  * a guest is taken through the normal login first, and the tap then means
///    "like" (never "unlike" something that happened to be saved already);
///  * a liked product is unliked;
///  * a new product is liked, unless the list already holds
///    [maxFavoriteProducts]: then the shopper must confirm that the oldest
///    favourite will be replaced, and nothing changes until they do.
///
/// Failures (offline, rules, timeouts) leave the list as it was and show a
/// message instead of an inconsistent heart.
class FavoriteActions {
  const FavoriteActions._();

  /// True while the replace dialog is open, so further taps are ignored.
  static bool _dialogOpen = false;

  /// Toggles [product] for the current shopper.
  static Future<void> toggle(BuildContext context, Product product) =>
      _run(context, product, likeOnly: false);

  /// Likes [product] (used for "move to wishlist"); never unlikes.
  ///
  /// [cubit] is for callers whose own context may be gone by the time they
  /// run (a swiped-away cart row): they read it up front and pass it in.
  static Future<void> add(
    BuildContext context,
    Product product, {
    WishlistCubit? cubit,
  }) => _run(context, product, likeOnly: true, cubit: cubit);

  static Future<void> _run(
    BuildContext context,
    Product product, {
    required bool likeOnly,
    WishlistCubit? cubit,
  }) async {
    if (_dialogOpen || product.id.isEmpty) return;
    // Everything the action needs is captured now: the tapped widget (a cart
    // row, say) may be gone by the time login or the dialog finishes. The
    // navigator's context outlives it and still sits under the providers.
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navContext = Navigator.of(context).context;
    final WishlistCubit favorites;
    try {
      favorites = cubit ?? context.read<WishlistCubit>();
    } catch (_) {
      return; // no favourites in this part of the app
    }

    var onlyLike = likeOnly;
    if (!AuthGuard.isAuthenticated(navContext)) {
      onlyLike = true;
      final signedIn = await AuthGuard.runWithAuth(
        navContext,
        message: l10n.favLoginRequired,
        onAuthenticated: () {},
      );
      if (!signedIn) return;
    }

    try {
      await favorites.prepare();
    } catch (_) {
      _fail(messenger, l10n);
      return;
    }

    final liked = favorites.state.contains(product.id);
    try {
      if (liked) {
        if (!onlyLike) await favorites.unlike(product.id);
        return;
      }
      if (favorites.state.isFull) {
        if (!navContext.mounted) return;
        if (!await _confirmReplace(navContext)) return;
        await favorites.like(product, replaceOldest: true);
      } else {
        await favorites.like(product);
      }
    } on FavoriteLimitReached {
      // Another device filled the list meanwhile: ask again on the next tap.
      _fail(messenger, l10n);
    } catch (_) {
      _fail(messenger, l10n);
    }
  }

  static void _fail(ScaffoldMessengerState messenger, AppLocalizations l10n) {
    messenger.showAppToast(
      SnackBar(
        content: Text(l10n.favSyncFailed),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static Future<bool> _confirmReplace(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    _dialogOpen = true;
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          key: const Key('favorite-limit-dialog'),
          title: Text(l10n.favLimitTitle),
          content: Text(l10n.favLimitBody(maxFavoriteProducts)),
          actions: [
            TextButton(
              key: const Key('favorite-limit-cancel'),
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              key: const Key('favorite-limit-confirm'),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.favReplaceOldest),
            ),
          ],
        ),
      );
      return ok == true;
    } finally {
      _dialogOpen = false;
    }
  }
}
