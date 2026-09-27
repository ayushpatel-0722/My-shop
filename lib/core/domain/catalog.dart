import '../models/category.dart';
import '../models/product.dart';

/// Stock health of a product, shared by the admin list and the store front.
enum StockStatus {
  outOfStock,
  lowStock,
  inStock,
  unlimited;

  bool get isSellable => this != StockStatus.outOfStock;

  String get label {
    switch (this) {
      case StockStatus.outOfStock:
        return 'Out of stock';
      case StockStatus.lowStock:
        return 'Low stock';
      case StockStatus.inStock:
        return 'In stock';
      case StockStatus.unlimited:
        return 'Unlimited';
    }
  }
}

/// Sort orders offered by the catalogue screens.
enum ProductSort {
  relevance,
  nameAsc,
  nameDesc,
  priceAsc,
  priceDesc,

  /// "Top rated first". Products carry no star ratings of their own yet, so
  /// the store's recommended picks act as the ranking signal — this keeps the
  /// store-front filter honest instead of inventing numbers.
  rating;

  String get label {
    switch (this) {
      case ProductSort.relevance:
        return 'Relevance';
      case ProductSort.nameAsc:
        return 'Name (A–Z)';
      case ProductSort.nameDesc:
        return 'Name (Z–A)';
      case ProductSort.priceAsc:
        return 'Price (low to high)';
      case ProductSort.priceDesc:
        return 'Price (high to low)';
      case ProductSort.rating:
        return 'Rating (top picks first)';
    }
  }
}

/// Immutable description of "which products should we show and in what order".
class CatalogQuery {
  final String search;
  final Set<String> categoryIds;
  final Set<String> companyIds;
  final List<Category>? categories;
  final bool inStockOnly;
  final bool discountedOnly;
  final bool includeOutOfStockLast;
  final ProductSort sort;

  /// Stock at or below this quantity is reported as [StockStatus.lowStock].
  final int lowStockThreshold;

  /// The curated order for the active category (Category.productList).
  /// Applied by [ProductSort.relevance]; products missing from the list are
  /// shown after the listed ones (alphabetical tiebreak).
  final List<String> productOrder;

  const CatalogQuery({
    this.search = '',
    this.categoryIds = const <String>{},
    this.companyIds = const <String>{},
    this.categories,
    this.inStockOnly = false,
    this.discountedOnly = false,
    this.includeOutOfStockLast = true,
    this.sort = ProductSort.relevance,
    this.lowStockThreshold = 20,
    this.productOrder = const <String>[],
  });

  CatalogQuery copyWith({
    String? search,
    Set<String>? categoryIds,
    Set<String>? companyIds,
    List<Category>? categories,
    bool? inStockOnly,
    bool? discountedOnly,
    bool? includeOutOfStockLast,
    ProductSort? sort,
    int? lowStockThreshold,
    List<String>? productOrder,
  }) => CatalogQuery(
    search: search ?? this.search,
    categoryIds: categoryIds ?? this.categoryIds,
    companyIds: companyIds ?? this.companyIds,
    categories: categories ?? this.categories,
    inStockOnly: inStockOnly ?? this.inStockOnly,
    discountedOnly: discountedOnly ?? this.discountedOnly,
    includeOutOfStockLast: includeOutOfStockLast ?? this.includeOutOfStockLast,
    sort: sort ?? this.sort,
    lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
    productOrder: productOrder ?? this.productOrder,
  );

  bool get hasSearch => search.trim().isNotEmpty;
  bool get hasCategoryFilter => categoryIds.isNotEmpty;
  bool get hasCompanyFilter => companyIds.isNotEmpty;

  /// True when the query does not restrict or reorder anything.
  bool get isIdentity =>
      !hasSearch &&
      !hasCategoryFilter &&
      !hasCompanyFilter &&
      !inStockOnly &&
      !discountedOnly &&
      productOrder.isEmpty &&
      sort == ProductSort.relevance;

  @override
  String toString() => 'CatalogQuery(search: "$search", sort: ${sort.name})';
}

/// Pure catalogue filtering / sorting used by every product list.
class Catalog {
  const Catalog();

