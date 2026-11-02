import 'package:flutter/material.dart';

import '../../../core/models/review.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/formatters.dart';

/// The reviews of one product, newest first: customer, stars, comment and the
/// date and time it was written.
///
/// Reviews are read from the product's own shop only, so another shop's
/// reviews can never show up here. Shoppers see the visible ones; with
/// [forStaff] the shop also sees the ones it hid, marked as hidden, and the
/// order each review came from.
class ProductReviewsList extends StatelessWidget {
  final String productId;
  final String companyId;
  final bool forStaff;

  const ProductReviewsList({
    super.key,
    required this.productId,
    required this.companyId,
    this.forStaff = false,
  });

  /// Reviews of [productId] from a shop's full list (hidden ones only when
  /// [includeHidden]); the stream is already newest first.
  static List<Review> forProduct(
    List<Review> all,
    String productId, {
    bool includeHidden = false,
  }) => [
    for (final r in all)
      if (r.productId == productId && (includeHidden || r.isVisible)) r,
  ];

  @override
  Widget build(BuildContext context) {
    if (productId.isEmpty || companyId.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<List<Review>>(
      stream: repo.reviews(companyId),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Could not load reviews right now.',
              key: Key('product-reviews-error'),
            ),
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final reviews = forProduct(
          snap.data!,
          productId,
          includeHidden: forStaff,
        );
        if (reviews.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No reviews yet', key: Key('product-reviews-empty')),
          );
        }
        return Column(
          key: const Key('product-reviews-list'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final r in reviews) _tile(context, r)],
        );
      },
    );
  }

  Widget _tile(BuildContext context, Review r) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.userName.isEmpty ? 'Customer' : r.userName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              for (var i = 0; i < 5; i++)
                Icon(
                  i < r.rating ? Icons.star : Icons.star_border,
                  size: 16,
                  color: Colors.amber,
                ),
            ],
          ),
          if (r.message.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(r.message),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            children: [
              Text(formatDate(r.createdAt), style: theme.textTheme.bodySmall),
              if (forStaff)
                Text(
                  'Order #${r.orderId.length > 6 ? r.orderId.substring(0, 6).toUpperCase() : r.orderId.toUpperCase()}',
                  style: theme.textTheme.bodySmall,
                ),
              if (forStaff && !r.isVisible)
                Text(
                  'Hidden from shoppers',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.deepOrange,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
