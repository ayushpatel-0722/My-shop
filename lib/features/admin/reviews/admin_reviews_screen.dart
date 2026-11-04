import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:myshop/app/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/routes/app_router.dart';
import '../../../core/models/order.dart';
import '../../../core/models/product.dart';
import '../../../core/models/review.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_product_image.dart';
import '../../../core/widgets/order_status_badge.dart';
import '../admin_shell.dart';

/// A review together with the order, product and customer it belongs to.
///
/// The review document itself is public (shoppers read it on the product
/// page), so the customer's phone and the order details are never stored on
/// it. They are joined here from the order, which only the shop's staff can
/// read.
class ReviewDetail {
  final Review review;
  final Order? order;
  final Product? product;

  const ReviewDetail(this.review, this.order, this.product);

  String get customerName {
    final fromOrder = order?.customerName.trim() ?? '';
    if (fromOrder.isNotEmpty) return fromOrder;
    return review.userName.trim().isEmpty ? '—' : review.userName.trim();
  }

  String get customerPhone => order?.customerPhone.trim() ?? '';
  String get customerEmail => order?.customerEmail.trim() ?? '';
  String get orderRef => order?.reference ?? '#${review.orderId}';

  String get productName {
    final fromReview = review.productName.trim();
    if (fromReview.isNotEmpty) return fromReview;
    return product?.name ?? '';
  }

  /// True when [q] (already lower-case) appears in anything the admin can
  /// see: customer, phone, order id, product, shop, comment.
  bool matches(String q) {
    if (q.isEmpty) return true;
    final haystack = [
      customerName,
      customerPhone,
      customerEmail,
      review.orderId,
      orderRef,
      productName,
      order?.companyName ?? '',
      review.message,
    ].join(' ').toLowerCase();
    return haystack.contains(q);
  }
}

/// Joins [reviews] with their orders and products (both keyed by id).
List<ReviewDetail> joinReviewDetails(
  List<Review> reviews,
  List<Order> orders,
  List<Product> products,
) {
  final orderById = {for (final o in orders) o.id: o};
  final productById = {for (final p in products) p.id: p};
  return [
    for (final r in reviews)
      ReviewDetail(r, orderById[r.orderId], productById[r.productId]),
  ];
}

/// Reviews panel for the signed-in admin's own shop: who wrote each review,
/// for which order and product, and how to reach them.
class AdminReviewsScreen extends StatefulWidget {
  const AdminReviewsScreen({super.key});

  @override
  State<AdminReviewsScreen> createState() => _AdminReviewsScreenState();
}

enum _Visibility { all, visible, hidden }

class _AdminReviewsScreenState extends State<AdminReviewsScreen> {
  static const _pageSize = 20;

  late final String _companyId = AuthSession.currentUser?.companyId ?? '';
  late final Stream<List<Review>> _reviews = repo.reviews(_companyId);
  late final Stream<List<Order>> _orders = repo.orders(companyId: _companyId);
  late final Stream<List<Product>> _products = repo.products(
    companyId: _companyId,
    includeUnpublished: true,
  );

