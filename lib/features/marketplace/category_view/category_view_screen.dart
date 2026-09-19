import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes/app_router.dart';
import '../../../core/models/product.dart';
import '../../../core/services/service_locator.dart';
import '../widgets/product_card.dart';

/// Category explorer pre-filtered to a category (Section 15.2 deep link target).
class CategoryViewScreen extends StatelessWidget {
  final String categoryId;
  final String categoryName;
  const CategoryViewScreen({
    super.key,
    required this.categoryId,
    this.categoryName = '',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(categoryName.isEmpty ? 'Category' : categoryName),
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
      body: StreamBuilder<List<Product>>(
        stream: repo.products(categoryId: categoryId),
        builder: (context, snap) {
          final list = snap.data ?? const <Product>[];
          if (list.isEmpty) {
            return const Center(child: Text('No products in this category'));
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width >= 1000
                  ? 4
                  : width >= 700
                  ? 3
                  : 2;
              final childAspectRatio = width >= 1000 ? 0.68 : 0.72;
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: childAspectRatio,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: list.length,
                itemBuilder: (context, i) => ProductCard(
                  product: list[i],
                  onTap: () => context.go(AppRoutes.productPath(list[i].id)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
