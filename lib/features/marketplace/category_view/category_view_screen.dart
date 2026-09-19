import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes/app_router.dart';
import '../../../core/domain/catalog.dart';
import '../../../core/domain/category_tree.dart';
import '../../../core/models/category.dart';
import '../../../core/models/product.dart';
import '../../../core/services/service_locator.dart';
import '../widgets/product_card.dart';

/// Category explorer (Section 15.2 deep link target).
///
/// Fixes over the previous version:
///  * distinguishes "loading" from "genuinely empty";
///  * includes products of **sub-categories** (a parent category used to show
///    nothing when only its children had products);
///  * offers sorting and an "in stock only" switch, consistent with search;
///  * shows how many products were found.
class CategoryViewScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;

  const CategoryViewScreen({
    super.key,
    required this.categoryId,
    this.categoryName = '',
  });

  @override
  State<CategoryViewScreen> createState() => _CategoryViewScreenState();
}

class _CategoryViewScreenState extends State<CategoryViewScreen> {
  ProductSort _sort = ProductSort.relevance;
  bool _inStockOnly = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.categoryName.isEmpty ? 'Category' : widget.categoryName,
        ),
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
      body: StreamBuilder<List<Category>>(
        stream: repo.categories(),
        builder: (context, categorySnap) {
          final categories = categorySnap.data ?? const <Category>[];

          // Parent + every descendant id, so "Electronics" also lists the
          // products filed under "Phones" and "Audio".
          final ids = <String>{
            widget.categoryId,
            ...CategoryHierarchy.descendantIds(widget.categoryId, categories),
          };

          return StreamBuilder<List<Product>>(
            stream: repo.products(),
            builder: (context, snap) {
              final loading = snap.connectionState == ConnectionState.waiting &&
                  (snap.data?.isEmpty ?? true);

              final products = Catalog.apply(
                snap.data ?? const <Product>[],
                CatalogQuery(
                  categoryIds: ids,
                  sort: _sort,
                  inStockOnly: _inStockOnly,
                ),
              );

              return Column(
                children: [
                  _Toolbar(
                    count: products.length,
                    sort: _sort,
                    inStockOnly: _inStockOnly,
                    onSortChanged: (value) =>
                        setState(() => _sort = value ?? ProductSort.relevance),
                    onStockChanged: (value) =>
                        setState(() => _inStockOnly = value),
                  ),
                  Expanded(
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : products.isEmpty
                            ? _EmptyCategory(
                                hasStockFilter: _inStockOnly,
                                onClear: () =>
                                    setState(() => _inStockOnly = false),
                              )
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  final width = constraints.maxWidth;
                                  final crossAxisCount = width >= 1000
                                      ? 4
                                      : width >= 700
                                          ? 3
                                          : 2;
                                  final childAspectRatio =
                                      width >= 1000 ? 0.68 : 0.72;
                                  return GridView.builder(
                                    padding: const EdgeInsets.all(16),
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      childAspectRatio: childAspectRatio,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                    ),
                                    itemCount: products.length,
                                    itemBuilder: (context, i) => ProductCard(
                                      product: products[i],
                                      onTap: () => context.go(
                                        AppRoutes.productPath(products[i].id),
                                      ),
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
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  final int count;
  final ProductSort sort;
  final bool inStockOnly;
  final ValueChanged<ProductSort?> onSortChanged;
  final ValueChanged<bool> onStockChanged;

  const _Toolbar({
    required this.count,
    required this.sort,
    required this.inStockOnly,
    required this.onSortChanged,
    required this.onStockChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Text(
            '$count product${count == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const Spacer(),
          Row(
            children: [
              const Text('In stock', style: TextStyle(fontSize: 12)),
              Switch(
                value: inStockOnly,
                onChanged: onStockChanged,
              ),
            ],
          ),
          const SizedBox(width: 4),
          DropdownButton<ProductSort>(
            value: sort,
            underline: const SizedBox.shrink(),
            items: [
              for (final value in ProductSort.values)
                DropdownMenuItem<ProductSort>(
                  value: value,
                  child: Text(value.label),
                ),
            ],
            onChanged: onSortChanged,
          ),
        ],
      ),
    );
  }
}

class _EmptyCategory extends StatelessWidget {
  final bool hasStockFilter;
  final VoidCallback onClear;

  const _EmptyCategory({
    required this.hasStockFilter,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.category_outlined, size: 52, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'No products in this category',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Products assigned to this category (or its sub-categories) '
              'will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            if (hasStockFilter) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: onClear,
                child: const Text('Show out-of-stock items'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
