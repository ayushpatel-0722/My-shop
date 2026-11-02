import '../models/category.dart';

/// Finds the category a home-screen entry (Explore Categories, Trending Now)
/// points at.
///
/// The shopper app loads the categories of every shop in one list, and a
/// category id is only unique inside its own shop. Matching on the id alone
/// can hand back another shop's category (wrong name, wrong picture), so the
/// shop id is part of the key. A category that has no shop recorded at all is
/// still accepted, so older data keeps working.
Category? findShopCategory(
  Iterable<Category> all,
  String shopId,
  String categoryId,
) {
  Category? legacy;
  for (final c in all) {
    if (c.id != categoryId) continue;
    if (c.companyId == shopId) return c;
    if (c.companyId.isEmpty) legacy = c;
  }
  return shopId.isEmpty
      ? all.cast<Category?>().firstWhere(
          (c) => c!.id == categoryId,
          orElse: () => null,
        )
      : legacy;
}
