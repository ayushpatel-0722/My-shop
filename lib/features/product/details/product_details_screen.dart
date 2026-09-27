import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../../../core/models/cart_item.dart';
import '../../../core/models/company.dart';
import '../../../core/models/product.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/collapsible_section.dart';
import '../../../core/widgets/modern_shimmer.dart';
import '../../auth/widgets/auth_bottom_sheet.dart';
import '../../checkout/cart/cart_cubit.dart';

/// Product Detail Page (Section 17.3).
///
/// Layout (top to bottom): gallery, name, price, stock label, SKU,
/// Select Variant, quantity, collapsible Highlights, collapsible
/// All Details sections and the add-to-cart / buy-now bar. Every details
/// block is collapsed by default and the selected variant drives the price,
/// stock label and SKU shown above it.
class ProductDetailsScreen extends StatefulWidget {
  final String productId;
  const ProductDetailsScreen({super.key, required this.productId});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  Product? _product;
  Company? _company;
  int _qty = 1;
  bool _loading = true;
  int _selectedImageIndex = 0;
  int _selectedVariantIndex = -1;

  /// Sections hidden behind the "View more" button.
  bool _showAllDetailSections = false;

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

  Future<void> _load() async {
    final p = await repo.product(widget.productId);
    Company? c;
    if (p != null) {
      final companies = await repo.companies().first;
      c = companies.where((e) => e.id == p.companyId).firstOrNull;
    }
    if (mounted) {
      setState(() {
        _product = p;
        _company = c;
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
      if (context.canPop()) {
        context.pop();
      } else if (_company != null && _company!.slug.isNotEmpty) {
        context.go(AppRoutes.companyPath(_company!.slug));
      } else {
        context.go(AppRoutes.home);
      }
    }

    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(leading: BackButton(onPressed: handleBack)),
        body: const M3ProductDetailSkeleton(),
      );
    }

    if (_product == null) {
      return Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: handleBack)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 56, color: Colors.grey),
                const SizedBox(height: 12),
                const Text('Product not found', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                TextButton(onPressed: handleBack, child: const Text('Go Back')),
              ],
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

