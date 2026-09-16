import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes/app_router.dart';
import '../../../core/models/category.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/widgets/modern_card.dart';
import '../admin_shell.dart';

/// Admin Categories management screen with nested tree hierarchy, product assignment
/// counts, create, edit, and delete support.
class AdminCategoriesScreen extends StatelessWidget {
  const AdminCategoriesScreen({super.key});

  Future<void> _confirmDelete(BuildContext context, Category cat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
          'Are you sure you want to delete "${cat.name}"? '
          '${cat.productList.isNotEmpty ? "This category has ${cat.productList.length} assigned product(s)." : ""}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await repo.deleteCategory(cat.id, companyId: cat.companyId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Category "${cat.name}" deleted.'),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete category: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Widget _buildIcon(String iconUrl) {
    if (iconUrl.startsWith('http://') || iconUrl.startsWith('https://')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          iconUrl,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const Text('🛍️', style: TextStyle(fontSize: 24)),
        ),
      );
    }
    return Text(
      iconUrl.isNotEmpty ? iconUrl : '🛍️',
      style: const TextStyle(fontSize: 24),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminCompanyId = AuthSession.currentUser?.companyId ?? '';

    return AdminShell(
      title: 'Categories',
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: 'Add Category',
          onPressed: () => context.push(AppRoutes.adminAddCategory),
        ),
      ],
      child: StreamBuilder<List<Category>>(
        stream: repo.categories(companyId: adminCompanyId),
        builder: (context, snap) {
          final list = snap.data ?? const <Category>[];
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.category_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No categories found',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create your first category and assign products to organize your store.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Category'),
                    onPressed: () => context.push(AppRoutes.adminAddCategory),
                  ),
                ],
              ),
            );
          }

          // Build a map for resolving parent category names
          final categoryMap = {for (final c in list) c.id: c.name};

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final cat = list[i];
              final parentName = cat.parentId != null
                  ? categoryMap[cat.parentId]
                  : null;

              return ModernCard(
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: _buildIcon(cat.iconUrl),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            cat.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Product Count Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${cat.productList.length} products',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          '${cat.type}${cat.companyId.isNotEmpty ? " • Store (${cat.companyId})" : " • Global"}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (parentName != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(
                                Icons.subdirectory_arrow_right,
                                size: 14,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Parent: $parentName',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          tooltip: 'Edit Category',
                          onPressed: () => context.push(
                            AppRoutes.adminEditCategoryPath(cat.id),
                            extra: cat,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: Colors.redAccent,
                          ),
                          tooltip: 'Delete Category',
                          onPressed: () => _confirmDelete(context, cat),
                        ),
                      ],
                    ),
                    onTap: () => context.push(
                      AppRoutes.adminEditCategoryPath(cat.id),
                      extra: cat,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
