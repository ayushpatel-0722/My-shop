/// The subscription plans a shop can be on, and what each one allows.
///
/// A shop's plan is the `plan` field on its company document (`basic`,
/// `golden` or `diamond`), set by the platform. It decides `max_products`:
/// a shop on a plan gets that plan's number whatever `max_products` says.
/// Shops without a `plan` keep using their own `max_products`.
///
/// `functions/product_limits.js` has the same table for the server.
enum SubscriptionPlan {
  basic(id: 'basic', maxProducts: 50, maxCategories: 4),
  golden(id: 'golden', maxProducts: 80, maxCategories: 5),
  diamond(id: 'diamond', maxProducts: 120, maxCategories: 7);

  const SubscriptionPlan({
    required this.id,
    required this.maxProducts,
    required this.maxCategories,
  });

  /// The value stored in the company's `plan` field.
  final String id;

  /// Most products that can be published on this plan.
  final int maxProducts;

  /// Most categories on this plan.
  final int maxCategories;

  /// The plan named by a stored `plan` value (any case), or null.
  static SubscriptionPlan? fromId(Object? raw) {
    final id = '${raw ?? ''}'.trim().toLowerCase();
    for (final p in values) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// The plan whose product limit is exactly [maxProducts]: how a shop that
  /// only has a `max_products` number (no `plan` yet) is shown. Null for any
  /// other number (a custom limit).
  static SubscriptionPlan? matchingMaxProducts(int? maxProducts) {
    for (final p in values) {
      if (p.maxProducts == maxProducts) return p;
    }
    return null;
  }

  /// Plans bigger than this one, smallest first.
  Iterable<SubscriptionPlan> get upgrades =>
      values.where((p) => p.maxProducts > maxProducts);
}

/// Who to contact to change a plan.
class PlanContact {
  const PlanContact._();

  static const name = 'Ayush Patel';
  static const email = 'work.ayushkumar112428@gmail.com';
}
