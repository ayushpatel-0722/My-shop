import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/banner.dart';
import '../../../core/models/category.dart';
import '../../../core/models/company.dart';
import '../../../core/models/product.dart';
import '../../../core/models/review.dart';
import '../../../core/models/voucher.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/widgets/auth_bottom_sheet.dart';
import '../../checkout/cart/cart_cubit.dart';

/// Company micro-storefront fully driven by live Firebase Firestore data:
/// - Store Profile & Logo from Firestore `/companies/{id}`
/// - Store Offer Banners from Firestore `/offer_banners` (filtered by companyId)
/// - Store Exclusive Vouchers from Firestore `/vouchers` (filtered by companyId)
/// - Store Catalog & Categories from Firestore `/products` & `/categories`
/// - Live Ratings & Customer Reviews from Firestore `/reviews` (filtered by companyId)
class CompanyStoreScreen extends StatefulWidget {
  final String slug;
  const CompanyStoreScreen({super.key, required this.slug});

  @override
  State<CompanyStoreScreen> createState() => _CompanyStoreScreenState();
}

class _CompanyStoreScreenState extends State<CompanyStoreScreen> {
  Company? _company;
  String _selectedCategoryId = 'all';
  String _sortBy = 'popularity'; // popularity, price_asc, price_desc, rating
  bool _onlyInStock = false;
  bool _isFollowing = false;
  final Set<String> _appliedVouchers = {};

