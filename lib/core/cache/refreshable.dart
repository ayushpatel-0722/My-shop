import 'dart:async';

import 'package:flutter/foundation.dart';

/// One piece of data that is shown from memory and refreshed in the
/// background — for data that is fetched once rather than streamed.
///
/// What it guarantees:
///  * the last good value stays available and is never cleared by a failed
///    refresh (the error is recorded, the value kept);
///  * at most one request runs at a time: asking again while one is in flight
///    joins it, so rapid navigation can not fire the same call twice;
///  * a fresh value (younger than [ttl]) is not fetched again unless forced;
///  * an answer that arrives after the data was [invalidate]d or [clear]ed
///    (a different account, say) is thrown away, never shown;
///  * listeners are told only when something they show changed: a refresh that
///    returns the same data does not rebuild anything.
class Refreshable<T> extends ChangeNotifier {
  Refreshable({
    required this.load,
    this.ttl = const Duration(minutes: 5),
    this.equals,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Fetches the latest value.
  final Future<T> Function() load;

  /// How long a value counts as fresh.
  final Duration ttl;

  /// Whether two values are the same data. Defaults to `==`.
  final bool Function(T a, T b)? equals;

  final DateTime Function() _now;

  T? _value;
  bool _hasValue = false;
  DateTime? _updatedAt;
  Object? _error;
  Future<void>? _inFlight;
  int _generation = 0;
  Timer? _timer;
  bool _disposed = false;

  bool get hasValue => _hasValue;
  T? get value => _value;
  Object? get error => _error;
  DateTime? get updatedAt => _updatedAt;

  /// First load, nothing to show yet: the only time a full loader is right.
  bool get isInitialLoading => _inFlight != null && !_hasValue;

  /// A refresh behind content that is already on screen: show no loader.
  bool get isRefreshing => _inFlight != null && _hasValue;

  bool get isStale =>
      !_hasValue || _updatedAt == null || _now().difference(_updatedAt!) >= ttl;

  /// Loads the value if it is missing or stale (or [force]d). Calls made while
  /// a request is in flight share it.
  Future<void> refresh({bool force = false}) {
    if (_inFlight != null) return _inFlight!;
    if (!force && !isStale) return Future<void>.value();
    final generation = _generation;
    final wasInitial = !_hasValue;
    if (wasInitial) _notify(); // let the loader appear
    late final Future<void> run;
    run = _run(generation).whenComplete(() {
      // A block body on purpose: returning the future from here would make it
      // wait on itself.
      if (identical(_inFlight, run)) _inFlight = null;
    });
    _inFlight = run;
    return run;
  }

  Future<void> _run(int generation) async {
    try {
      final fresh = await load();
      if (generation != _generation) return; // outdated: drop it
      final changed =
          !_hasValue || !(equals?.call(_value as T, fresh) ?? _value == fresh);
      final hadError = _error != null;
      _error = null;
      _updatedAt = _now();
      if (changed) {
        _value = fresh;
        _hasValue = true;
      }
      // The first load always notifies (the loader goes away); later ones only
      // when the data or the error state actually changed.
      if (changed || hadError) _notify();
    } catch (e) {
      if (generation != _generation) return;
      final first = _error == null;
      _error = e;
      // The old value stays. Only tell listeners if the error is news, or if
      // there is nothing else to show.
      if (first || !_hasValue) _notify();
    }
  }

  /// Refreshes after [delay], once, however many times this is called in the
  /// meantime — so switching tabs quickly asks the server once, not on every
  /// tap. A fresh value is still not fetched again.
  void scheduleRefresh(Duration delay, {bool force = false}) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      _timer = null;
      if (!_disposed) refresh(force: force);
    });
  }

  /// Marks the value stale (an order was placed, say) but keeps showing it
  /// until the next refresh replaces it. An answer already on its way is
  /// discarded: it may predate the change.
  void invalidate() {
    _generation++;
    _inFlight = null;
    _updatedAt = null;
  }

  /// Forgets the value completely (a different account signed in).
  void clear() {
    invalidate();
    _timer?.cancel();
    _timer = null;
    _value = null;
    _hasValue = false;
    _error = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
