import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The packer's tick-marks for one order ("this line is in the box").
///
/// They are a working aid, not order data, so they live on the device instead
/// of in the order document: they survive leaving the screen and a browser
/// refresh, and the order schema stays untouched. [revision] changes on every
/// save so order cards can refresh their progress.
class PackingChecklist {
  const PackingChecklist._();

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static String _key(String orderId) => 'packing_checks_$orderId';

  static Future<Set<int>> load(String orderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_key(orderId)) ?? const <String>[])
          .map(int.tryParse)
          .whereType<int>()
          .toSet();
    } catch (_) {
      return <int>{};
    }
  }

  static Future<void> save(String orderId, Set<int> checked) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _key(orderId),
        checked.map((e) => '$e').toList(),
      );
    } catch (_) {
      // Ticks are a convenience: failing to store them must not block packing.
    }
    revision.value++;
  }

  static Future<void> clear(String orderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(orderId));
    } catch (_) {}
    revision.value++;
  }
}
