import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes/app_router.dart';
import '../../../core/domain/category_tree.dart';
import '../../../core/models/category.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/widgets/copyable_id_badge.dart';
import '../../../core/widgets/modern_card.dart';
import '../admin_shell.dart';

/// Admin category manager with a real hierarchy view.
///
/// The previous version rendered a flat list: sub-categories were visually
/// indistinguishable from roots, "N products" only counted direct assignments
/// and deleting a parent silently orphaned its children. Now:
///  * the list is a collapsible tree built by [CategoryTree] (cycles and
///    missing parents are repaired instead of hanging),
///  * counts include descendants,
///  * delete explains exactly what will be re-parented.
class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  final _searchCtrl = TextEditingController();

  /// Nodes the admin collapsed; everything else starts expanded.
  final Set<String> _collapsed = <String>{};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _companyId => AuthSession.currentUser?.companyId ?? '';

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      showBack: true,
      backRoute: AppRoutes.admin,
      title: 'Categories',
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: 'Add Category',
          onPressed: () => context.push(AppRoutes.adminAddCategory),
        ),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              key: const Key('category-search-field'),
              controller: _searchCtrl,
              decoration: InputDecoration(
                labelText: 'Search categories',
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
          Expanded(
            child: StreamBuilder<List<Category>>(
              stream: repo.categories(companyId: _companyId),
              builder: (context, snap) {
                final categories = snap.data ?? const <Category>[];

                if (snap.connectionState == ConnectionState.waiting &&
                    categories.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (categories.isEmpty) {
                  return _EmptyCategories(
                    onAdd: () => context.push(AppRoutes.adminAddCategory),
                  );
                }

                final query = _searchCtrl.text.trim().toLowerCase();
                final tree = CategoryTree.build(categories);

                if (query.isNotEmpty) {
                  // Flat, filtered view: a tree would hide matches.
                  final matches = tree
                      .flatten()
                      .where((node) => node.name.toLowerCase().contains(query))
                      .toList();
                  if (matches.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: Text('No categories match this search'),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: matches.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _CategoryTile(
                      node: matches[i],
                      indent: 0,
                      pathLabel: CategoryHierarchy.pathLabel(
                        matches[i].id,
                        categories,
                      ),
                      onEdit: () => context.push(
                        AppRoutes.adminEditCategoryPath(matches[i].id),
                        extra: matches[i].category,
                      ),
                      onDelete: () =>
                          _confirmDelete(matches[i].category, categories),
                    ),
                  );
                }

                final expandedIds = tree
                    .flatten()
                    .where(
                      (node) =>
                          node.children.isNotEmpty &&
                          !_collapsed.contains(node.id),
                    )
                    .map((node) => node.id)
                    .toSet();
                final rows = tree.visibleRows(expandedIds);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    _SummaryRow(
                      total: categories.length,
                      roots: tree.roots.length,
                      products: tree.roots.fold<int>(
                        0,
                        (sum, node) => sum + node.totalProductCount,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final node in rows) ...[
                      _CategoryTile(
                        node: node,
                        indent: node.depth * 20.0,
                        collapsed: _collapsed.contains(node.id),
                        onToggle: node.isLeaf
                            ? null
                            : () => setState(() {
                                if (_collapsed.contains(node.id)) {
                                  _collapsed.remove(node.id);
                                } else {
                                  _collapsed.add(node.id);
                                }
                              }),
                        pathLabel: node.depth == 0
                            ? ''
                            : CategoryHierarchy.pathLabel(
                                node.category.parentId ?? node.id,
                                categories,
                              ),
                        onEdit: () => context.push(
                          AppRoutes.adminEditCategoryPath(node.id),
                          extra: node.category,
                        ),
                        onDelete: () =>
                            _confirmDelete(node.category, categories),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Category category, List<Category> all) async {
    final children = all
        .where((c) => c.parentId == category.id)
        .toList(growable: false);
    final parentName = category.parentId == null
        ? null
        : all
              .where((c) => c.id == category.parentId)
              .map((c) => c.name)
              .firstOrNull;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Delete "${category.name}"?'),
            const SizedBox(height: 10),
            if (category.productList.isNotEmpty)
              Text(
                '• ${category.productList.length} assigned product(s) will move '
                '${parentName == null ? 'to "Uncategorised"' : 'to "$parentName"'}',
              ),
            if (children.isNotEmpty)
              Text(
                '• ${children.length} sub-category(ies) will move up one level',
              ),
            if (category.productList.isEmpty && children.isEmpty)
              const Text('This category is empty.'),
          ],
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

    if (confirmed != true || !mounted) return;

    try {
      await repo.deleteCategory(category.id, companyId: category.companyId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Category "${category.name}" deleted.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete category: $e')));
    }
  }
}

class _SummaryRow extends StatelessWidget {
  final int total;
  final int roots;
  final int products;

  const _SummaryRow({
    required this.total,
    required this.roots,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Stat(label: 'Categories', value: '$total'),
        const SizedBox(width: 8),
        _Stat(label: 'Top level', value: '$roots'),
        const SizedBox(width: 8),
        _Stat(label: 'Assigned products', value: '$products'),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ModernCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final CategoryNode node;
  final double indent;
  final bool collapsed;
  final VoidCallback? onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String pathLabel;

  const _CategoryTile({
    required this.node,
    required this.indent,
    required this.onEdit,
    required this.onDelete,
    this.collapsed = false,
    this.onToggle,
    this.pathLabel = '',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: ModernCard(
        key: Key('category-tile-${node.id}'),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onToggle != null)
                IconButton(
                  icon: Icon(
                    collapsed
                        ? Icons.keyboard_arrow_right
                        : Icons.keyboard_arrow_down,
                    size: 20,
                  ),
                  tooltip: collapsed ? 'Expand' : 'Collapse',
                  onPressed: onToggle,
                )
              else
                const SizedBox(width: 24),
              const SizedBox(width: 4),
              _CategoryGlyph(category: node.category),
            ],
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  node.category.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  node.children.isEmpty
                      ? '${node.directProductCount} products'
                      : '${node.totalProductCount} products',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
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
                '${node.category.type.isEmpty ? 'Uncategorised type' : node.category.type}'
                '${node.category.companyId.isNotEmpty ? ' • Store' : ' • Global'}'
                '${node.children.isNotEmpty ? ' • ${node.descendantCount} sub' : ''}',
                style: const TextStyle(fontSize: 12),
              ),
              if (pathLabel.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Under: $pathLabel',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              CopyableIdBadge(
                key: Key('category-id-${node.id}'),
                id: node.id,
                label: 'Category',
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'Edit Category',
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: Colors.redAccent,
                ),
                tooltip: 'Delete Category',
                onPressed: onDelete,
              ),
            ],
          ),
          onTap: onEdit,
        ),
      ),
    );
  }
}

class _CategoryGlyph extends StatelessWidget {
  final Category category;

  const _CategoryGlyph({required this.category});

  @override
  Widget build(BuildContext context) {
    final icon = category.iconUrl.trim();
    if (category.hasImageIcon) {
      return Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200, width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Image.network(
            icon,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
            errorBuilder: (_, _, _) => Container(
              color: Colors.grey.shade100,
              child: const Center(
                child: Icon(
                  Icons.category_outlined,
                  size: 22,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          icon.isNotEmpty ? icon : '📁',
          style: const TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}

class _EmptyCategories extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyCategories({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.category_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No categories found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your first category and assign products to organize your store.',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Category'),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}
