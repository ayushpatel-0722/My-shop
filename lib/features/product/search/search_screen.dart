import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../../../core/domain/catalog.dart';
import '../../../core/models/product.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../core/widgets/modern_shimmer.dart';
import '../../marketplace/widgets/product_card.dart';

/// Interactive keyword product search screen.
///
/// When opened from a company storefront it searches **within that store**
/// ([companyId] set); otherwise it searches across the entire marketplace.
class SearchScreen extends StatefulWidget {
  final String companyId;
  final String companyName;

  const SearchScreen({super.key, this.companyId = '', this.companyName = ''});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _textCtrl = TextEditingController();
  String _query = '';
  ProductSort _sort = ProductSort.relevance;
  bool _onlyInStock = false;

  static const _popularQueries = [
    'Vegetables',
    'Fruits',
    'Milk',
    'Atta & Flour',
    'Snacks',
    'Oil',
    'Spices',
    'Beverages',
  ];

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _onQueryChanged(String val) {
    setState(() => _query = val.trim());
  }

  void _setQuery(String query) {
    _textCtrl.text = query;
    _textCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
    setState(() => _query = query.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scoped = widget.companyId.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, size: 20, color: Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: _textCtrl,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    hintText: scoped
                        ? AppLocalizations.of(context).searchIn(
                            widget.companyName.isEmpty
                                ? AppLocalizations.of(context).thisStore
                                : widget.companyName,
                          )
                        : l10n.searchHint,
                    border: InputBorder.none,
                    hintStyle: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 14,
                    ),
                  ),
                  onChanged: _onQueryChanged,
                ),
              ),
              if (_query.isNotEmpty)
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Color(0xFF64748B),
                  ),
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  onPressed: () {
                    _textCtrl.clear();
                    _onQueryChanged('');
                  },
                ),
            ],
          ),
        ),
      ),
      body: StreamBuilder<List<Product>>(
        stream: repo.products(companyId: widget.companyId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(top: 16),
                child: M3ProductGridSkeleton(itemCount: 6),
              ),
            );
          }

          final allProducts = snap.data ?? const <Product>[];

          if (_query.isEmpty) {
            return _buildDiscoveryView(allProducts, scoped);
          }

          // Apply full catalog search and filters
          final filtered = Catalog.apply(
            allProducts,
            CatalogQuery(
              search: _query,
              companyIds: scoped ? {widget.companyId} : const <String>{},
              sort: _sort,
              inStockOnly: _onlyInStock,
            ),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filter & Sort Pills
              _buildFilterBar(filtered.length),

              // Results Grid
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmptyResultsView()
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth - 32;
                          final crossAxisCount =
                              ResponsiveGrid.calculateCrossAxisCount(
                                width,
                                maxCardWidth: 250,
                              );
                          final childAspectRatio =
                              ResponsiveGrid.calculateProductAspectRatio(
                                width,
                                crossAxisCount,
                                spacing: 12,
                                showBrand: true,
                              );
                          return GridView.builder(
                            padding: const EdgeInsets.all(16),
                            physics: const BouncingScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  childAspectRatio: childAspectRatio,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 14,
                                ),
                            itemCount: filtered.length,
                            itemBuilder: (context, i) => ProductCard(
                              product: filtered[i],
                              onTap: () => context.push(
                                AppRoutes.productPath(filtered[i].id),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterBar(int resultCount) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            AppLocalizations.of(context).itemCount(resultCount),
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
          const Spacer(),
          // In-Stock toggle
          InkWell(
            onTap: () => setState(() => _onlyInStock = !_onlyInStock),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _onlyInStock ? const Color(0xFFFFEBEA) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _onlyInStock
                      ? const Color(0xFFB3261E)
                      : const Color(0xFFCBD5E1),
                ),
              ),
              child: Text(
                AppLocalizations.of(context).inStock,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: _onlyInStock
                      ? const Color(0xFFB3261E)
                      : const Color(0xFF475569),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Price Sort
          InkWell(
            onTap: () => setState(() {
              if (_sort == ProductSort.priceAsc) {
                _sort = ProductSort.priceDesc;
              } else if (_sort == ProductSort.priceDesc) {
                _sort = ProductSort.relevance;
              } else {
                _sort = ProductSort.priceAsc;
              }
            }),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _sort != ProductSort.relevance
                    ? const Color(0xFFFFEBEA)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _sort != ProductSort.relevance
                      ? const Color(0xFFB3261E)
                      : const Color(0xFFCBD5E1),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    _sort == ProductSort.priceAsc
                        ? AppLocalizations.of(context).price4
                        : _sort == ProductSort.priceDesc
                        ? AppLocalizations.of(context).price3
                        : AppLocalizations.of(context).price5,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _sort != ProductSort.relevance
                          ? const Color(0xFFB3261E)
                          : const Color(0xFF475569),
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

  Widget _buildDiscoveryView(List<Product> products, bool scoped) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Popular Searches
        Text(
          AppLocalizations.of(context).popularSearches,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E2229),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _popularQueries.map((q) {
            return InkWell(
              onTap: () => _setQuery(q),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.trending_up_rounded,
                      size: 15,
                      color: Color(0xFFB3261E),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      q,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 24),

        // Browse All Products
        if (products.isNotEmpty) ...[
          Row(
            children: [
              Text(
                scoped
                    ? AppLocalizations.of(context).allStoreProducts
                    : AppLocalizations.of(context).browseAllProducts,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E2229),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '(${products.length})',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
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
                    spacing: 12,
                    showBrand: true,
                  );
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: childAspectRatio,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 14,
                ),
                itemCount: products.length,
                itemBuilder: (context, i) => ProductCard(
                  product: products[i],
                  onTap: () =>
                      context.push(AppRoutes.productPath(products[i].id)),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyResultsView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 56,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 14),
            Text(
              AppLocalizations.of(context).noProductsFoundFor(_query),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E2229),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppLocalizations.of(
                context,
              ).tryCheckingForTyposOrSearchingForADifferentKeyword,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                _textCtrl.clear();
                _onQueryChanged('');
              },
              child: Text(AppLocalizations.of(context).clearSearch),
            ),
          ],
        ),
      ),
    );
  }
}
