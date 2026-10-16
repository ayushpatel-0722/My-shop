import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes/app_router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/domain/catalog.dart';
import '../../../core/domain/category_tree.dart';
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
import '../../../core/utils/cart_notification.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../core/widgets/modern_shimmer.dart';
import '../../auth/widgets/auth_bottom_sheet.dart';
import '../../checkout/cart/cart_cubit.dart';
import '../widgets/common_carousel.dart';
import '../widgets/location_picker_sheet.dart';
import '../widgets/marketplace_bottom_nav.dart';
import '../widgets/product_card.dart';
import 'package:myshop/app/l10n/app_localizations.dart';

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

  /// Selected category filter chip above shelves (null means 'All').
  String? _selectedCategoryId;

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
      showAddToCartNotification(context, productName: product.name);
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
          content: Text(
            AppLocalizations.of(context).voucherCopiedToClipboard(code),
          ),
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
      return Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: BackButton(
            color: const Color(0xFF1E2229),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(AppRoutes.home);
              }
            },
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SizedBox(height: 12),
                M3BannerSkeleton(),
                SizedBox(height: 18),
                M3CategoryRailSkeleton(),
                SizedBox(height: 18),
                M3ProductGridSkeleton(itemCount: 4),
              ],
            ),
          ),
        ),
      );
    }
    final company = _company!;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: _buildAppBar(context, company),
      bottomNavigationBar: const MarketplaceBottomNav(currentIndex: 0),
      body: StreamBuilder<List<Product>>(
        stream: repo.products(companyId: company.id),
        builder: (context, productSnap) {
          if (productSnap.connectionState == ConnectionState.waiting &&
              !productSnap.hasData) {
            return SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SizedBox(height: 12),
                    M3BannerSkeleton(),
                    SizedBox(height: 18),
                    M3CategoryRailSkeleton(),
                    SizedBox(height: 18),
                    M3ProductGridSkeleton(itemCount: 4),
                  ],
                ),
              ),
            );
          }
          final allProducts = productSnap.data ?? const <Product>[];
          return StreamBuilder<List<Category>>(
            stream: repo.categories(companyId: company.id),
            builder: (context, catSnap) {
              // Admin-defined category order (Category.sortOrder per level).
              final categories = CategoryHierarchy.sortedByOrder(
                catSnap.data ?? const <Category>[],
              );
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
  // 1. Top App Bar — clean white app bar with search, reviews, and cart
  // ---------------------------------------------------------------------------
  PreferredSizeWidget _buildAppBar(BuildContext context, Company company) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0.5,
      shadowColor: const Color.fromRGBO(0, 0, 0, 0.08),
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E2229)),
        tooltip: AppLocalizations.of(context).back,
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRoutes.home);
          }
        },
      ),
      title: Text(
        company.name,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: Color(0xFF1E2229),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded, color: Color(0xFF1E2229)),
          tooltip: AppLocalizations.of(context).searchInThisStore,
          onPressed: () => context.push(
            '${AppRoutes.search}?companyId=${company.id}&name=${Uri.encodeComponent(company.name)}',
          ),
        ),
        IconButton(
          icon: const Icon(
            Icons.rate_review_outlined,
            color: Color(0xFF1E2229),
          ),
          tooltip: AppLocalizations.of(context).storeReviews,
          onPressed: () => context.push(
            AppRoutes.reviews.replaceFirst(':companyId', company.id),
          ),
        ),
        BlocBuilder<CartCubit, CartState>(
          builder: (context, state) {
            final count = state.totalItems;
            return IconButton(
              icon: Badge(
                isLabelVisible: count > 0,
                label: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
                backgroundColor: const Color(0xFFFF5247),
                child: const Icon(
                  Icons.shopping_cart_outlined,
                  color: Color(0xFF1E2229),
                ),
              ),
              tooltip: AppLocalizations.of(context).cart,
              onPressed: () async {
                if (AuthSession.currentUser == null) {
                  final ok = await AuthBottomSheet.show(context);
                  if (ok && context.mounted) context.go(AppRoutes.cart);
                  return;
                }
                context.go(AppRoutes.cart);
              },
            );
          },
        ),
        const SizedBox(width: 6),
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
          bannerImage: _bannerImage(company, offerBanners),
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
          const SizedBox(height: 16),
        ],

        // 3. Offers from this store coupon row.
        if (vouchers.isNotEmpty) ...[
          _StoreCouponsSection(
            vouchers: vouchers,
            onClaimVoucher: (code) => _handleClaimVoucher(context, code),
          ),
          const SizedBox(height: 16),
        ],

        // 4. Horizontal category filter pills row (All, Category 1, Category 2, ...).
        _buildCategoryChips(context, categories, allProducts),

        // 5. Category shelves (one shelf per category this store sells in).
        _buildCategoryShelves(context, company, categories, allProducts),

        // 6. Trending Now — this store's own order velocity.
        _buildTrendingShelf(context, company, allProducts, orders),

        // 7. All Products grid with filter pills.
        _buildAllProducts(context, company, allProducts),
      ],
    );
  }

  String? _bannerImage(Company company, List<OfferBanner> banners) {
    if (company.bannerImage.isNotEmpty) return company.bannerImage;
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
      context.push(
        '${AppRoutes.categoryPath(banner.targetCatId!)}?companyId=${_company?.id ?? ''}',
      );
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
  // 3. Horizontal category filter chips row (All, Cat 1, Cat 2, ...)
  // ---------------------------------------------------------------------------
  Widget _buildCategoryChips(
    BuildContext context,
    List<Category> categories,
    List<Product> allProducts,
  ) {
    // Only show categories that have at least 1 product matching in this store
    final activeCategories = categories.where((cat) {
      return allProducts.any((p) => _productMatchesCategory(p, cat));
    }).toList();

    if (activeCategories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: activeCategories.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                final isSelected = _selectedCategoryId == null;
                return _CategoryChip(
                  key: const Key('category-chip-all'),
                  label: AppLocalizations.of(context).all3,
                  isSelected: isSelected,
                  onTap: () => setState(() => _selectedCategoryId = null),
                );
              }
              final cat = activeCategories[index - 1];
              final isSelected = _selectedCategoryId == cat.id;
              return _CategoryChip(
                key: Key('category-chip-${cat.id}'),
                label: cat.name,
                isSelected: isSelected,
                onTap: () => setState(() {
                  _selectedCategoryId = isSelected ? null : cat.id;
                }),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Per-category product shelves
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
        if (_selectedCategoryId == null || _selectedCategoryId == cat.id) {
          categoryEntries.add(MapEntry(cat, prods));
        }
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
              Text(
                AppLocalizations.of(context).trendingNow,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E2229),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context).msgIn(company.name),
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
          height: 285,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, i) => SizedBox(
              width: 165,
              child: ProductCard(
                product: products[i],
                company: company,
                showBrand: false,
                onTap: () =>
                    context.push(AppRoutes.productPath(products[i].id)),
              ),
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
            AppLocalizations.of(context).allProducts('${filtered.length}'),
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
                label: AppLocalizations.of(context).rating,
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
                label: AppLocalizations.of(context).inStock3,
                active: _onlyInStock,
                onTap: () => setState(() => _onlyInStock = !_onlyInStock),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (allProducts.isEmpty)
          Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text(
                AppLocalizations.of(context).thisStoreHasNoProductsYet,
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            ),
          )
        else if (visible.isEmpty)
          Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text(
                AppLocalizations.of(context).noProductsMatchTheseFilters,
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final crossAxisCount = ResponsiveGrid.calculateCrossAxisCount(
                  width,
                  maxCardWidth: 250,
                );
                final childAspectRatio =
                    ResponsiveGrid.calculateProductAspectRatio(
                      width,
                      crossAxisCount,
                      showBrand: false,
                    );
                return GridView.builder(
                  key: const Key('all-products-grid'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: childAspectRatio,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: visible.length,
                  itemBuilder: (context, i) => ProductCard(
                    product: visible[i],
                    company: company,
                    showBrand: false,
                    onTap: () =>
                        context.push(AppRoutes.productPath(visible[i].id)),
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
                AppLocalizations.of(
                  context,
                ).scrollForMoreLeft('${filtered.length - visible.length}'),
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
      ? AppLocalizations.of(context).price3
      : _sort == ProductSort.priceAsc
      ? AppLocalizations.of(context).price4
      : AppLocalizations.of(context).price5;
}

// =============================================================================
// Building blocks
// =============================================================================

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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Backdrop banner (~160 px) with the logo overlapping its bottom-left edge.
        Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              height: 160,
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
              height: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.45),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 16,
              bottom: -34,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Color.fromRGBO(0, 0, 0, 0.15),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(3.5),
                    child: CircleAvatar(
                      key: const Key('store-logo'),
                      backgroundColor: const Color(0xFFFFEBEA),
                      child: ClipOval(
                        child: hasLogo
                            ? Image.network(
                                company.logoUrl.trim(),
                                fit: BoxFit.cover,
                                width: 75,
                                height: 75,
                                errorBuilder: (_, _, _) => _logoFallback(),
                              )
                            : _logoFallback(),
                      ),
                    ),
                  ),
                  if (company.isVerified)
                    Positioned(
                      right: 0,
                      bottom: 2,
                      child: Container(
                        padding: const EdgeInsets.all(1.5),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified,
                          size: 20,
                          color: Color(0xFF3D38D9),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 42),

        // Name + verified badge (Left-Aligned).
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  company.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E2229),
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (company.isVerified) ...[
                const SizedBox(width: 8),
                Container(
                  key: const Key('verified-badge'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00796B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                      SizedBox(width: 3),
                      Text(
                        AppLocalizations.of(context).verified,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (company.details.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 3, 16, 0),
            child: Text(
              company.details,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF6C757D)),
            ),
          ),
        const SizedBox(height: 6),

        // Rating row (tappable → all reviews, only if >= 5 reviews) • Open/Closed pill (Left-Aligned).
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 5,
            children: [
              if (stats.reviewCount >= 5) ...[
                InkWell(
                  key: const Key('store-rating-row'),
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => context.push(
                    AppRoutes.reviews.replaceFirst(':companyId', company.id),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 16.5,
                        color: Color(0xFFFFB800),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        stats.ratingLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Color(0xFF1E2229),
                        ),
                      ),
                      Text(
                        AppLocalizations.of(
                          context,
                        ).reviewsCount(stats.reviewCount),
                        style: const TextStyle(
                          color: Color(0xFF6C757D),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Text(
                  '•',
                  style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
                ),
              ],

              // Open / Closed pill, driven by weekly hours.
              Container(
                key: const Key('open-closed-pill'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                      size: 6,
                      color: open
                          ? const Color(0xFF0CA678)
                          : const Color(0xFFE03131),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      open ? openLabel : closedLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: open
                            ? const Color(0xFF087F5B)
                            : const Color(0xFFC12525),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Delivery / Service info pill (Left-Aligned).
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 10),
          child: _buildDeliveryInfoPill(context, company),
        ),
      ],
    );
  }

  Widget _buildDeliveryInfoPill(BuildContext context, Company company) {
    final symbol = company.currencySymbol;
    final hasMinOrder = company.minOrderAmount > 0;
    final minOrderFormatted = formatCurrency(
      company.minOrderAmount,
      symbol: symbol,
    );

    final IconData icon;
    final Color iconColor;
    final String label;

    if (company.isSelfPickupOnly ||
        (!company.allowsHomeDelivery && company.allowsSelfPickup)) {
      // Self pickup only
      icon = Icons.storefront_outlined;
      iconColor = const Color(0xFF0F766E);
      label = hasMinOrder
          ? AppLocalizations.of(
              context,
            ).selfPickupOnlyMinOrder(minOrderFormatted)
          : AppLocalizations.of(context).selfPickupOnly;
    } else if (company.allowsHomeDelivery) {
      // Home delivery allowed
      icon = Icons.local_shipping_outlined;
      iconColor = const Color(0xFFE03131);
      label = hasMinOrder
          ? AppLocalizations.of(
              context,
            ).homeDeliveryAvailableMinOrder(minOrderFormatted)
          : AppLocalizations.of(context).homeDeliveryAvailableNoMinOrder;
    } else {
      // Neither or fallback
      icon = Icons.storefront_outlined;
      iconColor = const Color(0xFF64748B);
      label = AppLocalizations.of(context).storefrontService;
    }

    return InkWell(
      onTap: () => LocationPickerSheet.show(context, company: company),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 14,
              color: Color(0xFF64748B),
            ),
          ],
        ),
      ),
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
            child: _voucherPage(context, vouchers),
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
  Widget _voucherPage(BuildContext context, List<Voucher> vouchers) {
    final top = vouchers.first;
    final title = top.discountType == 'percentage'
        ? AppLocalizations.of(
            context,
          ).flatOff(top.discountValue.toStringAsFixed(0))
        : top.discountType == 'free_shipping'
        ? AppLocalizations.of(context).freeDeliveryOnYourOrder
        : AppLocalizations.of(
            context,
          ).flatOff2(top.discountValue.toStringAsFixed(0));
    final sub = top.minOrderAmt > 0
        ? AppLocalizations.of(
            context,
          ).validOnOrdersOver(top.minOrderAmt.toStringAsFixed(0))
        : AppLocalizations.of(context).storeExclusiveDeal;

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
                  child: Text(
                    AppLocalizations.of(context).specialOffer,
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
                  AppLocalizations.of(
                    context,
                  ).vouchersPlural11LiveOfferOtherLiveOffers(
                    sub,
                    vouchers.length,
                  ),
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
                      AppLocalizations.of(context).useCode(top.code),
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
                    AppLocalizations.of(context).seeAll,
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
          height: 285,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, i) => SizedBox(
              width: 165,
              child: ProductCard(
                product: products[i],
                company: company,
                showBrand: false,
                onTap: () =>
                    context.push(AppRoutes.productPath(products[i].id)),
              ),
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

/// Category pill chip styled like the reference UI (solid red pill for selected,
/// clean outlined white pill for unselected).
class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFB3261E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFB3261E)
                  : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFB3261E).withValues(alpha: 0.28),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.04),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF1E2229),
                letterSpacing: -0.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal store coupons / offers section styled matching the reference design.
