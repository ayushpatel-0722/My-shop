import 'package:flutter/material.dart';

/// Reusable section title with an optional "view all" action.
class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAll;

  const SectionHeader({super.key, required this.title, this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        if (onViewAll != null)
          TextButton(onPressed: onViewAll, child: const Text('View all')),
      ],
    );
  }
}
