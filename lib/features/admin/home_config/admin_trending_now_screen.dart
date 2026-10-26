import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes/app_router.dart';
import '../../../core/models/category.dart';
import '../../../core/models/company.dart';
import '../../../core/models/home_trending_item.dart';
import '../../../core/models/product.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_product_image.dart';
import '../admin_shell.dart';
import 'widgets/shop_selector_bar.dart';

/// Admin screen to manage items (products and categories) displayed in the
/// user home screen's "Trending Now" section for a specific shop.
class AdminTrendingNowScreen extends StatefulWidget {
  const AdminTrendingNowScreen({super.key});

  @override
  State<AdminTrendingNowScreen> createState() => _AdminTrendingNowScreenState();
}

class _AdminTrendingNowScreenState extends State<AdminTrendingNowScreen> {
  Company? _selectedShop;
  bool _isLoadingShop = true;

  @override
  void initState() {
    super.initState();
    _initShop();
  }

  Future<void> _initShop() async {
    final user = AuthSession.currentUser;
    final adminCompanyId = user?.companyId ?? '';

    final shops = await repo.companies().first;
    if (!mounted) return;

    if (adminCompanyId.isNotEmpty) {
      final found = shops.where((s) => s.id == adminCompanyId).firstOrNull;
      setState(() {
        _selectedShop =
            found ??
            Company(
              id: adminCompanyId,
              slug: adminCompanyId,
              name: user?.companyName.isNotEmpty == true
                  ? user!.companyName
                  : adminCompanyId,
            );
        _isLoadingShop = false;
      });
    } else if (shops.isNotEmpty) {
      final masala = shops
          .where(
            (s) =>
                s.id == 'masala-mart' ||
                s.name.toLowerCase().contains('masala'),
          )
          .firstOrNull;
      setState(() {
        _selectedShop = masala ?? shops.first;
        _isLoadingShop = false;
      });
    } else {
      setState(() {
        _isLoadingShop = false;
      });
    }
  }

  void _onShopChanged(Company shop) {
    setState(() {
      _selectedShop = shop;
    });
  }

