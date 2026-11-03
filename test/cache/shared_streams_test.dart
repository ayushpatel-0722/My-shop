import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/cache/cache_policy.dart';
import 'package:myshop/core/cache/shared_streams.dart';

void main() {
  const fast = CachePolicy(
    keepAlive: {
      DataClass.reference: Duration(milliseconds: 40),
      DataClass.catalog: Duration(milliseconds: 40),
      DataClass.volatile: Duration(milliseconds: 40),
    },
    maxAge: {
      DataClass.reference: Duration(seconds: 5),
      DataClass.catalog: Duration(seconds: 5),
      DataClass.volatile: Duration(seconds: 5),
    },
    maxSharedEntries: 3,
  );

  late SharedStreams shared;
  late List<StreamController<List<int>>> upstreams;

  Stream<List<int>> source() {
    final c = StreamController<List<int>>.broadcast();
    upstreams.add(c);
    return c.stream;
  }

  setUp(() {
    shared = SharedStreams(policy: fast);
    upstreams = [];
  });

  Future<void> tick([int ms = 5]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  test('many watchers share one upstream listener', () async {
    final a = <List<int>>[], b = <List<int>>[], c = <List<int>>[];
    final s = shared.stream('k', DataClass.reference, source);
    final subs = [s.listen(a.add), s.listen(b.add), s.listen(c.add)];
    await tick();
    expect(upstreams.length, 1);
    upstreams.first.add([1]);
    await tick();
    expect(a, [
      [1],
    ]);
    expect(b, [
      [1],
    ]);
    expect(c, [
      [1],
    ]);
    for (final x in subs) {
      await x.cancel();
    }
  });

  test('a later watcher gets the last value immediately', () async {
    final first = shared
        .stream('k', DataClass.reference, source)
        .listen((_) {});
    await tick();
    upstreams.first.add([7]);
    await tick();
    final seen = <List<int>>[];
    final late = shared
        .stream('k', DataClass.reference, source)
        .listen(seen.add);
    await tick();
    expect(seen, [
      [7],
    ], reason: 'replayed without waiting for the server');
    expect(upstreams.length, 1);
    await first.cancel();
    await late.cancel();
  });

  test(
    'the listener closes after the keep-alive but the value is kept',
    () async {
      var sub = shared.stream('k', DataClass.reference, source).listen((_) {});
      await tick();
      upstreams.first.add([1]);
      await tick();
      await sub.cancel();
      expect(shared.activeListeners, 1, reason: 'still open during keep-alive');
      await tick(80);
      expect(shared.activeListeners, 0);
      expect(upstreams.first.hasListener, isFalse);

      final seen = <List<int>>[];
      sub = shared.stream('k', DataClass.reference, source).listen(seen.add);
      await tick();
      expect(seen, [
        [1],
      ], reason: 'old value shown at once');
      expect(upstreams.length, 2, reason: 'and a fresh listener started');
      upstreams.last.add([2]);
      await tick();
      expect(seen, [
        [1],
        [2],
      ], reason: 'then refreshed in place');
      await sub.cancel();
    },
  );

  test('coming back within the keep-alive reuses the same listener', () async {
    var sub = shared.stream('k', DataClass.reference, source).listen((_) {});
    await tick();
    await sub.cancel();
    await tick(10);
    sub = shared.stream('k', DataClass.reference, source).listen((_) {});
    await tick(80);
    expect(upstreams.length, 1);
    expect(shared.activeListeners, 1);
    await sub.cancel();
  });

  test(
    'a failed refresh keeps the value and does not error the watchers',
    () async {
      final seen = <List<int>>[];
      final errors = <Object>[];
      final sub = shared
          .stream('k', DataClass.reference, source)
          .listen(seen.add, onError: errors.add);
      await tick();
      upstreams.first.add([1]);
      await tick();
      upstreams.first.addError(StateError('offline'));
      await tick();
      expect(errors, isEmpty);
      expect(shared.stampFor('k'), isNotNull, reason: 'value kept');

      // The next watcher restarts the listener and still sees the old value.
      final again = <List<int>>[];
      final sub2 = shared
          .stream('k', DataClass.reference, source)
          .listen(again.add);
      await tick();
      expect(again, [
        [1],
      ]);
      expect(upstreams.length, 2);
      await sub.cancel();
      await sub2.cancel();
    },
  );

  test('an error with nothing to show reaches the watcher', () async {
    final errors = <Object>[];
    final sub = shared
        .stream('k', DataClass.reference, source)
        .listen((_) {}, onError: errors.add);
    await tick();
    upstreams.first.addError(StateError('boom'));
    await tick();
    expect(errors.single, isA<StateError>());
    await sub.cancel();
  });

  test('a value older than the max age is not replayed', () async {
    var t = DateTime(2026);
    final s = SharedStreams(
      policy: const CachePolicy(
        keepAlive: {DataClass.reference: Duration(milliseconds: 10)},
        maxAge: {DataClass.reference: Duration(minutes: 1)},
      ),
      now: () => t,
    );
    var sub = s.stream('k', DataClass.reference, source).listen((_) {});
    await tick();
    upstreams.first.add([1]);
    await tick();
    await sub.cancel();
    await tick(40);
    t = t.add(const Duration(minutes: 2));
    final seen = <List<int>>[];
    sub = s.stream('k', DataClass.reference, source).listen(seen.add);
    await tick();
    expect(seen, isEmpty, reason: 'expired: wait for fresh data instead');
    await sub.cancel();
  });

  test('events of a closed subscription never overwrite newer data', () async {
    var sub = shared.stream('k', DataClass.reference, source).listen((_) {});
    await tick();
    final old = upstreams.first;
    await sub.cancel();
    await tick(80); // listener closed
    final seen = <List<int>>[];
    sub = shared.stream('k', DataClass.reference, source).listen(seen.add);
    await tick();
    upstreams.last.add([2]);
    old.add([1]); // a late answer from before
    await tick();
    expect(seen, [
      [2],
    ]);
    await sub.cancel();
  });

  test('least recently used queries are dropped beyond the limit', () async {
    for (final k in ['a', 'b', 'c']) {
      final sub = shared.stream(k, DataClass.reference, source).listen((_) {});
      await tick();
      await sub.cancel();
    }
    final sub = shared.stream('d', DataClass.reference, source).listen((_) {});
    await tick();
    expect(shared.entryCount, lessThanOrEqualTo(3));
    expect(shared.stampFor('a'), isNull, reason: 'oldest went first');
    await sub.cancel();
  });

  test(
    'clear forgets values, and live watchers get a fresh listener',
    () async {
      final seen = <List<int>>[];
      final sub = shared
          .stream('acct|1', DataClass.reference, source)
          .listen(seen.add);
      await tick();
      upstreams.first.add([1]);
      await tick();
      shared.clear('acct|');
      await tick();
      expect(upstreams.length, 2, reason: 'resubscribed');
      upstreams.last.add([9]);
      await tick();
      expect(seen.last, [9]);
      await sub.cancel();
      shared.clear();
      expect(shared.entryCount, 0);
      expect(shared.stampFor('acct|1'), isNull);
    },
  );

  test('different keys are independent queries', () async {
    final a = shared.stream('a', DataClass.reference, source).listen((_) {});
    final b = shared.stream('b', DataClass.reference, source).listen((_) {});
    await tick();
    expect(upstreams.length, 2);
    await a.cancel();
    await b.cancel();
  });
}
