import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes/app_router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/domain/catalog.dart';
import '../../../core/domain/store_profile.dart';
import '../../../core/models/banner.dart';
import '../../../core/models/category.dart';
import '../../../core/models/company.dart';
import '../../../core/models/order.dart';
import '../../../core/models/product.dart';
import '../../../core/models/review.dart';
import '../../../core/models/voucher.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/services/service_locator.dart';
import '../../auth/widgets/auth_bottom_sheet.dart';
import '../../checkout/cart/cart_cubit.dart';
import '../widgets/common_carousel.dart';
import '../widgets/marketplace_bottom_nav.dart';
import '../widgets/store_shelf_card.dart';

/// Company micro-storefront, restructured into clear "aisles":
///
///   App Bar (transparent, overlays the header)
///     → Shop Details (banner, logo, rating, open/closed pill, follow)
///     → Offer Banner Carousel (this store's own promotions)
///     → one product shelf per category the store sells in ("See All →")
///     → Trending Now (this store's own order velocity)
///     → All Products grid (Price / Rating / In-Stock pills, paginated)
///
/// Everything is live Firestore data — no invented ratings, coupons or
/// delivery times. Reviews live behind the rating row and the app-bar icon
/// instead of a bottom block, so the page ends where the catalogue ends.
class CompanyStoreScreen extends StatefulWidget {
  final String slug;
  const CompanyStoreScreen({super.key, required this.slug});

  @override
  State<CompanyStoreScreen> createState() => _CompanyStoreScreenState();
}

class _CompanyStoreScreenState extends State<CompanyStoreScreen> {
  Company? _company;

  // All Products grid controls.
  ProductSort _sort = ProductSort.relevance;
  bool _onlyInStock = false;
  int _visibleCount = 12;

  /// Length of the filtered grid in the last build, so pagination stops once
  /// everything is on screen.
  int _filteredCount = 0;

  bool _isFollowing = false;