  /// Case-insensitive match against name, SKU, description and sub-details.
  static bool matchesSearch(Product product, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;

    // Every term must appear somewhere (multi-word friendly search).
    for (final term in q.split(RegExp(r'\s+'))) {
      if (term.isEmpty) continue;
      if (!product.searchIndex.contains(term)) return false;
    }
    return true;
  }

  /// Flexible category matching that checks:
  /// 1. Direct match on p.categoryId with categoryIds / names / slugs
  /// 2. If categories list is provided, checks if category productList contains product.id
  ///    or if product.categoryId matches category id/name/type.
  static bool matchesCategory(
    Product product,
    Set<String> categoryTargets, [
    List<Category>? categories,
  ]) {
    if (categoryTargets.isEmpty) return true;

    final pCat = product.categoryId.trim();

    // 1. Direct match with target category IDs/names/slugs
    if (pCat.isNotEmpty) {
      for (final t in categoryTargets) {
        final target = t.trim();
        if (target.isEmpty) continue;
        if (pCat == target) return true;
        if (pCat.toLowerCase() == target.toLowerCase()) return true;
        if (pCat.replaceAll(' ', '-').toLowerCase() == target.toLowerCase()) {
          return true;
        }
        if (pCat.replaceAll('-', ' ').toLowerCase() == target.toLowerCase()) {
          return true;
        }
        if (pCat.replaceAll('_', '-').toLowerCase() == target.toLowerCase()) {
          return true;
        }
        if (pCat.replaceAll('-', '_').toLowerCase() == target.toLowerCase()) {
          return true;
        }
      }
    }

    // 2. Check against full category entities if available
    if (categories != null && categories.isNotEmpty) {
      for (final cat in categories) {
        final catMatchesTarget = categoryTargets.any((t) {
          final target = t.trim().toLowerCase();
          return cat.id.toLowerCase() == target ||
              cat.name.toLowerCase() == target ||
              cat.id.replaceAll('_', '-').toLowerCase() == target ||
              cat.id.replaceAll('-', '_').toLowerCase() == target ||
              cat.name.replaceAll(' ', '-').toLowerCase() == target ||
              cat.name.replaceAll('-', ' ').toLowerCase() == target;
        });

        if (catMatchesTarget) {
          // Check if this product belongs to this matched category
          if (cat.productList.contains(product.id)) return true;
          if (pCat.isNotEmpty) {
            if (pCat == cat.id ||
                pCat.toLowerCase() == cat.id.toLowerCase() ||
                pCat.toLowerCase() == cat.name.toLowerCase() ||
                pCat.replaceAll(' ', '-').toLowerCase() ==
                    cat.id.toLowerCase() ||
                pCat.replaceAll('-', ' ').toLowerCase() ==
                    cat.name.toLowerCase() ||
                pCat.toLowerCase() == cat.type.toLowerCase()) {
              return true;
            }
          }
        }
      }
    }

    return false;
  }

  /// Stock health for a product, honouring the "unlimited" flag.
  static StockStatus stockStatus(
    Product product, {
    int lowStockThreshold = 20,
  }) {
    if (product.isUnlimitedStock) return StockStatus.unlimited;
    if (product.stockQty <= 0) return StockStatus.outOfStock;
    if (product.stockQty <= lowStockThreshold) return StockStatus.lowStock;
    return StockStatus.inStock;
  }

