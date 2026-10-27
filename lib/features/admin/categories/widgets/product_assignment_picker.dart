import 'package:flutter/material.dart';
import 'package:myshop/app/l10n/app_localizations.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/models/product.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/modern_card.dart';

/// Interactive dual-panel product-assignment picker.
///
/// Features:
/// - Two panels: **All Products** (available) & **In This Category** (assigned).
/// - Each product card shows:
///   - Name
///   - Price (effective selling price: discountAmt if set/valid, else amount)
///   - Product ID (short/monospace)
/// - Swipe right / tap '+' on an All Products card -> moves to In This Category
///   (appended to the END of the display order).
/// - Swipe left / tap '–' on an In This Category card -> moves back.
/// - **In This Category ordering**: the drag handle (≡) reorders the display
///   order inside the category. Only the handle starts a drag, so the swipe
///   gestures still work. Ordering is local state — nothing is written until
///   the admin taps Save Changes. Reordering is disabled while searching.
/// - Position numbers (1, 2, 3…) on the assigned cards.
/// - Live "X product(s) selected" counter.
/// - Search box filtering both panels simultaneously by product name or ID.
/// - Responsive layout: side-by-side columns on wide screens, segmented tabs.
class ProductAssignmentPicker extends StatefulWidget {
  final List<Product> allProducts;

  /// Assigned product ids **in display order** (array position = position the
  /// customer sees inside the category).
  final List<String> selectedProductIds;
  final ValueChanged<List<String>> onSelectedChanged;

  const ProductAssignmentPicker({
    super.key,
    required this.allProducts,
    required this.selectedProductIds,
    required this.onSelectedChanged,
  });

  @override
  State<ProductAssignmentPicker> createState() =>
      _ProductAssignmentPickerState();
}