  final PageController _carouselCtrl = PageController();
  int _carouselIndex = 0;

  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _resolveCompany();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _carouselCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Loads more of the All Products grid as the shopper nears the bottom.
  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    if (_visibleCount >= _filteredCount) return;
    final position = _scrollCtrl.position;
    if (position.maxScrollExtent - position.pixels < 400) {
      setState(() => _visibleCount += 12);
    }
  }

  Future<void> _resolveCompany() async {
    final list = await repo.companies().first;
    final c =
        list.where((c) => c.slug == widget.slug).firstOrNull ??
        list.where((c) => c.id == widget.slug).firstOrNull ??
        list
            .where((c) => c.name.toLowerCase() == widget.slug.toLowerCase())
            .firstOrNull ??
        list.firstOrNull;
    if (mounted) setState(() => _company = c);
  }

  void _handleAddToCart(BuildContext context, Product product) {
    void doAdd() {
      context.read<CartCubit>().add(product, company: _company);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} added to cart'),
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: 'View Cart',
            textColor: Colors.white,
            onPressed: () => context.go(AppRoutes.cart),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    if (AuthSession.currentUser == null) {
      AuthBottomSheet.show(context, onAuthenticated: doAdd);
    } else {
      doAdd();
    }
  }

  void _handleClaimVoucher(BuildContext context, String code) {
    void doClaim() {
      Clipboard.setData(ClipboardData(text: code));
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Voucher "$code" copied to clipboard!'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    if (AuthSession.currentUser == null) {
      AuthBottomSheet.show(context, onAuthenticated: doClaim);
    } else {
      doClaim();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_company == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final company = _company!;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(context, company),
      bottomNavigationBar: const MarketplaceBottomNav(currentIndex: 0),
      body: StreamBuilder<List<Product>>(
        stream: repo.products(companyId: company.id),
        builder: (context, productSnap) {
          final allProducts = productSnap.data ?? const <Product>[];
          return StreamBuilder<List<Category>>(
            stream: repo.categories(companyId: company.id),
            builder: (context, catSnap) {
              final categories = catSnap.data ?? const <Category>[];
              return StreamBuilder<List<OfferBanner>>(
                stream: repo.offerBanners(company.id),
                builder: (context, bannerSnap) {
                  final offerBanners = bannerSnap.data ?? const <OfferBanner>[];
                  return StreamBuilder<List<Voucher>>(
                    stream: repo.vouchers(company.id),
                    builder: (context, voucherSnap) {
                      final activeVouchers =
                          (voucherSnap.data ?? const <Voucher>[])
                              .where(
                                (v) =>
                                    v.isLiveAt(DateTime.now()) &&
                                    !v.isExhausted,
                              )
                              .toList();
                      return StreamBuilder<List<Review>>(
                        stream: repo.reviews(company.id),
                        builder: (context, reviewSnap) {
                          final reviews = reviewSnap.data ?? const <Review>[];
                          return StreamBuilder<List<Order>>(
                            stream: repo.orders(companyId: company.id),
                            builder: (context, orderSnap) {
                              final orders = orderSnap.data ?? const <Order>[];
                              return _buildContent(
                                context,
                                company,
                                allProducts,
                                categories,
                                offerBanners,
                                activeVouchers,
                                reviews,
                                orders,
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Top App Bar — transparent, overlays the header banner.
  // ---------------------------------------------------------------------------
  PreferredSizeWidget _buildAppBar(BuildContext context, Company company) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12, top: 6),
        child: _CircleIconButton(
          icon: Icons.arrow_back,
          onTap: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
      ),
      title: const SizedBox.shrink(),
      actions: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: _CircleIconButton(
            icon: Icons.search,
            tooltip: 'Search in this store',
            onTap: () => context.push(
              '${AppRoutes.search}?companyId=${company.id}&name=${Uri.encodeComponent(company.name)}',
            ),
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: _CircleIconButton(
            icon: Icons.rate_review_outlined,
            tooltip: 'Store reviews',
            onTap: () => context.push(
              AppRoutes.reviews.replaceFirst(':companyId', company.id),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 6, right: 12),
          child: BlocBuilder<CartCubit, CartState>(
            builder: (context, state) {
              final count = state.totalItems;
              return _CircleIconButton(
                icon: Icons.shopping_cart_outlined,
                onTap: () => context.push(AppRoutes.cart),
                badge: count > 0 ? '$count' : null,
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Main Content Builder
  // ---------------------------------------------------------------------------
  Widget _buildContent(
    BuildContext context,
    Company company,
    List<Product> allProducts,
    List<Category> categories,
    List<OfferBanner> offerBanners,
    List<Voucher> vouchers,
    List<Review> reviews,
    List<Order> orders,
  ) {
    return ListView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // 1. Shop details block (banner + logo + meta).
        _ShopDetailsBlock(
          company: company,
          bannerImage: _bannerImage(offerBanners),
          stats: StoreStats.fromReviews(
            reviews,
            followerCount: company.followers + (_isFollowing ? 1 : 0),
          ),
          isFollowing: _isFollowing,
          onToggleFollow: () => setState(() => _isFollowing = !_isFollowing),
        ),

        const SizedBox(height: 16),

        // 2. Company offer banner carousel.
        if (offerBanners.any((b) => b.image.trim().isNotEmpty) ||
            vouchers.isNotEmpty) ...[
          _OfferCarousel(
            banners: offerBanners
                .where((b) => b.image.trim().isNotEmpty)
                .toList(),
            vouchers: vouchers,
            controller: _carouselCtrl,
            page: _carouselIndex,
            onPageChanged: (i) => setState(() => _carouselIndex = i),
            onClaimVoucher: (code) => _handleClaimVoucher(context, code),
            onBannerTap: (banner) => _openBannerTarget(context, banner),
          ),
          const SizedBox(height: 20),
        ],

        // 3. Category shelves (one shelf per category this store sells in).
        _buildCategoryShelves(context, company, categories, allProducts),

        // 4. Trending Now — this store's own order velocity.
        _buildTrendingShelf(context, company, allProducts, orders),

        // 5. All Products grid with filter pills.
        _buildAllProducts(context, company, allProducts),
      ],
    );
  }

  String? _bannerImage(List<OfferBanner> banners) {
    for (final b in banners) {
      final image = b.image.trim();
      if (image.isNotEmpty) return image;
    }
    return null;
  }

  void _openBannerTarget(BuildContext context, OfferBanner banner) {
    if (banner.targetProdId != null && banner.targetProdId!.isNotEmpty) {
      context.push(AppRoutes.productPath(banner.targetProdId!));
    } else if (banner.targetCatId != null && banner.targetCatId!.isNotEmpty) {
      context.push(AppRoutes.categoryPath(banner.targetCatId!));
    }
  }

  static bool _productMatchesCategory(Product p, Category cat) {
    final catId = p.categoryId.trim();
    if (catId.isNotEmpty) {
      if (catId == cat.id) return true;
      if (catId.toLowerCase() == cat.id.toLowerCase()) return true;
      if (catId.toLowerCase() == cat.name.toLowerCase()) return true;
      if (catId.replaceAll(' ', '-').toLowerCase() == cat.id.toLowerCase()) {
        return true;
      }
      if (catId.replaceAll('-', ' ').toLowerCase() == cat.name.toLowerCase()) {
        return true;
      }
    }
    if (cat.productList.contains(p.id)) return true;
    return false;
  }

  // ---------------------------------------------------------------------------
  // 3. Per-category product shelves
  // ---------------------------------------------------------------------------
  Widget _buildCategoryShelves(
    BuildContext context,
    Company company,
    List<Category> categories,
    List<Product> allProducts,
  ) {
    // For each category, collect all products that match. Categories with 0
    // products are skipped so empty headers or placeholders are not shown.
    final categoryEntries = <MapEntry<Category, List<Product>>>[];
    for (final cat in categories) {
      final prods = allProducts
          .where((p) => _productMatchesCategory(p, cat))
          .toList();
      if (prods.isNotEmpty) {
        categoryEntries.add(MapEntry(cat, prods));
      }
    }

    if (categoryEntries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in categoryEntries)
          _CategoryShelf(
            key: Key('store-shelf-${entry.key.id}'),
            category: entry.key,
            products: entry.value,
            company: company,
            onAddToCart: (p) => _handleAddToCart(context, p),
            onSeeAll: () => context.push(
              '${AppRoutes.categoryPath(entry.key.id)}?name=${Uri.encodeComponent(entry.key.name)}&companyId=${company.id}',
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Trending Now — from this store's own order velocity
  // ---------------------------------------------------------------------------
  Widget _buildTrendingShelf(
    BuildContext context,
    Company company,
    List<Product> allProducts,
    List<Order> orders,
  ) {
    // How often each product was bought recently in THIS store. Orders arrive
    // newest-first, so the most recent 30 are the head of the list.
    final score = <String, int>{};
    for (final order in orders.take(30)) {
      if (order.isCancelled) continue;
      for (final line in order.items) {
        score[line.productId] = (score[line.productId] ?? 0) + line.qty;
      }
    }

    final byId = {for (final p in allProducts) p.id: p};
    final trending =
        score.entries
            .map((e) => MapEntry(byId[e.key], e.value))
            .where((e) => e.key != null)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    var products = trending.map((e) => e.key!).toList();
    if (products.isEmpty) {
      // Fresh store with no history yet: the recommended picks stand in.
      products = allProducts.where((p) => p.isRecommended).toList();
      if (products.isEmpty) products = allProducts.take(6).toList();
    } else {
      products = products.take(10).toList();
    }

    if (products.isEmpty) return const SizedBox.shrink();

    return Column(
      key: const Key('trending-shelf'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                color: Color(0xFFE8590C),
                size: 20,
              ),
              const SizedBox(width: 6),
              const Text(
                'Trending Now',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E2229),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'in ${company.name}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF6C757D),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 236,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) => StoreShelfCard(
              product: products[i],
              company: company,
              width: 148,
              onTap: () => context.push(AppRoutes.productPath(products[i].id)),
              onAddToCart: () => _handleAddToCart(context, products[i]),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 5. All Products grid (filter pills + responsive catalog grid)
  // ---------------------------------------------------------------------------
  Widget _buildAllProducts(
    BuildContext context,
    Company company,
    List<Product> allProducts,
  ) {
    final filtered = Catalog.apply(
      allProducts,
      CatalogQuery(
        companyIds: {company.id},
        inStockOnly: _onlyInStock,
        sort: _sort,
      ),
    );
    _filteredCount = filtered.length;
    final visible = filtered.take(_visibleCount).toList();

    return Column(
      key: const Key('all-products-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'All Products (${filtered.length})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E2229),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Filter pills — same chip style as the Category Explorer.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _FilterPill(
                key: const Key('filter-pill-price'),
                label: _priceSortLabel(),
                active:
                    _sort == ProductSort.priceAsc ||
                    _sort == ProductSort.priceDesc,
                onTap: () => setState(() {
                  _sort = _sort == ProductSort.priceAsc
                      ? ProductSort.priceDesc
                      : ProductSort.priceAsc;
                }),
              ),
              const SizedBox(width: 8),
              _FilterPill(
                key: const Key('filter-pill-rating'),
                label: 'Rating',
                active: _sort == ProductSort.rating,
                onTap: () => setState(
                  () => _sort = _sort == ProductSort.rating
                      ? ProductSort.relevance
                      : ProductSort.rating,
                ),
              ),
              const SizedBox(width: 8),
              _FilterPill(
                key: const Key('filter-pill-instock'),
                label: 'In-Stock',
                active: _onlyInStock,
                onTap: () => setState(() => _onlyInStock = !_onlyInStock),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (allProducts.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text(
                'This store has no products yet',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            ),
          )
        else if (visible.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text(
                'No products match these filters',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = (constraints.maxWidth / 165)
                    .floor()
                    .clamp(2, 8);
                return GridView.builder(
                  key: const Key('all-products-grid'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: visible.length,
                  itemBuilder: (context, i) => StoreShelfCard(
                    product: visible[i],
                    company: company,
                    onTap: () =>
                        context.push(AppRoutes.productPath(visible[i].id)),
                    onAddToCart: () => _handleAddToCart(context, visible[i]),
                  ),
                );
              },
            ),
          ),

        if (filtered.length > visible.length)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: Text(
                'Scroll for more (${filtered.length - visible.length} left)',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _priceSortLabel() => _sort == ProductSort.priceDesc
      ? 'Price ↓'
      : _sort == ProductSort.priceAsc
      ? 'Price ↑'
      : 'Price';
}

// =============================================================================
// Building blocks
// =============================================================================

/// Round, semi-transparent white app-bar button (back / search / reviews /
/// cart with badge) that stays legible over the header banner.
class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? badge;
  final String? tooltip;

  const _CircleIconButton({
    required this.icon,
    this.onTap,
    this.badge,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(15, 23, 42, 0.18),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.all(7),
              child: Icon(icon, size: 20, color: const Color(0xFF1E2229)),
            ),
            if (badge != null)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  constraints: const BoxConstraints(minWidth: 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFB3261E),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badge!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// Shop details block: banner, overlapping logo, name + verified badge,
/// tappable rating row, open/closed pill, follower count + follow button.
class _ShopDetailsBlock extends StatelessWidget {
  final Company company;
  final String? bannerImage;
  final StoreStats stats;
  final bool isFollowing;
  final VoidCallback onToggleFollow;

  const _ShopDetailsBlock({
    required this.company,
    required this.bannerImage,
    required this.stats,
    required this.isFollowing,
    required this.onToggleFollow,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final open = StoreHours.isOpenAt(company, now);
    final openLabel = StoreHours.openLabel(company, now);
    final closedLabel = StoreHours.closedLabel(company, now);
    final hasLogo = company.logoUrl.trim().isNotEmpty;

    return Column(
      children: [
        // Backdrop banner (~120 px) with the logo overlapping its bottom edge.
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            SizedBox(
              height: 120,
              width: double.infinity,
              child: bannerImage != null
                  ? Image.network(
                      bannerImage!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _bannerFallback(),
                    )
                  : _bannerFallback(),
            ),
            Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: -34,
              child: Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.15),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(3),
                child: CircleAvatar(
                  key: const Key('store-logo'),
                  backgroundColor: const Color(0xFFFFEBEA),
                  child: ClipOval(
                    child: hasLogo
                        ? Image.network(
                            company.logoUrl.trim(),
                            fit: BoxFit.cover,
                            width: 74,
                            height: 74,
                            errorBuilder: (_, _, _) => _logoFallback(),
                          )
                        : _logoFallback(),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 42),

        // Name + verified badge.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  company.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E2229),
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (company.isVerified) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.verified_rounded,
                  key: Key('verified-badge'),
                  size: 18,
                  color: Color(0xFF3D38D9),
                ),
              ],
            ],
          ),
        ),
        if (company.details.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 3, 24, 0),
            child: Text(
              company.details,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF6C757D)),
            ),
          ),
        const SizedBox(height: 8),

        // Rating row (tappable → all reviews) + follower count + follow.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              InkWell(
                key: const Key('store-rating-row'),
                borderRadius: BorderRadius.circular(10),
                onTap: () => context.push(
                  AppRoutes.reviews.replaceFirst(':companyId', company.id),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        stats.reviewCount == 0
                            ? Icons.star_outline_rounded
                            : Icons.star_rounded,
                        size: 16,
                        color: const Color(0xFFFFB800),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        stats.ratingLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          color: Color(0xFF1E2229),
                        ),
                      ),
                      Text(
                        ' · ${stats.reviewCount} '
                        '${stats.reviewCount == 1 ? 'review' : 'reviews'}',
                        style: const TextStyle(
                          color: Color(0xFF6C757D),
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.chevron_right,
                        size: 15,
                        color: Color(0xFF94A3B8),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Open / Closed pill, driven by the weekly hours.
              Container(
                key: const Key('open-closed-pill'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: open
                      ? const Color(0xFFE6F7F2)
                      : const Color(0xFFFFEBEA),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: open
                        ? const Color(0xFFC3EADB)
                        : const Color(0xFFFFD0CB),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 7,
                      color: open
                          ? const Color(0xFF0CA678)
                          : const Color(0xFFE03131),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      open ? openLabel : closedLabel,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: open
                            ? const Color(0xFF087F5B)
                            : const Color(0xFFC12525),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Follower count + outlined Follow button.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    stats.followerLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6C757D),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    key: const Key('follow-button'),
                    onPressed: onToggleFollow,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: isFollowing
                          ? const Color(0xFFFFF0EE)
                          : Colors.white,
                      foregroundColor: const Color(0xFFB3261E),
                      side: const BorderSide(
                        color: Color(0xFFB3261E),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      minimumSize: const Size(0, 30),
                    ),
                    child: Text(
                      isFollowing ? '✓ Following' : '+ Follow',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bannerFallback() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF7A1414), Color(0xFFB3261E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Center(
      child: Icon(
        Icons.storefront,
        size: 44,
        color: Colors.white.withValues(alpha: 0.6),
      ),
    ),
  );

  Widget _logoFallback() {
    final initial = company.name.isNotEmpty
        ? company.name.substring(0, 1).toUpperCase()
        : 'S';
    return Container(
      color: const Color(0xFFFFEBEA),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Color(0xFFB3261E),
          fontSize: 30,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Full-width auto-scrolling offer carousel with dot pagination.
///
/// Pages come from the store's own uploaded banners; when there are none the
/// store's live vouchers become promo pages, so the block only disappears
/// when the store genuinely has nothing to promote.
class _OfferCarousel extends StatelessWidget {
  final List<OfferBanner> banners;
  final List<Voucher> vouchers;
  final PageController controller;
  final int page;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<String> onClaimVoucher;
  final ValueChanged<OfferBanner> onBannerTap;

  const _OfferCarousel({
    required this.banners,
    required this.vouchers,
    required this.controller,
    required this.page,
    required this.onPageChanged,
    required this.onClaimVoucher,
    required this.onBannerTap,
  });

  int get _pageCount => banners.length + (vouchers.isEmpty ? 0 : 1);

  @override
  Widget build(BuildContext context) {
    final hasBanners = banners.isNotEmpty;
    if (!hasBanners && vouchers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      key: const Key('store-banner-carousel'),
      child: CommonCarousel.banner(
        itemCount: _pageCount,
        controller: controller,
        initialPage: page,
        onPageChanged: onPageChanged,
        maxHeightFactor: 0.60,
        itemBuilder: (context, i) {
          if (i < banners.length) {
            final banner = banners[i];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _bannerPage(banner),
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _voucherPage(vouchers),
          );
        },
      ),
    );
  }

  Widget _bannerPage(OfferBanner banner) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => onBannerTap(banner),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          banner.image.trim(),
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF9E1B1B), Color(0xFFB3261E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.local_offer_outlined,
                size: 44,
                color: Colors.white70,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// One promo page listing the store's live voucher codes.
  Widget _voucherPage(List<Voucher> vouchers) {
    final top = vouchers.first;
    final title = top.discountType == 'percentage'
        ? 'Flat ${top.discountValue.toStringAsFixed(0)}% OFF'
        : top.discountType == 'free_shipping'
        ? 'Free Delivery on your order'
        : 'Flat ₹${top.discountValue.toStringAsFixed(0)} OFF';
    final sub = top.minOrderAmt > 0
        ? 'Valid on orders over ₹${top.minOrderAmt.toStringAsFixed(0)}'
        : 'Store exclusive deal';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF8A1414), Color(0xFFB3261E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB3261E).withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'SPECIAL OFFER',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$sub · ${vouchers.length} live '
                  '${vouchers.length == 1 ? 'offer' : 'offers'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                ),
                const SizedBox(height: 9),
                InkWell(
                  onTap: () => onClaimVoucher(top.code),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Use Code: ${top.code}',
                      style: const TextStyle(
                        color: Color(0xFFB3261E),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_offer, size: 34, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// One "aisle": header (category avatar + name + count + See All) +
/// horizontal product rail + a clean divider before the next shelf begins.
class _CategoryShelf extends StatelessWidget {
  final Category category;
  final List<Product> products;
  final Company company;
  final ValueChanged<Product> onAddToCart;
  final VoidCallback onSeeAll;

  const _CategoryShelf({
    super.key,
    required this.category,
    required this.products,
    required this.company,
    required this.onAddToCart,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Header Row (title left-aligned, optional See All on right)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E2229),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              InkWell(
                key: Key('shelf-see-all-${category.id}'),
                onTap: onSeeAll,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 4,
                  ),
                  child: Text(
                    'See All',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFFFF8A80)
                          : const Color(0xFFB3261E),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Horizontal Product Rail for this category
        SizedBox(
          height: 236,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) => StoreShelfCard(
              product: products[i],
              company: company,
              width: 148,
              onTap: () => context.push(AppRoutes.productPath(products[i].id)),
              onAddToCart: () => onAddToCart(products[i]),
            ),
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }
}

/// Pill-shaped filter button (Price / Rating / In-Stock).
class _FilterPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterPill({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFFEBEA) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? const Color(0xFFB3261E) : const Color(0xFFE2E6EC),
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: active ? FontWeight.bold : FontWeight.w600,
                color: active
                    ? const Color(0xFFB3261E)
                    : const Color(0xFF495057),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
