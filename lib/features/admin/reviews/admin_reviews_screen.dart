import '../../../app/routes/app_router.dart';
import 'package:flutter/material.dart';

import '../../../core/models/review.dart';
import '../../../core/services/service_locator.dart';
import '../admin_shell.dart';
import 'package:myshop/app/l10n/app_localizations.dart';

/// Reviews panel — view all ratings, hide inappropriate ones (Section 14.2).
class AdminReviewsScreen extends StatelessWidget {
  const AdminReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      showBack: true,
      backRoute: AppRoutes.admin,
      title: AppLocalizations.of(context).reviews,
      child: StreamBuilder<List<Review>>(
        stream: repo.reviews(''),
        builder: (context, snap) {
          final list = snap.data ?? const <Review>[];
          if (list.isEmpty) {
            return Center(child: Text(AppLocalizations.of(context).noReviewsYet));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final r = list[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Row(
                    children: [
                      Expanded(child: Text(r.userName)),
                      Row(
                        children: List.generate(
                            5,
                            (j) => Icon(
                                  j < r.rating ? Icons.star : Icons.star_border,
                                  color: Colors.amber,
                                  size: 16,
                                )),
                      ),
                    ],
                  ),
                  subtitle: r.message.isEmpty ? null : Text(r.message),
                  trailing: IconButton(
                    icon: Icon(r.isVisible
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () =>
                        repo.setReviewVisibility(r.id, !r.isVisible),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
