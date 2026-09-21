import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes/app_router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/domain/catalog.dart';
import '../../../core/domain/category_tree.dart';
import '../../../core/models/category.dart';
import '../../../core/models/product.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/services/service_locator.dart';
import '../../auth/widgets/auth_bottom_sheet.dart';
import '../../checkout/cart/cart_cubit.dart';
import '../widgets/product_card.dart';

/// Category explorer screen.
///
/// Features:
///  * Scoped to specific store (`companyId`) when navigated from Company Storefront "See All",
///    or marketplace-wide when navigated from Home / Categories.
///  * Matches products by category ID, name, slug, type, productList, and descendant hierarchy.
///  * Sub-category filter pills if parent category has children.
///  * Sorting and "In stock only" switch.
///  * Clean white AppBar with search and live cart badge.
class CategoryViewScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;

  /// When set, the explorer lists only this store's products — the company
  /// storefront's "See All" links land here pre-filtered.
  final String companyId;

  const CategoryViewScreen({
    super.key,
    required this.categoryId,
    this.categoryName = '',
    this.companyId = '',
  });

  @override
  State<CategoryViewScreen> createState() => _CategoryViewScreenState();
}

class _CategoryViewScreenState extends State<CategoryViewScreen> {
  ProductSort _sort = ProductSort.relevance;
  bool _inStockOnly = false;
  String? _selectedSubCatId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        shadowColor: const Color.fromRGBO(0, 0, 0, 0.08),
        leading: BackButton(
          color: const Color(0xFF1E2229),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else if (widget.companyId.isNotEmpty) {
              context.go(AppRoutes.companyPath(widget.companyId));
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
        title: Text(
          widget.categoryName.isNotEmpty ? widget.categoryName : 'Category',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E2229),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Color(0xFF1E2229)),
            tooltip: 'Search products',
            onPressed: () {
              if (widget.companyId.isNotEmpty) {
                context.push(
                  '${AppRoutes.search}?companyId=${widget.companyId}',
                );
              } else {
                context.push(AppRoutes.search);
              }
            },
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
                tooltip: 'Cart',
                onPressed: () async {
                  if (AuthSession.currentUser == null) {
                    final ok = await AuthBottomSheet.show(context);
                    if (ok && context.mounted) context.push(AppRoutes.cart);
                    return;
                  }
                  context.push(AppRoutes.cart);
                },
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: StreamBuilder<List<Category>>(
        stream: widget.companyId.isNotEmpty
            ? repo.categories(companyId: widget.companyId)
            : repo.categories(),
        builder: (context, categorySnap) {
          final categories = categorySnap.data ?? const <Category>[];

          // 1. Resolve active category
          Category? activeCat;
          final targetId = widget.categoryId.trim().toLowerCase();
          final targetName = widget.categoryName.trim().toLowerCase();
          for (final c in categories) {
            if (c.id.toLowerCase() == targetId ||
                c.id.replaceAll('_', '-').toLowerCase() == targetId ||
                c.id.replaceAll('-', '_').toLowerCase() == targetId ||
                c.name.toLowerCase() == targetId ||
                (targetName.isNotEmpty && c.name.toLowerCase() == targetName)) {
              activeCat = c;
              break;
            }
          }

          // 2. Collect all matching target IDs / names / descendant IDs
          final descendantIds = activeCat != null
              ? CategoryHierarchy.descendantIds(activeCat.id, categories)
              : const <String>{};

          final targetIds = <String>{
            if (widget.categoryId.isNotEmpty) widget.categoryId,
            if (widget.categoryName.isNotEmpty) widget.categoryName,
            if (activeCat != null) ...[
              activeCat.id,
              activeCat.name,
              ...descendantIds,
            ],
          };

          // 3. Child subcategories for chip filter bar
          final subCategories = activeCat != null
              ? categories.where((c) => c.parentId == activeCat!.id).toList()
              : <Category>[];

          final effectiveFilterIds = _selectedSubCatId != null
              ? {_selectedSubCatId!}
              : targetIds;

          return StreamBuilder<List<Product>>(
            stream: widget.companyId.isNotEmpty
                ? repo.products(companyId: widget.companyId)
                : repo.products(),
            builder: (context, productSnap) {
              final loading =
                  productSnap.connectionState == ConnectionState.waiting &&
                  (productSnap.data?.isEmpty ?? true);

              final rawProducts = productSnap.data ?? const <Product>[];

              final products = Catalog.apply(
                rawProducts,
                CatalogQuery(
                  categoryIds: effectiveFilterIds,
                  companyIds: widget.companyId.isNotEmpty
                      ? {widget.companyId}
                      : const <String>{},
                  categories: categories,
                  sort: _sort,
                  inStockOnly: _inStockOnly,
                ),
              );

              return Column(
                children: [
                  // Sub-category filter pills if parent has children
                  if (subCategories.isNotEmpty) ...[
                    Container(
                      height: 44,
                      margin: const EdgeInsets.only(top: 8, bottom: 4),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        physics: const BouncingScrollPhysics(),
                        itemCount: subCategories.length + 1,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, idx) {
                          if (idx == 0) {
                            final isSel = _selectedSubCatId == null;
                            return _SubCategoryPill(
                              label:
                                  'All ${widget.categoryName.isNotEmpty ? widget.categoryName : 'Items'}',
                              isSelected: isSel,
                              onTap: () =>
                                  setState(() => _selectedSubCatId = null),
                            );
                          }
                          final sub = subCategories[idx - 1];
                          final isSel = _selectedSubCatId == sub.id;
                          return _SubCategoryPill(
                            label: sub.name,
                            isSelected: isSel,
                            onTap: () => setState(() {
                              _selectedSubCatId = isSel ? null : sub.id;
                            }),
                          );
                        },
                      ),
                    ),
                  ],

                  // Toolbar: count, in-stock switch, sort dropdown
                  _Toolbar(
                    count: products.length,
                    sort: _sort,
                    inStockOnly: _inStockOnly,
                    onSortChanged: (value) =>
                        setState(() => _sort = value ?? ProductSort.relevance),
                    onStockChanged: (value) =>
                        setState(() => _inStockOnly = value),
                  ),

                  // Products Grid / Empty state / Loading
                  Expanded(
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : products.isEmpty
                        ? _EmptyCategory(
                            categoryName: widget.categoryName,
                            hasStockFilter: _inStockOnly,
                            onClearStockFilter: () =>
                                setState(() => _inStockOnly = false),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.maxWidth;
                              final crossAxisCount = width >= 1000
                                  ? 4
                                  : width >= 700
                                  ? 3
                                  : 2;
                              final childAspectRatio = width >= 1000
                                  ? 0.68
                                  : 0.70;
                              return GridView.builder(
                                padding: const EdgeInsets.all(16),
                                physics: const BouncingScrollPhysics(),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      childAspectRatio: childAspectRatio,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                    ),
                                itemCount: products.length,
                                itemBuilder: (context, i) => ProductCard(
                                  product: products[i],
                                  onTap: () => context.push(
                                    AppRoutes.productPath(products[i].id),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _SubCategoryPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SubCategoryPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF1E2229) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF1E2229)
                    : const Color(0xFFE2E6EC),
                width: 1,
              ),
              boxShadow: isSelected
                  ? const [
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.08),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF4B5563),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  final int count;
  final ProductSort sort;
  final bool inStockOnly;
  final ValueChanged<ProductSort?> onSortChanged;
  final ValueChanged<bool> onStockChanged;

  const _Toolbar({
    required this.count,
    required this.sort,
    required this.inStockOnly,
    required this.onSortChanged,
    required this.onStockChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        children: [
          Text(
            '$count product${count == 1 ? '' : 's'}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'In stock',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF4B5563),
                ),
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: inStockOnly,
                  activeThumbColor: const Color(0xFFFF5247),
                  onChanged: onStockChanged,
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
          DropdownButtonHideUnderline(
            child: DropdownButton<ProductSort>(
              value: sort,
              icon: const Icon(
                Icons.sort_rounded,
                size: 18,
                color: Color(0xFF4B5563),
              ),
              borderRadius: BorderRadius.circular(12),
              items: [
                for (final value in ProductSort.values)
                  DropdownMenuItem<ProductSort>(
                    value: value,
                    child: Text(
                      value.label,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
              ],
              onChanged: onSortChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCategory extends StatelessWidget {
  final String categoryName;
  final bool hasStockFilter;
  final VoidCallback onClearStockFilter;

  const _EmptyCategory({
    this.categoryName = '',
    required this.hasStockFilter,
    required this.onClearStockFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEA),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.category_outlined,
                size: 40,
                color: Color(0xFFFF5247),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              categoryName.isNotEmpty
                  ? 'No $categoryName products found'
                  : 'No products in this category',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E2229),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Products assigned to this category (or its sub-categories) will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            ),
            if (hasStockFilter) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF5247),
                  side: const BorderSide(color: Color(0xFFFF5247)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Show out-of-stock items'),
                onPressed: onClearStockFilter,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
