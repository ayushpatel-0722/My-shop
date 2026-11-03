import 'dart:async';
import 'dart:collection';

import 'cache_policy.dart';

/// When a shared query last received data, for freshness decisions.
class CacheStamp {
  final DateTime updatedAt;
  final bool listening;
  const CacheStamp(this.updatedAt, this.listening);
}

/// One live query shared by every widget that asks for it.
///
/// Without this each widget opens its own Firestore listener, so the home
/// screen paid for the same shops/categories/products many times over. Now:
///  * one listener per query, however many widgets watch it;
///  * a new watcher is shown the last value at once (revisiting a screen has
///    no spinner) while the listener is — or is again — bringing fresh data;
///  * when nobody watches, the listener closes after a short keep-alive but
///    the last value stays for `maxAge`, then is dropped;
///  * a failed refresh never clears a value that is already there;
///  * a result from an earlier subscription can never overwrite a newer one.
///
/// Only public/shared data goes through here. Private, per-user streams (an
/// account's orders, favourites, notifications) are never kept, so one
/// account can not be shown another's data.
class SharedStreams {
  SharedStreams({CachePolicy? policy, DateTime Function()? now})
    : policy = policy ?? CachePolicy.standard,
      _now = now ?? DateTime.now;

  /// Process-wide instance used by the repository.
  static SharedStreams instance = SharedStreams();

  final CachePolicy policy;
  final DateTime Function() _now;

  // Insertion order = least recently used first (re-inserted on every use).
  final LinkedHashMap<String, _Entry<dynamic>> _entries = LinkedHashMap();

  int get entryCount => _entries.length;

  /// How many upstream subscriptions are open right now (for tests/metrics).
  int get activeListeners => _entries.values.where((e) => e.sub != null).length;

  CacheStamp? stampFor(String key) {
    final e = _entries[key];
    if (e == null || !e.hasValue) return null;
    return CacheStamp(e.updatedAt!, e.sub != null);
  }

  /// The shared stream for [key]. [source] is called to (re)open the real
  /// query. Callers must put everything that changes the result into [key].
  Stream<T> stream<T>(String key, DataClass cls, Stream<T> Function() source) {
    final shared = Stream<T>.multi((controller) {
      final entry = _touch<T>(key, cls, source);
      entry.watchers.add(controller);
      _trim(); // after the watcher is counted, so this entry is never a victim
      entry.idleTimer?.cancel();
      entry.idleTimer = null;
      if (entry.hasValue && !entry.isExpired(_now())) {
        controller.add(entry.value as T);
      }
      _ensureListening(entry);
      controller.onCancel = () {
        entry.watchers.remove(controller);
        if (entry.watchers.isEmpty) _scheduleClose(entry);
      };
    }, isBroadcast: true);
    return ReplayStream<T>(shared, () {
      final e = _entries[key];
      if (e == null || !e.hasValue || e.isExpired(_now())) return null;
      return e.value as T;
    });
  }

  _Entry<T> _touch<T>(String key, DataClass cls, Stream<T> Function() source) {
    var entry = _entries.remove(key) as _Entry<T>?;
    entry ??= _Entry<T>(key, cls, source, policy);
    entry.source = source;
    _entries[key] = entry; // most recently used = last
    return entry;
  }

  void _ensureListening<T>(_Entry<T> entry) {
    if (entry.sub != null) return;
    final generation = ++entry.generation;
    entry.sub = entry.source().listen(
      (value) {
        if (generation != entry.generation) {
          return; // a newer subscription owns it
        }
        entry.value = value;
        entry.hasValue = true;
        entry.updatedAt = _now();
        for (final w in List.of(entry.watchers)) {
          w.add(value);
        }
      },
      onError: (Object e, StackTrace st) {
        if (generation != entry.generation) {
          return;
        }
        // Keep what we have; only a watcher with nothing to show hears of it.
        if (!entry.hasValue) {
          for (final w in List.of(entry.watchers)) {
            w.addError(e, st);
          }
        }
        // Reopen on the next watcher instead of staying on a dead stream.
        entry.sub?.cancel();
        entry.sub = null;
      },
      onDone: () {
        if (generation != entry.generation) return;
        entry.sub = null;
      },
    );
  }

  void _scheduleClose<T>(_Entry<T> entry) {
    entry.idleTimer?.cancel();
    entry.idleTimer = Timer(policy.keepAliveFor(entry.cls), () {
      entry.idleTimer = null;
      if (entry.watchers.isNotEmpty) return;
      entry.generation++; // late events from the closing subscription: ignored
      entry.sub?.cancel();
      entry.sub = null;
    });
  }

  void _trim() {
    // Expired, unwatched entries first, then least recently used.
    final now = _now();
    _entries.removeWhere(
      (_, e) => e.watchers.isEmpty && e.sub == null && e.isExpired(now),
    );
    while (_entries.length > policy.maxSharedEntries) {
      final victim = _entries.entries.firstWhere(
        (e) => e.value.watchers.isEmpty,
        orElse: () => _entries.entries.first,
      );
      if (victim.value.watchers.isNotEmpty) break; // everything is in use
      victim.value.dispose();
      _entries.remove(victim.key);
    }
  }

  /// Forgets everything whose key starts with [prefix] (all when empty) and
  /// closes their listeners. Used when the signed-in account changes.
  void clear([String prefix = '']) {
    final keys = _entries.keys.where((k) => k.startsWith(prefix)).toList();
    for (final k in keys) {
      final e = _entries.remove(k)!;
      e.dispose();
      // Open watchers keep working: they get a fresh subscription.
      if (e.watchers.isNotEmpty) {
        e.hasValue = false;
        e.value = null;
        _entries[k] = e;
        _ensureListening(e);
      }
    }
  }
}

class _Entry<T> {
  _Entry(this.key, this.cls, this.source, this.policy);

  final String key;
  final DataClass cls;
  final CachePolicy policy;
  Stream<T> Function() source;

  final List<MultiStreamController<T>> watchers = [];
  StreamSubscription<T>? sub;
  Timer? idleTimer;
  int generation = 0;

  bool hasValue = false;
  Object? value;
  DateTime? updatedAt;

  bool isExpired(DateTime now) =>
      !hasValue || now.difference(updatedAt!) > policy.maxAgeFor(cls);

  void dispose() {
    idleTimer?.cancel();
    generation++;
    sub?.cancel();
    sub = null;
  }
}

/// A shared stream that can also say what it last emitted, so a screen can
/// draw that at once (a StreamBuilder's `initialData`) instead of showing a
/// loader for the instant before the first event arrives.
class ReplayStream<T> extends Stream<T> {
  ReplayStream(this._inner, this._latest);

  final Stream<T> _inner;
  final T? Function() _latest;

  /// The last value still considered usable, or null.
  T? get latest => _latest();

  @override
  bool get isBroadcast => true;

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _inner.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
}
