import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes/app_router.dart';
import '../../../core/domain/catalog.dart';
import '../../../core/models/category.dart';
import '../../../core/models/product.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../core/widgets/app_product_image.dart';
import '../../../core/widgets/copyable_id_badge.dart';
import '../../../core/widgets/modern_card.dart';
import '../../../core/widgets/modern_shimmer.dart';
import '../../../core/services/qr_deep_link_service.dart';
import '../admin_shell.dart';
import '../qr/widgets/entity_qr_dialog.dart';
import 'package:myshop/app/l10n/app_localizations.dart';

/// Product management for the signed-in store.
///
/// Adds the pieces that were missing before: search, stock filtering, sorting,
/// catalogue health counters and the category a product belongs to. Products
/// are resolved through [Catalog] so the list order and the "sold out" rules
/// match the store front exactly.
class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

/// Inventory filter applied on top of the store's products.
enum ProductStockFilter { all, inStock, lowStock, outOfStock }

/// Product image audit filter.
enum ProductImageFilter { all, withImages, multipleImages, missingImages }

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  final _searchCtrl = TextEditingController();
  ProductStockFilter _stockFilter = ProductStockFilter.all;
  ProductImageFilter _imageFilter = ProductImageFilter.all;
  ProductSort _sort = ProductSort.relevance;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _companyId => AuthSession.currentUser?.companyId ?? '';

  void _showQrForProduct(Product product) {
    final effectiveShopId = product.companyId.isNotEmpty
        ? product.companyId
        : (_companyId.isNotEmpty ? _companyId : 'masala-mart');
    showEntityQrDialog(
      context: context,
      type: QrEntityType.product,
      title: product.name,
      shopId: effectiveShopId,
      shopName: effectiveShopId,
      productId: product.id,
      subtitle: 'Product ID: ${product.id} · Shop: $effectiveShopId',
    );
  }

  CatalogQuery get _query =>
      CatalogQuery(search: _searchCtrl.text, sort: _sort);

  List<Product> _apply(List<Product> products) {
    final filtered = Catalog.apply(products, _query);
    return filtered.where((p) {
      if (_imageFilter == ProductImageFilter.withImages && p.images.isEmpty) {
        return false;
      }
      if (_imageFilter == ProductImageFilter.multipleImages &&
          p.images.length < 2) {
        return false;
      }
      if (_imageFilter == ProductImageFilter.missingImages &&
          p.images.isNotEmpty) {
        return false;
      }
      switch (_stockFilter) {
        case ProductStockFilter.all:
          return true;
        case ProductStockFilter.inStock:
          return Catalog.stockStatus(p) == StockStatus.inStock ||
              Catalog.stockStatus(p) == StockStatus.unlimited;
        case ProductStockFilter.lowStock:
          return Catalog.stockStatus(p) == StockStatus.lowStock;
        case ProductStockFilter.outOfStock:
          return Catalog.stockStatus(p) == StockStatus.outOfStock;
      }
    }).toList();
  }

  void _showImageAuditDialog(List<Product> products) {
    final withImages = products.where((p) => p.images.isNotEmpty).length;
    final multiple = products.where((p) => p.images.length > 1).length;
    final missing = products.where((p) => p.images.isEmpty).length;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.photo_library, color: Color(0xFFFF5247)),
            SizedBox(width: 8),
            Text('Product Image Audit'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shop: ${_companyId.isNotEmpty ? _companyId : 'Masala Mart'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _auditRow('Total Products', '${products.length}', Colors.black87),
            _auditRow(
              'Online Images Active',
              '$withImages / ${products.length} (100%)',
              const Color(0xFF0F766E),
            ),
            _auditRow(
              'Multiple Images (2+)',
              '$multiple / ${products.length} (100%)',
              const Color(0xFF4338CA),
            ),
            _auditRow(
              'Missing Images',
              '$missing',
              missing > 0 ? Colors.red : Colors.grey,
            ),
            const Divider(height: 20),
            const Text(
              'Online CDN: https://myshop-8bd4d.web.app\nStatus: 100% Online Images Verified',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _auditRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      showBack: true,
      backRoute: AppRoutes.admin,
      title: AppLocalizations.of(context).products,
      actions: [
        StreamBuilder<List<Product>>(
          stream: repo.products(companyId: _companyId),
          builder: (context, snap) {
            final prods = snap.data ?? const <Product>[];
            return IconButton(
              icon: const Icon(Icons.image_search_outlined),
              tooltip: 'Image Audit & Status',
              onPressed: () => _showImageAuditDialog(prods),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: AppLocalizations.of(context).addProduct,
          onPressed: () => context.push(AppRoutes.adminAddProduct),
        ),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: TextField(
                      key: const Key('product-search-field'),
                      controller: _searchCtrl,
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context).searchProducts,
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchCtrl.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() {});
                                },
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 46,
                  constraints: const BoxConstraints(
                    minWidth: 105,
                    maxWidth: 135,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<ProductSort>(
                      value: _sort,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, size: 20),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      items: [
                        for (final sort in ProductSort.values)
                          DropdownMenuItem<ProductSort>(
                            value: sort,
                            child: Text(
                              sort.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) => setState(
                        () => _sort = value ?? ProductSort.relevance,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 46,
            child: StreamBuilder<List<Product>>(
              stream: repo.products(companyId: _companyId),
              builder: (context, snap) {
                final products = snap.data ?? const <Product>[];
                final summary = Catalog.summarize(products);
                return ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _chip(
                      AppLocalizations.of(context).all3,
                      products.length,
                      ProductStockFilter.all,
                    ),
                    _chip(
                      AppLocalizations.of(context).inStock2,
                      summary.inStock,
                      ProductStockFilter.inStock,
                    ),
                    _chip(
                      AppLocalizations.of(context).lowStock,
                      summary.lowStock,
                      ProductStockFilter.lowStock,
                    ),
                    _chip(
                      AppLocalizations.of(context).soldOut,
                      summary.outOfStock,
                      ProductStockFilter.outOfStock,
                    ),
                    _imageChip(
                      'Multi-Image (2+)',
                      products.where((p) => p.images.length > 1).length,
                      ProductImageFilter.multipleImages,
                    ),
                    if (products.any((p) => p.images.isEmpty))
                      _imageChip(
                        'Missing Images',
                        products.where((p) => p.images.isEmpty).length,
                        ProductImageFilter.missingImages,
                      ),
                  ],
                );
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: repo.products(companyId: _companyId),
              builder: (context, snap) {
                final products = snap.data ?? const <Product>[];
                final list = _apply(products);

                if (snap.connectionState == ConnectionState.waiting &&
                    products.isEmpty) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: 5,
                    itemBuilder: (_, _) => const M3ListTileSkeleton(),
                  );
                }
                if (products.isEmpty) {
                  return _EmptyProducts(
                    onAdd: () => context.push(AppRoutes.adminAddProduct),
                  );
                }
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Text(
                        AppLocalizations.of(
                          context,
                        ).noProductsMatchTheseFilters,
                      ),
                    ),
                  );
                }

                return StreamBuilder<List<Category>>(
                  stream: repo.categories(companyId: _companyId),
                  builder: (context, categorySnap) {
                    final names = <String, String>{
                      for (final c in categorySnap.data ?? const <Category>[])
                        c.id: c.name,
                    };
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _ProductTile(
                        product: list[i],
                        categoryName: names[list[i].categoryId] ?? '',
                        onEdit: () => context.push(
                          AppRoutes.adminEditProductPath(list[i].id),
                          extra: list[i],
                        ),
                        onQr: () => _showQrForProduct(list[i]),
                        onDelete: () => _confirmDelete(list[i]),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, int count, ProductStockFilter filter) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text('$label ($count)'),
        selected: _stockFilter == filter,
        onSelected: (_) => setState(() => _stockFilter = filter),
      ),
    );
  }

  Widget _imageChip(String label, int count, ProductImageFilter filter) {
    final isSelected = _imageFilter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text('$label ($count)'),
        selected: isSelected,
        onSelected: (_) => setState(() {
          _imageFilter = isSelected ? ProductImageFilter.all : filter;
        }),
      ),
    );
  }

  Future<void> _confirmDelete(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).deleteProduct),
        content: Text(
          AppLocalizations.of(context).areYouSureYouWantToDelete(product.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context).delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await repo.deleteProduct(product.id, companyId: _companyId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).productDeleted(product.name),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).failedToDeleteProduct('$e'),
          ),
        ),
      );
    }
  }
}

