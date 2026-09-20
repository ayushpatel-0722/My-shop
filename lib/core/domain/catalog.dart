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
  final bool inStockOnly;
  final bool discountedOnly;
  final bool includeOutOfStockLast;
  final ProductSort sort;

  /// Stock at or below this quantity is reported as [StockStatus.lowStock].
  final int lowStockThreshold;

  const CatalogQuery({
    this.search = '',
    this.categoryIds = const <String>{},
    this.companyIds = const <String>{},
    this.inStockOnly = false,
    this.discountedOnly = false,
    this.includeOutOfStockLast = true,
    this.sort = ProductSort.relevance,
    this.lowStockThreshold = 20,
  });

  CatalogQuery copyWith({
    String? search,
    Set<String>? categoryIds,
    Set<String>? companyIds,
    bool? inStockOnly,
    bool? discountedOnly,
    bool? includeOutOfStockLast,
    ProductSort? sort,
    int? lowStockThreshold,
  }) =>
      CatalogQuery(
        search: search ?? this.search,
        categoryIds: categoryIds ?? this.categoryIds,
        companyIds: companyIds ?? this.companyIds,
        inStockOnly: inStockOnly ?? this.inStockOnly,
        discountedOnly: discountedOnly ?? this.discountedOnly,
        includeOutOfStockLast:
            includeOutOfStockLast ?? this.includeOutOfStockLast,
        sort: sort ?? this.sort,
        lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
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
  static List<Product> apply(
    Iterable<Product> source,
    CatalogQuery query,
  ) {
    final filtered = source.where((p) {
      if (query.hasCompanyFilter && !query.companyIds.contains(p.companyId)) {
        return false;
      }
      if (query.hasCategoryFilter && !query.categoryIds.contains(p.categoryId)) {
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
          (a, b) => (b.isRecommended ? 1 : 0).compareTo(a.isRecommended ? 1 : 0),
        );
        break;
      case ProductSort.relevance:
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

  /// Products that will disappear from the store front soon.
  static List<Product> lowStock(
    Iterable<Product> products, {
    int lowStockThreshold = 20,
  }) =>
      products
          .where(
            (p) => stockStatus(p, lowStockThreshold: lowStockThreshold) ==
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
