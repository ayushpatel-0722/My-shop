import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/banner.dart';
import '../../../core/domain/category_tree.dart';
import '../../../core/models/category.dart';
import '../../../core/models/company.dart';
import '../../../core/models/home_explore_category.dart';
import '../../../core/models/home_trending_item.dart';
import '../../../core/models/product.dart';
import '../../../core/models/review.dart';
import '../../../core/models/voucher.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/cart_notification.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../core/widgets/app_product_image.dart';
import '../../../core/widgets/modern_shimmer.dart';
import '../../auth/auth_cubit.dart';
import '../../auth/widgets/auth_bottom_sheet.dart';
import '../../checkout/cart/cart_cubit.dart';
import '../widgets/location_picker_sheet.dart';
import '../widgets/marketplace_bottom_nav.dart';
import '../widgets/product_card.dart';
import '../widgets/section_header.dart';
import '../widgets/web_header.dart';

/// Vibrant Marketplace Home Feed matching design system screenshots.
///
/// Features:
/// - Curved coral header with delivery location, notification badge, cart count badge, and search pill.
/// - Grand Festive Mega Sale banner with interactive promo code.
/// - "Explore Categories" circle rail with soft pastel tints and resilient icon/emoji/image fallbacks.
/// - "Store Vouchers & Deals" horizontal claimable ticket coupons.
/// - "Shops Near You" with high-fidelity avatars, verified checkmarks, ratings, and delivery pills.
/// - "Recommended for You" 2-column product grid with discount tags and floating add-to-cart.
/// - "Trending Now 🔥" horizontal product rail.
/// - 4-item bottom navigation bar (MarketplaceBottomNav).
class HomeScreen extends StatefulWidget {
  final String? shopId;

  const HomeScreen({super.key, this.shopId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _carouselCtrl = PageController();
  final _scrollCtrl = ScrollController();
  final _categoryKey = GlobalKey();
  int _carouselIndex = 0;
  String? _selectedShopId;

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shopId != widget.shopId) {
      setState(() => _selectedShopId = widget.shopId);
    }
  }

  // Track claimed vouchers for visual feedback
  final Set<String> _claimedVouchers = {};

  // Pastel background colors for category circles
  static const _pastelColors = [
    Color(0xFFE6F7F2), // Mint Green
    Color(0xFFFFEBEA), // Soft Coral
    Color(0xFFEBF5FF), // Soft Ice Blue
    Color(0xFFF3E8FF), // Lavender
    Color(0xFFFFF0E6), // Soft Peach
    Color(0xFFFFF8E6), // Soft Amber
    Color(0xFFE6F9FB), // Soft Cyan
  ];

  bool _hasCheckedMobile = false;
  Timer? _mobileCheckTimer;

