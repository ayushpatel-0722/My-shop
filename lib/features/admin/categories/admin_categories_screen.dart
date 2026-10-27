import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myshop/app/l10n/app_localizations.dart';
import 'package:myshop/core/services/admin_company_name.dart';

import '../../../app/routes/app_router.dart';
import '../../../core/domain/category_tree.dart';
import '../../../core/models/category.dart';
import '../../../core/models/product.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/services/qr_deep_link_service.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../core/widgets/copyable_id_badge.dart';
import '../../../core/widgets/modern_card.dart';
import '../../../core/widgets/modern_shimmer.dart';
import '../admin_shell.dart';
import '../qr/widgets/entity_qr_dialog.dart';

/// Admin category manager with a real hierarchy view.
///
/// The previous version rendered a flat list: sub-categories were visually
/// indistinguishable from roots, "N products" only counted direct assignments
/// and deleting a parent silently orphaned its children. Now:
///  * the list is a collapsible tree built by [CategoryTree] (cycles and
///    missing parents are repaired instead of hanging),
///  * counts include descendants,
///  * delete explains exactly what will be re-parented.
/// "1 product" / "2 products" — never "1 products".
String _plural(int n, String one, String many) => '$n ${n == 1 ? one : many}';

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  final _searchCtrl = TextEditingController();

  /// Nodes the admin collapsed; everything else starts expanded.
  final Set<String> _collapsed = <String>{};

  /// Manual ordering mode (drag to set the sibling order).
  bool _reorderMode = false;

  /// Parent whose children are being reordered ('' = top level).
  String _reorderParentId = '';

  /// Optimistic sortOrder overrides applied until Firestore confirms.
  final Map<String, int> _pendingSortOrders = <String, int>{};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _companyId => AuthSession.currentUser?.companyId ?? '';

  void _showQrForCategory(Category cat) {
    final effectiveShopId = cat.companyId.isNotEmpty
        ? cat.companyId
        : (_companyId.isNotEmpty ? _companyId : 'masala-mart');
    showEntityQrDialog(
      context: context,
      type: QrEntityType.category,
      title: cat.name,
      shopId: effectiveShopId,
      shopName: AdminCompanyName.instance.displayName(
        AuthSession.currentUser,
        fallback: effectiveShopId,
      ),
      categoryId: cat.id,
      subtitle: 'Category ID: ${cat.id} · Shop: $effectiveShopId',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      showBack: true,
      backRoute: AppRoutes.admin,
      title: AppLocalizations.of(context).categories,
      actions: [
        IconButton(
          key: const Key('category-reorder-toggle'),
          icon: Icon(_reorderMode ? Icons.playlist_add_check : Icons.swap_vert),
          tooltip: _reorderMode
              ? AppLocalizations.of(context).doneReordering
              : AppLocalizations.of(context).reorder,
          onPressed: _toggleReorder,
        ),
        IconButton(
          key: const Key('category-backfill-order'),
          icon: const Icon(Icons.sort),
          tooltip: AppLocalizations.of(
            context,
          ).backfillOrderingForOldCategories,
          onPressed: () => _backfillOrder(),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: AppLocalizations.of(context).addCategory,
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
                labelText: AppLocalizations.of(context).searchCategories,
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
          if (_searchCtrl.text.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  AppLocalizations.of(context).clearSearchToReorder,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: repo.products(companyId: _companyId),
              builder: (context, productSnap) {
                final productImages = <String, String>{
                  for (final p in productSnap.data ?? const <Product>[])
                    if (p.images.isNotEmpty) p.id: p.images.first,
                };
                String? coverFor(Category c) {
                  for (final id in c.productList) {
                    final url = productImages[id];
                    if (url != null) return url;
                  }
                  return null;
                }

                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: StreamBuilder<List<Category>>(
                      stream: repo.categories(companyId: _companyId),
                      builder: (context, snap) {
                        final categories = snap.data ?? const <Category>[];

                        if (snap.connectionState == ConnectionState.waiting &&
                            categories.isEmpty) {
                          return ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: 5,
                            itemBuilder: (_, _) => const M3ListTileSkeleton(),
                          );
                        }
                        if (categories.isEmpty) {
                          return _EmptyCategories(
                            onAdd: () =>
                                context.push(AppRoutes.adminAddCategory),
                          );
                        }

                        final query = _searchCtrl.text.trim().toLowerCase();
                        final effective = _applyPending(categories);
                        final tree = CategoryTree.build(effective);

                        if (_reorderMode && query.isEmpty) {
                          return _CategoryReorderView(
                            tree: tree,
                            parentId: _reorderParentId,
                            categories: effective,
                            onEnterLevel: (id) =>
                                setState(() => _reorderParentId = id),
                            onExitLevel: (id) => setState(() {
                              final node = tree
                                  .flatten()
                                  .where((n) => n.id == id)
                                  .firstOrNull;
                              _reorderParentId = node?.category.parentId ?? '';
                            }),
                            onReorder: _reorderLevel,
                            coverFor: coverFor,
                          );
                        }

                        if (query.isNotEmpty) {
                          // Flat, filtered view: a tree would hide matches.
                          final matches = tree
                              .flatten()
                              .where(
                                (node) =>
                                    node.name.toLowerCase().contains(query),
                              )
                              .toList();
                          if (matches.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(28),
                                child: Text(
                                  AppLocalizations.of(
                                    context,
                                  ).noCategoriesMatchThisSearch,
                                ),
                              ),
                            );
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: matches.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) => _CategoryTile(
                              node: matches[i],
                              coverUrl: coverFor(matches[i].category),
                              indent: 0,
                              pathLabel: CategoryHierarchy.pathLabel(
                                matches[i].id,
                                categories,
                              ),
                              onEdit: () => context.push(
                                AppRoutes.adminEditCategoryPath(matches[i].id),
                                extra: matches[i].category,
                              ),
                              onQr: () =>
                                  _showQrForCategory(matches[i].category),
                              onDelete: () => _confirmDelete(
                                matches[i].category,
                                categories,
                              ),
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
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                key: const Key('category-arrange-button'),
                                onPressed: categories.length > 1
                                    ? _toggleReorder
                                    : null,
                                icon: const Icon(Icons.swap_vert, size: 18),
                                label: Text(
                                  AppLocalizations.of(context).reorder,
                                ),
                              ),
                            ),
                            for (final node in rows) ...[
                              _CategoryTile(
                                node: node,
                                coverUrl: coverFor(node.category),
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
                                onQr: () => _showQrForCategory(node.category),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Applies optimistic sortOrder overrides until Firestore confirms them.
  List<Category> _applyPending(List<Category> categories) {
    if (_pendingSortOrders.isEmpty) return categories;
    return [
      for (final c in categories)
        _pendingSortOrders[c.id] != null
            ? c.copyWith(sortOrder: _pendingSortOrders[c.id])
            : c,
    ];
  }

  /// Enters or leaves manual ordering (disabled while a search is active).
  void _toggleReorder() {
    if (_searchCtrl.text.trim().isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).clearSearchToReorder),
        ),
      );
      return;
    }
    setState(() {
      _reorderMode = !_reorderMode;
      _reorderParentId = '';
    });
  }

  /// Saves a new sibling order (0, 1, 2, …) after an optimistic update.
  Future<void> _reorderLevel(List<Category> orderedSiblings) async {
    final previous = Map<String, int>.from(_pendingSortOrders);
    setState(() {
      for (var i = 0; i < orderedSiblings.length; i++) {
        _pendingSortOrders[orderedSiblings[i].id] = i;
      }
    });
    try {
      // Pass the siblings untouched: each still carries its *current*
      // sortOrder, which is how the repository finds the ones that changed.
      await repo.reorderCategories(orderedSiblings);
      if (!mounted) return;
      setState(() {
        for (final c in orderedSiblings) {
          _pendingSortOrders.remove(c.id);
        }
      });
    } catch (e) {
      // Roll back to the previous order and explain.
      if (!mounted) return;
      setState(() {
        _pendingSortOrders
          ..clear()
          ..addAll(previous);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).couldNotSaveTheNewOrder('$e'),
          ),
        ),
      );
    }
  }

  /// One-time backfill of `sortOrder` for categories created before ordering
  /// existed. Safe to run again: already ordered groups are left untouched.
  Future<void> _backfillOrder() async {
    try {
      await repo.backfillCategorySortOrder(companyId: _companyId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).categoryOrderingBackfilled,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).backfillFailed('$e')),
        ),
      );
    }
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
        title: Text(AppLocalizations.of(context).deleteCategory),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context).delete2(category.name)),
            const SizedBox(height: 10),
            if (category.productList.isNotEmpty)
              Text(
                AppLocalizations.of(context).willMove2(
                  _plural(
                    category.productList.length,
                    AppLocalizations.of(context).assignedProduct,
                    AppLocalizations.of(context).assignedProducts,
                  ),
                  parentName == null
                      ? AppLocalizations.of(context).toUncategorised
                      : AppLocalizations.of(context).to(parentName),
                ),
              ),
            if (children.isNotEmpty)
              Text(
                AppLocalizations.of(context).willMoveUpOneLevel(
                  _plural(
                    children.length,
                    AppLocalizations.of(context).subCategory,
                    AppLocalizations.of(context).subCategories,
                  ),
                ),
              ),
            if (category.productList.isEmpty && children.isEmpty)
              Text(AppLocalizations.of(context).thisCategoryIsEmpty),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(AppLocalizations.of(context).delete),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await repo.deleteCategory(category.id, companyId: category.companyId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).categoryDeleted(category.name),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).failedToDeleteCategory('$e'),
          ),
        ),
      );
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
        _Stat(label: AppLocalizations.of(context).categories, value: '$total'),
        const SizedBox(width: 8),
        _Stat(label: AppLocalizations.of(context).topLevel, value: '$roots'),
        const SizedBox(width: 8),
        _Stat(
          label: AppLocalizations.of(context).assignedProducts2,
          value: '$products',
        ),
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
    final isMobile = context.isMobile;
    return Expanded(
      child: ModernCard(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 14,
          vertical: isMobile ? 10 : 14,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: isMobile ? 16 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: isMobile ? 10.5 : 13,
                color: Colors.grey,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
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
  final VoidCallback onQr;
  final String pathLabel;

  /// Photo of the category's first product that has an image (optional).
  final String? coverUrl;

  const _CategoryTile({
    required this.node,
    required this.indent,
    required this.onEdit,
    required this.onDelete,
    required this.onQr,
    this.collapsed = false,
    this.onToggle,
    this.pathLabel = '',
    this.coverUrl,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIndent = context.isMobile
        ? (indent * 0.6).clamp(0.0, 36.0)
        : indent;

    return Padding(
      padding: EdgeInsets.only(left: effectiveIndent),
      child: context.isMobile
          ? _buildMobileCard(context)
          : _buildDesktopCard(context),
    );
  }

  Widget _buildMobileCard(BuildContext context) {
    final theme = Theme.of(context);

    return ModernCard(
      key: Key('category-tile-${node.id}'),
      padding: const EdgeInsets.all(12),
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (onToggle != null) ...[
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  icon: Icon(
                    collapsed
                        ? Icons.keyboard_arrow_right
                        : Icons.keyboard_arrow_down,
                    size: 20,
                  ),
                  tooltip: collapsed
                      ? AppLocalizations.of(context).expand
                      : AppLocalizations.of(context).collapse,
                  onPressed: onToggle,
                ),
                const SizedBox(width: 4),
              ],
              _CategoryGlyph(category: node.category, coverUrl: coverUrl),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            node.category.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _plural(
                              node.children.isEmpty
                                  ? node.directProductCount
                                  : node.totalProductCount,
                              'product',
                              'products',
                            ),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context).str(
                        node.category.type.isEmpty
                            ? AppLocalizations.of(context).uncategorisedType
                            : node.category.type,
                        node.category.companyId.isNotEmpty
                            ? AppLocalizations.of(context).store
                            : AppLocalizations.of(context).global,
                        node.children.isNotEmpty
                            ? AppLocalizations.of(
                                context,
                              ).sub('${node.descendantCount}')
                            : '',
                      ),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.65,
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (pathLabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        AppLocalizations.of(context).under(pathLabel),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(
            height: 1,
            thickness: 0.5,
            color: theme.dividerColor.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: CopyableIdBadge(
                  key: Key('category-id-${node.id}'),
                  id: node.id,
                  label: AppLocalizations.of(context).category,
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
                    tooltip: AppLocalizations.of(context).editCategory,
                    onPressed: onEdit,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    iconSize: 20,
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    tooltip: AppLocalizations.of(context).deleteCategory,
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

  Widget _buildDesktopCard(BuildContext context) {
    final theme = Theme.of(context);

    return ModernCard(
      key: Key('category-tile-${node.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      onTap: onEdit,
      child: Row(
        children: [
          if (onToggle != null)
            IconButton(
              icon: Icon(
                collapsed
                    ? Icons.keyboard_arrow_right
                    : Icons.keyboard_arrow_down,
                size: 22,
              ),
              tooltip: collapsed
                  ? AppLocalizations.of(context).expand
                  : AppLocalizations.of(context).collapse,
              onPressed: onToggle,
            )
          else
            const SizedBox(width: 40),
          const SizedBox(width: 4),
          _CategoryGlyph(category: node.category, coverUrl: coverUrl, size: 64),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        node.category.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _plural(
                          node.children.isEmpty
                              ? node.directProductCount
                              : node.totalProductCount,
                          'product',
                          'products',
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  AppLocalizations.of(context).str(
                    node.category.type.isEmpty
                        ? AppLocalizations.of(context).uncategorisedType
                        : node.category.type,
                    node.category.companyId.isNotEmpty
                        ? AppLocalizations.of(context).store
                        : AppLocalizations.of(context).global,
                    node.children.isNotEmpty
                        ? AppLocalizations.of(
                            context,
                          ).sub('${node.descendantCount}')
                        : '',
                  ),
                  style: TextStyle(
                    fontSize: 13.5,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (node.category.details.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    node.category.details.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.85,
                      ),
                    ),
                  ),
                ],
                if (pathLabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    AppLocalizations.of(context).under(pathLabel),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                CopyableIdBadge(
                  key: Key('category-id-${node.id}'),
                  id: node.id,
                  label: AppLocalizations.of(context).category,
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          IconButton(
            icon: const Icon(Icons.qr_code_2_rounded, size: 22),
            tooltip: 'QR Code & Share Link',
            onPressed: onQr,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 22),
            tooltip: AppLocalizations.of(context).editCategory,
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              size: 22,
              color: Colors.redAccent,
            ),
            tooltip: AppLocalizations.of(context).deleteCategory,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _CategoryGlyph extends StatelessWidget {
  final Category category;

  /// Product photo used when the category has no image icon of its own.
  final String? coverUrl;
  final double size;

  const _CategoryGlyph({required this.category, this.coverUrl, this.size = 46});

  @override
  Widget build(BuildContext context) {
    final icon = category.iconUrl.trim();
    final image = category.hasImageIcon
        ? icon
        : ((coverUrl ?? '').isNotEmpty ? coverUrl! : '');
    final radius = size * 0.24;
    if (image.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.grey.shade200, width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius - 1),
          child: Image.network(
            image,
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
              child: Center(
                child: Icon(
                  Icons.category_outlined,
                  size: size * 0.48,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          icon.isNotEmpty ? icon : '\u{1F4C1}',
          style: TextStyle(fontSize: size * 0.48),
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
          Text(
            AppLocalizations.of(context).noCategoriesFound,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(
              context,
            ).createYourFirstCategoryAndAssignProductsToOrganizeYourStore,
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: Text(AppLocalizations.of(context).addCategory),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

/// Level-scoped drag-to-reorder view of one sibling list.
///
/// The admin picks the level (top-level, or inside a parent via "Open"), drags
/// the ≡ handles and the new order is saved as `sortOrder` 0, 1, 2, … — the
/// same order customers see. While reordering, edit/delete stay out of the
/// way; a breadcrumb walks back up the tree.
class _CategoryReorderView extends StatelessWidget {
  final CategoryTree tree;
  final String parentId;
  final List<Category> categories;
  final ValueChanged<String> onEnterLevel;
  final ValueChanged<String> onExitLevel;
  final ValueChanged<List<Category>> onReorder;

  /// Cover photo for a category (its first product that has an image).
  final String? Function(Category) coverFor;

  const _CategoryReorderView({
    required this.tree,
    required this.parentId,
    required this.categories,
    required this.onEnterLevel,
    required this.onExitLevel,
    required this.onReorder,
    required this.coverFor,
  });

  List<CategoryNode> get _siblings {
    if (parentId.isEmpty) return tree.roots;
    final node = tree.flatten().where((n) => n.id == parentId).firstOrNull;
    return node?.children ?? const <CategoryNode>[];
  }

  void _handleReorder(int oldIndex, int newIndex) {
    final siblings = [
      for (final n in _siblings)
        n.category.copyWith(sortOrder: n.category.sortOrder),
    ];
    if (oldIndex < 0 || oldIndex >= siblings.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex < 0 || newIndex >= siblings.length) return;
    final moved = siblings.removeAt(oldIndex);
    siblings.insert(newIndex, moved);
    onReorder(siblings);
  }

  /// Moves the item at [index] one place up ([delta] -1) or down (+1).
  void _move(int index, int delta) =>
      _handleReorder(index, delta > 0 ? index + 2 : index - 1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final siblings = _siblings;
    final parentName = parentId.isEmpty
        ? ''
        : (tree.flatten().where((n) => n.id == parentId).firstOrNull?.name ??
              '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Breadcrumb + hint
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              if (parentId.isNotEmpty)
                TextButton.icon(
                  key: const Key('reorder-go-up'),
                  onPressed: () => onExitLevel(parentId),
                  icon: const Icon(Icons.arrow_upward, size: 16),
                  label: Text(AppLocalizations.of(context).up),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  parentId.isEmpty
                      ? AppLocalizations.of(context).reorderingTopLevel
                      : AppLocalizations.of(
                          context,
                        ).reorderingInside(parentName),
                  key: const Key('reorder-level-label'),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            AppLocalizations.of(context).dragTheHandleToSetTheOrderCustomersSee,
            style: const TextStyle(
              fontSize: 11.5,
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: siblings.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Text(
                      AppLocalizations.of(context).noCategoriesAtThisLevel,
                    ),
                  ),
                )
              : ReorderableListView.builder(
                  key: Key('reorder-list-$parentId'),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: siblings.length,
                  buildDefaultDragHandles: false,
                  proxyDecorator: (child, index, animation) {
                    return Material(
                      elevation: 8,
                      shadowColor: Colors.black26,
                      borderRadius: BorderRadius.circular(14),
                      color: theme.colorScheme.surface,
                      child: child,
                    );
                  },
                  // ignore: deprecated_member_use
                  onReorder: _handleReorder,
                  itemBuilder: (context, i) {
                    final node = siblings[i];
                    final cat = node.category;
                    return Padding(
                      key: ValueKey('reorder-${cat.id}'),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ModernCard(
                        key: Key('category-tile-${cat.id}'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            ReorderableDragStartListener(
                              index: i,
                              // No Tooltip here: a tooltip's overlay cannot follow a
                              // row that jumps position in a ReorderableListView.
                              child: Semantics(
                                label: AppLocalizations.of(
                                  context,
                                ).dragToReorder,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.grab,
                                  child: Container(
                                    key: Key('category-drag-handle-${cat.id}'),
                                    padding: const EdgeInsets.all(6),
                                    child: Icon(
                                      Icons.drag_handle,
                                      size: 20,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.45),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              key: Key('category-position-${cat.id}'),
                              width: 26,
                              height: 26,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.12,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _CategoryGlyph(
                              category: cat,
                              coverUrl: coverFor(cat),
                              size: 52,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cat.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _plural(
                                      node.children.isEmpty
                                          ? node.directProductCount
                                          : node.totalProductCount,
                                      'product',
                                      'products',
                                    ),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Semantics(
                              label: AppLocalizations.of(context).moveUp,
                              button: true,
                              child: IconButton(
                                key: Key('category-move-up-${cat.id}'),
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.keyboard_arrow_up),
                                onPressed: i > 0 ? () => _move(i, -1) : null,
                              ),
                            ),
                            Semantics(
                              label: AppLocalizations.of(context).moveDown,
                              button: true,
                              child: IconButton(
                                key: Key('category-move-down-${cat.id}'),
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.keyboard_arrow_down),
                                onPressed: i < siblings.length - 1
                                    ? () => _move(i, 1)
                                    : null,
                              ),
                            ),
                            if (node.children.isNotEmpty)
                              TextButton.icon(
                                key: Key('reorder-open-${cat.id}'),
                                onPressed: () => onEnterLevel(cat.id),
                                icon: const Icon(
                                  Icons.subdirectory_arrow_right,
                                  size: 16,
                                ),
                                label: Text(AppLocalizations.of(context).open),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
