import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/product.dart';
import '../services/service_locator.dart';

/// Looks up a cover photo for a [Category]: the image of the first product in
/// its `productList` that has one.
///
/// Wrap the part of the screen that shows category thumbnails once, instead of
/// subscribing per row:
///
/// ```dart
/// CategoryCoverBuilder(
///   companyId: shop.id,
///   builder: (context, coverFor) => ... coverFor(category) ...,
/// )
/// ```
class CategoryCoverBuilder extends StatelessWidget {
  final String companyId;
  final Widget Function(BuildContext context, String? Function(Category))
  builder;

  const CategoryCoverBuilder({
    super.key,
    required this.companyId,
    required this.builder,
  });

  /// First usable image among the category's products, or null.
  static String? coverFor(
    Category category,
    Map<String, String> imageByProduct,
  ) {
    for (final id in category.productList) {
      final url = imageByProduct[id];
      if (url != null) return url;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Product>>(
      stream: repo.products(companyId: companyId),
      builder: (context, snap) {
        final imageByProduct = <String, String>{
          for (final p in snap.data ?? const <Product>[])
            if (p.images.isNotEmpty) p.id: p.images.first,
        };
        return builder(context, (c) => coverFor(c, imageByProduct));
      },
    );
  }
}