class _ProductAssignmentPickerState extends State<ProductAssignmentPicker> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int _mobileTab = 0; // 0 = All Products, 1 = In This Category

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _addProduct(String id) {
    if (!widget.selectedProductIds.contains(id)) {
      // Newly assigned products are appended to the END of the order.
      final updated = List<String>.from(widget.selectedProductIds)..add(id);
      widget.onSelectedChanged(updated);
    }
  }

  void _removeProduct(String id) {
    if (widget.selectedProductIds.contains(id)) {
      final updated = List<String>.from(widget.selectedProductIds)..remove(id);
      widget.onSelectedChanged(updated);
    }
  }

  void _addAllFiltered(List<Product> availableFiltered) {
    final updated = List<String>.from(widget.selectedProductIds);
    for (final p in availableFiltered) {
      if (!updated.contains(p.id)) {
        updated.add(p.id);
      }
    }
    widget.onSelectedChanged(updated);
  }

  void _removeAllFiltered(List<Product> assignedFiltered) {
    final idsToRemove = assignedFiltered.map((p) => p.id).toSet();
    final updated = widget.selectedProductIds
        .where((id) => !idsToRemove.contains(id))
        .toList();
    widget.onSelectedChanged(updated);
  }

  /// Reorders the assigned list (display order = [selectedProductIds] order).
  void _reorderAssigned(int oldIndex, int newIndex) {
    final ordered = _orderedAssignedIds();
    if (oldIndex < 0 || oldIndex >= ordered.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex < 0 || newIndex >= ordered.length) return;

    final moved = ordered.removeAt(oldIndex);
    ordered.insert(newIndex, moved);

    // Keep any ids that are not in the product catalogue at the end.
    final known = ordered.toSet();
    final unknown = widget.selectedProductIds
        .where((id) => !known.contains(id))
        .toList();
    widget.onSelectedChanged([...ordered, ...unknown]);
  }

  /// Assigned ids ordered by the display order, limited to known products.
  List<String> _orderedAssignedIds() {
    final byId = {for (final p in widget.allProducts) p.id: p};
    return widget.selectedProductIds
        .where((id) => byId.containsKey(id))
        .toList();
  }

  bool _matchesQuery(Product p) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery.toLowerCase();
    final nameMatch = p.name.toLowerCase().contains(q);
    final idMatch = p.id.toLowerCase().contains(q);
    return nameMatch || idMatch;
  }

  /// "1 product selected" / "2 products selected".
  String get _selectedLabel {
    final n = widget.selectedProductIds.length;
    return AppLocalizations.of(context).productsSelected(n);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final selectedSet = widget.selectedProductIds.toSet();
    final byId = {for (final p in widget.allProducts) p.id: p};

    // Partition products into available vs assigned. The assigned list follows
    // the manual display order (selectedProductIds array position).
    final availableProducts = widget.allProducts
        .where((p) => !selectedSet.contains(p.id))
        .toList();
    final assignedProducts = [
      for (final id in widget.selectedProductIds)
        if (byId[id] != null) byId[id]!,
    ];

    // Filter by search query
    final filteredAvailable = availableProducts.where(_matchesQuery).toList();
    final filteredAssigned = assignedProducts.where(_matchesQuery).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header & Live Counter
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context).productAssignment,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            // Live Counter Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: widget.selectedProductIds.isEmpty
                    ? (isDark ? Colors.grey.shade800 : Colors.grey.shade200)
                    : theme.colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.selectedProductIds.isEmpty
                      ? Colors.transparent
                      : theme.colorScheme.primary.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.selectedProductIds.isEmpty
                        ? Icons.check_box_outline_blank
                        : Icons.check_circle_outline,
                    size: 15,
                    color: widget.selectedProductIds.isEmpty
                        ? Colors.grey
                        : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _selectedLabel,
                    key: const Key('assignment-counter'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: widget.selectedProductIds.isEmpty
                          ? (isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade700)
                          : theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Hint instructions
        Text(
          AppLocalizations.of(
            context,
          ).swipeRightOrTapOnAvailableProductsToAssignSwipeLeftOrTapToRemoveDragTheHandleInInThisCategoryToSetTheDisplayOrder,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDark
                ? AppTheme.textSecondaryDark
                : AppTheme.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 14),

        // Unified Real-time Search Box
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context).searchProductsByNameOrId,
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          onChanged: (val) => setState(() => _searchQuery = val.trim()),
        ),
        if (_searchQuery.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).clearSearchToReorder,
            style: TextStyle(
              fontSize: 11.5,
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
        const SizedBox(height: 16),

        // Responsive Picker Panels
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 640;

            if (isWide) {
              // Side-by-Side Dual Panels
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Panel: All Products
                  Expanded(
                    child: _buildPanel(
                      context,
                      title: AppLocalizations.of(context).allProducts2,
                      count: filteredAvailable.length,
                      totalCount: availableProducts.length,
                      isAssignedPanel: false,
                      products: filteredAvailable,
                      onAddAll: filteredAvailable.isNotEmpty
                          ? () => _addAllFiltered(filteredAvailable)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Right Panel: In This Category
                  Expanded(
                    child: _buildPanel(
                      context,
                      title: AppLocalizations.of(context).inThisCategory,
                      count: filteredAssigned.length,
                      totalCount: assignedProducts.length,
                      isAssignedPanel: true,
                      products: filteredAssigned,
                      onRemoveAll: filteredAssigned.isNotEmpty
                          ? () => _removeAllFiltered(filteredAssigned)
                          : null,
                    ),
                  ),
                ],
              );
            } else {
              // Compact/Mobile View with Segmented Buttons
              return Column(
                children: [
                  SegmentedButton<int>(
                    segments: [
                      ButtonSegment<int>(
                        value: 0,
                        icon: const Icon(Icons.storefront_outlined, size: 18),
                        label: Text(
                          AppLocalizations.of(
                            context,
                          ).all('${filteredAvailable.length}'),
                        ),
                      ),
                      ButtonSegment<int>(
                        value: 1,
                        icon: const Icon(Icons.category_outlined, size: 18),
                        label: Text(
                          AppLocalizations.of(
                            context,
                          ).inCategory('${filteredAssigned.length}'),
                        ),
                      ),
                    ],
                    selected: {_mobileTab},
                    onSelectionChanged: (s) =>
                        setState(() => _mobileTab = s.first),
                  ),
                  const SizedBox(height: 14),
                  if (_mobileTab == 0)
                    _buildPanel(
                      context,
                      title: AppLocalizations.of(context).allProducts2,
                      count: filteredAvailable.length,
                      totalCount: availableProducts.length,
                      isAssignedPanel: false,
                      products: filteredAvailable,
                      onAddAll: filteredAvailable.isNotEmpty
                          ? () => _addAllFiltered(filteredAvailable)
                          : null,
                    )
                  else
                    _buildPanel(
                      context,
                      title: AppLocalizations.of(context).inThisCategory,
                      count: filteredAssigned.length,
                      totalCount: assignedProducts.length,
                      isAssignedPanel: true,
                      products: filteredAssigned,
                      onRemoveAll: filteredAssigned.isNotEmpty
                          ? () => _removeAllFiltered(filteredAssigned)
                          : null,
                    ),
                ],
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildPanel(
    BuildContext context, {
    required String title,
    required int count,
    required int totalCount,
    required bool isAssignedPanel,
    required List<Product> products,
    VoidCallback? onAddAll,
    VoidCallback? onRemoveAll,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Position lookup for the "1, 2, 3…" badges (assigned panel only).
    final positionOf = <String, int>{};
    if (isAssignedPanel) {
      for (var i = 0; i < widget.selectedProductIds.length; i++) {
        positionOf[widget.selectedProductIds[i]] = i + 1;
      }
    }

    final canReorder =
        isAssignedPanel && _searchQuery.isEmpty && products.length > 1;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Panel Header + bulk action
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _searchQuery.isNotEmpty
                            ? AppLocalizations.of(
                                context,
                              ).countOutOfTotal('$count', '$totalCount')
                            : '$count',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isAssignedPanel && onAddAll != null)
                TextButton(
                  onPressed: onAddAll,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: Text(
                    AppLocalizations.of(context).addAll,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              if (isAssignedPanel && onRemoveAll != null)
                TextButton(
                  onPressed: onRemoveAll,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: Text(
                    AppLocalizations.of(context).clearAll,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
          const Divider(height: 16),

          // List of Product Cards
          if (products.isEmpty)
            Container(
              height: 180,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isAssignedPanel
                        ? Icons.folder_open_outlined
                        : Icons.check_circle_outline,
                    size: 36,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAssignedPanel
                        ? (_searchQuery.isNotEmpty
                              ? AppLocalizations.of(
                                  context,
                                ).noAssignedProductsMatchSearch
                              : AppLocalizations.of(
                                  context,
                                ).noProductsAssignedYet)
                        : (_searchQuery.isNotEmpty
                              ? AppLocalizations.of(
                                  context,
                                ).noAvailableProductsMatchSearch
                              : AppLocalizations.of(
                                  context,
                                ).allProductsAreAssigned),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 380),
              child: canReorder
                  ? _buildReorderableAssigned(context, products, positionOf)
                  : _buildPlainList(
                      context,
                      products,
                      isAssignedPanel,
                      positionOf,
                    ),
            ),
        ],
      ),
    );
  }

  /// Plain list for the "All" panel (and the assigned panel while searching).
  Widget _buildPlainList(
    BuildContext context,
    List<Product> products,
    bool isAssignedPanel,
    Map<String, int> positionOf,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: products.length,
      separatorBuilder: (context, index) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final p = products[index];
        return _buildProductCard(
          context,
          p,
          isAssignedPanel,
          position: positionOf[p.id],
        );
      },
    );
  }

  /// Drag-to-reorder list of the assigned products (display order).
  Widget _buildReorderableAssigned(
    BuildContext context,
    List<Product> products,
    Map<String, int> positionOf,
  ) {
    return ReorderableListView(
      shrinkWrap: true,
      physics: const AlwaysScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      proxyDecorator: (child, index, animation) {
        // Lifted card while dragging.
        return Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surface,
          child: child,
        );
      },
      // ignore: deprecated_member_use
      onReorder: _reorderAssigned,
      children: [
        for (var i = 0; i < products.length; i++)
          Padding(
            key: ValueKey('assigned_${products[i].id}'),
            padding: const EdgeInsets.only(bottom: 6),
            child: _buildProductCard(
              context,
              products[i],
              true,
              position: positionOf[products[i].id],
              dragHandle: ReorderableDragStartListener(
                index: i,
                // No Tooltip: its overlay cannot follow a row that jumps position
                // in a ReorderableListView (throws a LayoutBuilder assertion).
                child: Semantics(
                  label: AppLocalizations.of(context).dragToReorder,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Container(
                      key: Key('drag-handle-${products[i].id}'),
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.drag_handle,
                        size: 18,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    Product product,
    bool isAssigned, {
    int? position,
    Widget? dragHandle,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Price: discountAmt if set and > 0, else amount
    final effectivePrice = (product.discountAmt > 0)
        ? product.discountAmt
        : product.amount;

    final cardContent = ModernCard(
      key: Key('assign-card-${product.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag handle (assigned panel only) — the ONLY drag starter.
          ?dragHandle,

          // Position badge (assigned panel).
          if (isAssigned && position != null)
            Container(
              key: Key('assign-position-${product.id}'),
              width: 22,
              height: 22,
              alignment: Alignment.center,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$position',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),

          // Product Info: Name, Price, Monospace Short ID
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Product Name
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    // Effective Price
                    Text(
                      formatCurrency(effectivePrice),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: product.isDiscounted
                            ? Colors.green.shade600
                            : null,
                      ),
                    ),
                    if (product.isDiscounted) ...[
                      const SizedBox(width: 6),
                      Text(
                        formatCurrency(product.amount),
                        style: const TextStyle(
                          fontSize: 11,
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    const Text(
                      '•',
                      style: TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                    const SizedBox(width: 8),
                    // Product ID (short/mono)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        product.id.length > 12
                            ? '${product.id.substring(0, 10)}…'
                            : product.id,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Tap Button (+ for Available, – for Assigned)
          if (!isAssigned)
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.green),
              tooltip: AppLocalizations.of(context).addToCategory,
              visualDensity: VisualDensity.compact,
              onPressed: () => _addProduct(product.id),
            )
          else
            // Assigned rows live in a ReorderableListView, so no Tooltip here.
            Semantics(
              label: AppLocalizations.of(context).removeFromCategory,
              button: true,
              child: IconButton(
                icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
                visualDensity: VisualDensity.compact,
                onPressed: () => _removeProduct(product.id),
              ),
            ),
        ],
      ),
    );

    // Wrap with Dismissible for Swipe Actions:
    // Swipe Right on Available -> Add
    // Swipe Left on Assigned -> Remove
    if (!isAssigned) {
      return Dismissible(
        key: ValueKey('all_${product.id}'),
        direction: DismissDirection.startToEnd,
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.green.shade600,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.add_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context).assign,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        onDismissed: (_) => _addProduct(product.id),
        child: cardContent,
      );
    } else {
      return Dismissible(
        key: ValueKey('assigned_${product.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.red.shade600,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                AppLocalizations.of(context).remove,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.remove_circle, color: Colors.white, size: 20),
            ],
          ),
        ),
        onDismissed: (_) => _removeProduct(product.id),
        child: cardContent,
      );
    }
  }
}
