import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/routes/app_router.dart';
import '../../core/models/review.dart';
import '../../core/services/service_locator.dart';
import '../../core/widgets/modern_shimmer.dart';

/// Lists all visible reviews for a company (Section 14.2, user side).
class ReviewsScreen extends StatelessWidget {
  final String companyId;
  const ReviewsScreen({super.key, required this.companyId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reviews),
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
      body: StreamBuilder<List<Review>>(
        stream: repo.reviews(companyId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 4,
              itemBuilder: (_, _) => const M3ListTileSkeleton(),
            );
          }
          final list = (snap.data ?? const <Review>[])
              .where((r) => r.isVisible)
              .toList();
          if (list.isEmpty) {
            return Center(
              child: Text(AppLocalizations.of(context).noReviewsYet),
            );
          }
          final avg = list.fold(0, (s, r) => s + r.rating) / list.length;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _averageCard(context, avg, list.length),
              const SizedBox(height: 12),
              for (final r in list) _reviewCard(r),
            ],
          );
        },
      ),
    );
  }

  Widget _averageCard(BuildContext context, double avg, int count) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Text(
              avg.toStringAsFixed(1),
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < avg.round() ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 20,
                    ),
                  ),
                ),
                Text(AppLocalizations.of(context).reviews2('$count')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewCard(Review r) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Row(
          children: [
            Expanded(child: Text(r.userName)),
            Row(
              children: List.generate(
                5,
                (i) => Icon(
                  i < r.rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
        subtitle: r.message.isEmpty ? null : Text(r.message),
      ),
    );
  }
}
