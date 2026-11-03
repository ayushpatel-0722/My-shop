import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/favorite.dart';
import '../../../core/models/product.dart';
import '../../../core/repositories/app_repository.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/services/service_locator.dart';

/// The signed-in shopper's favourite ("liked") products.
///
/// The list lives in Firestore, one document per user (see
/// `AppRepository.favorites`), and is kept in order: oldest like first. At most
/// [maxFavoriteProducts] products can be liked; liking one more needs the
/// caller to opt in with `replaceOldest`, which drops the oldest like.
///
/// Every change goes through one queue, so rapid taps cannot interleave or
/// push the list over the limit. A change shows in the UI at once and is
/// rolled back if saving it fails.
class WishlistState {
  /// Liked products, oldest first.
  final List<FavoriteEntry> entries;

  /// True once the saved list has been read for the current user.
  final bool loaded;

  const WishlistState({
    this.entries = const <FavoriteEntry>[],
    this.loaded = false,
  });

  bool contains(String productId) =>
      entries.any((e) => e.productId == productId);

  int get count => entries.length;

  bool get isFull => count >= maxFavoriteProducts;

  /// The like that a 26th product would replace.
  FavoriteEntry? get oldest => entries.isEmpty ? null : entries.first;
}

class WishlistCubit extends Cubit<WishlistState> {
  WishlistCubit({AppRepository Function()? repository})
    : _repoOf = repository ?? (() => repo),
      super(const WishlistState());

  final AppRepository Function() _repoOf;

  /// How long a like waits for the saved list to load before giving up.
  static const loadTimeout = Duration(seconds: 10);

  String? _userId;
  StreamSubscription<List<FavoriteEntry>>? _sub;
  Completer<void> _loaded = Completer<void>();
  bool _loadFailed = false;
  Future<void> _queue = Future<void>.value();
  int _pending = 0;
  List<FavoriteEntry>? _latest;

  /// The user whose favourites are loaded (null when signed out).
  String? get userId => _userId;

  /// Follows [userId]'s favourites; null (sign-out) clears everything.
  ///
  /// Called whenever the signed-in user changes, so one account's list is
  /// never shown to the next.
  void bindUser(String? userId) {
    if (userId == _userId && (userId == null || _sub != null)) return;
    _sub?.cancel();
    _sub = null;
    _userId = userId;
    _latest = null;
    _loadFailed = false;
    _loaded = Completer<void>();
    if (isClosed) return;
    emit(const WishlistState());
    if (userId == null || userId.isEmpty) return;
    _subscribe(userId);
  }

  void _subscribe(String userId) {
    _sub?.cancel();
    _loadFailed = false;
    if (_loaded.isCompleted) _loaded = Completer<void>();
    _sub = _repoOf()
        .favorites(userId)
        .listen(
          (entries) {
            if (_userId != userId || isClosed) return;
            _latest = entries;
            // A snapshot that arrives mid-save would flicker the heart: it is
            // applied once the queue is empty.
            if (_pending == 0) {
              emit(WishlistState(entries: entries, loaded: true));
            }
            if (!_loaded.isCompleted) _loaded.complete();
          },
          onError: (Object e, StackTrace st) {
            if (_userId != userId) return;
            _loadFailed = true;
            if (!_loaded.isCompleted) _loaded.completeError(e, st);
          },
        );
  }

  /// Completes once the current user's saved list has been read.
  ///
  /// Throws [TimeoutException] or the load error, in which case the next call
  /// subscribes again.
  Future<void> ensureLoaded() async {
    if (_userId == null) throw StateError('Sign in to use favourites.');
    if (_loadFailed) _subscribe(_userId!);
    try {
      await _loaded.future.timeout(loadTimeout);
    } catch (_) {
      _loadFailed = true;
      rethrow;
    }
  }

  /// Binds to the signed-in user and waits for their saved list; returns the
  /// user id. Call before reading [state] to decide what a tap should do.
  Future<String> prepare() async {
    final id = AuthSession.currentUser?.id ?? _userId;
    if (id == null || id.isEmpty) {
      throw StateError('Sign in to use favourites.');
    }
    if (_userId != id) {
      bindUser(id);
    }
    await ensureLoaded();
    return id;
  }

  /// Likes [product]. A product that is already liked is left as it is.
  ///
  /// With a full list, throws [FavoriteLimitReached] unless [replaceOldest] is
  /// true, in which case the oldest like is removed to make room.
  Future<void> like(Product product, {bool replaceOldest = false}) async {
    if (product.id.isEmpty) return;
    final uid = await prepare();
    final entry = FavoriteEntry(
      productId: product.id,
      companyId: product.companyId,
      addedAt: DateTime.now(),
    );
    await _enqueue(uid, (current) {
      if (current.any((e) => e.productId == product.id)) return current;
      if (current.length >= maxFavoriteProducts) {
        if (!replaceOldest) throw const FavoriteLimitReached();
        return [
          ...current.sublist(current.length - maxFavoriteProducts + 1),
          entry,
        ];
      }
      return [...current, entry];
    }, () => _repoOf().addFavorite(uid, entry, replaceOldest: replaceOldest));
  }

  /// Removes [productId] from the favourites.
  Future<void> unlike(String productId) async {
    final uid = await prepare();
    await _enqueue(
      uid,
      (current) => current.where((e) => e.productId != productId).toList(),
      () => _repoOf().removeFavorite(uid, productId),
    );
  }

  Future<void> _enqueue(
    String userId,
    List<FavoriteEntry> Function(List<FavoriteEntry> current) optimistic,
    Future<List<FavoriteEntry>> Function() commit,
  ) {
    final done = Completer<void>();
    _pending++;
    _queue = _queue.then((_) async {
      final before = state;
      try {
        if (_userId != userId || isClosed) return; // the account changed
        emit(WishlistState(entries: optimistic(before.entries), loaded: true));
        final saved = await commit();
        if (_userId == userId && !isClosed) {
          emit(WishlistState(entries: saved, loaded: true));
        }
        done.complete();
      } catch (e, st) {
        if (_userId == userId && !isClosed && state != before) emit(before);
        done.completeError(e, st);
      } finally {
        _pending--;
        if (!done.isCompleted) done.complete();
        final latest = _latest;
        if (_pending == 0 && latest != null && _userId == userId && !isClosed) {
          emit(WishlistState(entries: latest, loaded: true));
        }
      }
    });
    return done.future;
  }

  /// Forgets the list on this device (it stays saved for the account).
  void clear() => bindUser(null);

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
