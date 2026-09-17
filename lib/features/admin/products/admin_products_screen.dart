import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes/app_router.dart';
import '../../../core/models/product.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/modern_card.dart';
import '../admin_shell.dart';

/// Product management (Section 17.1): multi-image upload, variant matrix, SKU
/// generator, inventory alerts, price indexing.
class AdminProductsScreen extends StatelessWidget {
  const AdminProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final adminCompanyId = AuthSession.currentUser?.companyId ?? '';

    return AdminShell(
      title: 'Products',
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: 'Add Product',
          onPressed: () => context.push(AppRoutes.adminAddProduct),
        ),
      ],
      child: StreamBuilder<List<Product>>(
        stream: repo.products(companyId: adminCompanyId),
        builder: (context, snap) {
          final list = snap.data ?? const <Product>[];
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No products found',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Product'),
                    onPressed: () => context.push(AppRoutes.adminAddProduct),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _productTile(context, list[i]),
          );
        },
      ),
    );
  }

  Widget _productTile(BuildContext context, Product p) {
    final lowStock = p.stockQty < 20;
    final hasImage = p.images.isNotEmpty && p.images.first.isNotEmpty;
    return ModernCard(
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: hasImage
                ? Image.network(
                    p.images.first,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const CircleAvatar(child: Icon(Icons.image)),
                  )
                : const CircleAvatar(child: Icon(Icons.image)),
          ),
          title: Text(
            p.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Row(
            children: [
              Text(
                formatCurrency(p.price),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: p.isDiscounted ? Colors.green.shade700 : null,
                ),
              ),
              if (p.isDiscounted) ...[
                const SizedBox(width: 6),
                Text(
                  formatCurrency(p.amount),
                  style: const TextStyle(
                    decoration: TextDecoration.lineThrough,
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
              if (p.variants.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  '• ${p.variants.length} variants',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${p.stockQty} ${p.unitType}'),
                  if (lowStock)
                    const Text(
                      'LOW STOCK',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'Edit Product',
                onPressed: () => context.push(
                  AppRoutes.adminEditProductPath(p.id),
                  extra: p,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: Colors.redAccent,
                ),
                tooltip: 'Delete Product',
                onPressed: () => _confirmDelete(context, p),
              ),
            ],
          ),
          onTap: () =>
              context.push(AppRoutes.adminEditProductPath(p.id), extra: p),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Product p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${p.name}"?'),
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
    if (confirmed == true && context.mounted) {
      await repo.deleteProduct(p.id);
    }
  }
}