    return Scaffold(
      appBar: AppBar(
        title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        leading: BackButton(onPressed: handleBack),
      ),
      body: Column(
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
                      const SizedBox(height: 10),

                      // ------------------------------------------ 4. Stock label
                      _StockLabel(
                        key: ValueKey('stock-$unitDisplay'),
                        inStock: selectedVariant?.isInStock ?? p.isInStock,
                        isUnlimited:
                            selectedVariant?.isUnlimitedStock ??
                            p.isUnlimitedStock,
                        stock: selectedVariant?.stockQty ?? p.stockQty,
                      ),
                      const SizedBox(height: 6),

                      // ------------------------------------------------ 5. SKU
                      if (_skuOf(selectedVariant, p).isNotEmpty)
                        Text(
                          'SKU: ${_skuOf(selectedVariant, p)}',
                          key: const Key('product-sku'),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),

                      // ------------------------------------- 6. Select Variant
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

                      // ------------------------------- 7. Quantity selector hint
                      const SizedBox(height: 14),
                      _QtyHint(qty: _qty),

                      // -------------------------- 8. Highlights (collapsible)
                      ..._highlightsBlocks(p),

                      // --------------------- 9. All Details (each collapsible)
                      ..._allDetailsBlocks(p),

                      // Spec tables & policy, folded into the same collapsible
                      // treatment so nothing dominates the page.
                      ..._specAndPolicyBlocks(p),
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

  String _skuOf(ProductVariant? variant, Product p) {
    final vs = variant?.sku.trim() ?? '';
    return vs.isNotEmpty ? vs : p.sku.trim();
  }

  // ------------------------------------------------- Highlights & details --

  List<Widget> _highlightsBlocks(Product p) {
    // Rows with a value render even without a title (migrated legacy
    // highlights land as value-only rows).
    final highlights = p.sortedHighlights
        .where((h) => h.isUsable)
        .toList();
    final legacy = p.subDetails.trim();

    // Legacy fallback: old products only carry a highlights string.
    if (highlights.isEmpty && legacy.isEmpty) return const [];

    final content = highlights.isEmpty
        ? Text(
            legacy,
            style: const TextStyle(fontSize: 13.5, height: 1.45),
          )
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
      CollapsibleSection(title: 'Highlights', child: content),
    ];
  }

  List<Widget> _allDetailsBlocks(Product p) {
    var sections = p.sortedAllDetails
        .where((s) => !s.isEmptyContent)
        .toList();

    // Legacy fallback: a plain description becomes one text section.
    if (sections.isEmpty && p.details.trim().isNotEmpty) {
      sections = [
        DetailSection(
          title: 'Description',
          type: DetailSectionType.text,
          text: p.details.trim(),
        ),
      ];
    }
    if (sections.isEmpty) return const [];

    const visibleCount = 2;
    final visible = _showAllDetailSections
        ? sections
        : sections.take(visibleCount).toList();
    final hidden = sections.length - visible.length;

    return [
      const SizedBox(height: 4),
      for (final section in visible) ...[
        CollapsibleSection(
          title: section.title.isEmpty ? 'Details' : section.title,
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
      if (hidden > 0 && !_showAllDetailSections)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: OutlinedButton.icon(
            key: const Key('view-more-details'),
            onPressed: () => setState(() => _showAllDetailSections = true),
            icon: const Icon(Icons.unfold_more, size: 18),
            label: Text('View all details ($hidden more)'),
          ),
        ),
      if (_showAllDetailSections && sections.length > visibleCount)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: TextButton.icon(
            key: const Key('view-less-details'),
            onPressed: () => setState(() => _showAllDetailSections = false),
            icon: const Icon(Icons.unfold_less, size: 18),
            label: const Text('Show less'),
          ),
        ),
    ];
  }

  List<Widget> _specAndPolicyBlocks(Product p) {
    final blocks = <Widget>[];

    if (p.specifications.isNotEmpty) {
      blocks
        ..add(const SizedBox(height: 4))
        ..add(
          CollapsibleSection(
            title: 'Specifications',
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
            title: 'Delivery & Policies',
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
                            return Image.network(
                              url,
                              fit: BoxFit.cover,
                              loadingBuilder: (c, child, progress) {
                                if (progress == null) return child;
                                return Center(
                                  child: SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: scheme.primary,
                                      value: progress.expectedTotalBytes != null
                                          ? progress.cumulativeBytesLoaded /
                                                (progress.expectedTotalBytes ??
                                                    1)
                                          : null,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (c, e, s) => Center(
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
                          ? Icon(
                              Icons.image_outlined,
                              color: Colors.grey,
                              size: 20,
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                url,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => const Icon(
                                  Icons.broken_image,
                                  size: 18,
                                  color: Colors.grey,
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
                          final variantLabel = label.isNotEmpty
                              ? ' ($label)'
                              : '';
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${p.name}$variantLabel added to cart',
                              ),
                              duration: const Duration(seconds: 2),
                              action: SnackBarAction(
                                label: 'View Cart',
                                onPressed: () => context.go(AppRoutes.cart),
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
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
                child: Text(inStock ? l10n.addToCart : 'Out of Stock'),
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
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          formatCurrency(price, symbol: symbol),
          key: const Key('product-price'),
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
              '${percent.round()}% OFF',
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
      text = 'Out of Stock';
      color = Colors.red.shade700;
    } else if (!isUnlimited && stock <= _lowThreshold) {
      text = 'Only $stock left';
      color = Colors.orange.shade800;
    } else {
      text = 'In Stock';
      color = Colors.green.shade700;
    }

    return Row(
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
          key: const Key('stock-label'),
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
    final selected = selectedIndex >= 0 ? selectedIndex : product.defaultVariantIndex;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Select Variant',
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
                  fontWeight: isSelected
                      ? FontWeight.bold
                      : FontWeight.normal,
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

/// Small quantity summary shown in the page flow (the real picker lives in
/// the bottom bar).
class _QtyHint extends StatelessWidget {
  final int qty;

  const _QtyHint({required this.qty});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Quantity',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '× $qty',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
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
                  : Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder: (c, child, p) {
                        if (p == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) => const Icon(
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