  Future<void> _showCategoryFilterPicker(
    Company shop,
    List<HomeTrendingItem> entries,
  ) async {
    final categories = await repo.categories(companyId: shop.id).first;
    if (!mounted) return;
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No categories found for this shop.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<Category?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _CategorySelectionSheet(shop: shop, categories: categories);
      },
    );

    if (!mounted) return;
    if (selected != null) {
      _showAddItemSheet(
        context,
        shop,
        entries,
        initialCategoryId: selected.id.isEmpty ? null : selected.id,
      );
    }
  }

  void _showAddItemSheet(
    BuildContext context,
    Company shop,
    List<HomeTrendingItem> existing, {
    String? initialCategoryId,
  }) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _AddTrendingProductsSheet(
          shop: shop,
          existingEntries: existing,
          initialCategoryId: initialCategoryId,
          onItemAdded: (item) async {
            await repo.saveHomeTrendingItem(item);
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(
                  'Added "${item.productName ?? 'Product'}" to Trending Now.',
                ),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          },
          onMultipleItemsAdded: (items) async {
            for (final item in items) {
              await repo.saveHomeTrendingItem(item);
            }
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(
                  'Added ${items.length} ${items.length == 1 ? 'product' : 'products'} to Trending Now.',
                ),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteItem(HomeTrendingItem entry) async {
    final title = entry.isProduct
        ? (entry.productName ?? entry.productId ?? 'Product')
        : (entry.categoryName ?? entry.categoryId ?? 'Category');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from Trending?'),
        content: Text(
          'Remove "$title" from the Trending Now section on the home screen?',
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await repo.deleteHomeTrendingItem(entry.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed item from Trending Now.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showProductDetailsModal({
    required BuildContext context,
    required HomeTrendingItem entry,
    Product? product,
    Category? category,
    required VoidCallback onDelete,
    required ValueChanged<bool> onToggleActive,
  }) {
    final isProd = entry.isProduct;
    final title = isProd
        ? (product?.name ?? entry.productName ?? entry.productId ?? 'Product')
        : (category?.name ??
              entry.categoryName ??
              entry.categoryId ??
              'Category');
    final categoryName = isProd
        ? (entry.categoryName ??
              (product?.categoryId.isNotEmpty == true
                  ? product!.categoryId
                  : 'General'))
        : '';
    final resolvedImageUrl =
        (product != null &&
            product.images.isNotEmpty &&
            product.images.first.trim().isNotEmpty)
        ? product.images.first.trim()
        : ((entry.imageUrl != null && entry.imageUrl!.trim().isNotEmpty)
              ? entry.imageUrl!.trim()
              : '');
    final hasImg = resolvedImageUrl.isNotEmpty;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isProd
                            ? const Color(0xFFCCFBF1)
                            : const Color(0xFFE0E7FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isProd ? 'TRENDING PRODUCT' : 'TRENDING CATEGORY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isProd
                              ? const Color(0xFF0F766E)
                              : const Color(0xFF4338CA),
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (hasImg)
                  Center(
                    child: Container(
                      height: 120,
                      width: 120,
                      margin: const EdgeInsets.only(bottom: 14),
                      child: AppProductImage(
                        url: resolvedImageUrl,
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        borderRadius: BorderRadius.circular(12),
                        fallback: const Icon(
                          Icons.inventory_2_outlined,
                          size: 40,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                SelectableText(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E2229),
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                if (isProd && product != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Price',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          formatCurrency(product.price),
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF1E2229),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (categoryName.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Category',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            categoryName,
                            textAlign: TextAlign.end,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Stock Status',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          product.stockQty > 0
                              ? '${product.stockQty} in stock'
                              : 'Out of stock',
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: product.stockQty > 0
                                ? const Color(0xFF10B981)
                                : const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (product.sku.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'SKU',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            product.sku,
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1E2229),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Display Rank',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '#${entry.displayOrder + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Status',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          entry.isActive ? 'Active' : 'Hidden',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: entry.isActive
                                ? const Color(0xFF0F766E)
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Transform.scale(
                          scale: 0.85,
                          child: Switch.adaptive(
                            value: entry.isActive,
                            activeThumbColor: const Color(0xFFFF5247),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            onChanged: (val) {
                              Navigator.pop(ctx);
                              onToggleActive(val);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (isProd && product != null) ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Edit Product'),
                          onPressed: () {
                            Navigator.pop(ctx);
                            context.push(
                              AppRoutes.adminEditProductPath(product.id),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(color: Color(0xFFDC2626)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Remove from Trending'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          onDelete();
                        },
                      ),
                    ),
                  ],
                ),
                if (isProd)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Note: Updating this product in the admin editor will automatically remove it from Trending Now.',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingShop) {
      return const AdminShell(
        title: 'Home Trending Now',
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final shop = _selectedShop;
    if (shop == null) {
      return AdminShell(
        title: 'Home Trending Now',
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.storefront, size: 56, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('No authorized shop found.'),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _initShop, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return AdminShell(
      title: 'Home Trending Now',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: () => setState(() {}),
        ),
        IconButton(
          icon: const Icon(Icons.help_outline),
          tooltip: 'Help',
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Trending Now Configuration'),
                content: const Text(
                  'Configure trending items shown on the customer home screen in the "Trending Now" rail.\n\n'
                  '• Products link to Product Details.\n'
                  '• Reorder using the drag handle on the right.\n'
                  '• Toggle the switch to activate or hide an item.\n'
                  '• Tap any card to view complete product details.\n'
                  '• If no items are configured, the home screen falls back to the default trending product list.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Got it'),
                  ),
                ],
              ),
            );
          },
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFFF5247),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Products to Trending'),
        onPressed: () async {
          final entries = await repo.homeTrendingNow(shopId: shop.id).first;
          if (context.mounted) {
            _showAddItemSheet(context, shop, entries);
          }
        },
      ),
      child: Column(
        children: [
          ShopSelectorBar(selectedShop: shop, onShopChanged: _onShopChanged),
          Expanded(
            child: StreamBuilder<List<HomeTrendingItem>>(
              stream: repo.homeTrendingNow(shopId: shop.id),
              builder: (context, configSnap) {
                if (configSnap.connectionState == ConnectionState.waiting &&
                    !configSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final entries = configSnap.data ?? const <HomeTrendingItem>[];

                return StreamBuilder<List<Product>>(
                  stream: repo.products(companyId: shop.id),
                  builder: (context, productSnap) {
                    final products = productSnap.data ?? const <Product>[];
                    final productMap = {for (final p in products) p.id: p};

                    return StreamBuilder<List<Category>>(
                      stream: repo.categories(companyId: shop.id),
                      builder: (context, catSnap) {
                        final categories = catSnap.data ?? const <Category>[];
                        final catMap = {for (final c in categories) c.id: c};

                        if (entries.isEmpty) {
                          return _buildEmptyState(context, shop, entries);
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Responsive Header Bar
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isCompact = constraints.maxWidth < 650;
                                if (isCompact) {
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      6,
                                      16,
                                      6,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFFF7ED),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFFFED7AA,
                                                  ),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.local_fire_department,
                                                    size: 14,
                                                    color: Color(0xFFEA580C),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${entries.length} ${entries.length == 1 ? 'Trending Item' : 'Trending Items'}',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12.5,
                                                      color: Color(0xFF9A3412),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Expanded(
                                              child: Text(
                                                'Drag handle to reorder',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF64748B),
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: const Color(
                                                    0xFFFF5247,
                                                  ),
                                                  side: const BorderSide(
                                                    color: Color(0xFFFF5247),
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 8,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                ),
                                                icon: const Icon(
                                                  Icons.filter_list,
                                                  size: 16,
                                                ),
                                                label: const Text(
                                                  'By Category',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                onPressed: () =>
                                                    _showCategoryFilterPicker(
                                                      shop,
                                                      entries,
                                                    ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(
                                                    0xFFFF5247,
                                                  ),
                                                  foregroundColor: Colors.white,
                                                  elevation: 0,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 8,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                ),
                                                icon: const Icon(
                                                  Icons.add,
                                                  size: 17,
                                                ),
                                                label: const Text(
                                                  'Add Products',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                onPressed: () =>
                                                    _showAddItemSheet(
                                                      context,
                                                      shop,
                                                      entries,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                // Wider screens layout
                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    16,
                                    8,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF7ED),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFFED7AA),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.local_fire_department,
                                              size: 14,
                                              color: Color(0xFFEA580C),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${entries.length} ${entries.length == 1 ? 'Trending Item' : 'Trending Items'}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12.5,
                                                color: Color(0xFF9A3412),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      const Expanded(
                                        child: Text(
                                          '• Drag handle to reorder',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(
                                            0xFFFF5247,
                                          ),
                                          side: const BorderSide(
                                            color: Color(0xFFFF5247),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.filter_list,
                                          size: 16,
                                        ),
                                        label: const Text('Add by Category'),
                                        onPressed: () =>
                                            _showCategoryFilterPicker(
                                              shop,
                                              entries,
                                            ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFFFF5247,
                                          ),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(Icons.add, size: 18),
                                        label: const Text('Add Products'),
                                        onPressed: () => _showAddItemSheet(
                                          context,
                                          shop,
                                          entries,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 4),

                            // Selected Products List
                            Expanded(
                              child: ReorderableListView.builder(
                                buildDefaultDragHandles: false,
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  4,
                                  16,
                                  80,
                                ),
                                itemCount: entries.length,
                                onReorderItem: (oldIndex, target) async {
                                  final list = List<HomeTrendingItem>.from(
                                    entries,
                                  );
                                  final moved = list.removeAt(oldIndex);
                                  list.insert(target, moved);
                                  await repo.reorderHomeTrendingItems(list);
                                },
                                itemBuilder: (context, index) {
                                  final entry = entries[index];
                                  final isProd = entry.isProduct;
                                  final product = isProd
                                      ? productMap[entry.productId]
                                      : null;
                                  final category = !isProd
                                      ? catMap[entry.categoryId]
                                      : null;

                                  return _TrendingEntryCard(
                                    key: ValueKey(entry.id),
                                    index: index,
                                    entry: entry,
                                    product: product,
                                    category: category,
                                    onToggleActive: (val) async {
                                      await repo.saveHomeTrendingItem(
                                        entry.copyWith(isActive: val),
                                      );
                                    },
                                    onDelete: () => _deleteItem(entry),
                                    onTap: () => _showProductDetailsModal(
                                      context: context,
                                      entry: entry,
                                      product: product,
                                      category: category,
                                      onDelete: () => _deleteItem(entry),
                                      onToggleActive: (val) async {
                                        await repo.saveHomeTrendingItem(
                                          entry.copyWith(isActive: val),
                                        );
                                      },
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    Company shop,
    List<HomeTrendingItem> entries,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight > 0
                  ? constraints.maxHeight
                  : 300,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF7ED),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.local_fire_department_rounded,
                        size: 48,
                        color: Color(0xFFEA580C),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'No Trending Products for ${shop.name}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E2229),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Configure trending products displayed on the customer home screen. If none are configured, the home screen falls back to top products.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5247),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Products to Trending'),
                      onPressed: () =>
                          _showAddItemSheet(context, shop, entries),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Responsive Card for an entry in the Trending Now management list.
class _TrendingEntryCard extends StatelessWidget {
  final int index;
  final HomeTrendingItem entry;
  final Product? product;
  final Category? category;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _TrendingEntryCard({
    super.key,
    required this.index,
    required this.entry,
    this.product,
    this.category,
    required this.onToggleActive,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isProd = entry.isProduct;
    final title = isProd
        ? (product?.name ?? entry.productName ?? entry.productId ?? 'Product')
        : (category?.name ??
              entry.categoryName ??
              entry.categoryId ??
              'Category');

    final categoryName = isProd
        ? (entry.categoryName ??
              (product?.categoryId.isNotEmpty == true
                  ? product!.categoryId
                  : ''))
        : '';

    final priceStr = product != null
        ? formatCurrency(product!.price)
        : (entry.price != null ? formatCurrency(entry.price!) : null);

    final resolvedImageUrl =
        (product != null &&
            product!.images.isNotEmpty &&
            product!.images.first.trim().isNotEmpty)
        ? product!.images.first.trim()
        : ((entry.imageUrl != null && entry.imageUrl!.trim().isNotEmpty)
              ? entry.imageUrl!.trim()
              : '');
    final hasImg = resolvedImageUrl.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: entry.isActive ? Colors.white : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: entry.isActive
              ? const Color(0xFFE2E8F0)
              : const Color(0xFFCBD5E1),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.02),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Rank Number Pill
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      '#${index + 1}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Thumbnail Container
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isProd
                        ? const Color(0xFFF0FDFA)
                        : const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: isProd
                        ? (hasImg
                              ? AppProductImage(
                                  url: resolvedImageUrl,
                                  urls: product?.images,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  fallback: const Icon(
                                    Icons.inventory_2_outlined,
                                    color: Color(0xFF0D9488),
                                    size: 22,
                                  ),
                                )
                              : const Icon(
                                  Icons.inventory_2_outlined,
                                  color: Color(0xFF0D9488),
                                  size: 22,
                                ))
                        : (category != null &&
                                  (category!.iconUrl.startsWith('http://') ||
                                      category!.iconUrl.startsWith(
                                        'https://',
                                      ) ||
                                      category!.iconUrl.startsWith('assets/'))
                              ? AppProductImage(
                                  url: category!.iconUrl,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  fallback: const Icon(
                                    Icons.category_rounded,
                                    color: Color(0xFF6366F1),
                                    size: 22,
                                  ),
                                )
                              : (category != null &&
                                        category!.iconUrl.isNotEmpty &&
                                        category!.iconUrl.runes.length <= 4
                                    ? Center(
                                        child: Text(
                                          category!.iconUrl,
                                          style: const TextStyle(fontSize: 22),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.category_rounded,
                                        color: Color(0xFF6366F1),
                                        size: 22,
                                      ))),
                  ),
                ),
                const SizedBox(width: 10),

                // Expanded Middle Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Badge Row
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: isProd
                                  ? const Color(0xFFCCFBF1)
                                  : const Color(0xFFE0E7FF),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isProd ? 'PRODUCT' : 'CATEGORY',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: isProd
                                    ? const Color(0xFF0F766E)
                                    : const Color(0xFF4338CA),
                              ),
                            ),
                          ),
                          if (categoryName.isNotEmpty) ...[
                            const SizedBox(width: 5),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  categoryName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF4338CA),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (!entry.isActive) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: const Text(
                                'Hidden',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Product Name - wrapped across 2 lines for full visibility
                      Text(
                        title.isNotEmpty ? title : 'Unnamed Product',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          height: 1.25,
                          color: entry.isActive
                              ? const Color(0xFF1E2229)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 3),

                      // Subtitle Wrap: Price + Stock / SKU
                      Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (priceStr != null)
                            Text(
                              priceStr,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E2229),
                              ),
                            ),
                          if (isProd &&
                              product != null &&
                              product!.stockQty <= 0)
                            const Text(
                              'Out of stock',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFFDC2626),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          if (isProd && product?.sku.isNotEmpty == true)
                            Text(
                              'SKU: ${product!.sku}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF64748B),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),

                // Trailing actions: Switch on top, Delete + Reorder on bottom
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: 28,
                      child: Transform.scale(
                        scale: 0.8,
                        child: Switch.adaptive(
                          value: entry.isActive,
                          activeThumbColor: const Color(0xFFFF5247),
                          onChanged: onToggleActive,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Color(0xFFDC2626),
                            size: 19,
                          ),
                          tooltip: 'Remove',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          onPressed: onDelete,
                        ),
                        ReorderableDragStartListener(
                          index: index,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            child: const Icon(
                              Icons.drag_handle,
                              color: Color(0xFF94A3B8),
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper to match a product to a category via categoryId or category productList.
bool _productMatchesCategory(Product p, Category cat) {
  final catId = p.categoryId.trim();
  if (catId.isNotEmpty) {
    if (catId == cat.id ||
        catId.toLowerCase() == cat.id.toLowerCase() ||
        catId.toLowerCase() == cat.name.toLowerCase() ||
        catId.replaceAll(' ', '-').toLowerCase() == cat.id.toLowerCase() ||
        catId.replaceAll('-', ' ').toLowerCase() == cat.name.toLowerCase()) {
      return true;
    }
  }
  return cat.productList.contains(p.id);
}

/// Modal sheet allowing admin to pick a category to filter products by.
class _CategorySelectionSheet extends StatelessWidget {
  final Company shop;
  final List<Category> categories;

  const _CategorySelectionSheet({required this.shop, required this.categories});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.filter_list_rounded,
                    color: Color(0xFF4F46E5),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Category Filter',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E2229),
                        ),
                      ),
                      Text(
                        'Choose a category to browse and add products for ${shop.name}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.apps,
                        color: Color(0xFF475569),
                        size: 22,
                      ),
                    ),
                    title: const Text(
                      'All Categories',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF1E2229),
                      ),
                    ),
                    subtitle: const Text(
                      'Browse all products without a category filter',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Color(0xFF94A3B8),
                    ),
                    onTap: () => Navigator.pop(
                      context,
                      const Category(id: '', name: 'All Categories'),
                    ),
                  ),
                  const Divider(height: 1),
                  ...categories.map((cat) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                cat.iconUrl.isNotEmpty &&
                                        cat.iconUrl.runes.length <= 4
                                    ? cat.iconUrl
                                    : '📁',
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                          ),
                          title: Text(
                            cat.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Color(0xFF1E2229),
                            ),
                          ),
                          subtitle: Text(
                            cat.details.isNotEmpty
                                ? cat.details
                                : 'ID: ${cat.id}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF94A3B8),
                          ),
                          onTap: () => Navigator.pop(context, cat),
                        ),
                        const Divider(height: 1),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet allowing admin to filter products by category and search query,
/// then select single or multiple products to add to Trending Now.
class _AddTrendingProductsSheet extends StatefulWidget {
  final Company shop;
  final List<HomeTrendingItem> existingEntries;
  final String? initialCategoryId;
  final ValueChanged<HomeTrendingItem> onItemAdded;
  final ValueChanged<List<HomeTrendingItem>>? onMultipleItemsAdded;

  const _AddTrendingProductsSheet({
    required this.shop,
    required this.existingEntries,
    this.initialCategoryId,
    required this.onItemAdded,
    this.onMultipleItemsAdded,
  });

  @override
  State<_AddTrendingProductsSheet> createState() =>
      _AddTrendingProductsSheetState();
}

class _AddTrendingProductsSheetState extends State<_AddTrendingProductsSheet> {
  late String? _selectedCategoryId;
  String _searchQuery = '';
  final Set<String> _selectedProductIds = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _resolveCategoryName(
    Product p,
    List<Category> categories,
    Map<String, Category> catMap,
  ) {
    if (p.categoryId.isNotEmpty && catMap.containsKey(p.categoryId)) {
      return catMap[p.categoryId]!.name;
    }
    for (final cat in categories) {
      if (_productMatchesCategory(p, cat)) {
        return cat.name;
      }
    }
    return p.categoryId.isNotEmpty ? p.categoryId : 'General';
  }

  void _showSingleProductDetails(
    BuildContext context,
    Product p,
    String catName,
    bool isAlreadyAdded,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        catName.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4338CA),
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (p.imageUrl.trim().isNotEmpty)
                  Center(
                    child: Container(
                      height: 120,
                      width: 120,
                      margin: const EdgeInsets.only(bottom: 14),
                      child: AppProductImage(
                        url: p.imageUrl.trim(),
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        borderRadius: BorderRadius.circular(12),
                        fallback: const Icon(
                          Icons.inventory_2_outlined,
                          size: 40,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                SelectableText(
                  p.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E2229),
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Price',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        formatCurrency(p.price),
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF1E2229),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Stock',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        p.stockQty > 0
                            ? '${p.stockQty} in stock'
                            : 'Out of stock',
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: p.stockQty > 0
                              ? const Color(0xFF10B981)
                              : const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
                if (p.sku.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'SKU',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          p.sku,
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF1E2229),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                if (isAlreadyAdded)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'This product is already in Trending Now',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5247),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add This Product to Trending'),
                      onPressed: () {
                        Navigator.pop(ctx); // Close preview
                        Navigator.pop(context); // Close sheet
                        widget.onItemAdded(
                          HomeTrendingItem(
                            id: '${widget.shop.id}_product_${p.id}',
                            shopId: widget.shop.id,
                            shopName: widget.shop.name,
                            itemType: 'product',
                            productId: p.id,
                            productName: p.name,
                            categoryName: catName,
                            imageUrl: p.imageUrl,
                            price: p.price,
                            isActive: true,
                            displayOrder: widget.existingEntries.length,
                            createdAt: DateTime.now(),
                            createdBy: AuthSession.currentUser?.id ?? '',
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final existingProductIds = widget.existingEntries
        .where((e) => e.isProduct && e.productId != null)
        .map((e) => e.productId!)
        .toSet();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.88,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            MediaQuery.of(context).viewInsets.bottom + 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Sheet Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.local_fire_department,
                      color: Color(0xFFEA580C),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add Products to Trending',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E2229),
                          ),
                        ),
                        Text(
                          widget.shop.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Search Box
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search products by name or SKU...',
                  hintStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFFFF5247),
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val.trim().toLowerCase());
                },
              ),
              const SizedBox(height: 10),

              // Categories & Products Streams
              Expanded(
                child: StreamBuilder<List<Category>>(
                  stream: repo.categories(companyId: widget.shop.id),
                  builder: (context, catSnap) {
                    final categories = catSnap.data ?? const <Category>[];
                    final catMap = {for (final c in categories) c.id: c};

                    return StreamBuilder<List<Product>>(
                      stream: repo.products(companyId: widget.shop.id),
                      builder: (context, prodSnap) {
                        if (prodSnap.connectionState ==
                                ConnectionState.waiting &&
                            !prodSnap.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final allProducts = prodSnap.data ?? const <Product>[];

                        // Find currently active category
                        final selectedCategory = _selectedCategoryId != null
                            ? categories
                                  .where((c) => c.id == _selectedCategoryId)
                                  .firstOrNull
                            : null;

                        // Apply category filter
                        var filtered = selectedCategory != null
                            ? allProducts
                                  .where(
                                    (p) => _productMatchesCategory(
                                      p,
                                      selectedCategory,
                                    ),
                                  )
                                  .toList()
                            : allProducts;

                        // Apply search query filter
                        if (_searchQuery.isNotEmpty) {
                          filtered = filtered.where((p) {
                            return p.name.toLowerCase().contains(
                                  _searchQuery,
                                ) ||
                                p.sku.toLowerCase().contains(_searchQuery);
                          }).toList();
                        }

                        // Determine available unadded products in current filtered view
                        final availableInView = filtered
                            .where((p) => !existingProductIds.contains(p.id))
                            .toList();
                        final allAvailableSelected =
                            availableInView.isNotEmpty &&
                            availableInView.every(
                              (p) => _selectedProductIds.contains(p.id),
                            );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Horizontal Category Filter Chips
                            SizedBox(
                              height: 38,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ChoiceChip(
                                      label: Text(
                                        'All Categories (${allProducts.length})',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight:
                                              _selectedCategoryId == null
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: _selectedCategoryId == null
                                              ? const Color(0xFFEA580C)
                                              : const Color(0xFF475569),
                                        ),
                                      ),
                                      selected: _selectedCategoryId == null,
                                      selectedColor: const Color(0xFFFFF7ED),
                                      backgroundColor: const Color(0xFFF1F5F9),
                                      side: BorderSide(
                                        color: _selectedCategoryId == null
                                            ? const Color(0xFFEA580C)
                                            : Colors.transparent,
                                      ),
                                      onSelected: (val) {
                                        setState(() {
                                          _selectedCategoryId = null;
                                        });
                                      },
                                    ),
                                  ),
                                  ...categories.map((cat) {
                                    final count = allProducts
                                        .where(
                                          (p) =>
                                              _productMatchesCategory(p, cat),
                                        )
                                        .length;
                                    final isSelected =
                                        _selectedCategoryId == cat.id;

                                    return Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: ChoiceChip(
                                        label: Text(
                                          '${cat.name} ($count)',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: isSelected
                                                ? const Color(0xFFEA580C)
                                                : const Color(0xFF475569),
                                          ),
                                        ),
                                        selected: isSelected,
                                        selectedColor: const Color(0xFFFFF7ED),
                                        backgroundColor: const Color(
                                          0xFFF1F5F9,
                                        ),
                                        side: BorderSide(
                                          color: isSelected
                                              ? const Color(0xFFEA580C)
                                              : Colors.transparent,
                                        ),
                                        onSelected: (val) {
                                          setState(() {
                                            _selectedCategoryId = val
                                                ? cat.id
                                                : null;
                                          });
                                        },
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Active Filter Indicator Pill (when category is selected)
                            if (selectedCategory != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7ED),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFFED7AA),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.filter_alt,
                                      size: 15,
                                      color: Color(0xFFEA580C),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Filter: ${selectedCategory.name}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12.5,
                                          color: Color(0xFF9A3412),
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          _selectedCategoryId = null;
                                        });
                                      },
                                      child: const Text(
                                        'Clear Filter',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFEA580C),
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Subheader with count and Select All
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                                vertical: 4,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${filtered.length} products found',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                  if (availableInView.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          if (allAvailableSelected) {
                                            for (final p in availableInView) {
                                              _selectedProductIds.remove(p.id);
                                            }
                                          } else {
                                            for (final p in availableInView) {
                                              _selectedProductIds.add(p.id);
                                            }
                                          }
                                        });
                                      },
                                      child: Text(
                                        allAvailableSelected
                                            ? 'Deselect All'
                                            : 'Select All (${availableInView.length})',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFFF5247),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const Divider(height: 1),

                            // Product List
                            Expanded(
                              child: filtered.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.inventory_2_outlined,
                                              size: 40,
                                              color: Color(0xFF94A3B8),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              selectedCategory != null
                                                  ? 'No products found in "${selectedCategory.name}".'
                                                  : 'No products match your search.',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : ListView.separated(
                                      itemCount: filtered.length,
                                      separatorBuilder: (_, _) =>
                                          const SizedBox(height: 6),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      itemBuilder: (context, i) {
                                        final p = filtered[i];
                                        final isAlreadyAdded =
                                            existingProductIds.contains(p.id);
                                        final isSelected = _selectedProductIds
                                            .contains(p.id);
                                        final catName = _resolveCategoryName(
                                          p,
                                          categories,
                                          catMap,
                                        );

                                        return _AddProductSelectionCard(
                                          product: p,
                                          categoryName: catName,
                                          isAlreadyAdded: isAlreadyAdded,
                                          isSelected: isSelected,
                                          onToggleSelect: (val) {
                                            setState(() {
                                              if (val) {
                                                _selectedProductIds.add(p.id);
                                              } else {
                                                _selectedProductIds.remove(
                                                  p.id,
                                                );
                                              }
                                            });
                                          },
                                          onAddSingle: () {
                                            Navigator.pop(context);
                                            widget.onItemAdded(
                                              HomeTrendingItem(
                                                id: '${widget.shop.id}_product_${p.id}',
                                                shopId: widget.shop.id,
                                                shopName: widget.shop.name,
                                                itemType: 'product',
                                                productId: p.id,
                                                productName: p.name,
                                                categoryName: catName,
                                                imageUrl: p.imageUrl,
                                                price: p.price,
                                                isActive: true,
                                                displayOrder: widget
                                                    .existingEntries
                                                    .length,
                                                createdAt: DateTime.now(),
                                                createdBy:
                                                    AuthSession
                                                        .currentUser
                                                        ?.id ??
                                                    '',
                                              ),
                                            );
                                          },
                                          onShowDetails: () {
                                            _showSingleProductDetails(
                                              context,
                                              p,
                                              catName,
                                              isAlreadyAdded,
                                            );
                                          },
                                        );
                                      },
                                    ),
                            ),

                            // Sticky Bottom Action Bar for Bulk Selection
                            if (_selectedProductIds.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF5247),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(Icons.add_task, size: 20),
                                  label: Flexible(
                                    child: Text(
                                      'Add ${_selectedProductIds.length} Selected ${_selectedProductIds.length == 1 ? 'Product' : 'Products'} to Trending',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  onPressed: () {
                                    final items = <HomeTrendingItem>[];
                                    int offset = 0;
                                    for (final pId in _selectedProductIds) {
                                      final p = allProducts
                                          .where((prod) => prod.id == pId)
                                          .firstOrNull;
                                      if (p == null) continue;
                                      final catName = _resolveCategoryName(
                                        p,
                                        categories,
                                        catMap,
                                      );
                                      items.add(
                                        HomeTrendingItem(
                                          id: '${widget.shop.id}_product_${p.id}',
                                          shopId: widget.shop.id,
                                          shopName: widget.shop.name,
                                          itemType: 'product',
                                          productId: p.id,
                                          productName: p.name,
                                          categoryName: catName,
                                          imageUrl: p.imageUrl,
                                          price: p.price,
                                          isActive: true,
                                          displayOrder:
                                              widget.existingEntries.length +
                                              offset,
                                          createdAt: DateTime.now(),
                                          createdBy:
                                              AuthSession.currentUser?.id ?? '',
                                        ),
                                      );
                                      offset++;
                                    }

                                    Navigator.pop(context);
                                    if (widget.onMultipleItemsAdded != null) {
                                      widget.onMultipleItemsAdded!(items);
                                    } else {
                                      for (final item in items) {
                                        widget.onItemAdded(item);
                                      }
                                    }
                                  },
                                ),
                              ),
                            ],
                          ],
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
}

/// Compact, responsive product card for selection in the Add Products sheet.
class _AddProductSelectionCard extends StatelessWidget {
  final Product product;
  final String categoryName;
  final bool isAlreadyAdded;
  final bool isSelected;
  final ValueChanged<bool> onToggleSelect;
  final VoidCallback onAddSingle;
  final VoidCallback onShowDetails;

  const _AddProductSelectionCard({
    required this.product,
    required this.categoryName,
    required this.isAlreadyAdded,
    required this.isSelected,
    required this.onToggleSelect,
    required this.onAddSingle,
    required this.onShowDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFFF7ED) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected
              ? const Color(0xFFFF5247)
              : (isAlreadyAdded
                    ? const Color(0xFFE2E8F0)
                    : const Color(0xFFE2E8F0)),
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.02),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isAlreadyAdded
              ? onShowDetails
              : () => onToggleSelect(!isSelected),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Selection Checkbox / Added Indicator
                SizedBox(
                  width: 26,
                  height: 26,
                  child: isAlreadyAdded
                      ? const Icon(
                          Icons.check_circle,
                          size: 20,
                          color: Color(0xFF94A3B8),
                        )
                      : Checkbox(
                          value: isSelected,
                          onChanged: (val) => onToggleSelect(val == true),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          activeColor: const Color(0xFFFF5247),
                        ),
                ),
                const SizedBox(width: 8),

                // Product Thumbnail
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: AppProductImage.product(
                    product: product,
                    width: 46,
                    height: 46,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(8),
                    fallback: const Icon(
                      Icons.inventory_2_outlined,
                      size: 20,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Product Details (Expanded)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        product.name.isNotEmpty
                            ? product.name
                            : 'Unnamed Product',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                          color: isAlreadyAdded
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF1E2229),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (categoryName.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                categoryName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4338CA),
                                ),
                              ),
                            ),
                          Text(
                            formatCurrency(product.price),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E2229),
                            ),
                          ),
                          if (product.stockQty <= 0)
                            const Text(
                              'Out of stock',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),

                // Trailing Action Button
                if (isAlreadyAdded)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Text(
                      'Added',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  )
                else
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF5247),
                      side: const BorderSide(color: Color(0xFFFF5247)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: onAddSingle,
                    child: const Text(
                      '+ Add',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