  /// Applies [query] to [source] and returns a new list (input untouched).
  static List<Product> apply(Iterable<Product> source, CatalogQuery query) {
    final filtered = source.where((p) {
      if (query.hasCompanyFilter && !query.companyIds.contains(p.companyId)) {
        return false;
      }
      if (query.hasCategoryFilter &&
          !matchesCategory(p, query.categoryIds, query.categories)) {
        return false;
      }
      if (query.inStockOnly && !p.isInStock) return false;
      if (query.discountedOnly && !p.isDiscounted) return false;
      return matchesSearch(p, query.search);
    }).toList();

    switch (query.sort) {
      case ProductSort.nameAsc:
        filtered.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case ProductSort.nameDesc:
        filtered.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
        break;
      case ProductSort.priceAsc:
        filtered.sort((a, b) => a.price.compareTo(b.price));
        break;
      case ProductSort.priceDesc:
        filtered.sort((a, b) => b.price.compareTo(a.price));
        break;
      case ProductSort.rating:
        filtered.sort(
          (a, b) =>
              (b.isRecommended ? 1 : 0).compareTo(a.isRecommended ? 1 : 0),
        );
        break;
      case ProductSort.relevance:
        // Category curates its own product order (Category.productList).
        if (query.productOrder.isNotEmpty) {
          final orderIndex = <String, int>{
            for (var i = 0; i < query.productOrder.length; i++)
              query.productOrder[i]: i,
          };
          int rank(Product p) =>
              orderIndex[p.id] ?? (orderIndex.length + 1);
          filtered.sort((a, b) {
            final byOrder = rank(a).compareTo(rank(b));
            if (byOrder != 0) return byOrder;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
        }
        break;
    }

    if (query.includeOutOfStockLast) {
      // Sold-out items sink to the bottom of every list.
      filtered.sort((a, b) {
        final aOut = a.isInStock ? 0 : 1;
        final bOut = b.isInStock ? 0 : 1;
        return aOut.compareTo(bOut);
      });
    }
    return filtered;
  }

  /// How many products sit in each category (0 when a product has none).
  static Map<String, int> countByCategory(Iterable<Product> products) {
    final counts = <String, int>{};
    for (final p in products) {
      if (p.categoryId.isEmpty) continue;
      counts[p.categoryId] = (counts[p.categoryId] ?? 0) + 1;
    }
    return counts;
  }

  /// Distinct category ids present in [products].
  static Set<String> usedCategoryIds(Iterable<Product> products) =>
      products.map((p) => p.categoryId).where((id) => id.isNotEmpty).toSet();

  /// Sorts [products] by their position inside a category's ordered
  /// `productList` (array position = display order).
  ///
  /// Products missing from the array keep their relative order at the end.
  static List<Product> orderByAssignment(
    Iterable<Product> products,
    List<String> productList,
  ) {
    final rank = <String, int>{};
    for (var i = 0; i < productList.length; i++) {
      rank.putIfAbsent(productList[i], () => i);
    }
    final list = products.toList();
    final originalIndex = <String, int>{
      for (var i = 0; i < list.length; i++) list[i].id: i,
    };
    list.sort((a, b) {
      final ra = rank[a.id] ?? 1 << 30;
      final rb = rank[b.id] ?? 1 << 30;
      if (ra != rb) return ra.compareTo(rb);
      return (originalIndex[a.id] ?? 0).compareTo(originalIndex[b.id] ?? 0);
    });
    return list;
  }

  /// Products that will disappear from the store front soon.
  static List<Product> lowStock(
    Iterable<Product> products, {
    int lowStockThreshold = 20,
  }) => products
      .where(
        (p) =>
            stockStatus(p, lowStockThreshold: lowStockThreshold) ==
            StockStatus.lowStock,
      )
      .toList();

  /// Catalogue health summary for the admin dashboard.
  static CatalogSummary summarize(
    Iterable<Product> products, {
    int lowStockThreshold = 20,
  }) {
    final list = products.toList();
    var out = 0;
    var low = 0;
    var discounted = 0;
    for (final p in list) {
      final status = stockStatus(p, lowStockThreshold: lowStockThreshold);
      if (status == StockStatus.outOfStock) out++;
      if (status == StockStatus.lowStock) low++;
      if (p.isDiscounted) discounted++;
    }
    return CatalogSummary(
      total: list.length,
      outOfStock: out,
      lowStock: low,
      discounted: discounted,
    );
  }
}

/// Aggregated numbers for the product list header.
class CatalogSummary {
  final int total;
  final int outOfStock;
  final int lowStock;
  final int discounted;

  const CatalogSummary({
    this.total = 0,
    this.outOfStock = 0,
    this.lowStock = 0,
    this.discounted = 0,
  });

  int get inStock => total - outOfStock;

  @override
  String toString() =>
      'CatalogSummary(total: $total, out: $outOfStock, low: $lowStock)';
}