class _StoreCouponsSection extends StatelessWidget {
  final List<Voucher> vouchers;
  final ValueChanged<String> onClaimVoucher;

  const _StoreCouponsSection({
    required this.vouchers,
    required this.onClaimVoucher,
  });

  @override
  Widget build(BuildContext context) {
    if (vouchers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(
                Icons.confirmation_number_outlined,
                color: Color(0xFFB3261E),
                size: 18,
              ),
              SizedBox(width: 6),
              Text(
                AppLocalizations.of(context).offersFromThisStore,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E2229),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: vouchers.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final v = vouchers[index];
              return _StoreCouponCard(
                voucher: v,
                onApply: () => onClaimVoucher(v.code),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Compact coupon card with discount, requirement, code, and Apply button.
class _StoreCouponCard extends StatelessWidget {
  final Voucher voucher;
  final VoidCallback onApply;

  const _StoreCouponCard({required this.voucher, required this.onApply});

  @override
  Widget build(BuildContext context) {
    final discountTitle = voucher.discountType == 'percentage'
        ? AppLocalizations.of(
            context,
          ).off(voucher.discountValue.toStringAsFixed(0))
        : voucher.discountType == 'free_shipping'
        ? AppLocalizations.of(context).freeDel
        : AppLocalizations.of(
            context,
          ).off4(voucher.discountValue.toStringAsFixed(0));

    final sub = voucher.minOrderAmt > 0
        ? AppLocalizations.of(
            context,
          ).ordersOver(voucher.minOrderAmt.toStringAsFixed(0))
        : AppLocalizations.of(context).noMinOrder;

    final isFreeDel = voucher.discountType == 'free_shipping';

    return Container(
      width: 218,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.03),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  discountTitle,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: isFreeDel
                        ? const Color(0xFF0F766E)
                        : const Color(0xFFB3261E),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF6C757D),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  voucher.code.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF495057),
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 36,
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: const Color(0xFFE2E8F0),
          ),
          InkWell(
            onTap: onApply,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                AppLocalizations.of(context).apply,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFB3261E),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
