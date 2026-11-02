import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../../../core/models/order.dart';
import '../../../core/models/review.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/widgets/app_product_image.dart';

/// Opens the "rate your items" list for a completed [order] in a bottom sheet.
Future<void> showOrderReviewSheet(BuildContext context, Order order) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: OrderReviewSection(order: order),
      ),
    ),
  );
}

/// "Rate your items": every product in a completed order with a button to
/// review it, or the saved stars and an "Edit review" button once it has been.
///
/// Whether an item was reviewed is read from the reviews themselves (one per
/// product per order), not from the order, which shoppers cannot modify.
class OrderReviewSection extends StatefulWidget {
  final Order order;
  const OrderReviewSection({super.key, required this.order});

  @override
  State<OrderReviewSection> createState() => _OrderReviewSectionState();
}

class _OrderReviewSectionState extends State<OrderReviewSection> {
  late Future<Map<String, Review>> _reviews = _load();

  Future<Map<String, Review>> _load() async {
    final list = await repo.orderReviews(
      widget.order.id,
      companyId: widget.order.companyId,
    );
    return {for (final r in list) r.productId: r};
  }

  Future<void> _open(OrderItem item) async {
    final order = widget.order;
    await context.push(
      '${AppRoutes.leaveReview.replaceFirst(':orderId', order.id)}'
      '?companyId=${Uri.encodeQueryComponent(order.companyId)}'
      '&productId=${Uri.encodeQueryComponent(item.productId)}',
    );
    if (!mounted) return;
    setState(() => _reviews = _load());
  }

  /// One row per product, even when the order lists it more than once.
  List<OrderItem> get _items {
    final seen = <String>{};
    return [
      for (final i in widget.order.items)
        if (i.productId.isNotEmpty && seen.add(i.productId)) i,
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.order.canBeReviewed || _items.isEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      key: const Key('order-review-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.reviewRateYourItems,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        FutureBuilder<Map<String, Review>>(
          future: _reviews,
          builder: (context, snap) {
            final reviewed = snap.data ?? const <String, Review>{};
            return Column(
              children: [
                for (final item in _items)
                  _row(context, l10n, item, reviewed[item.productId]),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    AppLocalizations l10n,
    OrderItem item,
    Review? review,
  ) {
    final id = item.productId;
    return Padding(
      key: Key('review-item-$id'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 48,
              height: 48,
              child: AppProductImage(url: item.image),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (review != null)
                  Row(
                    key: Key('review-stars-$id'),
                    children: [
                      for (var i = 1; i <= 5; i++)
                        Icon(
                          i <= review.rating ? Icons.star : Icons.star_border,
                          size: 16,
                          color: Colors.amber,
                        ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (review == null)
            FilledButton.tonal(
              key: Key('review-write-$id'),
              onPressed: () => _open(item),
              child: Text(l10n.reviewWrite),
            )
          else
            TextButton(
              key: Key('review-edit-$id'),
              onPressed: () => _open(item),
              child: Text(l10n.reviewEdit),
            ),
        ],
      ),
    );
  }
}
