import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/company.dart';
import '../../../core/models/product.dart';
import '../../../core/utils/formatters.dart';
import '../../checkout/cart/cart_cubit.dart';

/// Product tile used across the home feed, category view and search results.
class ProductCard extends StatelessWidget {
  final Product product;
  final Company? company;
  final VoidCallback? onTap;

  const ProductCard(
      {super.key, required this.product, this.company, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final symbol = company?.currencySymbol ?? '₹';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                color: scheme.primaryContainer.withOpacity(0.3),
                child: Icon(
                  _iconFor(product.categoryId),
                  size: 48,
                  color: scheme.primary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    '${product.unit} ${product.unitType}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatCurrency(product.price, symbol: symbol),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          if (product.isDiscounted)
                            Text(
                              formatCurrency(product.amount, symbol: symbol),
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                        ],
                      ),
                      IconButton.filledTonal(
                        onPressed: () => context
                            .read<CartCubit>()
                            .add(product, company: company),
                        icon: const Icon(Icons.add_shopping_cart, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String categoryId) {
    switch (categoryId) {
      case 'cat_veg':
        return Icons.eco;
      case 'cat_fruit':
        return Icons.apple;
      case 'cat_dairy':
        return Icons.water_drop;
      case 'cat_phone':
        return Icons.smartphone;
      case 'cat_audio':
        return Icons.headphones;
      case 'cat_wear':
        return Icons.watch;
      default:
        return Icons.shopping_bag;
    }
  }
}
