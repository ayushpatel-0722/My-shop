import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/cache/refreshable.dart';

void main() {
  var now = DateTime(2026, 1, 1);
  late List<Completer<List<int>>> calls;
  late int notifications;

  Refreshable<List<int>> make({
    Duration ttl = const Duration(minutes: 5),
    bool Function(List<int>, List<int>)? equals,
  }) {
    final r = Refreshable<List<int>>(
      load: () {
        final c = Completer<List<int>>();
        calls.add(c);
        return c.future;
      },
      ttl: ttl,
      equals: equals ?? (a, b) => a.join(',') == b.join(','),
      now: () => now,
    );
    r.addListener(() => notifications++);
    return r;
  }

  setUp(() {
    now = DateTime(2026, 1, 1);
    calls = [];
    notifications = 0;
  });

  Future<void> tick([int ms = 5]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  test('the first load shows a loader, then the value', () async {
    final r = make();
    expect(r.hasValue, isFalse);
    final f = r.refresh();
    expect(r.isInitialLoading, isTrue);
    calls.single.complete([1, 2]);
    await f;
    expect(r.value, [1, 2]);
    expect(r.isInitialLoading, isFalse);
    expect(r.isRefreshing, isFalse);
    r.dispose();
  });

  test('requests made while one is running share it', () async {
    final r = make();
    final a = r.refresh();
    final b = r.refresh();
    final c = r.refresh(force: true);
    expect(calls.length, 1);
    calls.single.complete([1]);
    await Future.wait([a, b, c]);
    expect(calls.length, 1);
    r.dispose();
  });

  test('fresh data is not fetched again unless forced', () async {
    final r = make();
    final f = r.refresh();
    calls.last.complete([1]);
    await f;
    await r.refresh();
    expect(calls.length, 1, reason: 'still fresh');
    final g = r.refresh(force: true);
    calls.last.complete([1]);
    await g;
    expect(calls.length, 2);
    r.dispose();
  });

  test(
    'stale data is refreshed, and the old value stays visible meanwhile',
    () async {
      final r = make(ttl: const Duration(minutes: 1));
      var f = r.refresh();
      calls.last.complete([1]);
      await f;
      now = now.add(const Duration(minutes: 2));
      expect(r.isStale, isTrue);
      f = r.refresh();
      expect(r.isRefreshing, isTrue, reason: 'a refresh behind content');
      expect(r.isInitialLoading, isFalse, reason: 'no full-screen loader');
      expect(r.value, [1], reason: 'old content stays');
      calls.last.complete([1, 2]);
      await f;
      expect(r.value, [1, 2]);
      r.dispose();
    },
  );

  test('listeners hear only about real changes', () async {
    final r = make(ttl: Duration.zero);
    var f = r.refresh();
    calls.last.complete([1]);
    await f;
    final afterFirst = notifications;

    f = r.refresh(); // same data again
    calls.last.complete([1]);
    await f;
    expect(notifications, afterFirst, reason: 'unchanged: nothing rebuilt');

    f = r.refresh();
    calls.last.complete([1, 2]);
    await f;
    expect(notifications, afterFirst + 1, reason: 'changed: told once');
    r.dispose();
  });

  test('a failed refresh keeps the value; the error is recorded', () async {
    final r = make(ttl: Duration.zero);
    var f = r.refresh();
    calls.last.complete([7]);
    await f;
    f = r.refresh();
    calls.last.completeError(StateError('offline'));
    await f;
    expect(r.value, [7], reason: 'kept');
    expect(r.error, isA<StateError>());

    f = r.refresh(); // and it recovers
    calls.last.complete([8]);
    await f;
    expect(r.value, [8]);
    expect(r.error, isNull);
    r.dispose();
  });

  test('a first load that fails has no value and reports the error', () async {
    final r = make();
    final f = r.refresh();
    calls.last.completeError(StateError('no network'));
    await f;
    expect(r.hasValue, isFalse);
    expect(r.error, isNotNull);
    r.dispose();
  });

  test('an answer that arrives after clear() is thrown away', () async {
    final r = make();
    final f = r.refresh();
    r.clear(); // a different account signed in
    calls.last.complete([99]);
    await f;
    expect(r.hasValue, isFalse, reason: 'never shown to the new account');
    r.dispose();
  });

  test('an answer that predates invalidate() does not overwrite', () async {
    final r = make(ttl: Duration.zero);
    final f = r.refresh();
    calls.last.complete([1]);
    await f;
    final old = r.refresh();
    final oldCall = calls.last;
    r.invalidate(); // something changed: the request on its way may be old
    final newer = r.refresh();
    final newerCall = calls.last;
    expect(identical(oldCall, newerCall), isFalse);
    newerCall.complete([2]);
    await newer;
    oldCall.complete([1, 1, 1]); // the late, outdated answer
    await old;
    expect(r.value, [2]);
    r.dispose();
  });

  test('invalidate keeps showing the value but makes it stale', () async {
    final r = make();
    final f = r.refresh();
    calls.last.complete([1]);
    await f;
    expect(r.isStale, isFalse);
    r.invalidate();
    expect(r.isStale, isTrue);
    expect(r.value, [1]);
    r.dispose();
  });

  test('rapid scheduled refreshes ask the server once', () async {
    final r = make(ttl: Duration.zero);
    final f = r.refresh();
    calls.last.complete([1]);
    await f;
    calls.clear();
    for (var i = 0; i < 6; i++) {
      r.scheduleRefresh(const Duration(milliseconds: 30));
      await tick(5);
    }
    await tick(80);
    expect(calls.length, 1);
    calls.single.complete([1]);
    r.dispose();
  });

  test('a scheduled refresh respects freshness', () async {
    final r = make();
    final f = r.refresh();
    calls.last.complete([1]);
    await f;
    calls.clear();
    r.scheduleRefresh(const Duration(milliseconds: 10));
    await tick(50);
    expect(calls, isEmpty, reason: 'still fresh: no request');
    r.dispose();
  });

  test('disposing cancels a scheduled refresh', () async {
    final r = make(ttl: Duration.zero);
    final f = r.refresh();
    calls.last.complete([1]);
    await f;
    calls.clear();
    r.scheduleRefresh(const Duration(milliseconds: 20));
    r.dispose();
    await tick(60);
    expect(calls, isEmpty);
  });
}
