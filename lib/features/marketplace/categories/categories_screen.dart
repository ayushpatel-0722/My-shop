import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes/app_router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/category.dart';
import '../../../core/models/company.dart';
import '../../../core/models/order.dart' show DeliveryType;
import '../../../core/domain/category_tree.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/auth_session.dart';
import '../../auth/widgets/auth_bottom_sheet.dart';
import '../../checkout/cart/cart_cubit.dart';
import '../widgets/marketplace_bottom_nav.dart';
import '../widgets/section_header.dart';

/// Categories Screen displaying All Shops and All Shop Categories with rich styling.
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  static const _pastelColors = [
    Color(0xFFE6F7F2), // Mint Green
    Color(0xFFFFEBEA), // Soft Coral
    Color(0xFFEBF5FF), // Soft Ice Blue
    Color(0xFFF3E8FF), // Lavender
    Color(0xFFFFF0E6), // Soft Peach
    Color(0xFFFFF8E6), // Soft Amber
    Color(0xFFE6F9FB), // Soft Cyan
  ];

  @override
  Widget build(BuildContext context) {
    final categoriesStream = repo.categories();
    final companiesStream = repo.companies();

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text(
          'Categories & Shops',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E2229),
            fontSize: 19,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF1E2229)),
            onPressed: () => context.push(AppRoutes.search),
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
                onPressed: () async {
                  if (AuthSession.currentUser == null) {
                    final ok = await AuthBottomSheet.show(context);
                    if (ok && context.mounted) {
                      context.push(AppRoutes.cart);
                    }
                    return;
                  }
                  context.push(AppRoutes.cart);
                },
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Search Pill
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: InkWell(
                onTap: () => context.push(AppRoutes.search),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.03),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.search, color: Color(0xFFFF5247), size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Search categories, brands, or shops...',
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // All Categories Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: SectionHeader(
                title: 'Shop by Category',
                onViewAll: () => context.go(AppRoutes.search),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _buildCategoriesGrid(categoriesStream)),

          // All Shops Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
              child: SectionHeader(
                title: 'Explore All Shops & Stores',
                onViewAll: () => context.go(AppRoutes.search),
              ),
            ),
          ),
          _buildShopsSliver(companiesStream),

          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
      bottomNavigationBar: const MarketplaceBottomNav(currentIndex: 1),
    );
  }

  Widget _buildCategoriesGrid(Stream<List<Category>> categoriesStream) {
    return StreamBuilder<List<Category>>(
      stream: categoriesStream,
      builder: (context, snap) {
        final list = snap.data ?? const <Category>[];
        if (list.isEmpty) {
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        // Only top level categories belong in the grid: sub-categories are
        // reachable from their parent, so mixing them in duplicated entries.
        final roots = CategoryTree.build(list).roots;
        if (roots.isEmpty) {
          return const SizedBox(
            height: 120,
            child: Center(child: Text('No categories yet')),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: roots.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 14,
              crossAxisSpacing: 12,
              childAspectRatio: 0.76,
            ),
            itemBuilder: (context, i) {
              final cat = roots[i].category;
              final bgColor = _pastelColors[i % _pastelColors.length];

              return InkWell(
                onTap: () => context.push(
                  '${AppRoutes.categoryPath(cat.id)}?name=${Uri.encodeComponent(cat.name)}',
                ),
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: bgColor,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Color.fromRGBO(0, 0, 0, 0.04),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Center(child: _buildCategoryIcon(cat)),
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
                        color: Color(0xFF2D3139),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
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
      return Text(cat.iconUrl, style: const TextStyle(fontSize: 26));
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

  Widget _buildShopsSliver(Stream<List<Company>> companiesStream) {
    return StreamBuilder<List<Company>>(
      stream: companiesStream,
      builder: (context, snap) {
        final list = snap.data ?? const <Company>[];
        if (list.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No shops registered yet',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, i) {
              final company = list[i];
              return _buildShopCard(context, company, i);
            }, childCount: list.length),
          ),
        );
      },
    );
  }

  Widget _buildShopCard(BuildContext context, Company company, int index) {
    // NOTE: no invented ratings / delivery times / offers any more — every
    // badge below is derived from real company data.
    final isOpen = company.isOpenNow();
    final offersHomeDelivery = company.deliveryTypes.contains(
      DeliveryType.homeDelivery,
    );
    final offersPickup = company.deliveryTypes.contains(
      DeliveryType.selfPickup,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0F2F5)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.03),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => context.push(AppRoutes.companyPath(company.slug)),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Shop Logo / Avatar
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFFFD6D3),
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child:
                      company.logoUrl.isNotEmpty &&
                          (company.logoUrl.startsWith('http://') ||
                              company.logoUrl.startsWith('https://'))
                      ? Image.network(
                          company.logoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _shopFallbackAvatar(company),
                        )
                      : _shopFallbackAvatar(company),
                ),
              ),
              const SizedBox(width: 14),

              // Shop Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            company.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E2229),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          color: Color(0xFF1E8F66),
                          size: 16,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (company.address.isNotEmpty)
                      Text(
                        company.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    const SizedBox(height: 8),

                    // Badges row: open state + real fulfilment options
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isOpen
                                ? const Color(0xFFE8F5E9)
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isOpen ? Icons.schedule : Icons.event_busy,
                                size: 14,
                                color: isOpen
                                    ? const Color(0xFF1E8F66)
                                    : const Color(0xFF6B7280),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                isOpen ? 'Open now' : 'Closed',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isOpen
                                      ? const Color(0xFF1E8F66)
                                      : const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (offersHomeDelivery || offersPickup)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.bolt_rounded,
                                  size: 14,
                                  color: Color(0xFFFF5247),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  offersHomeDelivery && offersPickup
                                      ? 'Delivery & pickup'
                                      : offersHomeDelivery
                                      ? 'Home delivery'
                                      : 'Self pickup',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF4B5563),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const Spacer(),
                        if (!company.isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBEA),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              company.status.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF5247),
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
      ),
    );
  }

  Widget _shopFallbackAvatar(Company company) {
    return Container(
      color: const Color(0xFFFFEBEA),
      child: Center(
        child: Text(
          company.name.isNotEmpty
              ? company.name.substring(0, 1).toUpperCase()
              : 'S',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFF5247),
          ),
        ),
      ),
    );
  }
}
