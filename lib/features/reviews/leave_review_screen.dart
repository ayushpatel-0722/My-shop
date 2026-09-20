import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/routes/app_router.dart';
import '../../core/models/review.dart';
import '../../core/services/service_locator.dart';
import '../auth/auth_cubit.dart';

/// Post-completion review prompt (Section 14.1): 1-5 stars + optional message.
///
/// [initialRating] pre-selects the stars — the order-history card opens this
/// screen with the star the shopper tapped.
class LeaveReviewScreen extends StatefulWidget {
  final String orderId;
  final String orderCompanyId;
  final int initialRating;
  const LeaveReviewScreen({
    super.key,
    required this.orderId,
    this.orderCompanyId = '',
    this.initialRating = 5,
  });

  @override
  State<LeaveReviewScreen> createState() => _LeaveReviewScreenState();
}

class _LeaveReviewScreenState extends State<LeaveReviewScreen> {
  late int _rating = widget.initialRating.clamp(1, 5).toInt();
  final _messageCtrl = TextEditingController();

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.leaveReview)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                return IconButton(
                  iconSize: 40,
                  icon: Icon(
                    i < _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                  onPressed: () => setState(() => _rating = i + 1),
                );
              }),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _messageCtrl,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Write a short message'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submit,
              child: Text(l10n.submit),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final user = context.read<AuthCubit>().currentUser;
    await repo.submitReview(Review(
      id: '',
      orderId: widget.orderId,
      userId: user?.id ?? 'guest',
      userName: user?.name ?? 'Customer',
      companyId: widget.orderCompanyId,
      rating: _rating,
      message: _messageCtrl.text.trim(),
    ));
    if (!mounted) return;
    context.go(AppRoutes.orders);
  }
}
