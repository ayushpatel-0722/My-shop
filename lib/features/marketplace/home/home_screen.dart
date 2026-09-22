import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../auth/auth_cubit.dart';
import '../../auth/widgets/auth_bottom_sheet.dart';
import '../../checkout/cart/cart_cubit.dart';
import '../widgets/marketplace_bottom_nav.dart';
import '../widgets/product_card.dart';
import '../widgets/section_header.dart';

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
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _carouselCtrl = PageController();
  final _scrollCtrl = ScrollController();
  final _categoryKey = GlobalKey();
  int _carouselIndex = 0;

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted || _hasCheckedMobile) return;
        _hasCheckedMobile = true;
        _promptMobileNumberIfNeeded();
      });
    });
  }

  @override
  void dispose() {
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
    final trendingProducts = repo.products();
    final recommendedProducts = repo.products();
    final vouchers = repo.vouchers('');

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            // Vibrant Coral Header & Embedded Search
            SliverToBoxAdapter(child: _buildHeader(context, l10n)),

            // Content Body
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 14),

                  // 1. Promotional Banner Carousel (hides if empty)
                  _adsCarousel(ads),

                  // 2. Explore Categories (hides if empty, See All -> CategoriesScreen)
                  _exploreCategoriesSection(categories),

                  // 3. Store Vouchers & Deals (hides if empty, See All -> Vouchers Sheet)
                  _storeVouchersSection(vouchers),

                  // 4. Shops Near You (hides if empty, See All -> All Shops Sheet)
                  _shopsNearYouSection(companies),

                  // 5. Trending Now Rail (hides if empty, See All -> Search/Trending)
                  _trendingProductsSection(trendingProducts),

                  // 6. Recommended For You Grid (hides if empty, See All -> Search)
                  _recommendationsSection(recs, recommendedProducts, l10n),
                ]),
              ),
            ),
          ],
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: const MarketplaceBottomNav(currentIndex: 0),
    );
  }

  // ---------------------------------------------------------------------------
  // Top Header with Location, Actions, and Search Bar
  // ---------------------------------------------------------------------------
  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Delivery Location + Notification + Cart + User Avatar
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.white, size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                    child: InkWell(
                      onTap: () => _showLocationPicker(context),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Deliver to',
                            style: TextStyle(
                              color: Color(0xFFFFDAD6),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '12 Market Street, Ahmedabad',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Icon(
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
                        border: Border.all(color: Colors.white70, width: 1.5),
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
                          'Search products, categories, or stores...',
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
    );
  }

  Future<void> _openCartSafely(BuildContext context) async {
    if (AuthSession.currentUser == null) {
      final ok = await AuthBottomSheet.show(context);
      if (ok && context.mounted) {
        context.go(AppRoutes.cart);
      }
      return;
    }
    context.go(AppRoutes.cart);
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
            SizedBox(
              height: 165,
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
                        child: const Text(
                          'LIMITED TIME OFFER',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 9,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Grand Festive Mega Sale',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Flat 50% Off + Free Delivery',
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
                            const SnackBar(
                              content: Text(
                                'Promo Code FESTIVE50 copied to clipboard!',
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
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Code: FESTIVE50',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.copy, size: 11, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                    ],
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
                  child: const Text(
                    'Shop Now',
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
                  : 'Special Marketplace Offer',
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
  // Explore Categories Section
  // ---------------------------------------------------------------------------
  Widget _exploreCategoriesSection(Stream<List<Category>> categories) {
    return StreamBuilder<List<Category>>(
      stream: categories,
      builder: (context, snap) {
        final list = snap.data ?? const <Category>[];
        if (list.isEmpty) return const SizedBox.shrink();

        return Column(
          children: [
            Padding(
              key: _categoryKey,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SectionHeader(
                title: 'Explore Categories',
                onViewAll: () => context.go(AppRoutes.categories),
              ),
            ),
            const SizedBox(height: 12),
            _categoryRailContent(list),
            const SizedBox(height: 22),
          ],
        );
      },
    );
  }

  Widget _categoryRailContent(List<Category> list) {
    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final cat = list[i];
          final bgColor = _pastelColors[i % _pastelColors.length];

          return InkWell(
            onTap: () => context.push(
              '${AppRoutes.categoryPath(cat.id)}?name=${Uri.encodeComponent(cat.name)}',
            ),
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              width: 72,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromRGBO(0, 0, 0, 0.05),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(child: _buildCategoryIcon(cat)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    cat.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E2229),
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

  Widget _buildCategoryIcon(Category cat) {
    if (cat.iconUrl.startsWith('http://') ||
        cat.iconUrl.startsWith('https://')) {
      return Image.network(
        cat.iconUrl,
        width: 32,
        height: 32,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _fallbackCategoryIcon(cat),
      );
    }
    return _fallbackCategoryIcon(cat);
  }

  Widget _fallbackCategoryIcon(Category cat) {
    if (cat.iconUrl.isNotEmpty && cat.iconUrl.runes.length <= 4) {
      return Text(cat.iconUrl, style: const TextStyle(fontSize: 28));
    }
    final name = cat.name.toLowerCase();
    if (name.contains('cloth') ||
        name.contains('fashion') ||
        name.contains('wear')) {
      return const Icon(Icons.checkroom, color: Color(0xFFFF5247), size: 28);
    } else if (name.contains('sweet') ||
        name.contains('cake') ||
        name.contains('dessert')) {
      return const Icon(Icons.cake, color: Color(0xFFFF9800), size: 28);
    } else if (name.contains('food') ||
        name.contains('snack') ||
        name.contains('grocery')) {
      return const Icon(Icons.fastfood, color: Color(0xFF4CAF50), size: 28);
    } else if (name.contains('electr') ||
        name.contains('gadget') ||
        name.contains('phone')) {
      return const Icon(Icons.devices, color: Color(0xFF2196F3), size: 28);
    }
    return const Icon(Icons.category, color: Color(0xFFFF5247), size: 28);
  }

  // ---------------------------------------------------------------------------
  // Store Vouchers & Deals Section
  // ---------------------------------------------------------------------------
  Widget _storeVouchersSection(Stream<List<Voucher>> vouchers) {
    return StreamBuilder<List<Voucher>>(
      stream: vouchers,
      builder: (context, snap) {
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
                title: 'Store Vouchers & Deals',
                onViewAll: () => _showAllVouchersSheet(context, vouchers),
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
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _voucherCard(context, list[i]),
      ),
    );
  }

  Widget _voucherCard(BuildContext context, Voucher v) {
    final isClaimed = _claimedVouchers.contains(v.id);
    final discountStr = v.discountLabel;

    return Container(
      width: 210,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isClaimed ? const Color(0xFF1E8F66) : const Color(0xFFFFD6D3),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.03),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isClaimed
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFFFEBEA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.local_offer,
              color: isClaimed
                  ? const Color(0xFF1E8F66)
                  : const Color(0xFFFF5247),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  discountStr,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF1E2229),
                  ),
                ),
                Text(
                  v.code,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFFF5247),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (v.minOrderAmt > 0)
                  Text(
                    'Min ₹${v.minOrderAmt.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
              ],
            ),
          ),
          InkWell(
            onTap: () {
              setState(() => _claimedVouchers.add(v.id));
              Clipboard.setData(ClipboardData(text: v.code));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Coupon ${v.code} claimed & copied!'),
                  backgroundColor: const Color(0xFF1E8F66),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isClaimed
                    ? const Color(0xFF1E8F66)
                    : const Color(0xFFFF5247),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isClaimed ? 'CLAIMED' : 'CLAIM',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
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
        final list = (snap.data ?? const <Company>[])
            .where((c) => c.status != 'inactive' && c.status != 'suspended')
            .toList();
        if (list.isEmpty) return const SizedBox.shrink();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SectionHeader(
                title: 'Shops near you',
                subtitle: 'Verified local merchants',
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
                              Text(
                                '${avgRating.toStringAsFixed(1)} ($countStr)',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFFD54F),
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
  // Trending Products Section
  // ---------------------------------------------------------------------------
  Widget _trendingProductsSection(Stream<List<Product>> products) {
    return StreamBuilder<List<Product>>(
      stream: products,
      builder: (context, snap) {
        final list = snap.data ?? const <Product>[];
        if (list.isEmpty) return const SizedBox.shrink();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SectionHeader(
                title: 'Trending Now 🔥',
                onViewAll: () => context.push(AppRoutes.search),
              ),
            ),
            const SizedBox(height: 10),
            _trendingProductsRailContent(list),
            const SizedBox(height: 22),
          ],
        );
      },
    );
  }

  Widget _trendingProductsRailContent(List<Product> list) {
    return SizedBox(
      height: 285,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: list.length > 8 ? 8 : list.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          return SizedBox(
            width: 165,
            child: ProductCard(
              product: list[i],
              onTap: () => context.push(AppRoutes.productPath(list[i].id)),
            ),
          );
        },
      ),
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
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.63,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: products.length,
        itemBuilder: (context, i) => ProductCard(
          product: products[i],
          onTap: () => context.push(AppRoutes.productPath(products[i].id)),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Action Modals (Location, Vouchers Sheet, Mobile Prompt)
  // ---------------------------------------------------------------------------
  void _showLocationPicker(BuildContext context) {
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
            const Text(
              'Select Delivery Location',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.my_location, color: Color(0xFFFF5247)),
              title: const Text('Use Current Location'),
              subtitle: const Text('Ahmedabad, Gujarat'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(
                Icons.home_outlined,
                color: Color(0xFF3D38D9),
              ),
              title: const Text('Home: 12 Market Street'),
              subtitle: const Text('Ahmedabad, 380001'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllVouchersSheet(
    BuildContext context,
    Stream<List<Voucher>> vouchers,
  ) {
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
            const Text(
              'All Active Coupons',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<Voucher>>(
                stream: vouchers,
                builder: (context, snap) {
                  final list = snap.data ?? const <Voucher>[];
                  if (list.isEmpty) {
                    return const Center(child: Text('No vouchers available'));
                  }
                  return ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _voucherCard(context, list[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllShopsSheet(BuildContext context, List<Company> initialList) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (sheetContext, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'All Shops & Stores',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Verified local merchants',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
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
                      return const Center(child: Text('No shops available'));
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
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
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.5,
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
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
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
                                      isOpen ? 'Open Now' : 'Closed',
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
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Colors.grey,
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
          ),
        ),
      ),
    );
  }

  void _promptMobileNumberIfNeeded() {
    final user = context.read<AuthCubit>().currentUser;
    // Only prompt for signed-in customers without a mobile number
    if (user == null || !user.isUser || (user.mobileNumber).trim().isNotEmpty) {
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
                          children: const [
                            Text(
                              'Add Mobile Number',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'For instant order updates & delivery SMS',
                              style: TextStyle(
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
                      labelText: 'Mobile Number',
                      hintText: '9876543210',
                      prefixText: '+91  ',
                      prefixIcon: const Icon(Icons.phone),
                      helperText: 'Enter your 10-digit Indian mobile number',
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
                        return 'Enter a valid 10-digit mobile number';
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
                            final navigator = Navigator.of(sheetContext);
                            final ok = await authCubit.updateUserMobile(raw);
                            if (navigator.canPop()) {
                              navigator.pop();
                            }
                            if (ok) {
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Mobile number saved successfully!',
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
                        : const Text(
                            'Save Mobile Number',
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
                    child: const Text(
                      'Maybe Later',
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
