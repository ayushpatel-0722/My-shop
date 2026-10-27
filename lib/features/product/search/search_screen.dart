import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../../../core/domain/catalog.dart';
import '../../../core/models/category.dart';
import '../../../core/models/company.dart';
import '../../../core/models/product.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../core/widgets/back_to_admin_button.dart';
import '../../../core/widgets/modern_shimmer.dart';
import '../../marketplace/widgets/product_card.dart';
import '../../marketplace/widgets/web_header.dart';

/// Interactive keyword product search screen.
///
/// When opened from a company storefront it searches **within that store**
/// ([companyId] set); otherwise it searches across the entire marketplace.
class SearchScreen extends StatefulWidget {
  final String companyId;
  final String companyName;
  final String initialQuery;

  const SearchScreen({
    super.key,
    this.companyId = '',
    this.companyName = '',
    this.initialQuery = '',
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _textCtrl;
  String _query = '';
  ProductSort _sort = ProductSort.relevance;
  bool _onlyInStock = false;

  String _companyId = '';
  String _companyName = '';
  Company? _resolvedCompany;
  List<Category> _categories = [];
  List<Company> _companies = [];

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
  void initState() {
    super.initState();
    _query = widget.initialQuery.trim();
    _textCtrl = TextEditingController(text: _query);
    _companyId = widget.companyId.trim();
    _companyName = widget.companyName.trim();
    _resolveCompanyData();
  }

  Future<void> _resolveCompanyData() async {
    try {
      final comps = await repo.companies().first;
      if (mounted) setState(() => _companies = comps);

      if (_companyId.isNotEmpty) {
        final c =
            comps.where((c) => c.id == _companyId).firstOrNull ??
            comps.where((c) => c.slug == _companyId).firstOrNull ??
            comps
                .where((c) => c.name.toLowerCase() == _companyId.toLowerCase())
                .firstOrNull;
        if (c != null && mounted) {
          setState(() {
            _resolvedCompany = c;
            _companyId = c.id;
            if (_companyName.isEmpty) _companyName = c.name;
          });
        }
      }
    } catch (_) {}

    try {
      final cats = await repo.categories().first;
      if (mounted) setState(() => _categories = cats);
    } catch (_) {}
  }

  @override
  void didUpdateWidget(SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery) {
      _query = widget.initialQuery.trim();
      _textCtrl.text = _query;
    }
    if (oldWidget.companyId != widget.companyId) {
      _companyId = widget.companyId.trim();
      _companyName = widget.companyName.trim();
      _resolveCompanyData();
    }
  }

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

  void _clearCompanyScope() {
    setState(() {
      _companyId = '';
      _companyName = '';
      _resolvedCompany = null;
    });
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else if (_companyId.isNotEmpty) {
      context.go(AppRoutes.companyPath(_companyId));
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDesktop = context.isDesktop;
    final scoped = _companyId.isNotEmpty;
    final storeName = _companyName.isNotEmpty
        ? _companyName
        : (_resolvedCompany?.name ?? 'Store');

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: isDesktop
            ? const PreferredSize(
                preferredSize: Size.fromHeight(64),
                child: WebHeader(),
              )
            : AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                scrolledUnderElevation: 1,
                leading: BackButton(onPressed: _handleBack),
                title: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search,
                        size: 20,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          key: const Key('search-input-field'),
                          controller: _textCtrl,
                          autofocus: true,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                            hintText: scoped
                                ? AppLocalizations.of(
                                    context,
                                  ).searchIn(storeName)
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
                actions: const [BackToAdminButton()],
              ),
        body: Column(
          children: [
            // ── Desktop Header (Search Input & Breadcrumbs) ───────────────
            if (isDesktop) _buildDesktopSearchHeader(context),

            // ── Mobile Store Scope Banner (if scoped to a store) ─────────
            if (!isDesktop && scoped)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFEEF2FF),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFC7D2FE), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.storefront_rounded,
                      size: 16,
                      color: Color(0xFF3D38D9),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Searching in $storeName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3D38D9),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _clearCompanyScope,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Text(
                          'Search all stores',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4F46E5),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Main Products Content ────────────────────────────────────
            Expanded(
              child: StreamBuilder<List<Product>>(
                stream: repo.products(companyId: _companyId),
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

                  if (snap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 48,
                              color: Color(0xFFEF4444),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Could not load products. Please try again.',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () => setState(() {}),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
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
                      companyIds: scoped ? {_companyId} : const <String>{},
                      categories: _categories,
                      companies: _companies,
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
                                  final width =
                                      constraints.maxWidth -
                                      (isDesktop ? 48 : 32);
                                  final crossAxisCount =
                                      ResponsiveGrid.calculateCrossAxisCount(
                                        width,
                                        maxCardWidth: 280,
                                        maxCount: isDesktop ? 5 : 4,
                                      );
                                  final childAspectRatio =
                                      ResponsiveGrid.calculateProductAspectRatio(
                                        width,
                                        crossAxisCount,
                                        spacing: 12,
                                        showBrand: true,
                                      );
                                  return GridView.builder(
                                    padding: EdgeInsets.all(
                                      isDesktop ? 24 : 16,
                                    ),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopSearchHeader(BuildContext context) {
    final scoped = _companyId.isNotEmpty;
    final storeName = _companyName.isNotEmpty
        ? _companyName
        : (_resolvedCompany?.name ?? 'Store');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Desktop Breadcrumbs
          Row(
            children: [
              InkWell(
                onTap: _handleBack,
                borderRadius: BorderRadius.circular(4),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_back_rounded,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Back',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('•', style: TextStyle(color: Color(0xFFCBD5E1))),
              ),
              InkWell(
                onTap: () => context.go(AppRoutes.home),
                child: const Text(
                  'Home',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (scoped) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    Icons.chevron_right,
                    size: 15,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                InkWell(
                  onTap: () => context.go(AppRoutes.companyPath(_companyId)),
                  child: Text(
                    storeName,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.chevron_right,
                  size: 15,
                  color: Color(0xFF94A3B8),
                ),
              ),
              Text(
                _query.isNotEmpty ? 'Search: "$_query"' : 'Search Products',
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Search Input Bar
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFCBD5E1),
                      width: 1.2,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search,
                        color: Color(0xFFFF5247),
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          key: const Key('search-input-field'),
                          controller: _textCtrl,
                          onChanged: _onQueryChanged,
                          onSubmitted: (val) => _onQueryChanged(val),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: scoped
                                ? 'Search products in $storeName...'
                                : 'Search products, categories, or brands...',
                            hintStyle: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_query.isNotEmpty)
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: Color(0xFF64748B),
                          ),
                          splashRadius: 18,
                          onPressed: () {
                            _textCtrl.clear();
                            _onQueryChanged('');
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: () => _onQueryChanged(_textCtrl.text),
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text(
                    'Search',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5247),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Scoped store banner (if active)
          if (scoped) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFC7D2FE)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.storefront_rounded,
                    size: 16,
                    color: Color(0xFF3D38D9),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Searching in $storeName',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3D38D9),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: _clearCompanyScope,
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close, size: 14, color: Color(0xFF6366F1)),
                          SizedBox(width: 3),
                          Text(
                            'Search all stores',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4F46E5),
                              decoration: TextDecoration.underline,
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
        ],
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
          style: const TextStyle(
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
              final isDesktop = context.isDesktop;
              final width = constraints.maxWidth;
              final crossAxisCount = ResponsiveGrid.calculateCrossAxisCount(
                width,
                maxCardWidth: 280,
                maxCount: isDesktop ? 5 : 4,
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
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () {
                    _textCtrl.clear();
                    _onQueryChanged('');
                  },
                  child: Text(AppLocalizations.of(context).clearSearch),
                ),
                if (_companyId.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  FilledButton.tonal(
                    onPressed: _clearCompanyScope,
                    child: const Text('Search in all stores'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
