import 'package:flutter/material.dart';

import '../../../../core/models/product.dart';

/// Editors for the two structured product content blocks (Flipkart style):
///
///  * [HighlightsEditor] — N "Product Highlights" rows (Title + Value).
///  * [AllDetailsEditor] — N "All Details" sections, each either a simple
///    text paragraph or a repeatable Title & Value list.
///
/// Both are plain widgets driven by `value` + `onChanged`, so the create and
/// edit screens share exactly the same UI and validation.
class HighlightsEditor extends StatefulWidget {
  final List<HighlightItem> value;
  final ValueChanged<List<HighlightItem>> onChanged;

  /// Flips on after a failed save so empty rows show inline errors.
  final bool showErrors;

  const HighlightsEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.showErrors = false,
  });

  /// A highlights list is valid when no row is half-written. Every kept row
  /// must carry its value; the title stays optional so highlights migrated
  /// from the old plain-text field (which land as value-only rows) can still
  /// be saved without re-typing them.
  static bool isValid(List<HighlightItem> rows) {
    if (rows.isEmpty) return true; // block may be absent
    return rows.every((r) => r.isUsable || r.title.trim().isEmpty);
  }

  @override
  State<HighlightsEditor> createState() => _HighlightsEditorState();
}

class _HighlightsEditorState extends State<HighlightsEditor> {
  void _update(int index, HighlightItem item) {
    final rows = [...widget.value];
    rows[index] = item;
    widget.onChanged(rows);
  }

  void _add() {
    widget.onChanged([
      ...widget.value,
      HighlightItem(
        id: 'h_${DateTime.now().microsecondsSinceEpoch}',
        order: widget.value.length,
      ),
    ]);
  }

  void _remove(int index) {
    final rows = [...widget.value]..removeAt(index);
    widget.onChanged([
      for (var i = 0; i < rows.length; i++) rows[i].copyWith(order: i),
    ]);
  }

