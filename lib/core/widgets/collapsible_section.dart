import 'package:flutter/material.dart';
import 'package:my_shop/app/l10n/app_localizations.dart';

/// Collapsible tile with a title row, a rotating arrow and animated content.
///
/// Collapsed (default) it shows only [title] and a dropdown arrow ▼ on the
/// right; tapping the row or the arrow expands the content and rotates the
/// arrow to ▲. Several sections can be open at the same time (the parent keeps
/// the expansion state, or use [initiallyExpanded] for local state).
class CollapsibleSection extends StatefulWidget {
  final String title;

  /// Section content, only laid out while expanded.
  final Widget child;
  final bool initiallyExpanded;
  final VoidCallback? onExpanded;

  /// Style of the title row.
  final TextStyle? titleStyle;
  final EdgeInsetsGeometry? contentPadding;

  /// Thin divider drawn under the title row when collapsed.
  final bool showDivider;

  const CollapsibleSection({
    super.key,
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
    this.onExpanded,
    this.titleStyle,
    this.contentPadding,
    this.showDivider = true,
  });

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection> {
  late bool _expanded = widget.initiallyExpanded;

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) widget.onExpanded?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle =
        widget.titleStyle ??
        theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 15.5,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            key: Key('collapsible-toggle-${widget.title}'),
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: titleStyle,
                      key: Key('collapsible-title-${widget.title}'),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 22,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Padding(
                  padding:
                      widget.contentPadding ??
                      const EdgeInsets.only(bottom: 12),
                  child: widget.child,
                )
              : const SizedBox(width: double.infinity),
        ),
        if (widget.showDivider && !_expanded)
          Divider(height: 1, thickness: 0.6, color: theme.dividerColor),
      ],
    );
  }
}

/// Two-column Title / Value table used by the "keyValue" detail sections.
///
/// Title in grey on the left, value in dark text on the right, with a thin
/// divider between rows. Empty rows are skipped and the widget collapses to
/// nothing when there is nothing to show.
class KeyValueTable extends StatelessWidget {
  final List<({String title, String value})> rows;
  final bool compact;

  const KeyValueTable({super.key, required this.rows, this.compact = true});

  @override
  Widget build(BuildContext context) {
    final visible = rows
        .where((r) => r.title.trim().isNotEmpty || r.value.trim().isNotEmpty)
        .toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < visible.length; i++) ...[
          Padding(
            padding: EdgeInsets.symmetric(vertical: compact ? 8 : 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    visible[i].title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Text(
                    visible[i].value,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (i != visible.length - 1)
            Divider(height: 1, thickness: 0.5, color: theme.dividerColor),
        ],
      ],
    );
  }
}

/// Paragraph text that collapses to ~4 lines with a "Read more" toggle.
class ExpandableText extends StatefulWidget {
  final String text;
  final int maxLines;

  const ExpandableText({super.key, required this.text, this.maxLines = 4});

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      fontSize: 13.5,
      height: 1.45,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          style: textStyle,
          maxLines: _expanded ? null : widget.maxLines,
          overflow: _expanded ? null : TextOverflow.ellipsis,
        ),
        // "Read more" only when the text plausibly overflows the clamp.
        if (!_expanded && _estimateLines(widget.text) > widget.maxLines)
          GestureDetector(
            key: const Key('expandable-read-more'),
            onTap: () => setState(() => _expanded = true),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                AppLocalizations.of(context).readMore,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        if (_expanded)
          GestureDetector(
            key: const Key('expandable-read-less'),
            onTap: () => setState(() => _expanded = false),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                AppLocalizations.of(context).readLess,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Cheap line estimate (~38 chars/line at typical phone widths).
  static int _estimateLines(String text) {
    if (text.isEmpty) return 0;
    final paragraphs = text.split('\n');
    var lines = 0;
    for (final p in paragraphs) {
      lines += (p.length / 38).ceil().clamp(1, 1 << 20);
    }
    return lines == 0 ? 1 : lines;
  }
}
