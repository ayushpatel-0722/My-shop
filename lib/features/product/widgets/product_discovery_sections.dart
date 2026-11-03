import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../../../core/models/company.dart';
import '../../../core/models/home_trending_item.dart';
import '../../../core/models/product.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../core/widgets/replay_stream_builder.dart';
import '../../marketplace/widgets/product_card.dart';

/// What to look at next, under a product: the same kinds of rows as Home.
///
///  1. **More from this category** – side-scrolling row;
///  2. **Recommended for you**     – side-scrolling row (as on Home);
///  3. **Trending Now**            – a grid, two products per row on a phone
///                                   (more on wider screens), shown a page at
///                                   a time.
///
/// The product being viewed never appears in any of them, and out-of-stock
/// products are left out. A row with nothing to show is not drawn.
class ProductDiscoverySections extends StatefulWidget {
  const ProductDiscoverySections({
    super.key,
    required this.product,
    this.company,
  });

  final Product product;
  final Company? company;

  @override
  State<ProductDiscoverySections> createState() =>
      _ProductDiscoverySectionsState();
}

class _ProductDiscoverySectionsState extends State<ProductDiscoverySections> {
  /// Products of the trending grid built at first, and added per "Show more".
  static const int _page = 10;

  // Opened once (see SharedStreams): a rebuild must not open them again.
  late final Stream<List<Product>> _category = repo.products(
    companyId: widget.product.companyId,
    categoryId: widget.product.categoryId,
  );
  late final Stream<List<Product>> _allProducts = repo.products();
  late final Future<List<Product>> _recommended = repo.recommendations();
  late final Stream<List<HomeTrendingItem>> _trendingItems = repo
      .homeTrendingNow(shopId: widget.product.companyId, activeOnly: true);
  late final Stream<List<Product>> _shopProducts = repo.products(
    companyId: widget.product.companyId,
  );

  int _trendingShown = _page;

  bool _usable(Product item) => item.id != widget.product.id && item.isInStock;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    if (p.categoryId.isEmpty && p.companyId.isEmpty) {
      return const SizedBox.shrink();
    }
    final isDesktop = context.isDesktop;
    return Padding(
      padding: EdgeInsets.only(top: 24, bottom: isDesktop ? 48 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 24),
          _moreFromCategory(context),
          _recommendedRow(context),
          _trendingGrid(context),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ 1 ----

  Widget _moreFromCategory(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ReplayStreamBuilder<List<Product>>(
      stream: _category,
      builder: (context, snap) {
        final items = (snap.data ?? const <Product>[]).where(_usable).toList();
        if (items.isEmpty) return const SizedBox.shrink();
        return _section(
          context,
          key: const Key('discovery-category'),
          title: l10n.moreFromThisCategory,
          count: items.length,
          child: _horizontal(context, items),
        );
      },
    );
  }

  // ------------------------------------------------------------------ 2 ----

  Widget _recommendedRow(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ReplayStreamBuilder<List<Product>>(
      stream: _allProducts,
      builder: (context, all) {
        return FutureBuilder<List<Product>>(
          future: _recommended,
          builder: (context, recs) {
            // As on Home: the shop's recommendations, else everything.
            final picked = recs.data ?? const <Product>[];
            final source = picked.isNotEmpty
                ? picked
                : (all.data ?? const <Product>[]);
            final items = source.where(_usable).take(20).toList();
            if (items.isEmpty) return const SizedBox.shrink();
            return _section(
              context,
              key: const Key('discovery-recommended'),
              title: l10n.recommendedForYou,
              child: _horizontal(context, items),
            );
          },
        );
      },
    );
  }

  // ------------------------------------------------------------------ 3 ----

  Widget _trendingGrid(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ReplayStreamBuilder<List<Product>>(
      stream: _shopProducts,
      builder: (context, shop) {
        return ReplayStreamBuilder<List<HomeTrendingItem>>(
          stream: _trendingItems,
          builder: (context, trending) {
            final products = shop.data ?? const <Product>[];
            final byId = {for (final p in products) p.id: p};
            // The shop's own Trending Now picks when it set any, else its
            // products.
            final picks = <Product>[
              for (final t in trending.data ?? const <HomeTrendingItem>[])
                if (t.isProduct &&
                    t.productId != null &&
                    byId[t.productId] != null)
                  byId[t.productId]!,
            ];
            final source = picks.isNotEmpty ? picks : products;
            final all = source.where(_usable).toList();
            if (all.isEmpty) return const SizedBox.shrink();
            final shown = all.take(_trendingShown).toList();
            final hasMore = all.length > shown.length;

            return _section(
              context,
              key: const Key('discovery-trending'),
              title: l10n.trendingNow2,
              child: Column(
                children: [
                  _grid(context, shown),
                  if (hasMore)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: OutlinedButton(
                        key: const Key('discovery-trending-more'),
                        onPressed: () =>
                            setState(() => _trendingShown += _page),
                        child: Text(l10n.showMoreProducts),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------- building ----

  Widget _section(
    BuildContext context, {
    required Key key,
    required String title,
    required Widget child,
    int? count,
  }) {
    final isDesktop = context.isDesktop;
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: isDesktop ? 22 : 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E2229),
                  ),
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5247).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF5247),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  /// A side-scrolling row of product cards.
  Widget _horizontal(BuildContext context, List<Product> items) {
    const cardWidth = 172.0;
    final ratio = ResponsiveGrid.calculateProductAspectRatio(
      cardWidth * 2 + 12,
      2,
      showBrand: true,
    );
    return SizedBox(
      height: cardWidth / ratio,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) => SizedBox(
          width: cardWidth,
          child: ProductCard(
            product: items[i],
            company: widget.company,
            onTap: () => context.push(AppRoutes.productPath(items[i].id)),
          ),
        ),
      ),
    );
  }

  /// A grid of product cards: two per row on a phone.
  Widget _grid(BuildContext context, List<Product> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width < 600
            ? 2
            : width < 900
            ? 3
            : width < 1200
            ? 4
            : width < 1600
            ? 5
            : 6;
        final ratio = ResponsiveGrid.calculateProductAspectRatio(
          width,
          columns,
          showBrand: true,
        );
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: ratio,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) => ProductCard(
            product: items[i],
            company: widget.company,
            onTap: () => context.push(AppRoutes.productPath(items[i].id)),
          ),
        );
      },
    );
  }
}
