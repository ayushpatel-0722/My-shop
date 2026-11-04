import '../models/product.dart';

/// What a shop may do with its products under its plan.
///
/// The plan gives one number, `max_products`:
/// - at most [maxProducts] products can be **published** (visible to shoppers);
/// - the shop may hold up to [totalCap] products altogether, i.e. the plan
///   number plus [extraPercent]% of it, the extra ones staying unpublished.
///
/// Pure logic with no Firebase in it: the Add / Edit Product form, the
/// repositories and the tests all use it (the Cloud Function in
/// `functions/product_limits.js` applies the same rules on the server).
class ProductLimits {
  const ProductLimits(this.maxProducts);

  /// Share of the plan number that may be added as unpublished products.
  static const extraPercent = 20;

  /// The plan's `max_products`; null when the shop has no limit set.
  final int? maxProducts;

  bool get hasLimit => maxProducts != null;

  /// Plan number + 20% (whole products, rounded down): 50 -> 60.
  int? get totalCap {
    final max = maxProducts;
    return max == null ? null : max + (max * extraPercent) ~/ 100;
  }

  /// Decides a save. [others] are the shop's other products (the one being
  /// saved is left out, so an edit is never counted twice): [otherTotal] of
  /// them in all, [otherPublished] of them published.
  ProductLimitDecision decide({
    required bool isNew,
    required bool wasPublished,
    required bool wantsPublished,
    required int otherTotal,
    required int otherPublished,
  }) {
    final max = maxProducts;
    final cap = totalCap;
    if (max == null || cap == null) return ProductLimitDecision.allowed;

    // Creating is blocked once the shop holds the most it may.
    if (isNew && otherTotal >= cap) return ProductLimitDecision.createBlocked;

    // Publishing (a new product, or an unpublished one being switched on)
    // needs a free published slot. A product that is already published stays
    // published when edited.
    final publishing = wantsPublished && !(wasPublished && !isNew);
    if (publishing && otherPublished >= max) {
      return ProductLimitDecision.publishBlocked;
    }
    return ProductLimitDecision.allowed;
  }
}

enum ProductLimitDecision {
  /// Save as asked.
  allowed,

  /// The published limit is reached: save only if the product stays
  /// unpublished (ask the admin first).
  publishBlocked,

  /// The total limit is reached: do not create the product.
  createBlocked,
}

/// Thrown by a repository that refuses to create a product over the limit.
class ProductLimitException implements Exception {
  const ProductLimitException(this.cap);

  /// The most products the plan allows in total.
  final int cap;

  @override
  String toString() =>
      'ProductLimitException: the plan allows at most $cap products';
}

/// How many products a shop has: all of them, and the published ones.
class ProductCounts {
  const ProductCounts({required this.total, required this.published});

  final int total;
  final int published;

  int get unpublished => total - published;
}

extension ProductLimitsGuard on ProductLimits {
  /// What a repository must store for [product], given the shop's *other*
  /// products. Throws [ProductLimitException] when a new product would go over
  /// the total limit; a product that would go over the published limit is
  /// stored unpublished, so it can never be published by accident.
  ///
  /// [existing] is the stored version when this is an update (null when
  /// creating); it is never counted twice.
  Product guardSave(
    Product product, {
    required Product? existing,
    required ProductCounts others,
  }) {
    final decision = decide(
      isNew: existing == null,
      wasPublished: existing?.isPublished ?? false,
      wantsPublished: product.isPublished,
      otherTotal: others.total,
      otherPublished: others.published,
    );
    switch (decision) {
      case ProductLimitDecision.allowed:
        return product;
      case ProductLimitDecision.publishBlocked:
        return product.copyWith(isPublished: false);
      case ProductLimitDecision.createBlocked:
        throw ProductLimitException(totalCap!);
    }
  }
}
