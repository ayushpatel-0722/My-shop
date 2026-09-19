import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes/app_router.dart';
import '../../../core/domain/catalog.dart';
import '../../../core/models/category.dart';
import '../../../core/models/product.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/copyable_id_badge.dart';
import '../../../core/widgets/modern_card.dart';
import '../admin_shell.dart';

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

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  final _searchCtrl = TextEditingController();
  ProductStockFilter _stockFilter = ProductStockFilter.all;
  ProductSort _sort = ProductSort.relevance;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _companyId => AuthSession.currentUser?.companyId ?? '';

  CatalogQuery get _query => CatalogQuery(
        search: _searchCtrl.text,
        sort: _sort,
      );

  List<Product> _apply(List<Product> products) {
    final filtered = Catalog.apply(products, _query);
    return filtered.where((p) {
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

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      showBack: true,
      backRoute: AppRoutes.admin,
      title: 'Products',
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: 'Add Product',
          onPressed: () => context.push(AppRoutes.adminAddProduct),
        ),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('product-search-field'),
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      labelText: 'Search products',
                      hintText: 'Name or SKU',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchCtrl.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {});
                              },
                            ),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<ProductSort>(
                  value: _sort,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final sort in ProductSort.values)
                      DropdownMenuItem<ProductSort>(
                        value: sort,
                        child: Text(sort.label),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _sort = value ?? ProductSort.relevance),
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
                    _chip('All', products.length, ProductStockFilter.all),
                    _chip(
                      'In stock',
                      summary.inStock,
                      ProductStockFilter.inStock,
                    ),
                    _chip(
                      'Low stock',
                      summary.lowStock,
                      ProductStockFilter.lowStock,
                    ),
                    _chip(
                      'Sold out',
                      summary.outOfStock,
                      ProductStockFilter.outOfStock,
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
                  return const Center(child: CircularProgressIndicator());
                }
                if (products.isEmpty) {
                  return _EmptyProducts(
                    onAdd: () => context.push(AppRoutes.adminAddProduct),
                  );
                }
                if (list.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Text('No products match these filters'),
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
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _ProductTile(
                        product: list[i],
                        categoryName: names[list[i].categoryId] ?? '',
                        onEdit: () => context.push(
                          AppRoutes.adminEditProductPath(list[i].id),
                          extra: list[i],
                        ),
                        onDelete: () => _confirmDelete(context, list[i]),
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

  Future<void> _confirmDelete(BuildContext context, Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await repo.deleteProduct(product.id, companyId: _companyId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Product "${product.name}" deleted.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete product: $e')),
      );
    }
  }
}

class _ProductTile extends StatelessWidget {
  final Product product;
  final String categoryName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductTile({
    required this.product,
    required this.categoryName,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final status = Catalog.stockStatus(product);
    final statusColor = status == StockStatus.outOfStock
        ? Colors.redAccent
        : status == StockStatus.lowStock
            ? Colors.orange
            : Colors.green;

    return ModernCard(
      key: Key('product-tile-${product.id}'),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 48,
            height: 48,
            child: product.imageUrl.isNotEmpty &&
                    product.imageUrl.startsWith('http')
                ? Image.network(
                    product.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.image),
                  )
                : const Icon(Icons.image),
          ),
        ),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  formatCurrency(product.price),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: product.isDiscounted ? Colors.green.shade700 : null,
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
                  Text(
                    '• ${product.variants.length} variants',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              categoryName.isEmpty
                  ? 'Uncategorised'
                  : categoryName,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            CopyableIdBadge(key: Key('product-id-${product.id}'), id: product.id, label: 'Product'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      product.isUnlimitedStock
                          ? 'Unlimited'
                          : '${product.stockQty} ${product.unitType}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      status.label,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: 'Edit Product',
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Colors.redAccent,
                  ),
                  tooltip: 'Delete Product',
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
        onTap: onEdit,
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
          const Text(
            'No products found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add your first product to start selling.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Product'),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}
