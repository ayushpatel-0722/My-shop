import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Small monospace chip showing a document id; tapping copies it.
///
/// Used by the admin product / category / order lists. The id is the handle
/// support and deep links use, so it has to be copyable on every platform
/// (including web, where long-press selection is unavailable).
class CopyableIdBadge extends StatelessWidget {
  final String id;

  /// Noun used in the tooltip and snack bar, e.g. `Product`.
  final String label;

  const CopyableIdBadge({super.key, required this.id, this.label = 'ID'});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: 'Copy $label ID',
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () {
          Clipboard.setData(ClipboardData(text: id));
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$label ID copied to clipboard: $id'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  'ID: $id',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.copy_rounded,
                size: 12,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
