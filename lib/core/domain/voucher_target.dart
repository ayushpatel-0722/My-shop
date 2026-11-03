import '../models/voucher.dart';

/// Says where a voucher can be used: which shop, and on what.
///
/// Vouchers belong to one shop and apply to everything, to chosen categories,
/// or to chosen products. A shopper deciding whether a code is worth copying
/// needs exactly that, so cards show it as "GreenLeaf Organics · Spices".
class VoucherTarget {
  const VoucherTarget._();

  /// What the voucher applies to, for display.
  ///
  /// At most [maxNames] categories or products are named; the rest become
  /// "+N more". Ids that can not be resolved (a deleted category) are skipped,
  /// and when none can be, a generic phrase is used instead of nothing.
  static String appliesTo(
    Voucher v, {
    required Map<String, String> categoryNames,
    required Map<String, String> productNames,
    required String allProducts,
    required String selectedCategories,
    required String selectedProducts,
    required String Function(int count) more,
    int maxNames = 2,
  }) {
    String named(List<String> ids, Map<String, String> names, String fallback) {
      final found = <String>[
        for (final id in ids)
          if ((names[id] ?? '').trim().isNotEmpty) names[id]!.trim(),
      ];
      if (found.isEmpty) return fallback;
      final shown = found.take(maxNames).join(', ');
      final rest = found.length - maxNames;
      return rest > 0 ? '$shown ${more(rest)}' : shown;
    }

    switch (v.appliesTo) {
      case VoucherScope.specificCategory:
        return named(v.categoryIds, categoryNames, selectedCategories);
      case VoucherScope.specificProduct:
        return named(v.productIds, productNames, selectedProducts);
      default:
        return allProducts;
    }
  }

  /// "Shop · target" (or just the target when the shop is not known).
  static String label(
    Voucher v, {
    required String shopName,
    required String target,
  }) => shopName.trim().isEmpty ? target : '${shopName.trim()} · $target';
}
