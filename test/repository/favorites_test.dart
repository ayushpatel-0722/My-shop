import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/favorite.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/core/repositories/app_repository.dart';
import 'package:myshop/features/checkout/cart/wishlist_cubit.dart';

import '../helpers/test_harness.dart';

/// Favourite products: the 25 cap, replacing the oldest, duplicates, rapid
/// taps, account isolation and failure rollback — at the cubit + repository
/// level (the mock repository follows the same rules as Firestore).
void main() {
  late MockAppRepository mock;
  late WishlistCubit cubit;

  Product product(int i) => Product(
    id: 'p$i',
    companyId: 'c1',
    categoryId: 'cat',
    name: 'Product $i',
    amount: 10,
    stockQty: 5,
  );

  setUp(() {
    TestHarness.setupPlatformChannels();
    mock = TestHarness.useMockRepository();
    TestHarness.signIn(TestHarness.shopper);
    cubit = WishlistCubit()..bindUser(TestHarness.shopper.id);
  });

  tearDown(() async {
    await cubit.close();
    TestHarness.signOut();
  });

  Future<void> fill(int n) async {
    for (var i = 0; i < n; i++) {
      await cubit.like(product(i));
    }
  }

  List<String> ids() => cubit.state.entries.map((e) => e.productId).toList();

  test('likes up to 25 products in order, without any replacement', () async {
    await fill(25);
    expect(cubit.state.count, 25);
    expect(cubit.state.isFull, isTrue);
    expect(ids().first, 'p0');
    expect(ids().last, 'p24');
  });

  test(
    'the 26th like is refused unless replacing the oldest is confirmed',
    () async {
      await fill(25);
      await expectLater(
        cubit.like(product(25)),
        throwsA(isA<FavoriteLimitReached>()),
      );
      expect(cubit.state.count, 25);
      expect(cubit.state.contains('p25'), isFalse);
      expect(cubit.state.contains('p0'), isTrue);
    },
  );

  test('confirming removes the oldest and adds the new one', () async {
    await fill(25);
    await cubit.like(product(25), replaceOldest: true);
    expect(cubit.state.count, 25);
    expect(cubit.state.contains('p0'), isFalse);
    expect(ids().first, 'p1');
    expect(ids().last, 'p25');
    final saved = await mock.favorites('u_1').first;
    expect(saved.map((e) => e.productId), ids());
  });

  test(
    '"oldest" follows the order they were liked, not product order',
    () async {
      await cubit.like(product(9));
      for (var i = 100; i < 124; i++) {
        await cubit.like(product(i));
      }
      expect(cubit.state.isFull, isTrue);
      await cubit.like(product(0), replaceOldest: true);
      expect(cubit.state.contains('p9'), isFalse);
      expect(cubit.state.contains('p100'), isTrue);
      expect(ids().last, 'p0');
    },
  );

  test(
    'liking an already liked product changes nothing, even when full',
    () async {
      await fill(25);
      await cubit.like(product(3), replaceOldest: true);
      expect(cubit.state.count, 25);
      expect(ids().first, 'p0');
    },
  );

  test(
    'unliking removes it from state and storage; it can be re-added',
    () async {
      await fill(3);
      await cubit.unlike('p1');
      expect(cubit.state.contains('p1'), isFalse);
      expect((await mock.favorites('u_1').first).map((e) => e.productId), [
        'p0',
        'p2',
      ]);
      await cubit.like(product(1));
      expect(ids(), ['p0', 'p2', 'p1']);
    },
  );

  test('unliking something not liked is harmless', () async {
    await fill(2);
    await cubit.unlike('nope');
    expect(ids(), ['p0', 'p1']);
  });

  test('rapid taps on one product save it once', () async {
    await Future.wait([for (var i = 0; i < 10; i++) cubit.like(product(7))]);
    expect(ids(), ['p7']);
    expect((await mock.favorites('u_1').first).length, 1);
  });

  test('rapid taps on many products never pass the limit', () async {
    final results = await Future.wait([
      for (var i = 0; i < 40; i++)
        cubit.like(product(i)).then((_) => true).catchError((_) => false),
    ]);
    expect(cubit.state.count, maxFavoriteProducts);
    expect(results.where((ok) => ok).length, maxFavoriteProducts);
    expect((await mock.favorites('u_1').first).length, maxFavoriteProducts);
  });

  test('rapid like then unlike ends unliked', () async {
    final a = cubit.like(product(5));
    final b = cubit.unlike('p5');
    await Future.wait([a, b]);
    expect(cubit.state.contains('p5'), isFalse);
    expect(await mock.favorites('u_1').first, isEmpty);
  });

  test('a new session loads what was saved (persistence)', () async {
    await fill(4);
    final again = WishlistCubit()..bindUser('u_1');
    addTearDown(again.close);
    await again.ensureLoaded();
    expect(again.state.entries.map((e) => e.productId), [
      'p0',
      'p1',
      'p2',
      'p3',
    ]);
    expect(again.state.loaded, isTrue);
  });

  test('switching account never shows or touches the other list', () async {
    await fill(3);
    cubit.bindUser('u_2');
    expect(cubit.state.count, 0);
    await cubit.ensureLoaded();
    expect(cubit.state.count, 0);

    TestHarness.signIn(TestHarness.shopper.copyWith(id: 'u_2'));
    await cubit.like(product(50));
    expect(ids(), ['p50']);
    expect((await mock.favorites('u_1').first).length, 3);

    cubit.bindUser('u_1');
    await cubit.ensureLoaded();
    expect(ids(), ['p0', 'p1', 'p2']);
  });

  test('signing out clears the list from memory but keeps it saved', () async {
    await fill(2);
    cubit.bindUser(null);
    expect(cubit.state.count, 0);
    expect(cubit.userId, isNull);
    expect((await mock.favorites('u_1').first).length, 2);
  });

  test('a stale write for a previous account is dropped', () async {
    final slow = _SlowRepo(mock);
    final c = WishlistCubit(repository: () => slow)..bindUser('u_1');
    addTearDown(c.close);
    await c.ensureLoaded();
    final pending = c.like(product(1));
    await Future<void>.delayed(Duration.zero);
    c.bindUser('u_2');
    slow.release();
    await pending;
    expect(c.state.count, 0);
    expect(c.userId, 'u_2');
  });

  group('failures', () {
    test('a failed like rolls the list back and reports the error', () async {
      await fill(2);
      final failing = _FailingRepo(mock)..failWrites = true;
      final c = WishlistCubit(repository: () => failing)..bindUser('u_1');
      addTearDown(c.close);
      await c.ensureLoaded();
      await expectLater(c.like(product(9)), throwsA(isA<StateError>()));
      expect(c.state.entries.map((e) => e.productId), ['p0', 'p1']);
      failing.failWrites = false;
      await c.like(product(9));
      expect(c.state.contains('p9'), isTrue);
    });

    test('a failed unlike restores the heart', () async {
      await fill(2);
      final failing = _FailingRepo(mock)..failWrites = true;
      final c = WishlistCubit(repository: () => failing)..bindUser('u_1');
      addTearDown(c.close);
      await c.ensureLoaded();
      await expectLater(c.unlike('p0'), throwsA(isA<StateError>()));
      expect(c.state.contains('p0'), isTrue);
    });

    test('a failure in one queued tap does not block the next', () async {
      final failing = _FailingRepo(mock)..failNextWrite = true;
      final c = WishlistCubit(repository: () => failing)..bindUser('u_1');
      addTearDown(c.close);
      await c.ensureLoaded();
      final first = c
          .like(product(1))
          .then((_) => true)
          .catchError((_) => false);
      final second = c.like(product(2));
      expect(await first, isFalse);
      await second;
      expect(c.state.entries.map((e) => e.productId), ['p2']);
    });

    test('a load that never answers times out and can be retried', () async {
      final failing = _FailingRepo(mock)..neverLoad = true;
      final c = WishlistCubit(repository: () => failing)..bindUser('u_1');
      addTearDown(c.close);
      await expectLater(
        c.ensureLoaded().timeout(const Duration(milliseconds: 50)),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('a load error surfaces, then the next attempt recovers', () async {
      final failing = _FailingRepo(mock)..failLoadOnce = true;
      final c = WishlistCubit(repository: () => failing)..bindUser('u_1');
      addTearDown(c.close);
      await expectLater(c.ensureLoaded(), throwsA(isA<StateError>()));
      await c.ensureLoaded();
      expect(c.state.loaded, isTrue);
    });
  });

  group('repository', () {
    test('rejects the 26th unless replacing, never duplicates', () async {
      for (var i = 0; i < 25; i++) {
        await mock.addFavorite(
          'u',
          FavoriteEntry(
            productId: 'p$i',
            companyId: 'c',
            addedAt: DateTime(2026),
          ),
        );
      }
      final extra = FavoriteEntry(
        productId: 'x',
        companyId: 'c',
        addedAt: DateTime(2026),
      );
      await expectLater(
        mock.addFavorite('u', extra),
        throwsA(isA<FavoriteLimitReached>()),
      );
      final after = await mock.addFavorite('u', extra, replaceOldest: true);
      expect(after.length, 25);
      expect(after.first.productId, 'p1');
      expect(after.last.productId, 'x');
      expect(
        (await mock.addFavorite('u', extra, replaceOldest: true)).length,
        25,
      );
    });

    test('favourites are per user', () async {
      await mock.addFavorite(
        'a',
        FavoriteEntry(productId: 'p', companyId: 'c', addedAt: DateTime(2026)),
      );
      expect(await mock.favorites('b').first, isEmpty);
      expect((await mock.favorites('a').first).single.productId, 'p');
    });

    test('FavoriteEntry round-trips through its map', () {
      final e = FavoriteEntry(
        productId: 'p',
        companyId: 'c',
        addedAt: DateTime(2026, 3, 4, 5, 6, 7),
      );
      final back = FavoriteEntry.fromMap(e.toMap());
      expect(back.productId, 'p');
      expect(back.companyId, 'c');
      expect(back.addedAt, e.addedAt);
    });
  });
}

/// Wraps a repository, failing or stalling the favourites calls on demand.
class _FailingRepo implements AppRepository {
  _FailingRepo(this._inner);
  final MockAppRepository _inner;
  bool failWrites = false;
  bool failNextWrite = false;
  bool neverLoad = false;
  bool failLoadOnce = false;

  @override
  Stream<List<FavoriteEntry>> favorites(String userId) {
    if (neverLoad) return const Stream<List<FavoriteEntry>>.empty();
    if (failLoadOnce) {
      failLoadOnce = false;
      return Stream<List<FavoriteEntry>>.error(StateError('offline'));
    }
    return _inner.favorites(userId);
  }

  @override
  Future<List<FavoriteEntry>> addFavorite(
    String userId,
    FavoriteEntry entry, {
    bool replaceOldest = false,
  }) {
    if (failWrites || failNextWrite) {
      failNextWrite = false;
      return Future.error(StateError('offline'));
    }
    return _inner.addFavorite(userId, entry, replaceOldest: replaceOldest);
  }

  @override
  Future<List<FavoriteEntry>> removeFavorite(String userId, String productId) {
    if (failWrites) return Future.error(StateError('offline'));
    return _inner.removeFavorite(userId, productId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Holds writes until [release], to test an account change mid-save.
class _SlowRepo extends _FailingRepo {
  _SlowRepo(super.inner);
  final _gate = Completer<void>();
  void release() => _gate.complete();

  @override
  Future<List<FavoriteEntry>> addFavorite(
    String userId,
    FavoriteEntry entry, {
    bool replaceOldest = false,
  }) async {
    await _gate.future;
    return super.addFavorite(userId, entry, replaceOldest: replaceOldest);
  }
}
