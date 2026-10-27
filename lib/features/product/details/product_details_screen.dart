import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../../../core/models/cart_item.dart';
import '../../../core/models/company.dart';
import '../../../core/models/product.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/cart_notification.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../core/widgets/app_product_image.dart';
import '../../../core/widgets/back_to_admin_button.dart';
import '../../../core/widgets/collapsible_section.dart';
import '../../../core/widgets/modern_shimmer.dart';
import '../../auth/widgets/auth_bottom_sheet.dart';
import '../../checkout/cart/cart_cubit.dart';
import '../../checkout/cart/wishlist_cubit.dart';
import '../../marketplace/widgets/product_card.dart';
import '../../marketplace/widgets/web_header.dart';

/// Product Detail Page (Section 17.3).
///
/// Layout (top to bottom): gallery, name, price, stock label, SKU,
/// Select Variant, quantity, collapsible Highlights, collapsible
/// All Details sections and the add-to-cart / buy-now bar. Every details
/// block is collapsed by default and the selected variant drives the price,
/// stock label and SKU shown above it.
class ProductDetailsScreen extends StatefulWidget {
  final String productId;
  final String? shopId;
  const ProductDetailsScreen({super.key, required this.productId, this.shopId});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  Product? _product;
  Company? _company;
  bool _mismatchedShop = false;
  int _qty = 1;
  bool _loading = true;
  int _selectedImageIndex = 0;
  int _selectedVariantIndex = -1;

  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedImageIndex);
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ProductDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId ||
        oldWidget.shopId != widget.shopId) {
      _selectedImageIndex = 0;
      _selectedVariantIndex = -1;
      _qty = 1;
      _loading = true;
      _pageController.dispose();
      _pageController = PageController(initialPage: 0);
      _load();
    }
  }

  Future<void> _load() async {
    final p = await repo.product(widget.productId);
    Company? c;
    bool mismatched = false;
    if (p != null) {
      c = await repo.company(p.companyId);
      if (widget.shopId != null && widget.shopId!.trim().isNotEmpty) {
        final targetShop = widget.shopId!.trim();
        final matches =
            p.companyId == targetShop ||
            (c != null && (c.id == targetShop || c.slug == targetShop));
        if (!matches) {
          mismatched = true;
        }
      }
    }
    if (mounted) {
      setState(() {
        _product = p;
        _company = c;
        _mismatchedShop = mismatched;
        if (p != null && p.variants.isNotEmpty && _selectedVariantIndex == -1) {
          // Pre-select the product's own pack size ("1 kg" of a 1 kg
          // product) — never an arbitrary first chip.
          _selectedVariantIndex = p.defaultVariantIndex;
        }
        _loading = false;
      });
    }
  }

  ProductVariant? get _selectedVariant {
    final p = _product;
    if (p == null || p.variants.isEmpty) return null;
    if (_selectedVariantIndex >= 0 &&
        _selectedVariantIndex < p.variants.length) {
      return p.variants[_selectedVariantIndex];
    }
    return p.variants.first;
  }

  @override
  Widget build(BuildContext context) {
    void handleBack() {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else if (_company != null && _company!.slug.isNotEmpty) {
        context.go(AppRoutes.companyPath(_company!.slug));
      } else {
        context.go(AppRoutes.home);
      }
    }

    Widget wrapWithPopScope(Widget child) {
      final canPop = Navigator.of(context).canPop();
      return PopScope(
        canPop: canPop,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            handleBack();
          }
        },
        child: child,
      );
    }

    if (_loading) {
      return wrapWithPopScope(
        Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(leading: BackButton(onPressed: handleBack)),
          body: const M3ProductDetailSkeleton(),
        ),
      );
    }

    if (_mismatchedShop) {
      return wrapWithPopScope(
        Scaffold(
          appBar: AppBar(leading: BackButton(onPressed: handleBack)),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.store_mall_directory_outlined,
                    size: 56,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Product Not Available at this Store',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This product belongs to another merchant catalog.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: handleBack,
                    child: const Text('Back to Store'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_product == null) {
      return wrapWithPopScope(
        Scaffold(
          appBar: AppBar(leading: BackButton(onPressed: handleBack)),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 56, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(context).productNotFound,
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: handleBack,
                    child: Text(AppLocalizations.of(context).goBack),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final p = _product!;
    final symbol = _company?.currencySymbol ?? '₹';
    final selectedVariant = _selectedVariant;
    final effectivePrice = p.priceOf(selectedVariant);
    final effectiveMrp = p.mrpOf(selectedVariant);
    final unitDisplay = _variantDisplay(selectedVariant, p);
    final unitText = _unitTextOf(selectedVariant, p);
    final skuText = _skuOf(selectedVariant, p);
    final isDesktop = context.isDesktop;

    return wrapWithPopScope(
      Scaffold(
        appBar: isDesktop
            ? const PreferredSize(
                preferredSize: Size.fromHeight(64),
                child: WebHeader(currentIndex: -1),
              )
            : AppBar(
                leading: BackButton(onPressed: handleBack),
                backgroundColor: Colors.white,
                elevation: 0,
                actions: const [BackToAdminButton()],
              ),
        body: isDesktop
            ? SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Breadcrumbs
                    _buildBreadcrumbs(context, p),
                    const SizedBox(height: 18),

                    // 2-Column Responsive Layout
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column: Product Gallery
                        Expanded(flex: 5, child: _desktopGallery(p)),
                        const SizedBox(width: 36),

                        // Right Column: Product Information & Purchase Box
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_company != null &&
                                  _company!.name.isNotEmpty) ...[
                                Text(
                                  _company!.name.toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFF3D38D9),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],

                              // 2. Name
                              Text(
                                p.name,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
                              ),
                              const SizedBox(height: 8),

                              // Rating and Reviews
                              _buildRatingRow(context, p),
                              const SizedBox(height: 14),

                              // 3. Price
                              _PriceRow(
                                price: effectivePrice,
                                mrp: effectiveMrp,
                                symbol: symbol,
                              ),
                              if (unitText.isNotEmpty ||
                                  skuText.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    if (unitText.isNotEmpty)
                                      KeyedSubtree(
                                        key: const Key('product-unit-type'),
                                        child: Text(
                                          unitText,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                    if (unitText.isNotEmpty &&
                                        skuText.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        child: Text(
                                          '•',
                                          style: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    if (skuText.isNotEmpty)
                                      KeyedSubtree(
                                        key: const Key('product-sku'),
                                        child: Text(
                                          AppLocalizations.of(
                                            context,
                                          ).sku3(skuText),
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 13,
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 12),

                              // 4. Stock label
                              _StockLabel(
                                key: ValueKey('stock-$unitDisplay'),
                                inStock:
                                    selectedVariant?.isInStock ?? p.isInStock,
                                isUnlimited:
                                    selectedVariant?.isUnlimitedStock ??
                                    p.isUnlimitedStock,
                                stock: selectedVariant?.stockQty ?? p.stockQty,
                              ),

                              // 5. Select Variant
                              if (p.variants.isNotEmpty) ...[
                                const SizedBox(height: 18),
                                _VariantPicker(
                                  product: p,
                                  symbol: symbol,
                                  selectedIndex: _selectedVariantIndex,
                                  onSelected: (i) =>
                                      setState(() => _selectedVariantIndex = i),
                                ),
                              ],

                              // Desktop Buy Box Card
                              const SizedBox(height: 20),
                              Card(
                                elevation: 0,
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFF8FAFC),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: _desktopBuyBox(
                                    p,
                                    symbol,
                                    selectedVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),

                              // Delivery and Trust Perks
                              _buildTrustPerks(context),
                              const SizedBox(height: 22),

                              // 6. Highlights (collapsible)
                              ..._highlightsBlocks(p),

                              // 9. All Details (each collapsible)
                              ..._allDetailsBlocks(p),

                              // Spec tables & policy
                              ..._specAndPolicyBlocks(p),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Related Products: More from this Category
                    _buildRelatedProductsSection(p),
                  ],
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      children: [
                        _gallery(p),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ------------------------------------------------ 2. Name
                              Text(
                                p.name,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),

                              // ----------------------------------------------- 3. Price
                              _PriceRow(
                                price: effectivePrice,
                                mrp: effectiveMrp,
                                symbol: symbol,
                              ),
                              if (unitText.isNotEmpty ||
                                  skuText.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    if (unitText.isNotEmpty)
                                      KeyedSubtree(
                                        key: const Key('product-unit-type'),
                                        child: Text(
                                          unitText,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                    if (unitText.isNotEmpty &&
                                        skuText.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        child: Text(
                                          '•',
                                          style: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    if (skuText.isNotEmpty)
                                      KeyedSubtree(
                                        key: const Key('product-sku'),
                                        child: Text(
                                          AppLocalizations.of(
                                            context,
                                          ).sku3(skuText),
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12.5,
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 10),

                              // ------------------------------------------ 4. Stock label
                              _StockLabel(
                                key: ValueKey('stock-$unitDisplay'),
                                inStock:
                                    selectedVariant?.isInStock ?? p.isInStock,
                                isUnlimited:
                                    selectedVariant?.isUnlimitedStock ??
                                    p.isUnlimitedStock,
                                stock: selectedVariant?.stockQty ?? p.stockQty,
                              ),

                              // ------------------------------------- 5. Select Variant
                              if (p.variants.isNotEmpty) ...[
                                const SizedBox(height: 18),
                                _VariantPicker(
                                  product: p,
                                  symbol: symbol,
                                  selectedIndex: _selectedVariantIndex,
                                  onSelected: (i) =>
                                      setState(() => _selectedVariantIndex = i),
                                ),
                              ],

                              // -------------------------- 6. Highlights (collapsible)
                              ..._highlightsBlocks(p),

                              // --------------------- 9. All Details (each collapsible)
                              ..._allDetailsBlocks(p),

                              // Spec tables & policy, folded into the same collapsible
                              // treatment so nothing dominates the page.
                              ..._specAndPolicyBlocks(p),

                              // Related Products (Mobile)
                              _buildRelatedProductsSection(p),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ------------------------------------------ 10. Add to cart / Buy now
                  _bottomBar(p, symbol, selectedVariant),
                ],
              ),
      ),
    );
  }

  // -------------------------------------------------------------- Helpers --

  String _variantDisplay(ProductVariant? variant, Product p) {
    if (variant != null) {
      if (variant.title.isNotEmpty) return variant.title;
      if (variant.size.isNotEmpty) return variant.size;
      if (variant.attributes.isNotEmpty) {
        return variant.attributes.values.join(' / ');
      }
    }
    if (p.unit > 0) return CartUnit.format(p.unit, p.unitType);
    return p.name;
  }

  String _unitTextOf(ProductVariant? variant, Product p) {
    if (variant != null && variant.unitValue > 0) {
      final uType = variant.unitType.isNotEmpty ? variant.unitType : p.unitType;
      return CartUnit.format(variant.unitValue, uType);
    }
    if (variant != null && variant.label.isNotEmpty) {
      return variant.label;
    }
    if (p.unit > 0 && p.unitType.isNotEmpty) {
      return CartUnit.format(p.unit, p.unitType);
    }
    if (p.unitType.isNotEmpty) {
      return p.unitType;
    }
    return '';
  }

  String _skuOf(ProductVariant? variant, Product p) {
    final vs = variant?.sku.trim() ?? '';
    return vs.isNotEmpty ? vs : p.sku.trim();
  }

  // ------------------------------------------------- Highlights & details --

  List<Widget> _highlightsBlocks(Product p) {
    // Rows with a value render even without a title (migrated legacy
    // highlights land as value-only rows).
    final highlights = p.sortedHighlights.where((h) => h.isUsable).toList();
    final legacy = p.subDetails.trim();

    // Legacy fallback: old products only carry a highlights string.
    if (highlights.isEmpty && legacy.isEmpty) return const [];

    final content = highlights.isEmpty
        ? Text(legacy, style: const TextStyle(fontSize: 13.5, height: 1.45))
        : Column(
            children: [
              for (final h in highlights)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          h.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: Text(
                          h.value,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );

    return [
      const SizedBox(height: 8),
      CollapsibleSection(
        title: AppLocalizations.of(context).highlights,
        child: content,
      ),
    ];
  }

  List<Widget> _allDetailsBlocks(Product p) {
    var sections = p.sortedAllDetails.where((s) => !s.isEmptyContent).toList();

    // Legacy fallback: a plain description becomes one text section.
    if (sections.isEmpty && p.details.trim().isNotEmpty) {
      sections = [
        DetailSection(
          title: AppLocalizations.of(context).description,
          type: DetailSectionType.text,
          text: p.details.trim(),
        ),
      ];
    }
    if (sections.isEmpty) return const [];

    return [
      const SizedBox(height: 4),
      for (final section in sections) ...[
        CollapsibleSection(
          title: section.title.isEmpty
              ? AppLocalizations.of(context).details
              : section.title,
          child: section.isKeyValue
              ? KeyValueTable(
                  rows: [
                    for (final item in section.sortedItems)
                      (title: item.title, value: item.value),
                  ],
                )
              : ExpandableText(text: section.text.trim()),
        ),
      ],
    ];
  }

  List<Widget> _specAndPolicyBlocks(Product p) {
    final blocks = <Widget>[];

    if (p.specifications.isNotEmpty) {
      blocks
        ..add(const SizedBox(height: 4))
        ..add(
          CollapsibleSection(
            title: AppLocalizations.of(context).specifications,
            child: KeyValueTable(
              rows: [
                for (final s in p.specifications)
                  (title: s.key, value: s.value),
              ],
            ),
          ),
        );
    }

    if (p.policy.trim().isNotEmpty) {
      blocks
        ..add(const SizedBox(height: 4))
        ..add(
          CollapsibleSection(
            title: AppLocalizations.of(context).deliveryPolicies,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.local_shipping_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    p.policy,
                    style: const TextStyle(fontSize: 13.5, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        );
    }

    return blocks;
  }

  // ---------------------------------------------------------------- Gallery --

  Widget _gallery(Product p) {
    final scheme = Theme.of(context).colorScheme;
    final images = p.images.isEmpty ? [''] : p.images;
    final isMultiple = images.length > 1;
    final maxCarouselHeight = MediaQuery.of(context).size.height * 0.7;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          // Main Carousel Card with Rounded Border (16:9 ratio, max 70% height)
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxCarouselHeight),
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: AspectRatio(
                  aspectRatio: 3 / 2,
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => FullScreenGallery(
                              images: images,
                              initialIndex: _selectedImageIndex,
                            ),
                            fullscreenDialog: true,
                          ),
                        ),
                        child: PageView.builder(
                          itemCount: images.length,
                          controller: _pageController,
                          onPageChanged: (i) =>
                              setState(() => _selectedImageIndex = i),
                          itemBuilder: (context, i) {
                            final url = images[i].trim();
                            if (url.isEmpty) {
                              return Center(
                                child: Icon(
                                  Icons.image_outlined,
                                  size: 72,
                                  color: scheme.primary.withValues(alpha: 0.5),
                                ),
                              );
                            }
                            return AppProductImage(
                              url: url,
                              fit: BoxFit.cover,
                              fallback: Center(
                                child: Icon(
                                  Icons.broken_image,
                                  size: 64,
                                  color: scheme.outlineVariant,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (isMultiple)
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_selectedImageIndex + 1}/${images.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Thumbnail List underneath
          if (isMultiple) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 58,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final url = images[i].trim();
                  final isSelected = _selectedImageIndex == i;
                  return GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        i,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                      setState(() => _selectedImageIndex = i);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 58,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? scheme.primary
                              : scheme.outlineVariant.withValues(alpha: 0.4),
                          width: isSelected ? 2.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        color: scheme.surface,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: scheme.primary.withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: url.isEmpty
                          ? const Icon(
                              Icons.image_outlined,
                              color: Colors.grey,
                              size: 20,
                            )
                          : AppProductImage(
                              url: url,
                              fit: BoxFit.cover,
                              borderRadius: BorderRadius.circular(8),
                              fallback: const Icon(
                                Icons.broken_image,
                                size: 18,
                                color: Colors.grey,
                              ),
                            ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------- Bottom bar --

  Widget _bottomBar(Product p, String symbol, ProductVariant? selectedVariant) {
    final l10n = AppLocalizations.of(context);
    final activeVariant = _selectedVariant ?? selectedVariant;
    final inStock = activeVariant?.isInStock ?? p.isInStock;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            _qtyPicker(),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: inStock
                    ? () {
                        void doAddToCart() {
                          final currentVariant =
                              _selectedVariant ?? selectedVariant;
                          context.read<CartCubit>().add(
                            p,
                            variant: currentVariant,
                            company: _company,
                            qty: _qty,
                          );
                          final label = currentVariant?.label ?? '';
                          showAddToCartNotification(
                            context,
                            productName: p.name,
                            variantLabel: label,
                          );
                        }

                        if (AuthSession.currentUser == null) {
                          AuthBottomSheet.show(
                            context,
                            onAuthenticated: doAddToCart,
                          );
                        } else {
                          doAddToCart();
                        }
                      }
                    : null,
                child: Text(
                  inStock
                      ? l10n.addToCart
                      : AppLocalizations.of(context).outOfStock2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: inStock
                    ? () {
                        void doBuyNow() {
                          final currentVariant =
                              _selectedVariant ?? selectedVariant;
                          // Direct order carries the SELECTED variant snapshot.
                          final directItem = CartItem.fromSelection(
                            companyId: _company?.id ?? p.companyId,
                            companyName: _company?.name ?? '',
                            product: p,
                            selectedVariant: currentVariant,
                            qty: _qty,
                          );
                          context.push(AppRoutes.checkout, extra: directItem);
                        }

                        if (AuthSession.currentUser == null) {
                          AuthBottomSheet.show(
                            context,
                            onAuthenticated: doBuyNow,
                          );
                        } else {
                          doBuyNow();
                        }
                      }
                    : null,
                child: Text(l10n.buyNow),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qtyPicker() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: () => setState(() {
              if (_qty > 1) _qty--;
            }),
          ),
          Text('$_qty', style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => setState(() => _qty++),
          ),
        ],
      ),
    );
  }

  Widget _desktopGallery(Product p) {
    final scheme = Theme.of(context).colorScheme;
    final images = p.images.isEmpty ? [''] : p.images;
    final isMultiple = images.length > 1;
    final soldOut = !p.isInStock;

    WishlistCubit? wishlistCubit;
    try {
      wishlistCubit = context.watch<WishlistCubit>();
    } catch (_) {}
    final inWishlist = wishlistCubit?.state.contains(p.id) ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Primary Image Card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.04),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 1.05,
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FullScreenGallery(
                        images: images,
                        initialIndex: _selectedImageIndex,
                      ),
                      fullscreenDialog: true,
                    ),
                  ),
                  child: PageView.builder(
                    itemCount: images.length,
                    controller: _pageController,
                    onPageChanged: (i) =>
                        setState(() => _selectedImageIndex = i),
                    itemBuilder: (context, i) {
                      final url = images[i].trim();
                      if (url.isEmpty) {
                        return Center(
                          child: Icon(
                            Icons.image_outlined,
                            size: 80,
                            color: scheme.primary.withValues(alpha: 0.4),
                          ),
                        );
                      }
                      return AppProductImage(
                        url: url,
                        fit: BoxFit.contain,
                        fallback: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 72,
                            color: scheme.outlineVariant,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Wishlist Button (Top Right)
                Positioned(
                  top: 14,
                  right: 14,
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.92),
                    shape: const CircleBorder(),
                    elevation: 3,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        if (wishlistCubit != null) {
                          wishlistCubit.toggle(p);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          inWishlist
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: inWishlist
                              ? const Color(0xFFFF5247)
                              : const Color(0xFF64748B),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),

                // Sold Out Veil
                if (soldOut)
                  Positioned.fill(
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.7),
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB3261E),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'OUT OF STOCK',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Thumbnails Strip underneath
        if (isMultiple) ...[
          const SizedBox(height: 14),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final url = images[i].trim();
                final isSelected = _selectedImageIndex == i;
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        i,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      );
                      setState(() => _selectedImageIndex = i);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 72,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFF5247)
                              : scheme.outlineVariant.withValues(alpha: 0.4),
                          width: isSelected ? 2.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFFFF5247,
                                  ).withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: url.isEmpty
                          ? const Center(
                              child: Icon(
                                Icons.image_outlined,
                                size: 24,
                                color: Colors.grey,
                              ),
                            )
                          : AppProductImage(
                              url: url,
                              fit: BoxFit.cover,
                              fallback: const Center(
                                child: Icon(
                                  Icons.broken_image,
                                  size: 24,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _desktopBuyBox(
    Product p,
    String symbol,
    ProductVariant? selectedVariant,
  ) {
    final l10n = AppLocalizations.of(context);
    final activeVariant = _selectedVariant ?? selectedVariant;
    final inStock = activeVariant?.isInStock ?? p.isInStock;

    WishlistCubit? wishlistCubit;
    try {
      wishlistCubit = context.watch<WishlistCubit>();
    } catch (_) {}
    final inWishlist = wishlistCubit?.state.contains(p.id) ?? false;

    return Row(
      children: [
        _qtyPicker(),
        const SizedBox(width: 14),
        Expanded(
          child: OutlinedButton(
            key: const Key('desktop-add-to-cart-btn'),
            onPressed: inStock
                ? () {
                    void doAddToCart() {
                      final currentVariant =
                          _selectedVariant ?? selectedVariant;
                      context.read<CartCubit>().add(
                        p,
                        variant: currentVariant,
                        company: _company,
                        qty: _qty,
                      );
                      final label = currentVariant?.label ?? '';
                      showAddToCartNotification(
                        context,
                        productName: p.name,
                        variantLabel: label,
                      );
                    }

                    if (AuthSession.currentUser == null) {
                      AuthBottomSheet.show(
                        context,
                        onAuthenticated: doAddToCart,
                      );
                    } else {
                      doAddToCart();
                    }
                  }
                : null,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              inStock
                  ? l10n.addToCart
                  : AppLocalizations.of(context).outOfStock2,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            key: const Key('desktop-buy-now-btn'),
            onPressed: inStock
                ? () {
                    void doBuyNow() {
                      final currentVariant =
                          _selectedVariant ?? selectedVariant;
                      final directItem = CartItem.fromSelection(
                        companyId: _company?.id ?? p.companyId,
                        companyName: _company?.name ?? '',
                        product: p,
                        selectedVariant: currentVariant,
                        qty: _qty,
                      );
                      context.push(AppRoutes.checkout, extra: directItem);
                    }

                    if (AuthSession.currentUser == null) {
                      AuthBottomSheet.show(context, onAuthenticated: doBuyNow);
                    } else {
                      doBuyNow();
                    }
                  }
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.flash_on_rounded, size: 20),
            label: Text(
              l10n.buyNow,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filledTonal(
          onPressed: () {
            if (wishlistCubit != null) {
              wishlistCubit.toggle(p);
            }
          },
          icon: Icon(
            inWishlist ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: inWishlist ? const Color(0xFFFF5247) : Colors.grey.shade700,
          ),
          style: IconButton.styleFrom(
            padding: const EdgeInsets.all(14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBreadcrumbs(BuildContext context, Product p) {
    return Row(
      children: [
        InkWell(
          onTap: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else if (_company != null && _company!.slug.isNotEmpty) {
              context.go(AppRoutes.companyPath(_company!.slug));
            } else {
              context.go(AppRoutes.home);
            }
          },
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
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
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
              fontSize: 13,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (_company != null && _company!.name.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              Icons.chevron_right,
              size: 16,
              color: Color(0xFF94A3B8),
            ),
          ),
          InkWell(
            onTap: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go(AppRoutes.companyPath(_company!.slug));
              }
            },
            child: Text(
              _company!.name,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.chevron_right, size: 16, color: Color(0xFF94A3B8)),
        ),
        const Text(
          'Details',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF1E2229),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildRatingRow(BuildContext context, Product p) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFE6F7F2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_rounded, size: 14, color: Color(0xFF0CA678)),
              SizedBox(width: 3),
              Text(
                '4.5',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0CA678),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '120+ ratings & reviews',
          style: TextStyle(
            fontSize: 12.5,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTrustPerks(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Row(
        children: [
          Expanded(
            child: _TrustPerkItem(
              icon: Icons.local_shipping_outlined,
              title: 'Fast Delivery',
              subtitle: 'Dispatch in 24 hrs',
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _TrustPerkItem(
              icon: Icons.verified_user_outlined,
              title: '100% Genuine',
              subtitle: 'Quality Assured',
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _TrustPerkItem(
              icon: Icons.lock_outline,
              title: 'Secure Payment',
              subtitle: 'Encrypted checkout',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedProductsSection(Product p) {
    if (p.categoryId.isEmpty && p.companyId.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<Product>>(
      stream: repo.products(companyId: p.companyId, categoryId: p.categoryId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: M3ProductGridSkeleton(itemCount: 4),
          );
        }
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final related = snapshot.data!
            .where((item) => item.id != p.id && item.isInStock)
            .toList();

        if (related.isEmpty) {
          return const SizedBox.shrink();
        }

        final isDesktop = context.isDesktop;

        return Padding(
          padding: EdgeInsets.only(top: 32, bottom: isDesktop ? 48 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 32),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'More from this Category',
                    style: TextStyle(
                      fontSize: isDesktop ? 22 : 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1E2229),
                    ),
                  ),
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
                      '${related.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF5247),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  int columns;
                  if (width < 600) {
                    columns = 2;
                  } else if (width < 900) {
                    columns = 3;
                  } else if (width < 1200) {
                    columns = 4;
                  } else if (width < 1600) {
                    columns = 5;
                  } else {
                    columns = 6;
                  }

                  final childAspectRatio =
                      ResponsiveGrid.calculateProductAspectRatio(
                        width,
                        columns,
                        showBrand: true,
                      );

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      childAspectRatio: childAspectRatio,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: related.length,
                    itemBuilder: (context, index) {
                      final item = related[index];
                      return ProductCard(
                        product: item,
                        company: _company,
                        onTap: () =>
                            context.push(AppRoutes.productPath(item.id)),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TrustPerkItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _TrustPerkItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF3D38D9)),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: Color(0xFF1E2229),
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pieces of the product page
// ---------------------------------------------------------------------------

/// Price row: selling price, MRP strikethrough and the discount % chip.
class _PriceRow extends StatelessWidget {
  final double price;
  final double mrp;
  final String symbol;

  const _PriceRow({
    required this.price,
    required this.mrp,
    required this.symbol,
  });

  @override
  Widget build(BuildContext context) {
    final discounted = mrp > price + 0.001;
    final percent = discounted && mrp > 0 ? ((mrp - price) / mrp) * 100 : 0;
    return Row(
      key: const Key('product-price'),
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          formatCurrency(price, symbol: symbol),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        if (discounted) ...[
          const SizedBox(width: 8),
          Text(
            formatCurrency(mrp, symbol: symbol),
            style: const TextStyle(
              decoration: TextDecoration.lineThrough,
              color: Colors.grey,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              AppLocalizations.of(context).off3('${percent.round()}'),
              style: TextStyle(
                color: Colors.green.shade800,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Stock label between the price and the SKU.
///
/// "In Stock" (green) / "Only X left" (orange) / "Out of Stock" (red).
class _StockLabel extends StatelessWidget {
  final bool inStock;
  final bool isUnlimited;
  final int stock;

  const _StockLabel({
    super.key,
    required this.inStock,
    required this.isUnlimited,
    required this.stock,
  });

  static const _lowThreshold = 5;

  @override
  Widget build(BuildContext context) {
    final String text;
    final Color color;
    if (!inStock) {
      text = AppLocalizations.of(context).outOfStock2;
      color = Colors.red.shade700;
    } else if (!isUnlimited && stock <= _lowThreshold) {
      text = AppLocalizations.of(context).onlyLeft('$stock');
      color = Colors.orange.shade800;
    } else {
      text = AppLocalizations.of(context).inStock;
      color = Colors.green.shade700;
    }

    return Row(
      key: const Key('stock-label'),
      children: [
        Icon(
          !inStock
              ? Icons.cancel_outlined
              : (!isUnlimited && stock <= _lowThreshold)
              ? Icons.error_outline
              : Icons.check_circle_outline,
          size: 17,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// "Select Variant" chips — placed right below the pricing block. Selecting
/// a chip updates the price, stock label and SKU above it immediately.
class _VariantPicker extends StatelessWidget {
  final Product product;
  final String symbol;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _VariantPicker({
    required this.product,
    required this.symbol,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final selected = selectedIndex >= 0
        ? selectedIndex
        : product.defaultVariantIndex;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              AppLocalizations.of(context).selectVariant,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (selected >= 0 && selected < product.variants.length) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '(${product.variants[selected].label})',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(product.variants.length, (i) {
            final v = product.variants[i];
            final isSelected = selected == i;
            final vPrice = product.priceOf(v);
            final label = v.label.isNotEmpty ? v.label : v.sku;
            return ChoiceChip(
              key: Key('variant-chip-$i'),
              label: Text(
                '$label (${formatCurrency(vPrice, symbol: symbol)})',
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: v.isInStock || isSelected
                  ? (sel) {
                      if (sel) onSelected(i);
                    }
                  : null,
            );
          }),
        ),
      ],
    );
  }
}

class FullScreenGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  const FullScreenGallery({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  @override
  State<FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<FullScreenGallery> {
  late PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, elevation: 0),
      body: PageView.builder(
        controller: _controller,
        itemCount: images.length,
        itemBuilder: (context, i) {
          final url = images[i].trim();
          return Center(
            child: InteractiveViewer(
              child: url.isEmpty
                  ? const Icon(
                      Icons.image_outlined,
                      size: 120,
                      color: Colors.white24,
                    )
                  : AppProductImage(
                      url: url,
                      fit: BoxFit.contain,
                      fallback: const Icon(
                        Icons.broken_image,
                        size: 120,
                        color: Colors.white24,
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}