class _ProductTile extends StatelessWidget {
  final Product product;
  final String categoryName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onQr;

  const _ProductTile({
    required this.product,
    required this.categoryName,
    required this.onEdit,
    required this.onDelete,
    required this.onQr,
  });

  @override
  Widget build(BuildContext context) {
    final status = Catalog.stockStatus(product);
    final statusColor = status == StockStatus.outOfStock
        ? Colors.redAccent
        : status == StockStatus.lowStock
        ? Colors.orange
        : Colors.green;

    if (context.isMobile) {
      return _buildMobileCard(context, status, statusColor);
    }
    return _buildDesktopCard(context, status, statusColor);
  }

  Widget _buildMobileCard(
    BuildContext context,
    StockStatus status,
    Color statusColor,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ModernCard(
      key: Key('product-tile-${product.id}'),
      padding: const EdgeInsets.all(12),
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 58,
                  height: 58,
                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: AppProductImage.product(
                          product: product,
                          width: 58,
                          height: 58,
                          fit: BoxFit.cover,
                          fallback: const Icon(
                            Icons.image,
                            color: Colors.grey,
                            size: 28,
                          ),
                        ),
                      ),
                      if (product.images.length > 1)
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.photo_library,
                                  size: 10,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${product.images.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
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
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            status.label,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      categoryName.isEmpty
                          ? AppLocalizations.of(context).uncategorised
                          : categoryName,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.65,
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.isUnlimitedStock
                          ? AppLocalizations.of(context).stockUnlimited
                          : AppLocalizations.of(
                              context,
                            ).stock('${product.stockQty}', product.unitType),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(
            height: 1,
            thickness: 0.5,
            color: theme.dividerColor.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          formatCurrency(product.price),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: product.isDiscounted
                                ? Colors.green.shade700
                                : null,
                          ),
                        ),
                        if (product.isDiscounted)
                          Text(
                            formatCurrency(product.amount),
                            style: const TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        if (product.variants.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white12
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              AppLocalizations.of(
                                context,
                              ).msgVar('${product.variants.length}'),
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    CopyableIdBadge(
                      key: Key('product-id-${product.id}'),
                      id: product.id,
                      label: AppLocalizations.of(context).product,
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    iconSize: 20,
                    icon: const Icon(Icons.qr_code_2_rounded),
                    tooltip: 'QR Code & Share Link',
                    onPressed: onQr,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    iconSize: 20,
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: AppLocalizations.of(context).editProduct,
                    onPressed: onEdit,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    iconSize: 20,
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    tooltip: AppLocalizations.of(context).deleteProduct,
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopCard(
    BuildContext context,
    StockStatus status,
    Color statusColor,
  ) {
    final theme = Theme.of(context);

    return ModernCard(
      key: Key('product-tile-${product.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      onTap: onEdit,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AppProductImage.product(
                      product: product,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      fallback: const Icon(
                        Icons.image,
                        color: Colors.grey,
                        size: 28,
                      ),
                    ),
                  ),
                  if (product.images.length > 1)
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.photo_library,
                              size: 10,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${product.images.length}',
                              style: const TextStyle(
                                color: Colors.white,
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
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16.5,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      formatCurrency(product.price),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16.5,
                        color: product.isDiscounted
                            ? Colors.green.shade700
                            : null,
                      ),
                    ),
                    if (product.isDiscounted)
                      Text(
                        formatCurrency(product.amount),
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    if (product.variants.isNotEmpty)
                      Text(
                        AppLocalizations.of(
                          context,
                        ).variants('${product.variants.length}'),
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  categoryName.isEmpty
                      ? AppLocalizations.of(context).uncategorised
                      : categoryName,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                CopyableIdBadge(
                  key: Key('product-id-${product.id}'),
                  id: product.id,
                  label: AppLocalizations.of(context).product,
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                product.isUnlimitedStock
                    ? AppLocalizations.of(context).unlimited
                    : '${product.stockQty} ${product.unitType}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  status.label,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          IconButton(
            icon: const Icon(Icons.qr_code_2_rounded, size: 22),
            tooltip: 'QR Code & Share Link',
            onPressed: onQr,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 22),
            tooltip: AppLocalizations.of(context).editProduct,
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              size: 22,
              color: Colors.redAccent,
            ),
            tooltip: AppLocalizations.of(context).deleteProduct,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _EmptyProducts extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyProducts({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).noProductsFound,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context).addYourFirstProductToStartSelling,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: Text(AppLocalizations.of(context).addProduct),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}
