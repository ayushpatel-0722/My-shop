import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../../../core/models/company.dart';
import '../../../core/models/product.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/widgets/auth_bottom_sheet.dart';
import '../../checkout/cart/cart_cubit.dart';

/// Product Detail Page (Section 17.3): gallery, variants, voucher hint and a
/// persistent add-to-cart / buy-now bar.
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
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(AppRoutes.home);
              }
            },
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_product == null) {
      return Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(AppRoutes.home);
              }
            },
          ),
        ),
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
                TextButton(
                  onPressed: () => context.go(AppRoutes.home),
                  child: const Text('Back to Home'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final p = _product!;
    final symbol = _company?.currencySymbol ?? '₹';
    final selectedVariant =
        _selectedVariantIndex >= 0 && _selectedVariantIndex < p.variants.length
        ? p.variants[_selectedVariantIndex]
        : null;
    final effectivePrice =
        (selectedVariant != null && selectedVariant.priceOverride > 0)
        ? selectedVariant.priceOverride
        : p.price;

    return Scaffold(
      appBar: AppBar(
        title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
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
                      Text(
                        p.name,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${p.unit} ${p.unitType}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            formatCurrency(effectivePrice, symbol: symbol),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (p.isDiscounted && effectivePrice < p.amount) ...[
                            const SizedBox(width: 8),
                            Text(
                              formatCurrency(p.amount, symbol: symbol),
                              style: const TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Chip(
                              label: Text(
                                '${p.discountPercent.toStringAsFixed(0)}% OFF',
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(p.details),
                      if (p.subDetails.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          p.subDetails,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                      if (p.variants.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Text(
                          'Select Variant',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(p.variants.length, (i) {
                            final v = p.variants[i];
                            final isSelected = _selectedVariantIndex == i;
                            final labelText = v.title.isNotEmpty
                                ? v.title
                                : (v.color.isNotEmpty
                                      ? '${v.color} · ${v.sku}'
                                      : v.sku);
                            return ChoiceChip(
                              label: Text(
                                v.priceOverride > 0
                                    ? '$labelText (${formatCurrency(v.priceOverride, symbol: symbol)})'
                                    : labelText,
                              ),
                              selected: isSelected,
                              onSelected: (_) => setState(() {
                                _selectedVariantIndex =
                                    _selectedVariantIndex == i ? -1 : i;
                              }),
                            );
                          }),
                        ),
                      ],
                      if (p.specifications.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Specifications',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).dividerColor.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            children: [
                              for (
                                int i = 0;
                                i < p.specifications.length;
                                i++
                              ) ...[
                                if (i > 0)
                                  Divider(
                                    height: 1,
                                    color: Theme.of(
                                      context,
                                    ).dividerColor.withValues(alpha: 0.2),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          p.specifications[i].key,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          p.specifications[i].value,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      if (p.policy.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Delivery & Policies',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.local_shipping_outlined,
                                size: 20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  p.policy,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Builder(
                        builder: (context) {
                          final isUnlimited =
                              selectedVariant?.isUnlimitedStock ??
                              p.isUnlimitedStock;
                          final stock = selectedVariant?.stockQty ?? p.stockQty;
                          final inStock = isUnlimited || stock > 0;

                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: inStock
                                  ? Colors.green.withValues(alpha: 0.08)
                                  : Colors.red.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: inStock
                                    ? Colors.green.withValues(alpha: 0.25)
                                    : Colors.red.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  inStock
                                      ? Icons.check_circle_outline
                                      : Icons.cancel_outlined,
                                  size: 18,
                                  color: inStock
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isUnlimited
                                      ? 'In Stock (Unlimited Inventory)'
                                      : (stock > 0
                                            ? 'In Stock: $stock ${p.unitType}'
                                            : 'Out of Stock / Finished'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: inStock
                                        ? Colors.green.shade800
                                        : Colors.red.shade800,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _bottomBar(p, symbol),
        ],
      ),
    );
  }

  Widget _gallery(Product p) {
    final scheme = Theme.of(context).colorScheme;
    final images = p.images.isEmpty ? [''] : p.images;
    final isMultiple = images.length > 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          // Main Carousel Card with Rounded Border
          Container(
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
                aspectRatio: 16 / 10,
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
                                              progress.expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: scheme.surfaceContainerHighest
                                      .withValues(alpha: 0.3),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.broken_image_outlined,
                                          size: 48,
                                          color: Colors.grey.shade400,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Image unavailable',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                          );
                        },
                      ),
                    ),

                    // Top Right Badge: Image Counter
                    if (isMultiple)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.photo_library,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_selectedImageIndex + 1}/${images.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Left & Right Navigation Arrows for Carousel
                    if (isMultiple) ...[
                      if (_selectedImageIndex > 0)
                        Positioned(
                          left: 6,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: InkWell(
                              onTap: () {
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.chevron_left,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_selectedImageIndex < images.length - 1)
                        Positioned(
                          right: 6,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: InkWell(
                              onTap: () {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.chevron_right,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],

                    // Bottom Center: - - - Indicator Dots
                    if (isMultiple)
                      Positioned(
                        bottom: 10,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(images.length, (i) {
                            final isActive = _selectedImageIndex == i;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: isActive ? 22 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? scheme.primary
                                    : Colors.white.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ),
                  ],
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

  Widget _bottomBar(Product p, String symbol) {
    final l10n = AppLocalizations.of(context);
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
                onPressed: () {
                  void doAddToCart() {
                    for (var i = 0; i < _qty; i++) {
                      context.read<CartCubit>().add(p, company: _company);
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${p.name} added to cart'),
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
                    AuthBottomSheet.show(context, onAuthenticated: doAddToCart);
                  } else {
                    doAddToCart();
                  }
                },
                child: Text(l10n.addToCart),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  void doBuyNow() {
                    context.read<CartCubit>().add(p, company: _company);
                    context.go(AppRoutes.cart);
                  }

                  if (AuthSession.currentUser == null) {
                    AuthBottomSheet.show(context, onAuthenticated: doBuyNow);
                  } else {
                    doBuyNow();
                  }
                },
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