  @override
  void initState() {
    super.initState();
    _selectedShopId = widget.shopId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mobileCheckTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted || _hasCheckedMobile) return;
        _hasCheckedMobile = true;
        _promptMobileNumberIfNeeded();
      });
    });
  }

  @override
  void dispose() {
    _mobileCheckTimer?.cancel();
    _carouselCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final companies = repo.companies();
    final categories = repo.categories();
    final ads = repo.adBanners();
    final recs = repo.recommendations();
    final recommendedProducts = repo.products();
    final vouchers = repo.vouchers('');

    final effectiveShopId = _selectedShopId ?? widget.shopId ?? '';
    final dynamicExploreCategories = repo.homeExploreCategories(
      activeOnly: true,
    );
    final dynamicTrendingItems = repo.homeTrendingNow(
      shopId: effectiveShopId,
      activeOnly: true,
    );
    final trendingProducts = repo.products(companyId: effectiveShopId);

    final isDesktop = context.isDesktop;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      // Desktop sticky header replaces the mobile coral header
      appBar: isDesktop
          ? PreferredSize(
              preferredSize: const Size.fromHeight(64),
              child: WebHeader(currentIndex: 0),
            )
          : null,
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            // Mobile-only: Vibrant Coral Header & Embedded Search
            if (!isDesktop)
              SliverToBoxAdapter(child: _buildHeader(context, l10n)),

            // Content Body — Full Available Web Width
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 32),
              sliver: SliverToBoxAdapter(
                child: Padding(
                  padding: isDesktop
                      ? const EdgeInsets.symmetric(horizontal: 24)
                      : EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: isDesktop ? 20 : 14),

                      // 1. Promotional Banner Carousel (hides if empty)
                      _adsCarousel(ads),

                      // 2. Explore Categories (hides if empty, See All -> CategoriesScreen)
                      _exploreCategoriesSection(
                        categories,
                        dynamicExploreCategories,
                      ),

                      // 3. Store Vouchers & Deals (hides if empty, See All -> Vouchers Sheet)
                      _storeVouchersSection(vouchers),

                      // 4. Shops Near You (hides if empty, See All -> All Shops Sheet)
                      _shopsNearYouSection(companies),

                      // 5. Trending Now (Vertically scrollable list of all active items)
                      _trendingProductsSection(
                        products: trendingProducts,
                        categories: categories,
                        dynamicTrending: dynamicTrendingItems,
                      ),

                      // 6. Recommended For You Grid (hides if empty, See All -> Search)
                      _recommendationsSection(recs, recommendedProducts, l10n),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      // Bottom Navigation Bar — hidden on desktop
      bottomNavigationBar: isDesktop
          ? null
          : const MarketplaceBottomNav(currentIndex: 0),
    );
  }

  // ---------------------------------------------------------------------------
  // Top Header with Location, Actions, and Search Bar
  // ---------------------------------------------------------------------------
  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    final activeAddress = AuthSession.activeAddress;
    final deliverToTitle =
        activeAddress != null && activeAddress.name.isNotEmpty
        ? AppLocalizations.of(context).deliverTo(activeAddress.name)
        : activeAddress != null && activeAddress.label.isNotEmpty
        ? AppLocalizations.of(context).deliverTo(activeAddress.label)
        : AppLocalizations.of(context).deliverTo2;
    final deliverToAddress = activeAddress != null
        ? (activeAddress.shortLocation.isNotEmpty
              ? activeAddress.shortLocation
              : activeAddress.formattedAddress)
        : 'Ahmedabad, Gujarat 380001';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF5247), Color(0xFFD6281C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(255, 82, 71, 0.25),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppTheme.shopperMaxContentWidth,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                context.isDesktop ? 24 : 16,
                context.isDesktop ? 16 : 12,
                context.isDesktop ? 24 : 16,
                context.isDesktop ? 22 : 18,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Delivery Location + Notification + Cart + User Avatar
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: InkWell(
                          onTap: () => _showLocationPicker(context),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                deliverToTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFFFDAD6),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      deliverToAddress,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Notification Icon with Badge
                      IconButton(
                        icon: const Badge(
                          smallSize: 8,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.notifications_outlined,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        onPressed: () => context.push(AppRoutes.notifications),
                      ),

                      // Shopping Cart Icon with Count Badge
                      BlocBuilder<CartCubit, CartState>(
                        builder: (context, state) {
                          final count = state.totalItems;
                          return IconButton(
                            icon: Badge(
                              isLabelVisible: count > 0,
                              label: Text(
                                '$count',
                                style: const TextStyle(
                                  color: Color(0xFFFF5247),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                              backgroundColor: Colors.white,
                              child: const Icon(
                                Icons.shopping_cart_outlined,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            onPressed: () => _openCartSafely(context),
                          );
                        },
                      ),

                      // User Avatar
                      InkWell(
                        onTap: () => context.go(AppRoutes.account),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white70,
                              width: 1.5,
                            ),
                          ),
                          child: const CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.white24,
                            child: Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Search Bar Pill
                  InkWell(
                    onTap: () => context.push(AppRoutes.search),
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [
                          BoxShadow(
                            color: Color.fromRGBO(0, 0, 0, 0.08),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search,
                            color: Color(0xFFFF5247),
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              AppLocalizations.of(
                                context,
                              ).searchProductsCategoriesOrStores,
                              style: const TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.tune,
                              size: 16,
                              color: Color(0xFF4B5563),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openCartSafely(BuildContext context) async {
    if (AuthSession.currentUser == null) {
      final ok = await AuthBottomSheet.show(context);
      if (ok && context.mounted) {
        context.push(AppRoutes.cart);
      }
      return;
    }
    context.push(AppRoutes.cart);
  }

  // ---------------------------------------------------------------------------
  // Promotional Banner Carousel
  // ---------------------------------------------------------------------------
  Widget _adsCarousel(Stream<List<AdBanner>> ads) {
    return StreamBuilder<List<AdBanner>>(
      stream: ads,
      builder: (context, snap) {
        final list = snap.data ?? const <AdBanner>[];
        final totalCards = list.isEmpty ? 1 : list.length + 1;

        return Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth;
                // Desktop: ~21:6 ratio, Tablet: ~16:5, Mobile: fixed 165px
                final height = context.isDesktop
                    ? (availableWidth / (21 / 7)).clamp(240.0, 340.0)
                    : context.isTablet
                    ? (availableWidth / (16 / 5)).clamp(190.0, 260.0)
                    : 165.0;
                return SizedBox(
                  height: height,
                  child: PageView.builder(
                    controller: _carouselCtrl,
                    itemCount: totalCards,
                    onPageChanged: (i) => setState(() => _carouselIndex = i),
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return _festiveHeroBanner(context);
                      }
                      return _adBannerCard(context, list[i - 1]);
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                totalCards,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _carouselIndex ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _carouselIndex
                        ? const Color(0xFFFF5247)
                        : const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _festiveHeroBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF8E0E00), Color(0xFF1F1C18)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.15),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background subtle pattern
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.celebration,
              size: 140,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: context.isDesktop ? 600 : 230,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              AppLocalizations.of(context).limitedTimeOffer,
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 9,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            AppLocalizations.of(context).grandFestiveMegaSale,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppLocalizations.of(context).flat50OffFreeDelivery,
                            style: TextStyle(
                              color: Color(0xFFFFEBEA),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(
                                const ClipboardData(text: 'FESTIVE50'),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    AppLocalizations.of(
                                      context,
                                    ).promoCodeFestive50CopiedToClipboard,
                                  ),
                                  backgroundColor: Color(0xFF1E8F66),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white38),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      AppLocalizations.of(
                                        context,
                                      ).codeFestive50,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(
                                      Icons.copy,
                                      size: 11,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => context.push(AppRoutes.search),
                  child: Text(
                    AppLocalizations.of(context).shopNow,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _adBannerCard(BuildContext context, AdBanner ad) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.12),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child:
            ad.image.isNotEmpty &&
                (ad.image.startsWith('http://') ||
                    ad.image.startsWith('https://'))
            ? Image.network(
                ad.image,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _bannerFallbackContent(ad),
              )
            : _bannerFallbackContent(ad),
      ),
    );
  }

  Widget _bannerFallbackContent(AdBanner ad) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3D38D9), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.campaign, size: 36, color: Colors.white),
            const SizedBox(height: 6),
            Text(
              ad.actionTarget.isNotEmpty
                  ? ad.actionTarget
                  : AppLocalizations.of(context).specialMarketplaceOffer,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Categories Rail
  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------
  // Explore Categories Section (Dynamic Configuration with Fallback)
  // ---------------------------------------------------------------------------
  Widget _exploreCategoriesSection(
    Stream<List<Category>> categories,
    Stream<List<HomeExploreCategory>> dynamicCategories,
  ) {
    return StreamBuilder<List<Category>>(
      stream: categories,
      builder: (context, catSnap) {
        if (catSnap.connectionState == ConnectionState.waiting && !catSnap.hasData) {
          return const M3CategoryRailSkeleton();
        }
        final allCategories = catSnap.data ?? const <Category>[];

        return StreamBuilder<List<HomeExploreCategory>>(
          stream: dynamicCategories,
          builder: (context, dynamicSnap) {
            final dynamicItems =
                dynamicSnap.data ?? const <HomeExploreCategory>[];
            final List<Category> list;

            if (dynamicItems.isNotEmpty) {
              // Map dynamic items to Category instances in saved displayOrder
              final byId = {for (final c in allCategories) c.id: c};
              final resolved = <Category>[];
              for (final item in dynamicItems) {
                final cat = byId[item.categoryId];
                if (cat != null) {
                  resolved.add(cat);
                } else if (item.categoryName.isNotEmpty) {
                  resolved.add(
                    Category(
                      id: item.categoryId,
                      name: item.categoryName,
                      companyId: item.shopId,
                    ),
                  );
                }
              }
              list = resolved.isNotEmpty
                  ? resolved
                  : CategoryHierarchy.sortedByOrder(allCategories);
            } else {
              // Seamless fallback to default catalogue categories
              list = CategoryHierarchy.sortedByOrder(allCategories);
            }

            if (list.isEmpty) return const SizedBox.shrink();

            return Column(
              children: [
                Padding(
                  key: _categoryKey,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SectionHeader(
                    title: AppLocalizations.of(context).exploreCategories,
                    onViewAll: () => context.push(AppRoutes.categories),
                  ),
                ),
                const SizedBox(height: 12),
                _categoryRailContent(list),
                const SizedBox(height: 22),
              ],
            );
          },
        );
      },
    );
  }

  Widget _categoryRailContent(List<Category> list) {
    // On desktop, show a responsive grid; on mobile/tablet, keep horizontal scroll
    if (context.isDesktop) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = 100.0;
            final spacing = 16.0;
            final cols =
                ((constraints.maxWidth + spacing) / (itemWidth + spacing))
                    .floor()
                    .clamp(4, 12);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.78,
              ),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final cat = list[i];
                final bgColor = _pastelColors[i % _pastelColors.length];
                return _buildCategoryGridItem(cat, bgColor);
              },
            );
          },
        ),
      );
    }

    return SizedBox(
      height: 126,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final cat = list[i];
          final bgColor = _pastelColors[i % _pastelColors.length];

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.push(
                '${AppRoutes.categoryPath(cat.id)}?name=${Uri.encodeComponent(cat.name)}',
              ),
              borderRadius: BorderRadius.circular(20),
              splashColor: Theme.of(
                context,
              ).primaryColor.withValues(alpha: 0.12),
              highlightColor: Theme.of(
                context,
              ).primaryColor.withValues(alpha: 0.06),
              child: SizedBox(
                width: 80,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.9),
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color.fromRGBO(0, 0, 0, 0.05),
                            blurRadius: 10,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: _buildCategoryIcon(cat),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 32,
                      child: Center(
                        child: Text(
                          cat.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.1,
                            color: Color(0xFF1E2229),
                            height: 1.15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryGridItem(Category cat, Color bgColor) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(
          '${AppRoutes.categoryPath(cat.id)}?name=${Uri.encodeComponent(cat.name)}',
        ),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.9),
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.05),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: _buildCategoryIcon(cat),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              cat.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E2229),
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryIcon(Category cat) {
    if (cat.iconUrl.startsWith('http://') ||
        cat.iconUrl.startsWith('https://')) {
      return Image.network(
        cat.iconUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.black.withValues(alpha: 0.04),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (_, _, _) => Center(child: _fallbackCategoryIcon(cat)),
      );
    }
    if (cat.iconUrl.startsWith('assets/')) {
      return Image.asset(
        cat.iconUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Center(child: _fallbackCategoryIcon(cat)),
      );
    }
    return Center(child: _fallbackCategoryIcon(cat));
  }

  Widget _fallbackCategoryIcon(Category cat) {
    if (cat.iconUrl.isNotEmpty && cat.iconUrl.runes.length <= 4) {
      return Text(cat.iconUrl, style: const TextStyle(fontSize: 28));
    }
    final name = cat.name.toLowerCase();
    if (name.contains('cloth') ||
        name.contains('fashion') ||
        name.contains('wear')) {
      return const Icon(
        Icons.checkroom_rounded,
        color: Color(0xFFFF5247),
        size: 30,
      );
    } else if (name.contains('coffee') ||
        name.contains('cafe') ||
        name.contains('tea') ||
        name.contains('beverag')) {
      return const Icon(
        Icons.local_cafe_rounded,
        color: Color(0xFF795548),
        size: 30,
      );
    } else if (name.contains('spice') ||
        name.contains('masala') ||
        name.contains('herb') ||
        name.contains('seasoning')) {
      return const Icon(Icons.eco_rounded, color: Color(0xFFE65100), size: 30);
    } else if (name.contains('sweet') ||
        name.contains('cake') ||
        name.contains('dessert')) {
      return const Icon(Icons.cake_rounded, color: Color(0xFFFF9800), size: 30);
    } else if (name.contains('food') ||
        name.contains('snack') ||
        name.contains('grocery')) {
      return const Icon(
        Icons.fastfood_rounded,
        color: Color(0xFF4CAF50),
        size: 30,
      );
    } else if (name.contains('electr') ||
        name.contains('gadget') ||
        name.contains('phone')) {
      return const Icon(
        Icons.devices_rounded,
        color: Color(0xFF2196F3),
        size: 30,
      );
    }
    return const Icon(
      Icons.category_rounded,
      color: Color(0xFFFF5247),
      size: 30,
    );
  }

  // ---------------------------------------------------------------------------
  // Store Vouchers & Deals Section
  // ---------------------------------------------------------------------------
  Widget _storeVouchersSection(Stream<List<Voucher>> vouchers) {
    return StreamBuilder<List<Voucher>>(
      stream: vouchers,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const M3VoucherRailSkeleton();
        }
        final now = DateTime.now();
        final list = (snap.data ?? const <Voucher>[])
            .where((v) => v.isLiveAt(now) && !v.isExhausted)
            .toList();

        if (list.isEmpty) return const SizedBox.shrink();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SectionHeader(
                title: AppLocalizations.of(context).storeVouchersDeals,
                onViewAll: () => _showAllVouchersSheet(
                  context,
                  vouchers,
                  initialList: list,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _vouchersRailContent(list),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _vouchersRailContent(List<Voucher> list) {
    return SizedBox(
      height: 94,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _voucherCard(context, list[i]),
      ),
    );
  }

  Widget _voucherCard(
    BuildContext context,
    Voucher v, {
    bool isSheet = false,
    VoidCallback? onClaimed,
  }) {
    final isClaimed = _claimedVouchers.contains(v.id);
    final discountStr = v.discountLabel;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: isSheet ? double.infinity : 275,
      padding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: isSheet ? 12 : 10,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceContainerDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isClaimed
              ? const Color(0xFF1E8F66).withValues(alpha: 0.5)
              : (isDark ? const Color(0xFF3B4F6C) : const Color(0xFFFFD6D3)),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : const Color.fromRGBO(0, 0, 0, 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left Ticket Badge
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isClaimed
                  ? const Color(0xFFEFFAF5)
                  : const Color(0xFFFFEBEA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.confirmation_number_outlined,
              color: isClaimed
                  ? const Color(0xFF1E8F66)
                  : const Color(0xFFFF5247),
              size: 21,
            ),
          ),
          const SizedBox(width: 10),

          // Center Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  discountStr,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: isDark ? Colors.white : const Color(0xFF1E2229),
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isClaimed
                          ? const Color(0xFFEFFAF5)
                          : (isDark
                              ? const Color(0xFF2E3E55)
                              : const Color(0xFFF9FAFB)),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isClaimed
                            ? const Color(0xFF1E8F66).withValues(alpha: 0.3)
                            : (isDark
                                ? const Color(0xFF3B4F6C)
                                : const Color(0xFFE5E7EB)),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      v.code,
                      style: TextStyle(
                        fontSize: 11,
                        color: isClaimed
                            ? const Color(0xFF1E8F66)
                            : const Color(0xFFFF5247),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  v.minOrderAmt > 0
                      ? AppLocalizations.of(
                          context,
                        ).minOrder3(v.minOrderAmt.toStringAsFixed(0))
                      : (v.firstTimeOnly
                            ? AppLocalizations.of(context).firstOrderOnly
                            : AppLocalizations.of(context).onAllOrders),
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Right Claim / Copy Action
          InkWell(
            onTap: () {
              setState(() => _claimedVouchers.add(v.id));
              onClaimed?.call();
              Clipboard.setData(ClipboardData(text: v.code));
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(
                            context,
                          ).couponCopiedApplyAtCheckout(v.code),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: const Color(0xFF1E8F66),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isClaimed
                    ? const Color(0xFFEFFAF5)
                    : const Color(0xFFFF5247),
                borderRadius: BorderRadius.circular(20),
                border: isClaimed
                    ? Border.all(color: const Color(0xFF1E8F66))
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isClaimed ? Icons.check : Icons.copy_rounded,
                    size: 12,
                    color: isClaimed ? const Color(0xFF1E8F66) : Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isClaimed
                        ? AppLocalizations.of(context).copied
                        : AppLocalizations.of(context).copy,
                    style: TextStyle(
                      color: isClaimed ? const Color(0xFF1E8F66) : Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shops Near You Section
  // ---------------------------------------------------------------------------
  Widget _shopsNearYouSection(Stream<List<Company>> companies) {
    return StreamBuilder<List<Company>>(
      stream: companies,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: M3ShopCardSkeleton(),
          );
        }
        final list = (snap.data ?? const <Company>[])
            .where((c) => c.status != 'inactive' && c.status != 'suspended')
            .toList();
        if (list.isEmpty) return const SizedBox.shrink();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SectionHeader(
                title: AppLocalizations.of(context).shopsNearYou,
                subtitle: AppLocalizations.of(context).verifiedLocalMerchants,
                onViewAll: () => _showAllShopsSheet(context, list),
              ),
            ),
            const SizedBox(height: 12),
            _shopsNearYouRailContent(list),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _shopsNearYouRailContent(List<Company> list) {
    return SizedBox(
      height: 198,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, i) => _shopCard(context, list[i], i),
      ),
    );
  }

  Widget _shopCard(BuildContext context, Company company, int index) {
    final photoUrl = company.displayImage;
    final hasPhoto =
        photoUrl.isNotEmpty &&
        (photoUrl.startsWith('http://') || photoUrl.startsWith('https://'));
    final categoryOrDetails = company.category.isNotEmpty
        ? company.category
        : (company.details.isNotEmpty ? company.details : 'Grocery & Staples');

    return InkWell(
      onTap: () => context.push(
        AppRoutes.companyPath(
          company.slug.isNotEmpty ? company.slug : company.id,
        ),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 144,
        height: 196,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.12),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Storefront / Company background image
              hasPhoto
                  ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _shopCardFallbackBackground(company),
                    )
                  : _shopCardFallbackBackground(company),

              // 2. Dark gradient overlay for clear contrast
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.05),
                      Colors.black.withValues(alpha: 0.72),
                      Colors.black.withValues(alpha: 0.94),
                    ],
                    stops: const [0.0, 0.4, 0.72, 1.0],
                  ),
                ),
              ),

              // 3. Bottom text overlay
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Company Name
                    Text(
                      company.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),

                    // Rating & Review count — only displayed if at least 5 reviews
                    StreamBuilder<List<Review>>(
                      stream: repo.reviews(company.id),
                      builder: (context, reviewSnap) {
                        final reviews = reviewSnap.data ?? const <Review>[];
                        final reviewCount = reviews.isNotEmpty
                            ? reviews.length
                            : company.reviewCount;
                        if (reviewCount < 5) return const SizedBox.shrink();

                        final avgRating = reviews.isNotEmpty
                            ? (reviews.fold<double>(
                                    0.0,
                                    (s, r) => s + r.rating,
                                  ) /
                                  reviews.length)
                            : (company.rating > 0 ? company.rating : 4.8);

                        final countStr = reviewCount >= 1000
                            ? '${(reviewCount / 1000).toStringAsFixed(1)}k'
                            : '$reviewCount';

                        return Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: Color(0xFFFFC107),
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  '${avgRating.toStringAsFixed(1)} ($countStr)',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFFD54F),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // Store Category / Details
                    const SizedBox(height: 2),
                    Text(
                      categoryOrDetails,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFE2E8F0),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shopCardFallbackBackground(Company company) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF8E0E00), Color(0xFF1F1C18)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          company.name.isNotEmpty
              ? company.name.substring(0, 1).toUpperCase()
              : 'S',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white30,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Trending Products Section (Dynamic Configuration with Fallback)
  // ---------------------------------------------------------------------------
  Widget _trendingProductsSection({
    required Stream<List<Product>> products,
    required Stream<List<Category>> categories,
    required Stream<List<HomeTrendingItem>> dynamicTrending,
  }) {
    return StreamBuilder<List<Product>>(
      stream: products,
      builder: (context, prodSnap) {
        if (prodSnap.connectionState == ConnectionState.waiting && !prodSnap.hasData) {
          return const M3ProductGridSkeleton(itemCount: 4);
        }
        final allProducts = prodSnap.data ?? const <Product>[];

        return StreamBuilder<List<Category>>(
          stream: categories,
          builder: (context, catSnap) {
            final allCategories = catSnap.data ?? const <Category>[];

            return StreamBuilder<List<HomeTrendingItem>>(
              stream: dynamicTrending,
              builder: (context, trendSnap) {
                final dynamicItems =
                    trendSnap.data ?? const <HomeTrendingItem>[];

                Widget? content;

                if (dynamicItems.isNotEmpty) {
                  final prodsById = {for (final p in allProducts) p.id: p};
                  final catsById = {for (final c in allCategories) c.id: c};

                  final resolvedItems = <_TrendingRailItem>[];
                  for (final item in dynamicItems) {
                    if (item.isProduct && item.productId != null) {
                      final prod = prodsById[item.productId!];
                      if (prod != null) {
                        if (prod.images.isEmpty &&
                            item.imageUrl != null &&
                            item.imageUrl!.trim().isNotEmpty) {
                          resolvedItems.add(
                            _TrendingRailItem.product(
                              prod.copyWith(images: [item.imageUrl!.trim()]),
                            ),
                          );
                        } else {
                          resolvedItems.add(_TrendingRailItem.product(prod));
                        }
                      } else if (item.productName != null &&
                          item.productName!.isNotEmpty) {
                        final fallbackImages =
                            (item.imageUrl != null &&
                                item.imageUrl!.trim().isNotEmpty)
                            ? [item.imageUrl!.trim()]
                            : const <String>[];
                        resolvedItems.add(
                          _TrendingRailItem.product(
                            Product(
                              id: item.productId!,
                              companyId: item.shopId,
                              categoryId: item.categoryId ?? '',
                              name: item.productName!,
                              amount: item.price ?? 0,
                              images: fallbackImages,
                            ),
                          ),
                        );
                      }
                    } else if (item.isCategory && item.categoryId != null) {
                      final cat = catsById[item.categoryId!];
                      if (cat != null) {
                        resolvedItems.add(_TrendingRailItem.category(cat));
                      } else if (item.categoryName != null &&
                          item.categoryName!.isNotEmpty) {
                        resolvedItems.add(
                          _TrendingRailItem.category(
                            Category(
                              id: item.categoryId!,
                              name: item.categoryName!,
                              companyId: item.shopId,
                            ),
                          ),
                        );
                      }
                    }
                  }

                  if (resolvedItems.isNotEmpty) {
                    content = _dynamicTrendingVerticalContent(resolvedItems);
                  }
                } else if (allProducts.isNotEmpty) {
                  content = _trendingProductsVerticalContent(allProducts);
                }

                if (content == null) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SectionHeader(
                        title: AppLocalizations.of(context).trendingNow2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    StreamBuilder<List<Company>>(
                      stream: repo.companies(),
                      builder: (context, compSnap) {
                        final compList = (compSnap.data ?? const <Company>[])
                            .where(
                              (c) =>
                                  c.status != 'inactive' &&
                                  c.status != 'suspended',
                            )
                            .toList();
                        if (compList.length <= 1) {
                          return const SizedBox.shrink();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                ChoiceChip(
                                  label: const Text('All'),
                                  selected:
                                      _selectedShopId == null ||
                                      _selectedShopId!.isEmpty,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() => _selectedShopId = '');
                                    }
                                  },
                                ),
                                ...compList.map((c) {
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: ChoiceChip(
                                      label: Text(c.name),
                                      selected: _selectedShopId == c.id,
                                      onSelected: (selected) {
                                        setState(
                                          () => _selectedShopId = selected
                                              ? c.id
                                              : '',
                                        );
                                      },
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    content,
                    const SizedBox(height: 22),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  static int _trendingGridColumns(double width) {
    if (width < 600) return 2;
    if (width < 900) return 3;
    if (width < 1200) return 4;
    if (width < 1600) return 5;
    return 6;
  }

  Widget _dynamicTrendingVerticalContent(List<_TrendingRailItem> items) {
    if (context.isDesktop) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final crossAxisCount = _trendingGridColumns(width);
          final childAspectRatio = ResponsiveGrid.calculateProductAspectRatio(
            width,
            crossAxisCount,
            showBrand: true,
          );
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: childAspectRatio,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final entry = items[i];
              if (entry.isProduct && entry.product != null) {
                return ProductCard(
                  product: entry.product!,
                  onTap: () => context.push(
                    AppRoutes.productPath(entry.product!.id),
                  ),
                );
              } else if (entry.category != null) {
                return _TrendingCategoryCard(
                  category: entry.category!,
                  onTap: () => context.push(
                    '${AppRoutes.categoryPath(entry.category!.id)}?name=${Uri.encodeComponent(entry.category!.name)}',
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          );
        },
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final entry = items[i];
        if (entry.isProduct && entry.product != null) {
          return TrendingVerticalProductCard(product: entry.product!);
        } else if (entry.category != null) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TrendingCategoryCard(
              category: entry.category!,
              onTap: () => context.push(
                '${AppRoutes.categoryPath(entry.category!.id)}?name=${Uri.encodeComponent(entry.category!.name)}',
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _trendingProductsVerticalContent(List<Product> list) {
    if (context.isDesktop) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final crossAxisCount = _trendingGridColumns(width);
          final childAspectRatio = ResponsiveGrid.calculateProductAspectRatio(
            width,
            crossAxisCount,
            showBrand: true,
          );
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: childAspectRatio,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: list.length,
            itemBuilder: (context, i) {
              return ProductCard(
                product: list[i],
                onTap: () => context.push(
                  AppRoutes.productPath(list[i].id),
                ),
              );
            },
          );
        },
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: list.length,
      itemBuilder: (context, i) {
        return TrendingVerticalProductCard(product: list[i]);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Recommendations Section (2-Column Grid)
  // ---------------------------------------------------------------------------
  Widget _recommendationsSection(
    Future<List<Product>> recs,
    Stream<List<Product>> allProducts,
    AppLocalizations l10n,
  ) {
    return StreamBuilder<List<Product>>(
      stream: allProducts,
      builder: (context, snapAll) {
        if (snapAll.connectionState == ConnectionState.waiting && !snapAll.hasData) {
          return const M3ProductGridSkeleton(itemCount: 4);
        }
        final allList = snapAll.data ?? const <Product>[];
        if (allList.isEmpty) return const SizedBox.shrink();

        return FutureBuilder<List<Product>>(
          future: recs,
          builder: (context, snapRecs) {
            final recList = snapRecs.data ?? const <Product>[];
            final productsToShow = recList.isNotEmpty ? recList : allList;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SectionHeader(
                    title: l10n.recommendedForYou,
                    onViewAll: () => context.push(AppRoutes.search),
                  ),
                ),
                const SizedBox(height: 10),
                _buildProductGridView(productsToShow),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildProductGridView(List<Product> products) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final crossAxisCount = ResponsiveGrid.calculateCrossAxisCount(
            width,
            maxCardWidth: 250,
          );
          final childAspectRatio = ResponsiveGrid.calculateProductAspectRatio(
            width,
            crossAxisCount,
            showBrand: true,
          );
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: childAspectRatio,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: products.length,
            itemBuilder: (context, i) => ProductCard(
              product: products[i],
              onTap: () => context.push(AppRoutes.productPath(products[i].id)),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Action Modals (Location, Vouchers Sheet, Mobile Prompt)
  // ---------------------------------------------------------------------------
  void _showLocationPicker(BuildContext context) async {
    final selected = await LocationPickerSheet.show(context);
    if (selected != null && mounted) {
      setState(() {});
    }
  }

  void _showAllVouchersSheet(
    BuildContext context,
    Stream<List<Voucher>> vouchers, {
    List<Voucher>? initialList,
  }) {
    final isDesktop = context.isDesktop || context.screenWidth >= 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDesktop) {
      showDialog(
        context: context,
        barrierColor: Colors.black54,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 580,
              maxHeight: MediaQuery.sizeOf(context).height * 0.85,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.16),
                  blurRadius: 28,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: _buildVouchersSheetBody(
              ctx,
              vouchers,
              initialList: initialList,
              isDesktop: true,
              scrollController: null,
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) => Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDark : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.12),
                  blurRadius: 20,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: _buildVouchersSheetBody(
              ctx,
              vouchers,
              initialList: initialList,
              isDesktop: false,
              scrollController: scrollController,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildVouchersSheetBody(
    BuildContext ctx,
    Stream<List<Voucher>> vouchers, {
    List<Voucher>? initialList,
    required bool isDesktop,
    ScrollController? scrollController,
  }) {
    final l10n = AppLocalizations.of(ctx);
    final isDark = Theme.of(ctx).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isDesktop) ...[
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.local_offer_rounded,
                      color: Color(0xFFFF5247),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.allActiveCoupons,
                          style: TextStyle(
                            fontSize: isDesktop ? 20 : 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1E2229),
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tap copy to apply code at checkout',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                size: 22,
                color: isDark ? Colors.white70 : const Color(0xFF64748B),
              ),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Divider(
          height: 1,
          thickness: 1,
          color: isDark ? Colors.white12 : const Color(0xFFF1F5F9),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: StreamBuilder<List<Voucher>>(
            stream: vouchers,
            initialData: initialList,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData &&
                  initialList == null) {
                return const M3VoucherRailSkeleton();
              }
              final now = DateTime.now();
              final list = (snap.data ?? initialList ?? const <Voucher>[])
                  .where((v) => v.isLiveAt(now) && !v.isExhausted)
                  .toList();
              if (list.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF2A2E39)
                                : const Color(0xFFF3F4F6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.confirmation_number_outlined,
                            size: 32,
                            color: isDark
                                ? Colors.white38
                                : const Color(0xFF9CA3AF),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.noVouchersAvailableRightNow,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF374151),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Check back soon for special promotions & discounts',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.white60
                                : const Color(0xFF6B7280),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }
              return StatefulBuilder(
                builder: (context, setSheetState) {
                  return ListView.separated(
                    controller: scrollController,
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _voucherCard(
                      context,
                      list[i],
                      isSheet: true,
                      onClaimed: () => setSheetState(() {}),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAllShopsSheet(BuildContext context, List<Company> initialList) {
    final isDesktop = context.isDesktop || context.screenWidth >= 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDesktop) {
      showDialog(
        context: context,
        barrierColor: Colors.black54,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 600,
              maxHeight: MediaQuery.sizeOf(context).height * 0.85,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.16),
                  blurRadius: 28,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: _buildShopsSheetBody(
              ctx,
              initialList: initialList,
              isDesktop: true,
              scrollController: null,
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (sheetContext, scrollController) => Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDark : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.12),
                  blurRadius: 20,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: _buildShopsSheetBody(
              sheetContext,
              initialList: initialList,
              isDesktop: false,
              scrollController: scrollController,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildShopsSheetBody(
    BuildContext ctx, {
    required List<Company> initialList,
    required bool isDesktop,
    ScrollController? scrollController,
  }) {
    final l10n = AppLocalizations.of(ctx);
    final isDark = Theme.of(ctx).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isDesktop) ...[
          Center(
            child: Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.allShopsStores,
                    style: TextStyle(
                      fontSize: isDesktop ? 20 : 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E2229),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.verifiedLocalMerchants,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                color: isDark ? Colors.white70 : const Color(0xFF64748B),
              ),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Divider(
          height: 1,
          thickness: 1,
          color: isDark ? Colors.white12 : const Color(0xFFF1F5F9),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<List<Company>>(
            stream: repo.companies(),
            initialData: initialList,
            builder: (context, snap) {
              final list = (snap.data ?? initialList)
                  .where(
                    (c) =>
                        c.status != 'inactive' && c.status != 'suspended',
                  )
                  .toList();
              if (list.isEmpty) {
                return Center(
                  child: Text(
                    l10n.noShopsAvailable,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    ),
                  ),
                );
              }
              return ListView.separated(
                controller: scrollController,
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final c = list[i];
                  final isOpen = c.isOpenNow();
                  final img = c.displayImage;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    tileColor: isDark ? AppTheme.surfaceContainerDark : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
                      ),
                    ),
                    leading: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child:
                            img.isNotEmpty &&
                                (img.startsWith('http://') ||
                                    img.startsWith('https://'))
                            ? Image.network(
                                img,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    _shopCardFallbackBackground(c),
                              )
                            : _shopCardFallbackBackground(c),
                      ),
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            c.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                              color: isDark ? Colors.white : const Color(0xFF1E2229),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          color: Color(0xFF1E8F66),
                          size: 15,
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (c.category.isNotEmpty ||
                              c.details.isNotEmpty)
                            Text(
                              c.category.isNotEmpty
                                  ? c.category
                                  : c.details,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white70 : const Color(0xFF64748B),
                              ),
                            ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.circle,
                                size: 8,
                                color: isOpen
                                    ? const Color(0xFF1E8F66)
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isOpen
                                    ? l10n.openNow2
                                    : l10n.closed,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isOpen
                                      ? const Color(0xFF1E8F66)
                                      : Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: isDark ? Colors.white38 : Colors.grey,
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push(
                        AppRoutes.companyPath(
                          c.slug.isNotEmpty ? c.slug : c.id,
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _promptMobileNumberIfNeeded() {
    try {
      final user = context.read<AuthCubit>().currentUser;
      // Only prompt for signed-in customers without a mobile number
      if (user == null || !user.isUser || (user.mobileNumber).trim().isNotEmpty) {
        return;
      }
    } catch (_) {
      return;
    }

    final mobileCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.fromLTRB(24, 20, 24, bottomInset + 24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFFF5252,
                          ).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.phone_iphone_rounded,
                          color: Color(0xFFFF5252),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context).addMobileNumber,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppLocalizations.of(
                                context,
                              ).forInstantOrderUpdatesDeliverySms,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: mobileCtrl,
                    keyboardType: TextInputType.phone,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).mobileNumber,
                      hintText: '9876543210',
                      prefixText: '+91  ',
                      prefixIcon: const Icon(Icons.phone),
                      helperText: AppLocalizations.of(
                        context,
                      ).enterYour10DigitIndianMobileNumber,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    validator: (v) {
                      final raw = (v ?? '').replaceAll(
                        RegExp(r'[\s\-().]+'),
                        '',
                      );
                      final digits = raw.startsWith('+91')
                          ? raw.substring(3)
                          : raw.startsWith('91') && raw.length == 12
                          ? raw.substring(2)
                          : raw.startsWith('0')
                          ? raw.substring(1)
                          : raw;
                      if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
                        return AppLocalizations.of(
                          context,
                        ).enterAValid10DigitMobileNumber;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 22),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5252),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            if (formKey.currentState?.validate() != true) {
                              return;
                            }
                            setModalState(() => isSubmitting = true);
                            final raw = mobileCtrl.text.trim();
                            final authCubit = context.read<AuthCubit>();
                            final scaffoldMessenger = ScaffoldMessenger.of(
                              context,
                            );
                            final l10n = AppLocalizations.of(context);
                            final navigator = Navigator.of(sheetContext);
                            final ok = await authCubit.updateUserMobile(raw);
                            if (navigator.canPop()) {
                              navigator.pop();
                            }
                            if (ok) {
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    l10n.mobileNumberSavedSuccessfully,
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            AppLocalizations.of(context).saveMobileNumber,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                      if (Navigator.of(sheetContext).canPop()) {
                        Navigator.of(sheetContext).pop();
                      }
                    },
                    child: Text(
                      AppLocalizations.of(context).maybeLater,
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Helper model for dynamic trending rail holding either a [Product] or a [Category].
class _TrendingRailItem {
  final Product? product;
  final Category? category;
  final bool isProduct;

  _TrendingRailItem.product(this.product) : category = null, isProduct = true;

  _TrendingRailItem.category(this.category) : product = null, isProduct = false;
}

/// Full-featured product card used in the vertical Trending Now list.
class TrendingVerticalProductCard extends StatelessWidget {
  final Product product;
  final Company? company;

  const TrendingVerticalProductCard({
    super.key,
    required this.product,
    this.company,
  });

  int _discountPercent() {
    if (product.amount <= 0 || product.price >= product.amount) return 0;
    return (((product.amount - product.price) / product.amount) * 100).round();
  }

  void _doAddToCart(BuildContext context) {
    context.read<CartCubit>().add(product, company: company);
    showAddToCartNotification(context, productName: product.name);
  }

  @override
  Widget build(BuildContext context) {
    final symbol = company?.currencySymbol ?? '₹';
    final soldOut = !product.isInStock;
    final discount = _discountPercent();
    final isDesktop = context.isDesktop;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F2F5)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.03),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push(AppRoutes.productPath(product.id)),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(isDesktop ? 16 : 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image with discount badge & sold-out veil
                SizedBox(
                  width: isDesktop ? 112 : 96,
                  height: isDesktop ? 112 : 96,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AppProductImage.product(
                          product: product,
                          fit: BoxFit.cover,
                        ),
                      ),
                      if (product.isDiscounted && !soldOut && discount > 0)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5247),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$discount% OFF',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      if (soldOut)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFB3261E),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                AppLocalizations.of(context).outOfStock,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(width: isDesktop ? 18 : 14),

                // Details & Actions
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Product Name
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isDesktop ? 16.5 : 14.5,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Pack / Unit & Variant Indicator
                      Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (product.unit > 0 && product.unitType.isNotEmpty)
                            Text(
                              '${product.unit.toString().replaceAll(RegExp(r'\.0$'), '')} ${product.unitType}',
                              style: TextStyle(
                                fontSize: isDesktop ? 12.5 : 11.5,
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          if (product.variants.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFC7D2FE),
                                ),
                              ),
                              child: Text(
                                '${product.variants.length} Options',
                                style: TextStyle(
                                  fontSize: isDesktop ? 11 : 10,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF3D38D9),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Price, MRP & Savings
                      Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            formatCurrency(product.price, symbol: symbol),
                            style: TextStyle(
                              fontSize: isDesktop ? 17 : 15.5,
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          if (product.isDiscounted) ...[
                            Text(
                              formatCurrency(product.amount, symbol: symbol),
                              style: TextStyle(
                                fontSize: isDesktop ? 12.5 : 11.5,
                                color: const Color(0xFF94A3B8),
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            Text(
                              'Save ${formatCurrency(product.amount - product.price, symbol: symbol)}',
                              style: TextStyle(
                                fontSize: isDesktop ? 11.5 : 10.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0CA678),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Action Button
                      Align(
                        alignment: Alignment.centerLeft,
                        child: soldOut
                            ? Text(
                                AppLocalizations.of(context).outOfStock,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFDC2626),
                                ),
                              )
                            : product.variants.isNotEmpty
                            ? OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFFF5247),
                                  side: const BorderSide(
                                    color: Color(0xFFFF5247),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isDesktop ? 16 : 12,
                                    vertical: isDesktop ? 6 : 4,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () => context.push(
                                  AppRoutes.productPath(product.id),
                                ),
                                icon: const Icon(Icons.tune_rounded, size: 14),
                                label: Text(
                                  'Select Variant',
                                  style: TextStyle(
                                    fontSize: isDesktop ? 13 : 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF5247),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isDesktop ? 18 : 14,
                                    vertical: isDesktop ? 6 : 4,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () {
                                  if (AuthSession.currentUser == null) {
                                    AuthBottomSheet.show(
                                      context,
                                      onAuthenticated: () {
                                        _doAddToCart(context);
                                      },
                                    );
                                  } else {
                                    _doAddToCart(context);
                                  }
                                },
                                icon: const Icon(Icons.add, size: 15),
                                label: Text(
                                  'ADD',
                                  style: TextStyle(
                                    fontSize: isDesktop ? 13 : 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Card representing a trending category in the horizontal "Trending Now" rail.
class _TrendingCategoryCard extends StatelessWidget {
  final Category category;
  final VoidCallback onTap;

  const _TrendingCategoryCard({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF8C00).withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Flame Badge: TRENDING CATEGORY
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3.5,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF9233), Color(0xFFE8590C)],
                    ),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        size: 11,
                        color: Colors.white,
                      ),
                      SizedBox(width: 3),
                      Text(
                        'TRENDING CATEGORY',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Category Image / Visual Box
                Expanded(
                  child: Center(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4EC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _buildCategoryVisual(category),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Category Title
                Text(
                  category.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E2229),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),

                // Action Call to Action
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 5.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0E6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Explore Products',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE8590C),
                        ),
                      ),
                      SizedBox(width: 3),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 11,
                        color: Color(0xFFE8590C),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryVisual(Category category) {
    final icon = category.iconUrl;
    if (icon.startsWith('http://') || icon.startsWith('https://')) {
      return Image.network(
        icon,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildPlaceholder(),
      );
    }
    if (icon.startsWith('assets/')) {
      return Image.asset(
        icon,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildPlaceholder(),
      );
    }
    if (icon.isNotEmpty && icon.runes.length <= 4) {
      return Center(child: Text(icon, style: const TextStyle(fontSize: 36)));
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(
        Icons.category_rounded,
        size: 38,
        color: Colors.orange.shade300,
      ),
    );
  }
}
