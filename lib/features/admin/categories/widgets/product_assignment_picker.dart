import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/models/product.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/modern_card.dart';

/// Interactive dual-panel product-assignment picker.
///
/// Features:
/// - Two panels: **All Products** (available) & **In This Category** (assigned).
/// - Each product card shows exactly:
///   - Name
///   - Price (effective selling price: discountAmt if set/valid, else amount)
///   - Product ID (short/monospace)
/// - Swipe right / tap '+' on an All Products card -> moves to In This Category.
/// - Swipe left / tap '–' on an In This Category card -> moves back to All Products.
/// - Live "X products selected" counter.
/// - Search box filtering both panels simultaneously by product name or ID.
/// - Responsive layout: side-by-side columns on wide screens, segmented tabs on mobile.
class ProductAssignmentPicker extends StatefulWidget {
  final List<Product> allProducts;
  final List<String> selectedProductIds;
  final ValueChanged<List<String>> onSelectedChanged;

  const ProductAssignmentPicker({
    super.key,
    required this.allProducts,
    required this.selectedProductIds,
    required this.onSelectedChanged,
  });

  @override
  State<ProductAssignmentPicker> createState() => _ProductAssignmentPickerState();
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

  bool _matchesQuery(Product p) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery.toLowerCase();
    final nameMatch = p.name.toLowerCase().contains(q);
    final idMatch = p.id.toLowerCase().contains(q);
    return nameMatch || idMatch;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final selectedSet = widget.selectedProductIds.toSet();

    // Partition products into available vs assigned
    final availableProducts = widget.allProducts
        .where((p) => !selectedSet.contains(p.id))
        .toList();
    final assignedProducts = widget.allProducts
        .where((p) => selectedSet.contains(p.id))
        .toList();

    // Filter by search query
    final filteredAvailable = availableProducts.where(_matchesQuery).toList();
    final filteredAssigned = assignedProducts.where(_matchesQuery).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header & Live Counter
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2_outlined, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Product Assignment',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            // Live Counter Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    size: 16,
                    color: widget.selectedProductIds.isEmpty
                        ? Colors.grey
                        : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.selectedProductIds.length} products selected',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: widget.selectedProductIds.isEmpty
                          ? (isDark ? Colors.grey.shade400 : Colors.grey.shade700)
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
          'Swipe right or tap + on available products to assign. Swipe left or tap – to remove.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 14),

        // Unified Real-time Search Box
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Search products by name or ID...',
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onChanged: (val) => setState(() => _searchQuery = val.trim()),
        ),
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
                      title: 'All Products',
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
                      title: 'In This Category',
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
                        label: Text('All (${filteredAvailable.length})'),
                      ),
                      ButtonSegment<int>(
                        value: 1,
                        icon: const Icon(Icons.category_outlined, size: 18),
                        label: Text('In Category (${filteredAssigned.length})'),
                      ),
                    ],
                    selected: {_mobileTab},
                    onSelectionChanged: (val) => setState(() => _mobileTab = val.first),
                  ),
                  const SizedBox(height: 14),
                  if (_mobileTab == 0)
                    _buildPanel(
                      context,
                      title: 'All Products',
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
                      title: 'In This Category',
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

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2430) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Panel Title Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      isAssignedPanel ? Icons.check_box : Icons.grid_view,
                      size: 16,
                      color: isAssignedPanel ? Colors.green.shade600 : theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _searchQuery.isNotEmpty ? '$count of $totalCount' : '$count',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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
                  child: const Text('Add All', style: TextStyle(fontSize: 12)),
                ),
              if (isAssignedPanel && onRemoveAll != null)
                TextButton(
                  onPressed: onRemoveAll,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: const Text('Clear All', style: TextStyle(fontSize: 12)),
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
                    isAssignedPanel ? Icons.folder_open_outlined : Icons.check_circle_outline,
                    size: 36,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAssignedPanel
                        ? (_searchQuery.isNotEmpty
                            ? 'No assigned products match search'
                            : 'No products assigned yet')
                        : (_searchQuery.isNotEmpty
                            ? 'No available products match search'
                            : 'All products are assigned!'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 380),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: products.length,
                separatorBuilder: (context, index) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final p = products[index];
                  return _buildProductCard(context, p, isAssignedPanel);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Product product, bool isAssigned) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Price: discountAmt if set and > 0, else amount
    final effectivePrice = (product.discountAmt > 0) ? product.discountAmt : product.amount;

    final cardContent = ModernCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
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
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
                        color: product.isDiscounted ? Colors.green.shade600 : null,
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
                    const Text('•', style: TextStyle(color: Colors.grey, fontSize: 10)),
                    const SizedBox(width: 8),
                    // Product ID (short/mono)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        product.id.length > 12 ? '${product.id.substring(0, 10)}…' : product.id,
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
              tooltip: 'Add to Category',
              visualDensity: VisualDensity.compact,
              onPressed: () => _addProduct(product.id),
            )
          else
            IconButton(
              icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
              tooltip: 'Remove from Category',
              visualDensity: VisualDensity.compact,
              onPressed: () => _removeProduct(product.id),
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
          child: const Row(
            children: [
              Icon(Icons.add_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Assign',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
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
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Remove',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(width: 8),
              Icon(Icons.remove_circle, color: Colors.white, size: 20),
            ],
          ),
        ),
        onDismissed: (_) => _removeProduct(product.id),
        child: cardContent,
      );
    }
  }
}