  final _searchCtrl = TextEditingController();
  String _query = '';
  int? _rating;
  _Visibility _visibility = _Visibility.all;
  int _shown = _pageSize;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _resetPaging() => _shown = _pageSize;

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      showBack: true,
      backRoute: AppRoutes.admin,
      title: AppLocalizations.of(context).reviews,
      child: StreamBuilder<List<Review>>(
        stream: _reviews,
        builder: (context, reviewSnap) {
          if (reviewSnap.hasError) {
            return _message(
              Icons.error_outline,
              'Could not load reviews. Check your connection and try again.',
            );
          }
          if (!reviewSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<List<Order>>(
            stream: _orders,
            builder: (context, orderSnap) => StreamBuilder<List<Product>>(
              stream: _products,
              builder: (context, productSnap) {
                final details = joinReviewDetails(
                  reviewSnap.data!,
                  orderSnap.data ?? const <Order>[],
                  productSnap.data ?? const <Product>[],
                );
                return _content(context, details);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _content(BuildContext context, List<ReviewDetail> all) {
    if (all.isEmpty) {
      return _message(
        Icons.rate_review_outlined,
        AppLocalizations.of(context).noReviewsYet,
      );
    }
    final q = _query.trim().toLowerCase();
    final filtered = all.where((d) {
      if (_rating != null && d.review.rating != _rating) return false;
      if (_visibility == _Visibility.visible && !d.review.isVisible) {
        return false;
      }
      if (_visibility == _Visibility.hidden && d.review.isVisible) {
        return false;
      }
      return d.matches(q);
    }).toList();
    final page = filtered.take(_shown).toList();
    final average =
        all.fold<int>(0, (s, d) => s + d.review.rating) / all.length;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _summary(context, average, all.length),
            const SizedBox(height: 12),
            _filters(context),
            const SizedBox(height: 8),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: _message(
                  Icons.search_off,
                  'No reviews match these filters.',
                ),
              )
            else ...[
              for (final d in page)
                _ReviewCard(
                  key: ValueKey('review-${d.review.companyId}-${d.review.id}'),
                  detail: d,
                  onToggleVisible: () => _toggleVisible(d.review),
                ),
              if (filtered.length > page.length)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 16),
                  child: Center(
                    child: OutlinedButton(
                      key: const Key('reviews-load-more'),
                      onPressed: () => setState(() => _shown += _pageSize),
                      child: Text(
                        'Load more (${filtered.length - page.length} left)',
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _toggleVisible(Review r) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repo.setReviewVisibility(
        r.id,
        !r.isVisible,
        companyId: r.companyId,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not update the review: $e')),
      );
    }
  }

  Widget _message(IconData icon, String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    ),
  );

  Widget _summary(BuildContext context, double average, int count) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Text(
              average.toStringAsFixed(1),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.star, color: Colors.amber),
            const SizedBox(width: 12),
            Text('$count review${count == 1 ? '' : 's'}'),
          ],
        ),
      ),
    );
  }

  Widget _filters(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('reviews-search'),
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Search customer, mobile, order ID, product or comment',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() {
                      _searchCtrl.clear();
                      _query = '';
                      _resetPaging();
                    }),
                  ),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onChanged: (v) => setState(() {
            _query = v;
            _resetPaging();
          }),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ChoiceChip(
              label: const Text('All ratings'),
              selected: _rating == null,
              onSelected: (_) => setState(() {
                _rating = null;
                _resetPaging();
              }),
            ),
            for (var s = 5; s >= 1; s--)
              ChoiceChip(
                key: Key('reviews-rating-$s'),
                label: Text('$s ★'),
                selected: _rating == s,
                onSelected: (_) => setState(() {
                  _rating = _rating == s ? null : s;
                  _resetPaging();
                }),
              ),
            const SizedBox(width: 8),
            for (final v in _Visibility.values)
              ChoiceChip(
                key: Key('reviews-visibility-${v.name}'),
                label: Text(switch (v) {
                  _Visibility.all => 'All',
                  _Visibility.visible => 'Visible',
                  _Visibility.hidden => 'Hidden',
                }),
                selected: _visibility == v,
                onSelected: (_) => setState(() {
                  _visibility = v;
                  _resetPaging();
                }),
              ),
          ],
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ReviewDetail detail;
  final VoidCallback onToggleVisible;

  const _ReviewCard({
    super.key,
    required this.detail,
    required this.onToggleVisible,
  });

  Review get r => detail.review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = detail.product;
    final image = (product != null && product.images.isNotEmpty)
        ? product.images.first
        : '';
    final phone = detail.customerPhone;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: r.isVisible
              ? theme.colorScheme.outlineVariant
              : Colors.orange.shade300,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rating, date and visibility.
            Row(
              children: [
                for (var j = 0; j < 5; j++)
                  Icon(
                    j < r.rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 18,
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    formatDate(r.createdAt),
                    key: Key('review-date-${r.id}'),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                if (!r.isVisible)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Hidden',
                      style: TextStyle(fontSize: 11, color: Colors.deepOrange),
                    ),
                  ),
                IconButton(
                  key: Key('review-toggle-${r.id}'),
                  tooltip: r.isVisible
                      ? 'Hide from shoppers'
                      : 'Show to shoppers',
                  icon: Icon(
                    r.isVisible ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: onToggleVisible,
                ),
              ],
            ),
            if (r.message.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(r.message, key: Key('review-message-${r.id}')),
            ],
            const Divider(height: 24),

            // Customer: name, mobile, email.
            _section(
              theme,
              Icons.person_outline,
              'Customer',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.customerName,
                    key: Key('review-customer-${r.id}'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  if (phone.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 15),
                        const SizedBox(width: 4),
                        SelectableText(phone, key: Key('review-phone-${r.id}')),
                        IconButton(
                          tooltip: 'Call customer',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.call, size: 18),
                          onPressed: () =>
                              launchUrl(Uri(scheme: 'tel', path: phone)),
                        ),
                        IconButton(
                          tooltip: 'Copy mobile number',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.copy, size: 16),
                          onPressed: () =>
                              _copy(context, phone, 'Mobile number'),
                        ),
                      ],
                    )
                  else
                    Text(
                      'Mobile number not available on the order',
                      key: Key('review-no-phone-${r.id}'),
                      style: theme.textTheme.bodySmall,
                    ),
                  if (detail.customerEmail.isNotEmpty)
                    Text(
                      detail.customerEmail,
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Shop + product.
            _section(
              theme,
              Icons.storefront_outlined,
              'Shop',
              Text(
                (detail.order?.companyName ?? '').isNotEmpty
                    ? detail.order!.companyName
                    : (AuthSession.currentUser?.companyName ?? '—'),
              ),
            ),
            const SizedBox(height: 10),
            _section(
              theme,
              Icons.inventory_2_outlined,
              'Product',
              Row(
                children: [
                  if (image.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: AppProductImage(url: image),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detail.productName.isEmpty
                              ? 'Whole order'
                              : detail.productName,
                          key: Key('review-product-${r.id}'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (product != null && product.details.isNotEmpty)
                          Text(
                            product.details,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        if (r.productId.isNotEmpty)
                          Text(
                            'Product ID: ${r.productId}',
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Order.
            _section(
              theme,
              Icons.receipt_long_outlined,
              'Order',
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  InkWell(
                    onTap: () => _copy(context, r.orderId, 'Order ID'),
                    child: Text(
                      'Order ${detail.orderRef}',
                      key: Key('review-order-${r.id}'),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  if (detail.order != null)
                    OrderStatusBadge(status: detail.order!.orderStatus),
                  TextButton.icon(
                    key: Key('review-open-order-${r.id}'),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('View order'),
                    onPressed: () => context.push(
                      AppRoutes.adminOrderDetailsPath(r.orderId),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(ThemeData theme, IconData icon, String label, Widget body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Row(
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.outline),
              const SizedBox(width: 4),
              Text(label, style: theme.textTheme.labelMedium),
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );
  }

  void _copy(BuildContext context, String value, String what) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$what copied')));
  }
}