  void _move(int from, int to) {
    if (to < 0 || to >= widget.value.length) return;
    final rows = [...widget.value];
    final item = rows.removeAt(from);
    rows.insert(to, item);
    widget.onChanged([
      for (var i = 0; i < rows.length; i++) rows[i].copyWith(order: i),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.format_list_bulleted, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Product Highlights',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton.icon(
              key: const Key('add-highlight'),
              onPressed: _add,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Highlight'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Title and value rows shown as the compact highlights list on the product page.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 12),
        if (widget.value.isEmpty)
          Container(
            key: const Key('highlights-empty'),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.35,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'No highlights yet — tap "Add Highlight".',
              style: theme.textTheme.bodySmall,
            ),
          ),
        for (var i = 0; i < widget.value.length; i++) ...[
          HighlightRowEditor(
            key: Key('highlight-row-$i'),
            item: widget.value[i],
            index: i,
            showErrors: widget.showErrors,
            isFirst: i == 0,
            isLast: i == widget.value.length - 1,
            onChanged: (item) => _update(i, item),
            onRemove: () => _remove(i),
            onMoveUp: () => _move(i, i - 1),
            onMoveDown: () => _move(i, i + 1),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

/// One editable "Title + Value" highlight row with reorder + delete controls.
class HighlightRowEditor extends StatelessWidget {
  final HighlightItem item;
  final int index;
  final bool showErrors;
  final bool isFirst;
  final bool isLast;
  final ValueChanged<HighlightItem> onChanged;
  final VoidCallback onRemove;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  const HighlightRowEditor({
    super.key,
    required this.item,
    required this.index,
    required this.onChanged,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
    this.showErrors = false,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: Key('highlight-title-$index'),
                  initialValue: item.title,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => onChanged(item.copyWith(title: v)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  key: Key('highlight-value-$index'),
                  initialValue: item.value,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Value *',
                    isDense: true,
                    border: const OutlineInputBorder(),
                    errorText: showErrors && item.isHalfWritten
                        ? 'Required'
                        : null,
                  ),
                  onChanged: (v) => onChanged(item.copyWith(value: v)),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    tooltip: 'Move up',
                    onPressed: isFirst ? null : onMoveUp,
                    icon: const Icon(Icons.keyboard_arrow_up),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    tooltip: 'Move down',
                    onPressed: isLast ? null : onMoveDown,
                    icon: const Icon(Icons.keyboard_arrow_down),
                  ),
                ],
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                tooltip: 'Delete row',
                onPressed: onRemove,
                icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// All Details
// ---------------------------------------------------------------------------

/// Editor for the whole "All Details" block (N collapsible sections).
class AllDetailsEditor extends StatefulWidget {
  final List<DetailSection> value;
  final ValueChanged<List<DetailSection>> onChanged;
  final bool showErrors;

  const AllDetailsEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.showErrors = false,
  });

  /// Valid when every section has a title and complete content.
  static bool isValid(List<DetailSection> sections) {
    for (final s in sections) {
      if (s.title.trim().isEmpty) return false;
      if (s.isText && s.text.trim().isEmpty) return false;
      if (s.isKeyValue) {
        if (s.items.isEmpty) return false;
        if (s.items.any((i) => !i.isComplete)) return false;
      }
    }
    return true;
  }

  @override
  State<AllDetailsEditor> createState() => _AllDetailsEditorState();
}

class _AllDetailsEditorState extends State<AllDetailsEditor> {
  void _update(int index, DetailSection section) {
    final rows = [...widget.value];
    rows[index] = section;
    widget.onChanged(rows);
  }

  void _add() {
    widget.onChanged([
      ...widget.value,
      DetailSection(
        id: 'd_${DateTime.now().microsecondsSinceEpoch}',
        title: '',
        type: DetailSectionType.text,
        order: widget.value.length,
      ),
    ]);
  }

  void _remove(int index) async {
    final section = widget.value[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Section'),
        content: Text(
          'Delete "${section.title.isEmpty ? 'Untitled section' : section.title}"? '
          'Its content will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final rows = [...widget.value]..removeAt(index);
    widget.onChanged([
      for (var i = 0; i < rows.length; i++) rows[i].copyWith(order: i),
    ]);
  }

  void _move(int from, int to) {
    if (to < 0 || to >= widget.value.length) return;
    final rows = [...widget.value];
    final item = rows.removeAt(from);
    rows.insert(to, item);
    widget.onChanged([
      for (var i = 0; i < rows.length; i++) rows[i].copyWith(order: i),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.menu_book_outlined, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'All Details',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton.icon(
              key: const Key('add-detail-section'),
              onPressed: _add,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Section'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Sections shown under "All Details" on the product page — '
          'Simple Text paragraphs or Title & Value tables.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 12),
        if (widget.value.isEmpty)
          Container(
            key: const Key('details-empty'),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.35,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'No detail sections yet — tap "Add Section".',
              style: theme.textTheme.bodySmall,
            ),
          ),
        for (var i = 0; i < widget.value.length; i++) ...[
          DetailSectionEditor(
            key: Key('detail-section-$i'),
            section: widget.value[i],
            index: i,
            showErrors: widget.showErrors,
            isFirst: i == 0,
            isLast: i == widget.value.length - 1,
            onChanged: (s) => _update(i, s),
            onRemove: () => _remove(i),
            onMoveUp: () => _move(i, i - 1),
            onMoveDown: () => _move(i, i + 1),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// One collapsible "All Details" section editor card.
class DetailSectionEditor extends StatefulWidget {
  final DetailSection section;
  final int index;
  final bool showErrors;
  final bool isFirst;
  final bool isLast;
  final ValueChanged<DetailSection> onChanged;
  final VoidCallback onRemove;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  const DetailSectionEditor({
    super.key,
    required this.section,
    required this.index,
    required this.onChanged,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
    this.showErrors = false,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  State<DetailSectionEditor> createState() => _DetailSectionEditorState();
}

class _DetailSectionEditorState extends State<DetailSectionEditor> {
  // Editors start expanded so the content is immediately editable; the admin
  // can collapse a section card once done with it.
  late bool _expanded = true;

  Future<void> _onTypeChanged(String? newType) async {
    if (newType == null || newType == widget.section.type) return;
    final hasContent = widget.section.text.trim().isNotEmpty ||
        widget.section.items.any((i) => !i.isEmpty);
    if (hasContent) {
      // Changing the type clears the existing content — confirm first.
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Change Section Type'),
          content: const Text(
            'Switching the type will clear the content of this section. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Change & Clear'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    widget.onChanged(
      widget.section.copyWith(
        type: newType,
        text: newType == DetailSectionType.text ? widget.section.text : '',
        items: newType == DetailSectionType.keyValue
            ? widget.section.items
            : const <DetailItem>[],
      ),
    );
    // A type switch should reveal the (now empty) content to edit.
    if (mounted) setState(() => _expanded = true);
  }

  void _updateItem(int i, DetailItem item) {
    final rows = [...widget.section.items];
    rows[i] = item;
    widget.onChanged(widget.section.copyWith(items: rows));
  }

  void _addItem() {
    widget.onChanged(
      widget.section.copyWith(
        items: [
          ...widget.section.items,
          DetailItem(
            id: 'i_${DateTime.now().microsecondsSinceEpoch}',
            order: widget.section.items.length,
          ),
        ],
      ),
    );
  }

  void _removeItem(int i) {
    final rows = [...widget.section.items]..removeAt(i);
    widget.onChanged(
      widget.section.copyWith(
        items: [
          for (var j = 0; j < rows.length; j++) rows[j].copyWith(order: j),
        ],
      ),
    );
  }

  void _moveItem(int from, int to) {
    if (to < 0 || to >= widget.section.items.length) return;
    final rows = [...widget.section.items];
    final item = rows.removeAt(from);
    rows.insert(to, item);
    widget.onChanged(
      widget.section.copyWith(
        items: [
          for (var j = 0; j < rows.length; j++) rows[j].copyWith(order: j),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = widget.section;
    final isText = s.type == DetailSectionType.text;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: chevron + title field + type + reorder + delete
          InkWell(
            key: Key('detail-section-toggle-${widget.index}'),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(
                children: [
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    size: 20,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.title.trim().isEmpty
                          ? 'Untitled section'
                          : s.title.trim(),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isText ? 'Simple Text' : 'Title & Value',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    tooltip: 'Move up',
                    onPressed: widget.isFirst ? null : widget.onMoveUp,
                    icon: const Icon(Icons.keyboard_arrow_up),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    tooltip: 'Move down',
                    onPressed: widget.isLast ? null : widget.onMoveDown,
                    icon: const Icon(Icons.keyboard_arrow_down),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    tooltip: 'Delete section',
                    onPressed: widget.onRemove,
                    icon: Icon(
                      Icons.delete_outline,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: Key('detail-section-title-${widget.index}'),
                    initialValue: s.title,
                    style: const TextStyle(fontSize: 13.5),
                    decoration: InputDecoration(
                      labelText: 'Section Title *',
                      hintText: 'e.g. Description, General, Display Features',
                      isDense: true,
                      border: const OutlineInputBorder(),
                      errorText:
                          widget.showErrors && s.title.trim().isEmpty
                          ? 'Section title is required'
                          : null,
                    ),
                    onChanged: (v) => widget.onChanged(s.copyWith(title: v)),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: DetailSectionType.isValid(s.type)
                        ? s.type
                        : DetailSectionType.text,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Section Type *',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: DetailSectionType.text,
                        child: Text('Simple Text'),
                      ),
                      DropdownMenuItem(
                        value: DetailSectionType.keyValue,
                        child: Text('Title & Value'),
                      ),
                    ],
                    onChanged: _onTypeChanged,
                  ),
                  const SizedBox(height: 10),
                  if (isText) ...[
                    TextFormField(
                      key: Key('detail-section-text-${widget.index}'),
                      initialValue: s.text,
                      maxLines: 5,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Text *',
                        hintText: 'Long description shown as a paragraph...',
                        alignLabelWithHint: true,
                        border: const OutlineInputBorder(),
                        errorText:
                            widget.showErrors && s.text.trim().isEmpty
                            ? 'Text is required'
                            : null,
                      ),
                      onChanged: (v) =>
                          widget.onChanged(s.copyWith(text: v)),
                    ),
                  ] else ...[
                    if (widget.showErrors && s.items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Add at least one complete title & value row',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    for (var i = 0; i < s.items.length; i++) ...[
                      KeyValueRowEditor(
                        key: Key('detail-item-${widget.index}-$i'),
                        item: s.items[i],
                        index: i,
                        showErrors: widget.showErrors,
                        isFirst: i == 0,
                        isLast: i == s.items.length - 1,
                        onChanged: (item) => _updateItem(i, item),
                        onRemove: () => _removeItem(i),
                        onMoveUp: () => _moveItem(i, i - 1),
                        onMoveDown: () => _moveItem(i, i + 1),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        key: Key('add-detail-item-${widget.index}'),
                        onPressed: _addItem,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Row'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One editable Title & Value row inside a keyValue detail section.
class KeyValueRowEditor extends StatelessWidget {
  final DetailItem item;
  final int index;
  final bool showErrors;
  final bool isFirst;
  final bool isLast;
  final ValueChanged<DetailItem> onChanged;
  final VoidCallback onRemove;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  const KeyValueRowEditor({
    super.key,
    required this.item,
    required this.index,
    required this.onChanged,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
    this.showErrors = false,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      key: Key('key-value-row-$index'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            initialValue: item.title,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Title *',
              isDense: true,
              border: const OutlineInputBorder(),
              errorText: showErrors && item.title.trim().isEmpty
                  ? 'Required'
                  : null,
            ),
            onChanged: (v) => onChanged(item.copyWith(title: v)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            initialValue: item.value,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Value *',
              isDense: true,
              border: const OutlineInputBorder(),
              errorText: showErrors && item.value.trim().isEmpty
                  ? 'Required'
                  : null,
            ),
            onChanged: (v) => onChanged(item.copyWith(value: v)),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              tooltip: 'Move up',
              onPressed: isFirst ? null : onMoveUp,
              icon: const Icon(Icons.keyboard_arrow_up),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              tooltip: 'Move down',
              onPressed: isLast ? null : onMoveDown,
              icon: const Icon(Icons.keyboard_arrow_down),
            ),
          ],
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          iconSize: 18,
          tooltip: 'Delete row',
          onPressed: onRemove,
          icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
        ),
      ],
    );
  }
}
