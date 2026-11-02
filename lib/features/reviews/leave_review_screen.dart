import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:myshop/core/widgets/app_toast.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/routes/app_router.dart';
import '../../core/models/order.dart';
import '../../core/models/review.dart';
import '../../core/services/service_locator.dart';
import '../../core/widgets/app_product_image.dart';
import '../auth/auth_cubit.dart';

/// Why the shopper cannot review right now.
enum _Blocked { signIn, notFound, notYours, notDelivered, itemMissing, error }

/// Write (or edit) a review of one product from a completed order:
/// 1-5 stars plus an optional message.
///
/// There is one review per product per order, so opening this again for a
/// product that was already reviewed shows the saved review for editing.
/// [initialRating] pre-selects the stars for a new review.
class LeaveReviewScreen extends StatefulWidget {
  final String orderId;
  final String orderCompanyId;

  /// The product being reviewed ('' reviews the order as a whole).
  final String productId;
  final int initialRating;

  const LeaveReviewScreen({
    super.key,
    required this.orderId,
    this.orderCompanyId = '',
    this.productId = '',
    this.initialRating = 5,
  });

  @override
  State<LeaveReviewScreen> createState() => _LeaveReviewScreenState();
}

class _LeaveReviewScreenState extends State<LeaveReviewScreen> {
  static const _maxMessage = 500;

  late int _rating = widget.initialRating.clamp(1, 5).toInt();
  final _messageCtrl = TextEditingController();

  bool _loading = true;
  bool _submitting = false;
  _Blocked? _blocked;
  String? _submitError;

  Order? _order;
  OrderItem? _item;
  Review? _existing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = context.read<AuthCubit>().currentUser;
    if (user == null) return _block(_Blocked.signIn);
    if (widget.orderId.isEmpty) return _block(_Blocked.notFound);
    try {
      final order = await repo.order(
        widget.orderId,
        companyId: widget.orderCompanyId,
      );
      if (order == null) return _block(_Blocked.notFound);
      if (order.userId != user.id) return _block(_Blocked.notYours);
      if (!order.canBeReviewed) return _block(_Blocked.notDelivered);

      OrderItem? item;
      if (widget.productId.isNotEmpty) {
        for (final i in order.items) {
          if (i.productId == widget.productId) {
            item = i;
            break;
          }
        }
        if (item == null) return _block(_Blocked.itemMissing);
      }

      final reviews = await repo.orderReviews(
        order.id,
        companyId: order.companyId,
      );
      Review? existing;
      for (final r in reviews) {
        if (r.productId == widget.productId) {
          existing = r;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _order = order;
        _item = item;
        _existing = existing;
        if (existing != null) {
          _rating = existing.rating.clamp(1, 5).toInt();
          _messageCtrl.text = existing.message;
        }
        _loading = false;
      });
    } catch (_) {
      _block(_Blocked.error);
    }
  }

  void _block(_Blocked reason) {
    if (!mounted) return;
    setState(() {
      _blocked = reason;
      _loading = false;
    });
  }

  Future<void> _submit() async {
    if (_submitting || _order == null) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final user = context.read<AuthCubit>().currentUser;
    if (user == null) return _block(_Blocked.signIn);

    setState(() {
      _submitting = true;
      _submitError = null;
    });
    final isEdit = _existing != null;
    try {
      await repo.submitReview(
        Review(
          id: '',
          orderId: _order!.id,
          userId: user.id,
          userName: user.name.isNotEmpty ? user.name : l10n.customer,
          companyId: _order!.companyId,
          productId: widget.productId,
          productName: _item?.name ?? '',
          rating: _rating,
          message: _messageCtrl.text.trim(),
        ),
      );
      if (!mounted) return;
      // Drop an earlier error message so this one is shown right away.
      messenger.clearSnackBars();
      messenger.showAppToast(
        SnackBar(
          content: Text(isEdit ? l10n.reviewUpdated : l10n.reviewThanks),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go(AppRoutes.orders);
      }
    } catch (e) {
      if (!mounted) return;
      final message = l10n.reviewCouldNotSubmit('$e');
      setState(() {
        _submitting = false;
        _submitError = message;
      });
      messenger.clearSnackBars();
      messenger.showAppToast(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.orders);
    }
  }

  String _blockedText(AppLocalizations l10n) => switch (_blocked!) {
    _Blocked.signIn => l10n.reviewSignInRequired,
    _Blocked.notFound => l10n.reviewOrderNotFound,
    _Blocked.notYours => l10n.reviewNotYourOrder,
    _Blocked.notDelivered => l10n.reviewOnlyAfterDelivery,
    _Blocked.itemMissing => l10n.reviewItemNotInOrder,
    _Blocked.error => l10n.reviewCouldNotLoad,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEdit = _existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit ? l10n.reviewEditTitle : l10n.reviewRateProductTitle,
        ),
        leading: BackButton(onPressed: _goBack),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _blocked != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _blockedText(l10n),
                      key: const Key('review-blocked-message'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _goBack,
                      child: Text(
                        MaterialLocalizations.of(context).backButtonTooltip,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : _form(context, l10n, isEdit),
    );
  }

  Widget _form(BuildContext context, AppLocalizations l10n, bool isEdit) {
    final theme = Theme.of(context);
    final item = _item;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (item != null)
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: AppProductImage(url: item.image),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          key: const Key('review-product-name'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (item.variantLabel.isNotEmpty)
                          Text(
                            item.variantLabel,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),
            Text(l10n.reviewYourRating, style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                return IconButton(
                  key: Key('review-star-${i + 1}'),
                  iconSize: 40,
                  icon: Icon(
                    i < _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                  onPressed: _submitting
                      ? null
                      : () => setState(() => _rating = i + 1),
                );
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('review-message-field'),
              controller: _messageCtrl,
              enabled: !_submitting,
              maxLines: 4,
              maxLength: _maxMessage,
              decoration: InputDecoration(
                labelText: l10n.reviewMessageLabel,
                hintText: l10n.writeAShortMessage,
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_submitError != null) ...[
              const SizedBox(height: 8),
              Text(
                _submitError!,
                key: const Key('review-error'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('review-submit-button'),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      isEdit
                          ? l10n.reviewUpdateButton
                          : l10n.reviewSubmitButton,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
