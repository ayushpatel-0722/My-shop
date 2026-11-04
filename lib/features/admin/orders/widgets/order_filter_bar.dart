import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/l10n/app_localizations.dart';

/// Search + date range + "clear" for an orders list.
///
/// Shared by the Admin pipeline and the Employee queue so both look and
/// behave the same.
///
/// * Wide (>= 640 px): one horizontal row - search grows, the date range and
///   clear sit beside it.
/// * Narrow: search on its own row, then the date range and clear below it.
class OrderFilterBar extends StatelessWidget {
  const OrderFilterBar({
    super.key,
    required this.searchController,
    required this.searchHint,
    required this.onSearchChanged,
    required this.dateRange,
    required this.onDateRangeChanged,
    required this.onClear,
    required this.hasActiveFilters,
    this.searchKey,
  });

  final TextEditingController searchController;
  final String searchHint;
  final ValueChanged<String> onSearchChanged;
  final DateTimeRange? dateRange;
  final ValueChanged<DateTimeRange?> onDateRangeChanged;
  final VoidCallback onClear;
  final bool hasActiveFilters;
  final Key? searchKey;

  Future<void> _pickRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: dateRange,
      helpText: AppLocalizations.of(context).orderFilterPickDate,
    );
    if (picked != null) onDateRangeChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    final search = TextField(
      key: searchKey,
      controller: searchController,
      onChanged: onSearchChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: searchHint,
        prefixIcon: const Icon(Icons.search),
        isDense: true,
        suffixIcon: searchController.text.isEmpty
            ? null
            : IconButton(
                tooltip: l10n.clearSearch,
                icon: const Icon(Icons.close),
                onPressed: () {
                  searchController.clear();
                  onSearchChanged('');
                },
              ),
      ),
    );

    final fmt = DateFormat('d MMM');
    final range = dateRange;
    final dateLabel = range == null
        ? l10n.orderFilterAnyDate
        : '${fmt.format(range.start)} - ${fmt.format(range.end)}';
    final dateButton = OutlinedButton.icon(
      key: const Key('order-filter-date'),
      icon: const Icon(Icons.calendar_today_outlined, size: 18),
      label: Text(dateLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        foregroundColor: range == null ? scheme.onSurface : scheme.primary,
        side: BorderSide(
          color: range == null ? scheme.outlineVariant : scheme.primary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: () => _pickRange(context),
    );
    final clearButton = TextButton(
      key: const Key('order-filter-clear'),
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: hasActiveFilters ? onClear : null,
      child: Text(l10n.orderFilterClear),
    );

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 640;
        if (wide) {
          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: dateButton,
              ),
              const SizedBox(width: 8),
              clearButton,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            search,
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: dateButton),
                const SizedBox(width: 8),
                clearButton,
              ],
            ),
          ],
        );
      },
    );
  }
}

/// True when [created] falls inside [range] (whole days, both ends included).
/// A missing date never matches an active range.
bool orderInDateRange(DateTime? created, DateTimeRange? range) {
  if (range == null) return true;
  if (created == null) return false;
  final local = created.toLocal();
  final start = DateTime(range.start.year, range.start.month, range.start.day);
  final end = DateTime(
    range.end.year,
    range.end.month,
    range.end.day,
    23,
    59,
    59,
    999,
  );
  return !local.isBefore(start) && !local.isAfter(end);
}
