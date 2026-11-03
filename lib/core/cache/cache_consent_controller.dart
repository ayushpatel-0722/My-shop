import 'package:flutter/foundation.dart';

import 'cache_consent.dart';
import 'storage_persistence.dart';

/// Holds the shopper's answer to the cache-consent question and carries it out.
///
/// The app starts straight away; on the web, when nothing is stored yet, a
/// prompt is shown *over* the app (see CacheConsentPrompt) and the app keeps
/// running with nothing saved on disk until the answer comes. Android and iOS
/// never ask.
class CacheConsentController extends ChangeNotifier {
  CacheConsentController({
    required CacheConsent initial,
    required this.isWeb,
    required this.onApply,
    CacheConsentStore? store,
    this.persistence,
  }) : _value = isWeb ? initial : CacheConsent.allowed,
       _store = store ?? CacheConsentStore();

  /// The one used by the running app (set in `main`); null in tests.
  static CacheConsentController? instance;

  final bool isWeb;

  /// Applies the consent to the caches (Firestore persistence). Called once at
  /// start with the stored answer — "undecided" counts as no disk caching —
  /// and again when the shopper answers.
  final void Function(CacheConsent consent) onApply;

  final CacheConsentStore _store;

  /// Browser storage API; defaults to the real one. Replaceable in tests.
  final StoragePersistenceApi? persistence;

  CacheConsent _value;
  bool _busy = false;

  CacheConsent get value => _value;
  bool get busy => _busy;

  /// True while the question is open: web only, and not answered yet.
  bool get needsPrompt => isWeb && _value == CacheConsent.undecided;

  /// Applies the stored answer. Call before the app first reads data.
  void start() => onApply(_value);

  /// Records [choice]. Ignored while one is being recorded or once answered,
  /// so a double tap never asks the browser twice.
  Future<void> choose(CacheConsent choice) async {
    if (!needsPrompt || _busy || choice == CacheConsent.undecided) return;
    _busy = true;
    notifyListeners();
    await _store.write(choice);
    if (choice == CacheConsent.allowed) {
      // Agreeing and the browser agreeing are different things: ask, and
      // carry on whatever it answers (denied / unsupported only means the
      // browser may evict the cache; the size limits still apply).
      try {
        await (persistence ?? createStoragePersistence()).request();
      } catch (_) {}
    }
    _value = choice;
    _busy = false;
    onApply(choice);
    notifyListeners();
  }
}