  @override
  void initState() {
    super.initState();
    _resolveCompany();
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
      setState(() => _appliedVouchers.add(code));
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
    final l10n = AppLocalizations.of(context);
    if (_company == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final company = _company!;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: _buildAppBar(context, company),
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
                      final rawVouchers = voucherSnap.data ?? const <Voucher>[];
                      // Only advertise codes a shopper can actually redeem.
                      final activeVouchers = rawVouchers
                          .where(
                            (v) =>
                                v.isLiveAt(DateTime.now()) && !v.isExhausted,
                          )
                          .toList();
                      return StreamBuilder<List<Review>>(
                        stream: repo.reviews(company.id),
                        builder: (context, reviewSnap) {
                          final reviews = reviewSnap.data ?? const <Review>[];
                          return _buildContent(
                            context,
                            company,
                            allProducts,
                            categories,
                            offerBanners,
                            activeVouchers,
                            reviews,
                            l10n,
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
  // Top App Bar
  // ---------------------------------------------------------------------------
  PreferredSizeWidget _buildAppBar(BuildContext context, Company company) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF1E2229)),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRoutes.home);
          }
        },
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Color(0xFF1E2229)),
          onPressed: () => context.go(AppRoutes.search),
        ),
        IconButton(
          icon: const Icon(
            Icons.receipt_long_outlined,
            color: Color(0xFF1E2229),
          ),
          onPressed: () => _showStoreDetailsSheet(context, company),
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
                backgroundColor: const Color(0xFFB3261E),
                child: const Icon(
                  Icons.shopping_cart_outlined,
                  color: Color(0xFF1E2229),
                ),
              ),
              onPressed: () => context.go(AppRoutes.cart),
            );
          },
        ),
        const SizedBox(width: 4),
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
    AppLocalizations l10n,
  ) {
    final topPicks = allProducts.where((p) => p.isRecommended).toList();
    final effectiveTopPicks = topPicks.isNotEmpty
        ? topPicks
        : allProducts.take(6).toList();

    // Filter products for "All Products" section
    var filteredProducts = allProducts.where((p) {
      if (_selectedCategoryId != 'all' && p.categoryId != _selectedCategoryId) {
        return false;
      }
      if (_onlyInStock && p.stockQty <= 0) {
        return false;
      }
      return true;
    }).toList();

    // Sort products
    if (_sortBy == 'price_asc') {
      filteredProducts.sort((a, b) => a.price.compareTo(b.price));
    } else if (_sortBy == 'price_desc') {
      filteredProducts.sort((a, b) => b.price.compareTo(a.price));
    } else if (_sortBy == 'rating') {
      filteredProducts.sort(
        (a, b) => (b.isRecommended ? 1 : 0).compareTo(a.isRecommended ? 1 : 0),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        // 1. Cover Banner + Overlapping Avatar + Follow Action
        _buildCoverAndHeader(context, company, offerBanners),

        const SizedBox(height: 12),

        // 2. Store Metadata (Real Rating calculation, Open/Closed, Delivery Info)
        _buildStoreMetadata(context, company, reviews),

        const SizedBox(height: 16),

        // 3. Live Promo Banner / Top Voucher Card from Firestore
        if (offerBanners.isNotEmpty || vouchers.isNotEmpty) ...[
          _buildLivePromoCard(context, company, offerBanners, vouchers),
          const SizedBox(height: 16),
        ],

        // 4. Live Offers & Vouchers from Firestore for this company
        if (vouchers.isNotEmpty) ...[
          _buildOffersSection(context, company, vouchers),
          const SizedBox(height: 16),
        ],

        // 5. Category Filter Chips (Derived dynamically from company products)
        if (categories.isNotEmpty || allProducts.isNotEmpty) ...[
          _buildCategoryFilterRail(categories, allProducts),
          const SizedBox(height: 18),
        ],

        // 6. Top Picks from [Store Name]
        if (effectiveTopPicks.isNotEmpty) ...[
          _buildTopPicksSection(context, company, effectiveTopPicks),
          const SizedBox(height: 24),
        ],

        // 7. All Products Grid with Live Sort/Filters
        _buildAllProductsSection(context, company, filteredProducts),

        const SizedBox(height: 28),

        // 8. Live Customer Reviews & Rating Breakdown from Firestore
        _buildReviewsSection(context, company, reviews),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Store Cover Banner + Overlapping Avatar + Follow Action
  // ---------------------------------------------------------------------------
  Widget _buildCoverAndHeader(
    BuildContext context,
    Company company,
    List<OfferBanner> offerBanners,
  ) {
    final hasLogo = company.logoUrl.trim().isNotEmpty;
    // Prefer banner image from company offer banners if uploaded, otherwise brand gradient
    final bannerImg =
        offerBanners.isNotEmpty && offerBanners.first.image.trim().isNotEmpty
        ? offerBanners.first.image.trim()
        : null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Store Cover Banner
        Container(
          height: 155,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF7A1414), Color(0xFFB3261E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: bannerImg != null
              ? Image.network(
                  bannerImg,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _coverFallback(company),
                )
              : _coverFallback(company),
        ),

        // Bottom gradient for cover
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 55,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.0),
                  Colors.black.withValues(alpha: 0.4),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),

        // Profile Section Row (Overlapping Avatar + Follow Button)
        Container(
          margin: const EdgeInsets.only(top: 110),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Circular Store Avatar
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.12),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipOval(
                      child: SizedBox(
                        width: 76,
                        height: 76,
                        child: hasLogo
                            ? Image.network(
                                company.logoUrl.trim(),
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    _avatarFallback(company),
                              )
                            : _avatarFallback(company),
                      ),
                    ),
                    // Blue Verified Badge Overlay
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3D38D9),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          size: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Follow Pill Button
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: OutlinedButton(
                  onPressed: () {
                    setState(() => _isFollowing = !_isFollowing);
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _isFollowing
                              ? 'You are now following ${company.name}'
                              : 'Unfollowed ${company.name}',
                        ),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _isFollowing
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
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 34),
                  ),
                  child: Text(
                    _isFollowing ? '✓ Following' : '+ Follow',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _coverFallback(Company company) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7A1414), Color(0xFFB3261E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.storefront, size: 48, color: Colors.white70),
            const SizedBox(height: 4),
            Text(
              company.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback(Company company) {
    final initial = company.name.isNotEmpty
        ? company.name.substring(0, 1).toUpperCase()
        : 'S';
    return Container(
      color: const Color(0xFFFFEBEA),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Color(0xFFB3261E),
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Store Metadata & Dynamic Ratings Calculation
  // ---------------------------------------------------------------------------
  Widget _buildStoreMetadata(
    BuildContext context,
    Company company,
    List<Review> reviews,
  ) {
    final open = company.isOpenNow();

    // Calculate real dynamic rating from Firestore reviews
    final double avgRating;
    final int reviewCount = reviews.length;
    if (reviews.isNotEmpty) {
      final totalStars = reviews.fold<int>(0, (sum, r) => sum + r.rating);
      avgRating = totalStars / reviews.length;
    } else {
      avgRating = 5.0; // Default when fresh
    }

    final deliveryTypes = company.deliveryTypes;
    final isHomeDel = deliveryTypes.contains('home_delivery');
    final isPickup = deliveryTypes.contains('self_pickup');
    final deliveryText = isHomeDel && isPickup
        ? 'Home Delivery & Store Pickup available'
        : isHomeDel
        ? 'Home Delivery available'
        : isPickup
        ? 'Store Pickup only'
        : 'Direct store ordering';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Store Name + Verified Pill
          Row(
            children: [
              Flexible(
                child: Text(
                  company.name,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E2229),
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F7F2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, color: Color(0xFF0CA678), size: 13),
                    SizedBox(width: 3),
                    Text(
                      'Verified',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0CA678),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (company.details.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              company.details,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF6C757D)),
            ),
          ],

          const SizedBox(height: 6),

          // Rating, Open/Closed Status
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                size: 16,
                color: Color(0xFFFFB800),
              ),
              const SizedBox(width: 2),
              Text(
                avgRating.toStringAsFixed(1),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                ' ($reviewCount ${reviewCount == 1 ? 'review' : 'reviews'})',
                style: const TextStyle(color: Color(0xFF6C757D), fontSize: 12),
              ),
              const Text(' • ', style: TextStyle(color: Color(0xFF94A3B8))),
              Text(
                open ? 'Open Now' : 'Closed',
                style: TextStyle(
                  color: open
                      ? const Color(0xFF0CA678)
                      : const Color(0xFFE03131),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              if (company.address.isNotEmpty) ...[
                const Text(' • ', style: TextStyle(color: Color(0xFF94A3B8))),
                Flexible(
                  child: Text(
                    company.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF6C757D),
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 10),

          // Delivery Banner Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7F6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFE0DC)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt, color: Color(0xFFB3261E), size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    deliveryText,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB3261E),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Live Promo Card / Top Voucher Card from Firestore (16:9 & Max 60% Height)
  // ---------------------------------------------------------------------------
  Widget _buildLivePromoCard(
    BuildContext context,
    Company company,
    List<OfferBanner> offerBanners,
    List<Voucher> vouchers,
  ) {
    final maxBannerHeight = MediaQuery.of(context).size.height * 0.60;
    final validBanners = offerBanners
        .where((b) => b.image.trim().isNotEmpty)
        .toList();

    // If company has uploaded OfferBanner(s) in Firestore, render large 16/9 banner(s)
    if (validBanners.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxBannerHeight),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: validBanners.length == 1
                  ? _bannerItem(context, validBanners.first)
                  : PageView.builder(
                      itemCount: validBanners.length,
                      itemBuilder: (context, i) =>
                          _bannerItem(context, validBanners[i]),
                    ),
            ),
          ),
        ),
      );
    }

    // Otherwise, render promotional card featuring company's top voucher
    return _renderVoucherPromoFallback(context, vouchers, maxBannerHeight);
  }

  Widget _bannerItem(BuildContext context, OfferBanner banner) {
    return InkWell(
      onTap: () {
        if (banner.targetProdId != null && banner.targetProdId!.isNotEmpty) {
          context.go(AppRoutes.productPath(banner.targetProdId!));
        } else if (banner.targetCatId != null &&
            banner.targetCatId!.isNotEmpty) {
          context.go(AppRoutes.categoryPath(banner.targetCatId!));
        }
      },
      child: Image.network(
        banner.image.trim(),
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            color: const Color(0xFFF1F3F5),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
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
              size: 48,
              color: Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  Widget _renderVoucherPromoFallback(
    BuildContext context,
    List<Voucher> vouchers,
    double maxHeight,
  ) {
    if (vouchers.isEmpty) return const SizedBox.shrink();

    final topVoucher = vouchers.first;
    final discountTitle = topVoucher.discountType == 'percentage'
        ? 'Flat ${topVoucher.discountValue.toStringAsFixed(0)}% OFF'
        : topVoucher.discountType == 'free_shipping'
        ? 'Free Delivery on your order'
        : 'Flat ₹${topVoucher.discountValue.toStringAsFixed(0)} OFF';

    final sub = topVoucher.minOrderAmt > 0
        ? 'Valid on orders over ₹${topVoucher.discountValue > 0 ? topVoucher.minOrderAmt.toStringAsFixed(0) : "0"}'
        : 'Store exclusive deal';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'SPECIAL OFFER',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        discountTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () =>
                            _handleClaimVoucher(context, topVoucher.code),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Use Code: ${topVoucher.code}',
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
                const SizedBox(width: 14),
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_offer,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Live Offers & Vouchers from Firestore
  // ---------------------------------------------------------------------------
  Widget _buildOffersSection(
    BuildContext context,
    Company company,
    List<Voucher> vouchers,
  ) {
    if (vouchers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: const [
              Icon(
                Icons.local_offer_outlined,
                color: Color(0xFFB3261E),
                size: 18,
              ),
              SizedBox(width: 6),
              Text(
                'Offers from this store',
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
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: vouchers.length,
            itemBuilder: (context, i) {
              final v = vouchers[i];
              final title = v.discountType == 'percentage'
                  ? '${v.discountValue.toStringAsFixed(0)}% OFF'
                  : v.discountType == 'free_shipping'
                  ? 'FREE DEL'
                  : '₹${v.discountValue.toStringAsFixed(0)} OFF';
              final sub = v.minOrderAmt > 0
                  ? 'Orders over ₹${v.minOrderAmt.toStringAsFixed(0)}'
                  : v.firstTimeOnly
                      ? 'First order'
                      : 'No minimum';
              return _voucherItem(title: title, sub: sub, code: v.code);
            },
          ),
        ),
      ],
    );
  }

  Widget _voucherItem({
    required String title,
    required String sub,
    required String code,
  }) {
    final isClaimed = _appliedVouchers.contains(code);

    return Container(
      width: 210,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E6EC)),
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
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Color(0xFFB3261E),
                  ),
                ),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF6C757D),
                  ),
                ),
                Text(
                  code,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => _handleClaimVoucher(context, code),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isClaimed
                    ? const Color(0xFFE6F7F2)
                    : const Color(0xFFFFEBEA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isClaimed ? '✓' : 'Apply',
                style: TextStyle(
                  color: isClaimed
                      ? const Color(0xFF0CA678)
                      : const Color(0xFFB3261E),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Category Filter Chips (Dynamic from live categories)
  // ---------------------------------------------------------------------------
  Widget _buildCategoryFilterRail(
    List<Category> categories,
    List<Product> allProducts,
  ) {
    final activeCatIds = allProducts.map((p) => p.categoryId).toSet();
    final visibleCats = categories
        .where((c) => activeCatIds.contains(c.id))
        .toList();

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _categoryChip(id: 'all', label: 'All'),
          ...visibleCats.map((c) => _categoryChip(id: c.id, label: c.name)),
        ],
      ),
    );
  }

  Widget _categoryChip({required String id, required String label}) {
    final isSelected = _selectedCategoryId == id;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF495057),
          ),
        ),
        selected: isSelected,
        selectedColor: const Color(0xFFB3261E),
        backgroundColor: Colors.white,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected
                ? const Color(0xFFB3261E)
                : const Color(0xFFE2E6EC),
            width: 1,
          ),
        ),
        onSelected: (_) => setState(() => _selectedCategoryId = id),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. Top Picks from [Store Name] (Recommended products from Firestore)
  // ---------------------------------------------------------------------------
  Widget _buildTopPicksSection(
    BuildContext context,
    Company company,
    List<Product> topPicks,
  ) {
    final symbol = company.currencySymbol;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top Picks from ${company.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E2229),
                      ),
                    ),
                    const Text(
                      'Store favorites, recommended for you',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF6C757D),
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => setState(() => _selectedCategoryId = 'all'),
                child: const Row(
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB3261E),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: Color(0xFFB3261E),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 242,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: topPicks.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) =>
                _topPickCard(context, company, topPicks[i], symbol),
          ),
        ),
      ],
    );
  }

  Widget _topPickCard(
    BuildContext context,
    Company company,
    Product p,
    String symbol,
  ) {
    final hasImage = p.images.isNotEmpty && p.images.first.trim().isNotEmpty;
    final discountPercent = p.discountPercent.round();

    return Container(
      width: 155,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E6EC)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => context.go(AppRoutes.productPath(p.id)),
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image with Discount Badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                  child: AspectRatio(
                    aspectRatio: 1.15,
                    child: hasImage
                        ? Image.network(
                            p.images.first.trim(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _productFallbackImage(p),
                          )
                        : _productFallbackImage(p),
                  ),
                ),
                if (discountPercent > 0)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5.5,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB3261E),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$discountPercent% OFF',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Product Details & Price Row
            Padding(
              padding: const EdgeInsets.all(8.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${p.unit} ${p.unitType}',
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF6C757D),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E2229),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatCurrency(p.price, symbol: symbol),
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E2229),
                            ),
                          ),
                          if (p.isDiscounted)
                            Text(
                              formatCurrency(p.amount, symbol: symbol),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF94A3B8),
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                        ],
                      ),
                      // Quick Add '+' Button
                      InkWell(
                        onTap: () => _handleAddToCart(context, p),
                        child: Container(
                          padding: const EdgeInsets.all(5.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFB3261E),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.add,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 7. All Products Grid with Dynamic Filters
  // ---------------------------------------------------------------------------
  Widget _buildAllProductsSection(
    BuildContext context,
    Company company,
    List<Product> products,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'All Products (${products.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E2229),
                ),
              ),
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

        const SizedBox(height: 10),

        // Quick Filter / Sort Pills Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Sort dropdown popup
              PopupMenuButton<String>(
                onSelected: (val) => setState(() => _sortBy = val),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E6EC)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _sortLabel(_sortBy),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down, size: 16),
                    ],
                  ),
                ),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'popularity',
                    child: Text('Sort: Popularity'),
                  ),
                  PopupMenuItem(
                    value: 'price_asc',
                    child: Text('Price: Low to High'),
                  ),
                  PopupMenuItem(
                    value: 'price_desc',
                    child: Text('Price: High to Low'),
                  ),
                  PopupMenuItem(
                    value: 'rating',
                    child: Text('Rating: Highest First'),
                  ),
                ],
              ),
              const SizedBox(width: 8),

              // In Stock Filter Chip
              FilterChip(
                label: const Text('In Stock'),
                selected: _onlyInStock,
                onSelected: (val) => setState(() => _onlyInStock = val),
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: _onlyInStock ? FontWeight.bold : FontWeight.w500,
                  color: _onlyInStock
                      ? const Color(0xFFB3261E)
                      : const Color(0xFF495057),
                ),
                backgroundColor: Colors.white,
                selectedColor: const Color(0xFFFFEBEA),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: _onlyInStock
                        ? const Color(0xFFB3261E)
                        : const Color(0xFFE2E6EC),
                  ),
                ),
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Responsive Product Grid
        if (products.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text(
                'No products found matching the selected category',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 900
                    ? 4
                    : constraints.maxWidth > 600
                    ? 3
                    : 2;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 0.62,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, i) =>
                      _gridProductCard(context, company, products[i]),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _gridProductCard(BuildContext context, Company company, Product p) {
    final symbol = company.currencySymbol;
    final hasImage = p.images.isNotEmpty && p.images.first.trim().isNotEmpty;
    final discountPercent = p.discountPercent.round();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E6EC)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.04),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => context.go(AppRoutes.productPath(p.id)),
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Product Image & Discount Tag
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: hasImage
                          ? Image.network(
                              p.images.first.trim(),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  _productFallbackImage(p),
                            )
                          : _productFallbackImage(p),
                    ),
                  ),
                  if (discountPercent > 0)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5.5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB3261E),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$discountPercent% OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Details & Add Button
            Padding(
              padding: const EdgeInsets.all(9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${p.unit} ${p.unitType}',
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF6C757D),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E2229),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        formatCurrency(p.price, symbol: symbol),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E2229),
                        ),
                      ),
                      if (p.isDiscounted) ...[
                        const SizedBox(width: 4),
                        Text(
                          formatCurrency(p.amount, symbol: symbol),
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF94A3B8),
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Solid Red '🛒 Add' Button
                  SizedBox(
                    width: double.infinity,
                    height: 32,
                    child: ElevatedButton(
                      onPressed: () => _handleAddToCart(context, p),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB3261E),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 14,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Add',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 8. Dynamic Customer Reviews from Firestore
  // ---------------------------------------------------------------------------
  Widget _buildReviewsSection(
    BuildContext context,
    Company company,
    List<Review> reviews,
  ) {
    final total = reviews.length;
    final avgRating = total > 0
        ? reviews.fold<int>(0, (sum, r) => sum + r.rating) / total
        : 5.0;

    final count5 = reviews.where((r) => r.rating == 5).length;
    final count4 = reviews.where((r) => r.rating == 4).length;
    final count3 = reviews.where((r) => r.rating == 3).length;
    final count2 = reviews.where((r) => r.rating == 2).length;
    final count1 = reviews.where((r) => r.rating == 1).length;

    final p5 = total > 0 ? count5 / total : 0.8;
    final p4 = total > 0 ? count4 / total : 0.15;
    final p3 = total > 0 ? count3 / total : 0.05;
    final p2 = total > 0 ? count2 / total : 0.0;
    final p1 = total > 0 ? count1 / total : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E6EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Customer Reviews',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E2229),
                ),
              ),
              Row(
                children: [
                  Text(
                    avgRating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E2229),
                    ),
                  ),
                  const Text(
                    ' /5.0',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6C757D)),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 2),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                total > 0
                    ? 'Based on $total verified ${total == 1 ? 'review' : 'reviews'}'
                    : 'No customer reviews yet',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF6C757D),
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < avgRating.round()
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 14,
                    color: const Color(0xFFFFB800),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Rating Breakdown Progress Bars
          _ratingBar(5, p5, '${(p5 * 100).round()}%'),
          _ratingBar(4, p4, '${(p4 * 100).round()}%'),
          _ratingBar(3, p3, '${(p3 * 100).round()}%'),
          _ratingBar(2, p2, '${(p2 * 100).round()}%'),
          _ratingBar(1, p1, '${(p1 * 100).round()}%'),

          const Divider(height: 24),

          // Render Real Customer Review items from Firestore
          if (reviews.isNotEmpty) ...[
            ...reviews
                .take(3)
                .map(
                  (r) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              r.userName.trim().isNotEmpty
                                  ? r.userName
                                  : 'Verified Shopper',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            if (r.createdAt != null)
                              Text(
                                formatDate(r.createdAt!),
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: List.generate(
                            5,
                            (i) => Icon(
                              i < r.rating
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 13,
                              color: const Color(0xFFFFB800),
                            ),
                          ),
                        ),
                        if (r.message.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '"${r.message}"',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFF495057),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Text(
                  'Be the first to leave a review for this store!',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6C757D)),
                ),
              ),
            ),

          const SizedBox(height: 8),

          // Leave / View All Reviews Link
          Center(
            child: TextButton.icon(
              onPressed: () => context.go(
                AppRoutes.reviews.replaceFirst(':companyId', company.id),
              ),
              icon: const Icon(
                Icons.rate_review_outlined,
                size: 16,
                color: Color(0xFFB3261E),
              ),
              label: const Text(
                'View All Reviews & Leave Feedback',
                style: TextStyle(
                  color: Color(0xFFB3261E),
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratingBar(int star, double percent, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Text(
            '$star★',
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6C757D),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: const Color(0xFFECEEF1),
                valueColor: AlwaysStoppedAnimation<Color>(
                  star >= 4
                      ? const Color(0xFF0CA678)
                      : star == 3
                      ? const Color(0xFFFFB800)
                      : const Color(0xFFE03131),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 28,
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  Widget _productFallbackImage(Product p) {
    return Container(
      color: const Color(0xFFF8F9FA),
      child: Center(
        child: Icon(
          Icons.shopping_bag_outlined,
          size: 32,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }

  String _sortLabel(String sort) {
    switch (sort) {
      case 'price_asc':
        return 'Price: Low to High';
      case 'price_desc':
        return 'Price: High to Low';
      case 'rating':
        return 'Rating: Highest First';
      default:
        return 'Sort: Popularity';
    }
  }

  void _showStoreDetailsSheet(BuildContext context, Company company) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              company.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (company.details.isNotEmpty) ...[
              Text(
                company.details,
                style: const TextStyle(color: Color(0xFF6C757D)),
              ),
              const SizedBox(height: 8),
            ],
            if (company.address.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Color(0xFFB3261E),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      company.address,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 16,
                  color: Color(0xFF0CA678),
                ),
                const SizedBox(width: 6),
                Text(
                  company.isOpenNow() ? 'Open Now' : 'Currently Closed',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: company.isOpenNow()
                        ? const Color(0xFF0CA678)
                        : const Color(0xFFE03131),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
